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
        case .junk: return "trash"
        case .orphaned: return "app.badge.questionmark"
        case .package: return "shippingbox"
        case .cache: return "internaldrive"
        case .log: return "doc.text"
        case .duplicate: return "doc.on.doc"
        case .temporary: return "clock"
        case .largeFile: return "arrow.up.circle"
        }
    }
}