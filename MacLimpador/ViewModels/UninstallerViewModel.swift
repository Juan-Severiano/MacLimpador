import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class UninstallerViewModel {
    var apps: [InstalledApp] = []
    var isScanning: Bool = false
    var isUninstalling: Bool = false
    
    var totalSelectedSize: Int64 {
        apps.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var formattedTotalSelectedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSelectedSize)
    }
    
    init() {
        startScan()
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        
        Task {
            let foundApps = await Task.detached {
                var results: [InstalledApp] = []
                let fileManager = FileManager.default
                
                let directoriesToScan = [
                    URL(fileURLWithPath: "/Applications"),
                    fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
                ]
                
                for dir in directoriesToScan {
                    guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
                    
                    for url in contents where url.pathExtension == "app" {
                        let name = url.deletingPathExtension().lastPathComponent
                        let bundleId = Bundle(url: url)?.bundleIdentifier
                        let icon = NSWorkspace.shared.icon(forFile: url.path)
                        
                        var size = Self.calculateSize(at: url)
                        var residues: [URL] = []
                        
                        // Find residues
                        if let bundleId = bundleId {
                            let home = fileManager.homeDirectoryForCurrentUser
                            let potentialResidues = [
                                home.appendingPathComponent("Library/Application Support/\(bundleId)"),
                                home.appendingPathComponent("Library/Application Support/\(name)"),
                                home.appendingPathComponent("Library/Caches/\(bundleId)"),
                                home.appendingPathComponent("Library/Preferences/\(bundleId).plist"),
                                home.appendingPathComponent("Library/Saved Application State/\(bundleId)")
                            ]
                            
                            for res in potentialResidues {
                                if fileManager.fileExists(atPath: res.path) {
                                    residues.append(res)
                                    size += Self.calculateSize(at: res)
                                }
                            }
                        }
                        
                        results.append(InstalledApp(url: url, name: name, bundleIdentifier: bundleId, icon: icon, size: size, residueURLs: residues))
                    }
                }
                return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
            }.value
            
            self.apps = foundApps
            self.isScanning = false
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
    
    func uninstallSelected() {
        guard !isUninstalling else { return }
        isUninstalling = true
        
        Task {
            let itemsToDelete = apps.filter { $0.isSelected }
            await Task.detached {
                let fileManager = FileManager.default
                for item in itemsToDelete {
                    try? fileManager.removeItem(at: item.url)
                    for res in item.residueURLs {
                        try? fileManager.removeItem(at: res)
                    }
                }
            }.value
            
            apps.removeAll { $0.isSelected }
            isUninstalling = false
        }
    }
}