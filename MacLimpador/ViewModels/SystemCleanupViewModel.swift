import Foundation
import SwiftUI

@Observable
@MainActor
final class SystemCleanupViewModel {
    var categories: [SystemCleanupCategory] = []
    var isScanning: Bool = false
    var isCleaning: Bool = false
    
    var totalSize: Int64 {
        categories.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    init() {
        setupCategories()
    }
    
    private func setupCategories() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        categories = [
            SystemCleanupCategory(
                name: "Caches do Usuário",
                description: "Arquivos temporários gerados por aplicativos.",
                icon: "externaldrive",
                urls: [home.appendingPathComponent("Library/Caches")]
            ),
            SystemCleanupCategory(
                name: "Logs do Sistema",
                description: "Arquivos de registro de atividades de aplicativos.",
                icon: "doc.text",
                urls: [home.appendingPathComponent("Library/Logs")]
            ),
            SystemCleanupCategory(
                name: "Lixeira",
                description: "Arquivos descartados que ainda ocupam espaço.",
                icon: "trash",
                urls: [home.appendingPathComponent(".Trash")]
            )
        ]
    }
    
    func toggleCategorySelection(index: Int) {
        categories[index].isSelected.toggle()
        let isSelected = categories[index].isSelected
        for i in 0..<categories[index].items.count {
            categories[index].items[i].isSelected = isSelected
        }
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        
        for i in 0..<categories.count {
            categories[i].isCalculated = false
            categories[i].items = []
        }
        
        Task {
            for i in 0..<categories.count {
                let urls = categories[i].urls
                let items = await Task.detached {
                    var foundItems: [SystemCleanupItem] = []
                    let fileManager = FileManager.default
                    
                    for url in urls {
                        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
                        
                        for itemUrl in contents {
                            let size = Self.calculateSize(at: itemUrl)
                            if size > 0 {
                                foundItems.append(SystemCleanupItem(url: itemUrl, name: itemUrl.lastPathComponent, size: size))
                            }
                        }
                    }
                    
                    return foundItems.sorted { $0.size > $1.size }
                }.value
                
                categories[i].items = items
                categories[i].isCalculated = true
            }
            
            isScanning = false
        }
    }
    
    nonisolated private static func calculateSize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else { return 0 }
                while let fileURL = enumerator.nextObject() as? URL {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        if let fileSize = resourceValues.fileSize {
                            size += Int64(fileSize)
                        }
                    } catch {}
                }
            } else {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = resourceValues.fileSize {
                        size += Int64(fileSize)
                    }
                } catch {}
            }
        }
        return size
    }
    
    func cleanSelected() {
        guard !isCleaning else { return }
        isCleaning = true
        
        Task {
            for i in 0..<categories.count {
                if categories[i].isSelected {
                    let itemsToClean = categories[i].items.filter { $0.isSelected }
                    await Task.detached {
                        let fileManager = FileManager.default
                        for item in itemsToClean {
                            do {
                                try fileManager.removeItem(at: item.url)
                            } catch { }
                        }
                    }.value
                    
                    // Remove cleaned items from the list
                    categories[i].items.removeAll { $0.isSelected }
                }
            }
            
            isCleaning = false
        }
    }
}