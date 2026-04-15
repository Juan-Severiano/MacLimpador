import Foundation

final class DeletionService {
    static let shared = DeletionService()
    
    private let fileManager = FileManager.default
    private let blocklistPath = "deletion_blocklist"
    
    private let protectedPaths: Set<String> = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/var",
        "/Library/Keychains",
        "/Library/Logs",
        "/private"
    ]
    
    private init() {
        loadBlocklist()
    }
    
    func previewDeletion(_ items: [ScanResult]) -> DeletionPreview {
        var totalSize: Int64 = 0
        var warnings: [String] = []
        var details: [DeletionDetail] = []
        
        for item in items {
            let isProtected = isPathProtected(item.path)
            
            if isProtected {
                warnings.append("Protected: \(item.path)")
            }
            
            let detail = DeletionDetail(
                path: item.path,
                name: item.name,
                size: item.size,
                willMoveToTrash: true,
                isProtected: isProtected
            )
            
            details.append(detail)
            totalSize += item.size
        }
        
        return DeletionPreview(
            totalSize: totalSize,
            itemCount: items.count,
            warnings: warnings,
            details: details
        )
    }
    
    func deleteItems(_ items: [ScanResult], permanent: Bool = false) async throws -> DeletionResult {
        var deletedCount = 0
        var freedSpace: Int64 = 0
        var failures: [String] = []
        let timestamp = Date()
        
        for item in items {
            guard !isPathProtected(item.path) else {
                failures.append("Protected: \(item.name)")
                continue
            }
            
            let url = URL(fileURLWithPath: item.path)
            
            do {
                if permanent {
                    try fileManager.removeItem(at: url)
                } else {
                    var resultingURL: NSURL?
                    try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                }
                
                deletedCount += 1
                freedSpace += item.size
                
                // Log deletion
                logDeletion(item: item, permanent: permanent, timestamp: timestamp)
            } catch {
                failures.append("\(item.name): \(error.localizedDescription)")
            }
        }
        
        return DeletionResult(
            deletedCount: deletedCount,
            freedSpace: freedSpace,
            failures: failures
        )
    }
    
    private func isPathProtected(_ path: String) -> Bool {
        for protected in protectedPaths {
            if path.hasPrefix(protected) {
                return true
            }
        }
        return false
    }
    
    private func loadBlocklist() {
        // Load custom blocklist from user defaults
    }
    
    private func logDeletion(item: ScanResult, permanent: Bool, timestamp: Date) {
        var logs = getDeletionLogs()
        
        logs.append(DeletionLog(
            path: item.path,
            size: item.size,
            category: item.category.rawValue,
            permanent: permanent,
            timestamp: timestamp
        ))
        
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: "deletionLogs")
        }
    }
    
    func getDeletionLogs() -> [DeletionLog] {
        guard let data = UserDefaults.standard.data(forKey: "deletionLogs"),
              let logs = try? JSONDecoder().decode([DeletionLog].self, from: data) else {
            return []
        }
        return logs
    }
    
    func restoreFromTrash(path: String) throws {
        let homeDir = NSHomeDirectory()
        let trashPath = homeDir + "/.Trash"
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: trashPath) else {
            throw DeletionError.restoreFailed
        }
        
        for item in contents {
            let trashItemPath = (trashPath as NSString).appendingPathComponent(item)
            if trashItemPath.contains(path) {
                try fileManager.moveItem(
                    at: URL(fileURLWithPath: trashItemPath),
                    to: URL(fileURLWithPath: path)
                )
                return
            }
        }
        
        throw DeletionError.restoreFailed
    }
}

struct DeletionPreview {
    let totalSize: Int64
    let itemCount: Int
    let warnings: [String]
    let details: [DeletionDetail]
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct DeletionDetail {
    let path: String
    let name: String
    let size: Int64
    let willMoveToTrash: Bool
    let isProtected: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct DeletionResult {
    let deletedCount: Int
    let freedSpace: Int64
    let failures: [String]
    
    var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file)
    }
}

struct DeletionLog: Codable {
    let path: String
    let size: Int64
    let category: String
    let permanent: Bool
    let timestamp: Date
}

enum DeletionError: Error, LocalizedError {
    case restoreFailed
    case protectedPath
    
    var errorDescription: String? {
        switch self {
        case .restoreFailed:
            return "Failed to restore file from Trash"
        case .protectedPath:
            return "Cannot delete protected system path"
        }
    }
}