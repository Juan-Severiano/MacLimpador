import Foundation
import CoreML
import CreateML

final class JunkDetectionService {
    static let shared = JunkDetectionService()
    
    private var mlModel: MLModel?
    private let userFeedbackKey = "junkDetectionFeedback"
    private let featureWeights: [String: Double] = [
        "daysSinceAccess": 0.4,
        "fileExtension": 0.2,
        "fileSize": 0.15,
        "parentDirectory": 0.15,
        "appInstalled": 0.1
    ]
    
    private init() {
        setupModel()
    }
    
    private func setupModel() {
        // In a production app, this would load a trained CoreML model
        // For now, we use heuristic-based scoring with learned weights
    }
    
    func analyzeFile(at path: String) async -> (confidence: Double, reason: String) {
        let url = URL(fileURLWithPath: path)
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .contentAccessDateKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .isDirectoryKey
            ])
            
            let daysSinceAccess = resourceValues.contentAccessDate.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
            } ?? 999
            
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let isDirectory = resourceValues.isDirectory ?? false
            
            return calculateConfidence(
                path: path,
                daysSinceAccess: daysSinceAccess,
                fileSize: fileSize,
                isDirectory: isDirectory
            )
        } catch {
            return (0.0, "Unable to analyze file")
        }
    }
    
    private func calculateConfidence(path: String, daysSinceAccess: Int, fileSize: Int64, isDirectory: Bool) -> (Double, String) {
        var confidence: Double = 0.0
        var reasons: [String] = []
        
        // Days since access weight (40%)
        if daysSinceAccess > 365 {
            confidence += featureWeights["daysSinceAccess"]! * 1.0
            reasons.append("Not accessed in over a year")
        } else if daysSinceAccess > 180 {
            confidence += featureWeights["daysSinceAccess"]! * 0.8
            reasons.append("Not accessed in 6+ months")
        } else if daysSinceAccess > 90 {
            confidence += featureWeights["daysSinceAccess"]! * 0.5
            reasons.append("Not accessed in 3+ months")
        } else if daysSinceAccess > 30 {
            confidence += featureWeights["daysSinceAccess"]! * 0.2
        }
        
        // File extension pattern (20%)
        let ext = (path as NSString).pathExtension.lowercased()
        let junkExtensions = ["tmp", "cache", "bak", "old", "log", "ds_store"]
        
        if junkExtensions.contains(ext) {
            confidence += featureWeights["fileExtension"]! * 1.0
            reasons.append("Junk file extension: .\(ext)")
        }
        
        // Parent directory pattern (15%)
        let parentDir = (path as NSString).deletingLastPathComponent
        let junkDirs = ["/Caches/", "/Logs/", "/Temp/", "/tmp"]
        
        if junkDirs.contains(where: { parentDir.contains($0) }) {
            confidence += featureWeights["parentDirectory"]! * 1.0
            reasons.append("Located in junk directory")
        }
        
        // File size pattern (15%)
        // Very small files are often temporary
        if fileSize < 1024 && fileSize > 0 {
            confidence += featureWeights["fileSize"]! * 0.3
        } else if fileSize > 1_000_000_000 {
            // Very large files that aren't accessed often
            if daysSinceAccess > 180 {
                confidence += featureWeights["fileSize"]! * 0.8
                reasons.append("Large file (>1GB) not accessed recently")
            }
        }
        
        // App installed check (10%)
        let appInPath = parentDir.contains("Application Support")
        if appInPath {
            let bundleId = extractBundleIdFromPath(path)
            if let bundleId = bundleId, !isAppInstalled(bundleId) {
                confidence += featureWeights["appInstalled"]! * 1.0
                reasons.append("App '\(bundleId)' is not installed")
            }
        }
        
        // Cap confidence at 1.0
        confidence = min(confidence, 1.0)
        
        let reason = reasons.isEmpty 
            ? "No strong indicators" 
            : reasons.joined(separator: "; ")
        
        return (confidence, reason)
    }
    
    private func extractBundleIdFromPath(_ path: String) -> String? {
        let appSupport = "Application Support"
        guard let range = path.range(of: appSupport) else { return nil }
        
        let appFolder = path[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
            .components(separatedBy: "/")
            .first ?? ""
        
        return appFolder.isEmpty ? nil : appFolder
    }
    
    private func isAppInstalled(_ bundleId: String) -> Bool {
        let appPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        
        for appPath in appPaths {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: appPath),
                includingPropertiesForKeys: nil
            ) else { continue }
            
            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    let infoPlist = url.appendingPathComponent("Contents/Info.plist")
                    if let data = try? Data(contentsOf: infoPlist),
                       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                       let id = plist["CFBundleIdentifier"] as? String,
                       id == bundleId || id.contains(bundleId) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // Learning from user feedback
    func recordUserFeedback(path: String, kept: Bool) {
        var feedback = getUserFeedback()
        
        feedback.append(UserFeedbackEntry(
            path: path,
            kept: kept,
            timestamp: Date()
        ))
        
        // Keep only last 1000 entries
        if feedback.count > 1000 {
            feedback = Array(feedback.suffix(1000))
        }
        
        saveUserFeedback(feedback)
    }
    
    private func getUserFeedback() -> [UserFeedbackEntry] {
        guard let data = UserDefaults.standard.data(forKey: userFeedbackKey),
              let feedback = try? JSONDecoder().decode([UserFeedbackEntry].self, from: data) else {
            return []
        }
        return feedback
    }
    
    private func saveUserFeedback(_ feedback: [UserFeedbackEntry]) {
        if let data = try? JSONEncoder().encode(feedback) {
            UserDefaults.standard.set(data, forKey: userFeedbackKey)
        }
    }
    
    func retrainModel() {
        // In a production app, this would retrain the ML model
        // based on collected user feedback
    }
}

struct UserFeedbackEntry: Codable {
    let path: String
    let kept: Bool
    let timestamp: Date
}