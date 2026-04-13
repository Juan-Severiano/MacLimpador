import Foundation
import AppKit

struct InstalledApp: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage
    var size: Int64
    var isSelected: Bool = false
    var residueURLs: [URL] = []
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}