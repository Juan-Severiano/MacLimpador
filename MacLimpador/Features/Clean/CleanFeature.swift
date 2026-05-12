import Foundation
import Observation

nonisolated struct CleanCategoryDefinition: Hashable, Sendable {
    let key: String
    let title: String
    let paths: [String]
    let risk: CleanupRiskLevel
}

actor CleanService {
    static let shared = CleanService()

    private let fileManager = FileManager.default
    private let maxItemsPerPath = 200

    private init() {}

    private var homePath: String { NSHomeDirectory() }

    func scanPlan() async -> CleanupPlan {
        var targets: [CleanupTarget] = []

        let categories = buildCategories()

        for category in categories {
            let categoryTargets = await scanCategory(category)
            targets.append(contentsOf: categoryTargets)
        }

        // App leftovers from orphaned file detector.
        let leftovers = await OrphanedFilesService.shared.scanForOrphanedFiles()
        targets.append(contentsOf: leftovers.map {
            CleanupTarget(
                path: $0.path,
                displayName: $0.name,
                category: "leftovers",
                size: $0.size,
                disposition: .trash,
                riskLevel: .medium
            )
        })

        let deduped = deduplicate(targets: targets)
            .sorted { $0.size > $1.size }

        return CleanupPlan(targets: deduped)
    }

    private func buildCategories() -> [CleanCategoryDefinition] {
        let home = homePath
        return [
            CleanCategoryDefinition(
                key: "user_essentials",
                title: "User Essentials",
                paths: [
                    home + "/.Trash",
                    home + "/Library/Saved Application State"
                ],
                risk: .low
            ),
            CleanCategoryDefinition(
                key: "app_caches",
                title: "App Caches",
                paths: [
                    home + "/Library/Caches",
                    home + "/Library/Logs",
                    home + "/Library/Containers/com.apple.mail/Data/Library/Logs",
                    "/Library/Caches"
                ],
                risk: .low
            ),
            CleanCategoryDefinition(
                key: "browsers",
                title: "Browsers",
                paths: [
                    home + "/Library/Application Support/Google/Chrome/Default/Cache",
                    home + "/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage",
                    home + "/Library/Application Support/Google/Chrome/Default/Code Cache",
                    home + "/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",
                    home + "/Library/Application Support/Firefox/Profiles",
                    home + "/Library/Application Support/com.operasoftware.Opera/Default/Cache",
                    home + "/Library/Caches/com.apple.Safari",
                    home + "/Library/Safari/LocalStorage",
                    home + "/Library/Safari/Databases"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "xcode",
                title: "Xcode",
                paths: [
                    home + "/Library/Developer/Xcode/DerivedData",
                    home + "/Library/Developer/Xcode/Archives",
                    home + "/Library/Developer/Xcode/iOS DeviceSupport",
                    home + "/Library/Developer/Xcode/watchOS DeviceSupport",
                    home + "/Library/Developer/Xcode/visionOS DeviceSupport",
                    home + "/Library/Developer/CoreSimulator/Caches"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "node_js",
                title: "Node / npm",
                paths: [
                    home + "/.npm/_cacache",
                    home + "/.pnpm-store",
                    home + "/.yarn/cache",
                    home + "/.bun/install/cache"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "python",
                title: "Python",
                paths: [
                    home + "/Library/Caches/pip",
                    home + "/.mypy_cache",
                    home + "/.ruff_cache",
                    home + "/.pytest_cache"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "java_kotlin",
                title: "Java / Kotlin",
                paths: [
                    home + "/.gradle/caches",
                    home + "/.m2/repository"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "rust",
                title: "Rust",
                paths: [
                    home + "/.cargo/registry/cache",
                    home + "/.cargo/git/db"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "apple_dev",
                title: "Apple Dev Tools",
                paths: [
                    home + "/Library/Caches/CocoaPods",
                    home + "/.swiftpm/cache"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "third_party_apps",
                title: "Third-party Apps",
                paths: [
                    home + "/Library/Caches/JetBrains",
                    home + "/Library/Application Support/Spotify/PersistentCache",
                    home + "/Library/Application Support/Slack/Cache",
                    home + "/Library/Application Support/Slack/Service Worker/CacheStorage",
                    home + "/Library/Application Support/discord/Cache",
                    home + "/Library/Application Support/zoom.us/data",
                    home + "/Library/Containers/com.docker.docker/Data/vms"
                ],
                risk: .medium
            ),
            CleanCategoryDefinition(
                key: "system_logs",
                title: "System Logs",
                paths: [
                    home + "/Library/Logs",
                    "/private/var/log",
                    "/Library/Logs"
                ],
                risk: .low
            ),
            CleanCategoryDefinition(
                key: "homebrew",
                title: "Homebrew",
                paths: [
                    home + "/Library/Caches/Homebrew",
                    "/opt/homebrew/var/cache"
                ],
                risk: .low
            )
        ]
    }

    private func scanCategory(_ category: CleanCategoryDefinition) async -> [CleanupTarget] {
        var targets: [CleanupTarget] = []

        for path in category.paths {
            let url = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: url.path) else { continue }

            if let childTargets = scanChildren(of: url, category: category), !childTargets.isEmpty {
                targets.append(contentsOf: childTargets)
            } else {
                let size = calculateSize(at: url)
                guard size > 0 else { continue }
                targets.append(
                    CleanupTarget(
                        path: url.path,
                        displayName: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                        category: category.key,
                        size: size,
                        disposition: .trash,
                        riskLevel: category.risk
                    )
                )
            }
        }

        return targets
    }

    private func scanChildren(of baseURL: URL, category: CleanCategoryDefinition) -> [CleanupTarget]? {
        guard let children = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var targets: [CleanupTarget] = []
        var processed = 0

        for child in children {
            processed += 1
            if processed > maxItemsPerPath { break }

            let size = calculateSize(at: child)
            guard size > 0 else { continue }

            targets.append(
                CleanupTarget(
                    path: child.path,
                    displayName: child.lastPathComponent,
                    category: category.key,
                    size: size,
                    disposition: .trash,
                    riskLevel: category.risk
                )
            )
        }

        return targets
    }

    private func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            return (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }

        return total
    }

    private func deduplicate(targets: [CleanupTarget]) -> [CleanupTarget] {
        var seen = Set<String>()
        var deduped: [CleanupTarget] = []

        for target in targets {
            let key = target.path
            if seen.insert(key).inserted {
                deduped.append(target)
            }
        }

        return deduped
    }
}

@Observable
@MainActor
final class CleanViewModel {
    var plan: CleanupPlan?
    var selectedTargetIDs: Set<UUID> = []
    var isScanning: Bool = false
    var isExecuting: Bool = false
    var dryRunReport: DryRunReport?
    var lastExecution: CleanupExecutionResult?
    var errorMessage: String?
    var showConfirmation: Bool = false

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        dryRunReport = nil

        Task {
            let plan = await CleanService.shared.scanPlan()
            self.plan = plan
            self.selectedTargetIDs = Set(plan.targets.map(\.id))
            self.isScanning = false
        }
    }

    func runDryRun() {
        guard let plan else { return }
        let selected = plan.targets.filter { selectedTargetIDs.contains($0.id) }

        Task {
            let report = await SafetyGuard.shared.buildDryRunReport(targets: selected)
            self.dryRunReport = report
            await OperationLogger.shared.log(
                level: .info,
                operation: "clean.dryRun",
                message: "Dry-run finished",
                metadata: [
                    "targets": "\(selected.count)",
                    "reclaimable": "\(report.totalReclaimableSize)"
                ]
            )
        }
    }

    func requestClean() {
        guard !selectedTargets.isEmpty else { return }
        showConfirmation = true
    }

    func confirmClean() {
        showConfirmation = false
        guard let plan, !isExecuting else { return }
        isExecuting = true
        errorMessage = nil

        let selected = plan.targets.filter { selectedTargetIDs.contains($0.id) }

        Task {
            let result = await SafetyGuard.shared.execute(
                targets: selected,
                permanentDeletion: false,
                operationName: "clean.execute"
            )

            self.lastExecution = result
            self.isExecuting = false

            let refreshedPlan = await CleanService.shared.scanPlan()
            self.plan = refreshedPlan
            self.selectedTargetIDs = Set(refreshedPlan.targets.map(\.id))
        }
    }

    func toggleSelection(for targetID: UUID) {
        if selectedTargetIDs.contains(targetID) {
            selectedTargetIDs.remove(targetID)
        } else {
            selectedTargetIDs.insert(targetID)
        }
    }

    var selectedTargets: [CleanupTarget] {
        guard let plan else { return [] }
        return plan.targets.filter { selectedTargetIDs.contains($0.id) }
    }

    var selectedTotalSize: Int64 {
        selectedTargets.reduce(0) { $0 + $1.size }
    }

    var formattedSelectedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }
}
