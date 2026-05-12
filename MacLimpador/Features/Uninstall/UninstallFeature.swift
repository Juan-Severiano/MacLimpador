import Foundation
import Observation

actor UninstallService {
    static let shared = UninstallService()

    private let fileManager = FileManager.default

    private init() {}

    func scanCandidates() async -> [UninstallCandidate] {
        let appDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var candidates: [UninstallCandidate] = []

        for appDirectory in appDirectories {
            guard let apps = try? fileManager.contentsOfDirectory(
                at: appDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for appURL in apps where appURL.pathExtension == "app" {
                let appName = appURL.deletingPathExtension().lastPathComponent
                let bundle = Bundle(url: appURL)
                let bundleID = bundle?.bundleIdentifier
                let appSize = calculateSize(at: appURL)
                let residues = findResidues(bundleIdentifier: bundleID, appName: appName)
                let lastModified = try? appURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

                let candidate = UninstallCandidate(
                    appName: appName,
                    bundleIdentifier: bundleID,
                    appPath: appURL.path,
                    appSize: appSize,
                    residueTargets: residues,
                    lastModified: lastModified
                )
                candidates.append(candidate)
            }
        }

        return candidates.sorted { $0.totalSize > $1.totalSize }
    }

    func execute(selection: UninstallSelection, from candidates: [UninstallCandidate]) async -> UninstallExecutionResult {
        let startedAt = Date()

        var selectedCandidates = candidates.filter { selection.candidateIDs.contains($0.id) }
        selectedCandidates.sort { $0.totalSize > $1.totalSize }

        var totalReclaimed: Int64 = 0
        var removedApps = 0
        var removedResidues = 0
        var warnings: [String] = []
        var failures: [String] = []

        for candidate in selectedCandidates {
            var targets: [CleanupTarget] = []

            targets.append(
                CleanupTarget(
                    path: candidate.appPath,
                    displayName: candidate.appName,
                    category: "uninstall_app",
                    size: candidate.appSize,
                    disposition: .trash,
                    riskLevel: .medium
                )
            )
            targets.append(contentsOf: candidate.residueTargets)

            let sensitiveResidues = candidate.residueTargets.filter { isSensitive(path: $0.path) }
            if !sensitiveResidues.isEmpty {
                warnings.append("\(candidate.appName): has sensitive residue paths")
            }

            let result = await SafetyGuard.shared.execute(
                targets: targets,
                permanentDeletion: false,
                operationName: "uninstall.execute"
            )

            totalReclaimed += result.reclaimedSize
            removedResidues += max(0, result.deletedCount - 1)
            if result.deletedCount > 0 {
                removedApps += 1
            }
            failures.append(contentsOf: result.failures)
        }

        return UninstallExecutionResult(
            startedAt: startedAt,
            finishedAt: Date(),
            removedApps: removedApps,
            removedResidues: removedResidues,
            reclaimedSize: totalReclaimed,
            warnings: warnings,
            failures: failures
        )
    }

    private func findResidues(bundleIdentifier: String?, appName: String) -> [CleanupTarget] {
        let home = fileManager.homeDirectoryForCurrentUser

        let normalizedName = appName.lowercased().replacingOccurrences(of: " ", with: "")
        let maybeBundleID = bundleIdentifier ?? ""

        let candidatePaths: [URL] = [
            home.appendingPathComponent("Library/Application Support/\(maybeBundleID)"),
            home.appendingPathComponent("Library/Application Support/\(appName)"),
            home.appendingPathComponent("Library/Caches/\(maybeBundleID)"),
            home.appendingPathComponent("Library/Preferences/\(maybeBundleID).plist"),
            home.appendingPathComponent("Library/Saved Application State/\(maybeBundleID).savedState"),
            home.appendingPathComponent("Library/Logs/\(appName)"),
            home.appendingPathComponent("Library/Containers/\(maybeBundleID)")
        ]

        var targets: [CleanupTarget] = []

        for path in candidatePaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            let size = calculateSize(at: path)
            guard size > 0 else { continue }

            let risk: CleanupRiskLevel = isSensitive(path: path.path) ? .high : .low

            targets.append(
                CleanupTarget(
                    path: path.path,
                    displayName: path.lastPathComponent,
                    category: "uninstall_residue",
                    size: size,
                    disposition: .trash,
                    riskLevel: risk
                )
            )
        }

        // fallback heuristic for common residue folders by app name
        let supportRoot = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        if let supportEntries = try? fileManager.contentsOfDirectory(at: supportRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in supportEntries {
                let lower = entry.lastPathComponent.lowercased().replacingOccurrences(of: " ", with: "")
                guard lower.contains(normalizedName), !targets.contains(where: { $0.path == entry.path }) else {
                    continue
                }

                let size = calculateSize(at: entry)
                guard size > 0 else { continue }

                targets.append(
                    CleanupTarget(
                        path: entry.path,
                        displayName: entry.lastPathComponent,
                        category: "uninstall_residue",
                        size: size,
                        disposition: .trash,
                        riskLevel: .medium
                    )
                )
            }
        }

        return targets
    }

    private func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

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

    private func isSensitive(path: String) -> Bool {
        let sensitiveMarkers = [
            "/Documents/",
            "/Desktop/",
            "/Downloads/",
            "/.ssh/",
            "/.gnupg/",
            "/Keychains/",
            "/Cookies/"
        ]

        return sensitiveMarkers.contains { path.contains($0) }
    }
}

@Observable
@MainActor
final class UninstallFeatureViewModel {
    var candidates: [UninstallCandidate] = []
    var selectedIDs: Set<UUID> = []
    var isScanning: Bool = false
    var isExecuting: Bool = false
    var query: String = ""
    var executionResult: UninstallExecutionResult?

    var filteredCandidates: [UninstallCandidate] {
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.appName.localizedCaseInsensitiveContains(query) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedTotalSize: Int64 {
        candidates
            .filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
    }

    var formattedSelectedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }

    var selectedCount: Int {
        candidates.filter { selectedIDs.contains($0.id) }.count
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true

        Task {
            let scanned = await UninstallService.shared.scanCandidates()
            self.candidates = scanned
            self.selectedIDs = Set(scanned.map(\.id))
            self.isScanning = false
        }
    }

    func toggleSelection(_ candidateID: UUID) {
        if selectedIDs.contains(candidateID) {
            selectedIDs.remove(candidateID)
        } else {
            selectedIDs.insert(candidateID)
        }
    }

    func execute() {
        guard !isExecuting else { return }
        isExecuting = true

        let selection = UninstallSelection(candidateIDs: selectedIDs)

        Task {
            let result = await UninstallService.shared.execute(selection: selection, from: candidates)
            self.executionResult = result
            self.isExecuting = false
            self.scan()
        }
    }
}
