import Foundation

final class OrphanedFilesService {
    static let shared = OrphanedFilesService()
    
    private let knownOrphanLocations: [(path: String, keyPath: String)] = [
        (NSHomeDirectory() + "/Library/Application Support", "Application Support"),
        (NSHomeDirectory() + "/Library/Caches", "Caches"),
        (NSHomeDirectory() + "/Library/Preferences", "Preferences"),
        (NSHomeDirectory() + "/Library/Containers", "Containers"),
        (NSHomeDirectory() + "/Library/Group Containers", "Group Containers"),
        (NSHomeDirectory() + "/Library/Logs", "Logs"),
        (NSHomeDirectory() + "/Library/Saved Application State", "Saved State"),
        (NSHomeDirectory() + "/Library/WebKit", "WebKit"),
        ("/Library/Application Support", "Application Support"),
        ("/Library/Caches", "Caches"),
        ("/Library/Logs", "Logs"),
        ("/Library/Preferences", "Preferences"),
    ]
    
    private init() {}
    
    func scanForOrphanedFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        let installedApps = await getInstalledAppBundleIdentifiers()
        
        await withTaskGroup(of: [ScanResult].self) { group in
            for location in knownOrphanLocations {
                group.addTask {
                    await self.scanLocation(location.path, installedApps: installedApps)
                }
            }
            
            for await locationResults in group {
                results.append(contentsOf: locationResults)
            }
        }
        
        return results.sorted { $0.size > $1.size }
    }
    
    private func getInstalledAppBundleIdentifiers() async -> Set<String> {
        var bundleIds = Set<String>()
        
        let appPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        
        for appPath in appPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appPath) else {
                continue
            }
            
            for item in contents where item.hasSuffix(".app") {
                let appPathFull = (appPath as NSString).appendingPathComponent(item)
                if let bundleId = extractBundleIdentifier(from: appPathFull) {
                    bundleIds.insert(bundleId)
                    // Also insert the name as a potential identifier for matching
                    let name = (item as NSString).deletingPathExtension
                    bundleIds.insert(name.lowercased())
                }
            }
        }
        
        return bundleIds
    }
    
    private func scanLocation(_ path: String, installedApps: Set<String>) async -> [ScanResult] {
        var results: [ScanResult] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return results }
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return results
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else { continue }
            
            let potentialBundleId = normalizeBundleIdentifier(item)
            
            // Skip Apple and System related files
            if isSystemRelated(item) { continue }
            
            // Check if this belongs to an installed app
            let isOrphaned = !installedApps.contains { installedId in
                installedId == potentialBundleId || 
                installedId == item.lowercased() ||
                installedId.contains(potentialBundleId) ||
                (potentialBundleId.count > 5 && installedId.contains(potentialBundleId))
            }
            
            if isOrphaned {
                let size = isDirectory.boolValue ? calculateDirectorySize(at: itemPath) : (try? fileManager.attributesOfItem(atPath: itemPath)[.size] as? Int64) ?? 0
                
                if size > 0 {
                    results.append(ScanResult(
                        path: itemPath,
                        name: item,
                        size: size,
                        category: .orphaned,
                        confidence: calculateConfidence(appName: item),
                        reason: "Residual files from uninstalled application: \(item)",
                        isDirectory: isDirectory.boolValue,
                        bundleIdentifier: potentialBundleId
                    ))
                }
            }
        }
        
        return results
    }
    
    private func isSystemRelated(_ name: String) -> Bool {
        let systemPrefixes = ["com.apple", "apple", "system", "local", "network", "security", "uikit", "swift"]
        let lowerName = name.lowercased()
        return systemPrefixes.contains { lowerName.hasPrefix($0) } || lowerName.contains(".apple.")
    }
    
    private func normalizeBundleIdentifier(_ name: String) -> String {
        var normalized = name
            .replacingOccurrences(of: " ", with: ".")
            .replacingOccurrences(of: "-", with: ".")
            .lowercased()
        
        // Remove common suffixes and prefixes
        let junkStrings = [".app", ".appdata", ".preferences", ".support", "com.", "org.", "net."]
        for junk in junkStrings {
            normalized = normalized.replacingOccurrences(of: junk, with: "")
        }
        
        return normalized
    }
    
    private func calculateConfidence(appName: String) -> Double {
        // Higher confidence for known app patterns
        let knownHeuristicApps = ["android", "google", "microsoft", "adobe", "dropbox", "slack", "zoom", "discord", "spotify", "steam"]
        
        for knownApp in knownHeuristicApps {
            if appName.lowercased().contains(knownApp) {
                return 0.9
            }
        }
        
        // Default confidence
        return 0.7
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
        
        guard let enumerator = FileManager.default.enumerator(
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
}