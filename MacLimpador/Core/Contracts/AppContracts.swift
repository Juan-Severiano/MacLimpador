import Foundation

// MARK: - Cleanup

nonisolated enum CleanupTargetDisposition: String, Codable, Sendable {
    case trash
    case permanent
}

nonisolated enum CleanupRiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

nonisolated struct CleanupTarget: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let path: String
    let displayName: String
    let category: String
    let size: Int64
    let disposition: CleanupTargetDisposition
    let riskLevel: CleanupRiskLevel

    init(
        id: UUID = UUID(),
        path: String,
        displayName: String,
        category: String,
        size: Int64,
        disposition: CleanupTargetDisposition = .trash,
        riskLevel: CleanupRiskLevel = .low
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.category = category
        self.size = size
        self.disposition = disposition
        self.riskLevel = riskLevel
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

nonisolated struct CleanupPlan: Sendable {
    let id: UUID
    let createdAt: Date
    let targets: [CleanupTarget]

    init(id: UUID = UUID(), createdAt: Date = Date(), targets: [CleanupTarget]) {
        self.id = id
        self.createdAt = createdAt
        self.targets = targets
    }

    var totalSize: Int64 {
        targets.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

nonisolated struct DryRunReport: Sendable {
    let createdAt: Date
    let targetCount: Int
    let totalReclaimableSize: Int64
    let warnings: [String]

    var formattedTotalReclaimableSize: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableSize, countStyle: .file)
    }
}

nonisolated struct CleanupExecutionResult: Sendable {
    let startedAt: Date
    let finishedAt: Date
    let deletedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let reclaimedSize: Int64
    let failures: [String]

    var formattedReclaimedSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimedSize, countStyle: .file)
    }
}

// MARK: - Uninstall

nonisolated struct UninstallCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String?
    let appPath: String
    let appSize: Int64
    let residueTargets: [CleanupTarget]
    let lastModified: Date?

    init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String?,
        appPath: String,
        appSize: Int64,
        residueTargets: [CleanupTarget],
        lastModified: Date?
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.appSize = appSize
        self.residueTargets = residueTargets
        self.lastModified = lastModified
    }

    var totalSize: Int64 {
        appSize + residueTargets.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

nonisolated struct UninstallSelection: Sendable {
    let candidateIDs: Set<UUID>

    init(candidateIDs: Set<UUID>) {
        self.candidateIDs = candidateIDs
    }
}

nonisolated struct UninstallExecutionResult: Sendable {
    let startedAt: Date
    let finishedAt: Date
    let removedApps: Int
    let removedResidues: Int
    let reclaimedSize: Int64
    let warnings: [String]
    let failures: [String]

    var formattedReclaimedSize: String {
        ByteCountFormatter.string(fromByteCount: reclaimedSize, countStyle: .file)
    }
}

// MARK: - Analyze

nonisolated enum AnalyzeEntryKind: String, Codable, Sendable {
    case directory
    case file
    case insight
}

nonisolated struct AnalyzeEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let name: String
    let kind: AnalyzeEntryKind
    let size: Int64
    let lastAccess: Date?
    let cleanable: Bool

    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        kind: AnalyzeEntryKind,
        size: Int64,
        lastAccess: Date? = nil,
        cleanable: Bool
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.kind = kind
        self.size = size
        self.lastAccess = lastAccess
        self.cleanable = cleanable
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

nonisolated struct LargeFileEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let name: String
    let size: Int64

    init(id: UUID = UUID(), path: String, name: String, size: Int64) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

nonisolated enum AnalyzeAction: String, Sendable {
    case open
    case reveal
    case preview
    case trash
}

nonisolated struct AnalyzeSnapshot: Sendable {
    let scannedPath: String
    let scannedAt: Date
    let entries: [AnalyzeEntry]
    let largeFiles: [LargeFileEntry]
    let totalSize: Int64
    let totalFiles: Int64

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Status

nonisolated struct StatusProcessAlert: Identifiable, Hashable, Sendable {
    let id: UUID
    let processName: String
    let pid: Int
    let cpuPercent: Double
    let message: String

    init(id: UUID = UUID(), processName: String, pid: Int, cpuPercent: Double, message: String) {
        self.id = id
        self.processName = processName
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.message = message
    }
}

nonisolated struct StatusNetworkSnapshot: Sendable {
    let downloadMBps: Double
    let uploadMBps: Double
}

nonisolated struct StatusDiskSnapshot: Sendable {
    let usedBytes: Int64
    let totalBytes: Int64
    let freeBytes: Int64
}

nonisolated struct StatusSnapshot: Sendable {
    let collectedAt: Date
    let hostName: String
    let healthScore: Int
    let cpuUsagePercent: Double
    let memoryUsedBytes: Int64
    let memoryTotalBytes: Int64
    let disk: StatusDiskSnapshot
    let batteryPercent: Double?
    let batteryCharging: Bool?
    let network: StatusNetworkSnapshot
    let processAlerts: [StatusProcessAlert]

    var memoryUsedPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return (Double(memoryUsedBytes) / Double(memoryTotalBytes)) * 100
    }
}

// MARK: - Optimize

nonisolated enum OptimizeTaskState: String, Sendable {
    case pending
    case running
    case success
    case skipped
    case failed
}

nonisolated struct OptimizeTask: Identifiable, Hashable, Sendable {
    let id: UUID
    let action: String
    let name: String
    let description: String
    let isSafe: Bool
    var state: OptimizeTaskState

    init(
        id: UUID = UUID(),
        action: String,
        name: String,
        description: String,
        isSafe: Bool,
        state: OptimizeTaskState = .pending
    ) {
        self.id = id
        self.action = action
        self.name = name
        self.description = description
        self.isSafe = isSafe
        self.state = state
    }
}

nonisolated struct OptimizePlan: Sendable {
    let id: UUID
    let createdAt: Date
    var tasks: [OptimizeTask]

    init(id: UUID = UUID(), createdAt: Date = Date(), tasks: [OptimizeTask]) {
        self.id = id
        self.createdAt = createdAt
        self.tasks = tasks
    }
}

nonisolated struct OptimizeExecutionResult: Sendable {
    let startedAt: Date
    let finishedAt: Date
    let successCount: Int
    let skippedCount: Int
    let failedCount: Int
    let failures: [String]
}
