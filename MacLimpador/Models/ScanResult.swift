import Foundation

struct ScanResult: Identifiable, Hashable {
    let id: UUID
    let path: String
    let name: String
    let size: Int64
    let category: StorageCategory
    let confidence: Double
    let reason: String
    let lastAccessed: Date?
    let lastModified: Date?
    let isDirectory: Bool
    let bundleIdentifier: String?

    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        size: Int64,
        category: StorageCategory,
        confidence: Double = 1.0,
        reason: String,
        lastAccessed: Date? = nil,
        lastModified: Date? = nil,
        isDirectory: Bool = false,
        bundleIdentifier: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.category = category
        self.confidence = confidence
        self.reason = reason
        self.lastAccessed = lastAccessed
        self.lastModified = lastModified
        self.isDirectory = isDirectory
        self.bundleIdentifier = bundleIdentifier
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var confidencePercentage: String {
        "\(Int(confidence * 100))%"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScanResult, rhs: ScanResult) -> Bool {
        lhs.id == rhs.id
    }
}