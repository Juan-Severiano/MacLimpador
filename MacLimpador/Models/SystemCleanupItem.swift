import Foundation

struct SystemCleanupItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    var size: Int64
    var isSelected: Bool = true
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}