import Foundation

struct SystemCleanupCategory: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let urls: [URL]
    
    var items: [SystemCleanupItem] = []
    var isSelected: Bool = true
    var isCalculated: Bool = false
    var isExpanded: Bool = false
    
    var size: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var totalSizeCalculated: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}