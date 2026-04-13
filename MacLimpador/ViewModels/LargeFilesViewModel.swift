import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class LargeFilesViewModel {
    var files: [LargeFileItem] = []
    var isScanning: Bool = false
    var isDeleting: Bool = false
    var scannedDirectory: URL? = nil
    var minSizeMB: Int64 = 50
    
    var totalSelectedSize: Int64 {
        files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var formattedTotalSelectedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSelectedSize)
    }
    
    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        if panel.runModal() == .OK, let url = panel.url {
            self.scannedDirectory = url
            startScan(at: url)
        }
    }
    
    func startScan(at url: URL) {
        guard !isScanning else { return }
        isScanning = true
        files = []
        let threshold = minSizeMB * 1024 * 1024
        
        Task {
            let foundFiles = await Task.detached {
                var results: [LargeFileItem] = []
                let fileManager = FileManager.default
                
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                    return results
                }
                
                while let fileURL = enumerator.nextObject() as? URL {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                        if let isDir = resourceValues.isDirectory, isDir {
                            continue
                        }
                        
                        if let size = resourceValues.fileSize, Int64(size) >= threshold {
                            results.append(LargeFileItem(
                                url: fileURL,
                                name: fileURL.lastPathComponent,
                                size: Int64(size),
                                lastModified: resourceValues.contentModificationDate ?? Date()
                            ))
                        }
                    } catch {}
                }
                return results.sorted { $0.size > $1.size }
            }.value
            
            self.files = foundFiles
            self.isScanning = false
        }
    }
    
    func deleteSelected() {
        guard !isDeleting else { return }
        isDeleting = true
        
        Task {
            let itemsToDelete = files.filter { $0.isSelected }
            await Task.detached {
                let fileManager = FileManager.default
                for item in itemsToDelete {
                    try? fileManager.removeItem(at: item.url)
                }
            }.value
            
            files.removeAll { $0.isSelected }
            isDeleting = false
        }
    }
}