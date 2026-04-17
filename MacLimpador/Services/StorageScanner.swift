import Foundation
import AppKit

actor StorageScanner {
    static let shared = StorageScanner()
    
    private var isScanning = false
    private var scanResults: [ScanResult] = []
    
    private init() {}
    
    func scan() async throws -> [ScanResult] {
        guard !isScanning else { 
            throw StorageScannerError.scanInProgress 
        }
        
        isScanning = true
        scanResults = []
        
        defer { isScanning = false }
        
        async let junkResults = scanJunkFiles()
        async let orphanResults = scanOrphanedFiles()
        async let largeFilesResults = scanLargeFiles()
        
        let (junk, orphans, largeFiles) = await (junkResults, orphanResults, largeFilesResults)
        
        scanResults = junk + orphans + largeFiles
        
        return scanResults
    }
    
    private func scanJunkFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let tempPaths = [
            NSTemporaryDirectory(),
            NSHomeDirectory() + "/Library/Caches",
            NSHomeDirectory() + "/Library/Logs"
        ]
        
        for basePath in tempPaths {
            results.append(contentsOf: scanDirectory(at: basePath, category: .junk))
        }
        
        return results
    }
    
    private func scanOrphanedFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let applicationSupport = NSHomeDirectory() + "/Library/Application Support"
        let caches = NSHomeDirectory() + "/Library/Caches"
        
        results.append(contentsOf: scanApplicationSupportDir(at: applicationSupport))
        results.append(contentsOf: scanCachesDir(at: caches))
        
        return results
    }
    
    private func scanLargeFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let homeDir = NSHomeDirectory()
        let skipDirs = [".Trash", "Library", "Applications", "Documents", "Music", "Movies"]
        
        if let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: homeDir),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let path = fileURL.path
                if skipDirs.contains(where: { path.contains("/\($0)/") }) {
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                    
                    if let isDirectory = resourceValues.isDirectory, isDirectory {
                        continue
                    }
                    
                    if let fileSize = resourceValues.fileSize, fileSize > 100_000_000 {
                        let name = fileURL.lastPathComponent
                        let modDate = resourceValues.contentModificationDate
                        
                        results.append(ScanResult(
                            path: path,
                            name: name,
                            size: Int64(fileSize),
                            category: .largeFile,
                            confidence: 0.5,
                            reason: "Large file (>100MB)",
                            lastModified: modDate,
                            isDirectory: false
                        ))
                    }
                } catch {
                    continue
                }
            }
        }
        
        return results.sorted { $0.size > $1.size }.prefix(100).map { $0 }
    }
    
    private func scanDirectory(at path: String, category: StorageCategory) -> [ScanResult] {
        var results: [ScanResult] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return results }
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) else { return results }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .contentAccessDateKey])
                
                if let isDir = resourceValues.isDirectory, isDir {
                    continue
                }
                
                guard let fileSize = resourceValues.fileSize, fileSize > 1_000_000 else {
                    continue
                }
                
                let name = fileURL.lastPathComponent
                let modDate = resourceValues.contentModificationDate
                let accessDate = resourceValues.contentAccessDate
                let daysSinceAccess = accessDate.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 0
                
                let confidence: Double
                let reason: String
                
                if daysSinceAccess > 90 {
                    confidence = 0.9
                    reason = "Not accessed in \(daysSinceAccess) days"
                } else if daysSinceAccess > 30 {
                    confidence = 0.5
                    reason = "Not accessed in \(daysSinceAccess) days"
                } else {
                    confidence = 0.2
                    reason = "Potential junk"
                }
                
                results.append(ScanResult(
                    path: fileURL.path,
                    name: name,
                    size: Int64(fileSize),
                    category: category,
                    confidence: confidence,
                    reason: reason,
                    lastAccessed: accessDate,
                    lastModified: modDate,
                    isDirectory: false
                ))
            } catch {
                continue
            }
        }
        
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    private func scanApplicationSupportDir(at path: String) -> [ScanResult] {
        var results: [ScanResult] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return results }
        
        let installedApps = getInstalledAppBundleIdentifiers()
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return results
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            let bundleId = extractBundleIdentifier(from: itemPath)
            
            if let bundleId = bundleId, !installedApps.contains(bundleId) {
                let size = calculateDirectorySize(at: itemPath)
                
                results.append(ScanResult(
                    path: itemPath,
                    name: item,
                    size: size,
                    category: .orphaned,
                    confidence: 0.8,
                    reason: "App '\(bundleId)' is not installed",
                    isDirectory: true,
                    bundleIdentifier: bundleId
                ))
            }
        }
        
        return results
    }
    
    private func scanCachesDir(at path: String) -> [ScanResult] {
        var results: [ScanResult] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return results }
        
        let installedApps = getInstalledAppBundleIdentifiers()
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return results
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            let bundleId = item.replacingOccurrences(of: ".plist", with: "")
                .replacingOccurrences(of: ".", with: "")
            
            if !installedApps.contains(where: { $0.contains(bundleId) }) && !item.hasPrefix("com.apple") {
                let size = calculateDirectorySize(at: itemPath)
                
                results.append(ScanResult(
                    path: itemPath,
                    name: item,
                    size: size,
                    category: .orphaned,
                    confidence: 0.7,
                    reason: "Cache for uninstalled app",
                    isDirectory: true,
                    bundleIdentifier: bundleId
                ))
            }
        }
        
        return results
    }
    
    private func getInstalledAppBundleIdentifiers() -> Set<String> {
        var bundleIds = Set<String>()
        
        let appPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        
        let fileManager = FileManager.default
        
        for appPath in appPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: appPath) else {
                continue
            }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (appPath as NSString).appendingPathComponent(item)
                if let bundleId = extractBundleIdentifier(from: appPath) {
                    bundleIds.insert(bundleId)
                }
            }
        }
        
        return bundleIds
    }
    
    private func extractBundleIdentifier(from appPath: String) -> String? {
        let infoPlist = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: infoPlist)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        
        return bundleId
    }
    
    private func calculateDirectorySize(at path: String) -> Int64 {
        var totalSize: Int64 = 0
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize ?? 0)
            }
        }
        
        return totalSize
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