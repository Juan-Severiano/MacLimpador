import Foundation

final class OrphanedFilesService {
    static let shared = OrphanedFilesService()
    
    private let knownOrphanLocations: [(path: String, keyPath: String)] = [
        (NSHomeDirectory() + "/Library/Application Support", "Application Support"),
        (NSHomeDirectory() + "/Library/Caches", "Caches"),
        (NSHomeDirectory() + "/Library/Preferences", "Preferences"),
        (NSHomeDirectory() + "/Library/Containers", "Containers"),
        (NSHomeDirectory() + "/Library/Group Containers", "Group Containers"),
        ("/Library/Application Support", "Application Support"),
    ]
    
    private init() {}
    
    func scanForOrphanedFiles() async -> [ScanResult] {
        var results: [ScanResult] = []
        let installedApps = await getInstalledAppBundleIdentifiers()
        
        for location in knownOrphanLocations {
            let orphans = await scanLocation(location.path, installedApps: installedApps)
            results.append(contentsOf: orphans)
        }
        
        return results.sorted { $0.size > $1.size }
    }
    
    private func getInstalledAppBundleIdentifiers() async -> Set<String> {
        var bundleIds = Set<String>()
        
        let appPaths = [
            "/Applications",
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
            
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            let potentialBundleId = normalizeBundleIdentifier(item)
            
            // Check if this belongs to an installed app
            let isOrphaned = !installedApps.contains { installedId in
                installedId == potentialBundleId || 
                installedId.contains(potentialBundleId) ||
                potentialBundleId.contains(installedId)
            }
            
            // Also check for Apple apps (they're always installed)
            let isAppleApp = item.hasPrefix("com.apple") || 
                            item.hasPrefix("Apple") ||
                            item.contains("com.apple.")
            
            if isOrphaned && !isAppleApp {
                let size = calculateDirectorySize(at: itemPath)
                
                results.append(ScanResult(
                    path: itemPath,
                    name: item,
                    size: size,
                    category: .orphaned,
                    confidence: calculateConfidence(appName: item),
                    reason: "App folder remains from uninstalled application",
                    isDirectory: true,
                    bundleIdentifier: potentialBundleId
                ))
            }
        }
        
        return results
    }
    
    private func normalizeBundleIdentifier(_ name: String) -> String {
        var normalized = name
            .replacingOccurrences(of: " ", with: ".")
            .replacingOccurrences(of: "-", with: ".")
            .lowercased()
        
        // Remove common suffixes
        let suffixes = [".app", ".appdata", ".preferences", ".support"]
        for suffix in suffixes {
            if normalized.hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count))
            }
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