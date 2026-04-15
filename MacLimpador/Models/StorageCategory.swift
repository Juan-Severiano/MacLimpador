import Foundation

enum StorageCategory: String, CaseIterable, Codable, Identifiable {
    case junk = "Junk"
    case orphaned = "Orphaned"
    case package = "Package"
    case cache = "Cache"
    case log = "Log"
    case duplicate = "Duplicate"
    case temporary = "Temporary"
    case largeFile = "Large File"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .junk: return "Temporary and unused files"
        case .orphaned: return "Files from uninstalled apps"
        case .package: return "Package managers (Homebrew)"
        case .cache: return "Application caches"
        case .log: return "Log files"
        case .duplicate: return "Duplicate files"
        case .temporary: return "Temporary files"
        case .largeFile: return "Large files"
        }
    }

    var iconName: String {
        switch self {
        case .junk: return "trash.fill"
        case .orphaned: return "questionmark.folder.fill"
        case .package: return "shippingbox.fill"
        case .cache: return "internaldrive.fill"
        case .log: return "doc.text.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .temporary: return "clock.fill"
        case .largeFile: return "arrow.up.circle.fill"
        }
    }
}