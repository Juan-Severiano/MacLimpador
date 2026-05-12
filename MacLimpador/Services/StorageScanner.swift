import Foundation
import AppKit

actor StorageScanner {
    static let shared = StorageScanner()
    
    private var isScanning = false
    private var scanResults: [ScanResult] = []
    
    private init() {}
    
    func scan() -> AsyncStream<[ScanResult]> {
        AsyncStream { continuation in
            let task = Task {
                guard !isScanning else {
                    continuation.finish()
                    return
                }
                
                isScanning = true
                scanResults = []
                
                // 1. Scan por categorias de forma sequencial para não sobrecarregar
                
                // Pacotes
                let packages = await scanPackages()
                scanResults.append(contentsOf: packages)
                continuation.yield(packages)
                
                // Órfãos
                let orphans = await OrphanedFilesService.shared.scanForOrphanedFiles()
                scanResults.append(contentsOf: orphans)
                continuation.yield(orphans)
                
                // Arquivos Grandes
                let largeFiles = await scanLargeFiles()
                scanResults.append(contentsOf: largeFiles)
                continuation.yield(largeFiles)
                
                // Junk (Lixo) - Geralmente o mais demorado
                let junk = await scanJunkFiles()
                var scoredJunk: [ScanResult] = []
                for item in junk {
                    if !isScanning { break }
                    let (confidence, reason) = await JunkDetectionService.shared.analyzeFile(at: item.path)
                    if confidence > 0.1 {
                        let result = ScanResult(
                            path: item.path,
                            name: item.name,
                            size: item.size,
                            category: item.category,
                            confidence: confidence,
                            reason: reason,
                            lastAccessed: item.lastAccessed,
                            lastModified: item.lastModified,
                            isDirectory: item.isDirectory
                        )
                        scoredJunk.append(result)
                    }
                }
                scanResults.append(contentsOf: scoredJunk)
                continuation.yield(scoredJunk)
                
                isScanning = false
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    private func scanPackages() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        // 1. Homebrew packages
        let brewResults = await HomebrewService.shared.getPackagesAsScanResults()
        results.append(contentsOf: brewResults)
        
        // 2. Common binary locations
        let binPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"]
        let fileManager = FileManager.default
        
        for basePath in binPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: basePath) else { continue }
            
            for item in contents {
                let path = (basePath as NSString).appendingPathComponent(item)
                
                // Skip symbolic links (most are links to the actual binary elsewhere, brew does this)
                // But we want to see the "real" ones or those that aren't links
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: path)
                    if let type = attributes[.type] as? FileAttributeType, type == .typeSymbolicLink {
                        continue
                    }
                    
                    let size = (attributes[.size] as? Int64) ?? 0
                    if size > 1_000_000 { // Only care about binaries > 1MB
                        results.append(ScanResult(
                            path: path,
                            name: item,
                            size: size,
                            category: .package,
                            confidence: 0.1,
                            reason: "System binary or tool",
                            isDirectory: false
                        ))
                    }
                } catch { continue }
            }
        }
        
        return results
    }
    
    private func scanJunkFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let junkPaths = [
            NSTemporaryDirectory(),
            NSHomeDirectory() + "/Library/Caches",
            NSHomeDirectory() + "/Library/Logs",
            NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData",
            NSHomeDirectory() + "/Downloads",
            "/Library/Caches",
            "/Library/Logs"
        ]
        
        for basePath in junkPaths {
            results.append(contentsOf: await scanDirectoryForJunk(at: basePath))
        }
        
        return results
    }
    
    private func scanDirectoryForJunk(at path: String) async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return results }
        
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .contentAccessDateKey],
            options: options
        ) else { return results }
        
        var count = 0
        for case let fileURL as URL in enumerator {
            if !isScanning { break }
            
            // Limit to 1000 items per base path to avoid massive scans in MVP
            count += 1
            if count > 1000 { break }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .contentAccessDateKey])
                
                let isDir = resourceValues.isDirectory ?? false
                if isDir {
                    // Only include directories if they are specific junk types
                    if !fileURL.path.contains("DerivedData") && !fileURL.path.contains("Caches") {
                        continue
                    }
                }
                
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                // Small files are usually not worth cleaning individually unless confidence is high
                if !isDir && fileSize < 100_000 { continue } 
                
                results.append(ScanResult(
                    path: fileURL.path,
                    name: fileURL.lastPathComponent,
                    size: fileSize,
                    category: .junk,
                    confidence: 0.5,
                    reason: "Analyzing...",
                    lastAccessed: resourceValues.contentAccessDate,
                    lastModified: resourceValues.contentModificationDate,
                    isDirectory: isDir
                ))
            } catch {
                continue
            }
        }
        
        return results
    }
    
    private func scanLargeFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let homeDir = NSHomeDirectory()
        let skipDirs = [".Trash", "Library", "Applications"]
        
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: homeDir),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var count = 0
        for case let fileURL as URL in enumerator {
            if !isScanning { break }
            count += 1
            if count > 10000 { break } // Sanity limit
            
            let path = fileURL.path
            if skipDirs.contains(where: { path.contains("/\($0)/") }) {
                enumerator.skipDescendants()
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    continue
                }
                
                if let fileSize = resourceValues.fileSize, fileSize > 100_000_000 {
                    results.append(ScanResult(
                        path: path,
                        name: fileURL.lastPathComponent,
                        size: Int64(fileSize),
                        category: .largeFile,
                        confidence: 0.5,
                        reason: "Large file (>100MB)",
                        lastModified: resourceValues.contentModificationDate,
                        isDirectory: false
                    ))
                }
            } catch {
                continue
            }
        }
        
        return results.sorted { $0.size > $1.size }.prefix(50).map { $0 }
    }
    
    func cancelScan() {
        isScanning = false
    }
    
    var scanning: Bool {
        isScanning
    }
}

enum StorageScannerError: Error, LocalizedError {
    case scanInProgress
    case scanFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .scanInProgress:
            return "A scan is already in progress"
        case .scanFailed(let message):
            return "Scan failed: \(message)"
        }
    }
}
