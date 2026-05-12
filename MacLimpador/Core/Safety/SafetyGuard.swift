import Foundation

nonisolated enum SafetyDecision: Sendable {
    case allowed
    case blocked(reason: String)
}

actor SafetyGuard {
    static let shared = SafetyGuard()

    private let fileManager = FileManager.default
    private let protectedRoots: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/private",
        "/Library/Keychains",
        "/Applications/Utilities"
    ]

    private let configDirectory: URL
    private let whitelistFile: URL

    private var whitelist: Set<String> = []

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        configDirectory = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("maclimpador", isDirectory: true)
        whitelistFile = configDirectory.appendingPathComponent("whitelist", isDirectory: false)

        if let data = try? Data(contentsOf: whitelistFile),
           let raw = String(data: data, encoding: .utf8) {
            whitelist = Set(
                raw
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            )
        }
    }

    func currentWhitelist() -> [String] {
        whitelist.sorted()
    }

    func addToWhitelist(path: String) {
        guard !path.isEmpty else { return }
        whitelist.insert(normalize(path: path))
        persistWhitelist()
    }

    func removeFromWhitelist(path: String) {
        whitelist.remove(normalize(path: path))
        persistWhitelist()
    }

    func evaluate(path: String) -> SafetyDecision {
        let normalized = normalize(path: path)
        guard normalized.hasPrefix("/") else {
            return .blocked(reason: "Path must be absolute")
        }

        if normalized.contains("..") {
            return .blocked(reason: "Path traversal is not allowed")
        }

        if whitelist.contains(normalized) {
            return .allowed
        }

        for root in protectedRoots {
            if normalized == root || normalized.hasPrefix(root + "/") {
                return .blocked(reason: "Protected system path: \(root)")
            }
        }

        return .allowed
    }

    func buildDryRunReport(targets: [CleanupTarget]) -> DryRunReport {
        let warnings = targets.compactMap { target -> String? in
            switch evaluate(path: target.path) {
            case .allowed:
                return nil
            case .blocked(let reason):
                return "\(target.displayName): \(reason)"
            }
        }

        let reclaimable = targets.reduce(0) { $0 + $1.size }
        return DryRunReport(
            createdAt: Date(),
            targetCount: targets.count,
            totalReclaimableSize: reclaimable,
            warnings: warnings
        )
    }

    func execute(
        targets: [CleanupTarget],
        permanentDeletion: Bool = false,
        operationName: String
    ) async -> CleanupExecutionResult {
        let startedAt = Date()
        var deletedCount = 0
        var skippedCount = 0
        var failedCount = 0
        var reclaimedSize: Int64 = 0
        var failures: [String] = []

        for target in targets {
            switch evaluate(path: target.path) {
            case .blocked(let reason):
                skippedCount += 1
                failures.append("Skipped \(target.displayName): \(reason)")
                await OperationLogger.shared.log(
                    level: .warning,
                    operation: operationName,
                    message: "Skipped target",
                    metadata: ["path": target.path, "reason": reason]
                )
                continue
            case .allowed:
                break
            }

            let url = URL(fileURLWithPath: target.path)

            do {
                if permanentDeletion || target.disposition == .permanent {
                    try fileManager.removeItem(at: url)
                } else {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                }

                deletedCount += 1
                reclaimedSize += target.size

                await OperationLogger.shared.log(
                    level: .info,
                    operation: operationName,
                    message: "Deleted target",
                    metadata: ["path": target.path, "size": "\(target.size)"]
                )
            } catch {
                failedCount += 1
                failures.append("Failed \(target.displayName): \(error.localizedDescription)")

                await OperationLogger.shared.log(
                    level: .error,
                    operation: operationName,
                    message: "Deletion failed",
                    metadata: ["path": target.path, "error": error.localizedDescription]
                )
            }
        }

        return CleanupExecutionResult(
            startedAt: startedAt,
            finishedAt: Date(),
            deletedCount: deletedCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            reclaimedSize: reclaimedSize,
            failures: failures
        )
    }

    private func normalize(path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") && normalized.count > 1 {
            normalized.removeLast()
        }
        return normalized
    }

    private func loadWhitelist() {
        guard let data = try? Data(contentsOf: whitelistFile),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }

        whitelist = Set(
            raw
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        )
    }

    private func persistWhitelist() {
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        let content = whitelist.sorted().joined(separator: "\n") + "\n"
        try? content.write(to: whitelistFile, atomically: true, encoding: .utf8)
    }
}
