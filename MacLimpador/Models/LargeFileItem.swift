import Foundation

struct LargeFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let lastModified: Date
    var isSelected: Bool = false
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}