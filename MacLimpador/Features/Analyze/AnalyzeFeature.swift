import Foundation
import AppKit
import Observation

actor AnalyzeService {
    static let shared = AnalyzeService()

    private let fileManager = FileManager.default
    private var snapshotCache: [String: AnalyzeSnapshot] = [:]

    private init() {}

    func snapshot(for path: String, forceRefresh: Bool = false) async -> AnalyzeSnapshot {
        if !forceRefresh, let cached = snapshotCache[path] {
            return cached
        }

        let baseURL = URL(fileURLWithPath: path)
        let isHome = path == NSHomeDirectory()

        async let regularEntriesTask = scanEntries(in: baseURL)
        async let insightsTask = isHome ? insightEntries() : []

        var entries = await regularEntriesTask
        let insights = await insightsTask
        entries.append(contentsOf: insights)

        let largeFiles = await scanLargeFiles(in: baseURL, limit: 50)

        let totalSize = entries.filter { $0.kind != .insight }.reduce(0) { $0 + $1.size }
        let totalFiles = Int64(entries.filter { $0.kind == .file }.count)

        let (diskUsed, diskTotal) = Self.queryDiskUsage(at: path)

        let snapshot = AnalyzeSnapshot(
            scannedPath: path,
            scannedAt: Date(),
            entries: entries.sorted { $0.size > $1.size },
            largeFiles: largeFiles.sorted { $0.size > $1.size },
            totalSize: totalSize,
            totalFiles: totalFiles,
            diskUsedBytes: diskUsed,
            diskTotalBytes: diskTotal
        )

        snapshotCache[path] = snapshot
        return snapshot
    }

    private nonisolated static func queryDiskUsage(at path: String) -> (used: Int64, total: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let total = attrs[.systemSize] as? Int64 ?? 0
            return (max(0, total - free), total)
        } catch {
            return (0, 0)
        }
    }

    func perform(action: AnalyzeAction, path: String) async {
        let url = URL(fileURLWithPath: path)

        switch action {
        case .open:
            NSWorkspace.shared.open(url)
        case .reveal:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .preview:
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/qlmanage", arguments: ["-p", path], timeout: 3)
        case .trash:
            let target = CleanupTarget(
                path: path,
                displayName: url.lastPathComponent,
                category: "analyze_delete",
                size: Self.calculateSizeSync(at: url),
                disposition: .trash,
                riskLevel: .medium
            )
            _ = await SafetyGuard.shared.execute(targets: [target], operationName: "analyze.trash")
        }
    }

    func trash(paths: [String]) async -> CleanupExecutionResult {
        let targets = paths.map { path in
            let url = URL(fileURLWithPath: path)
            return CleanupTarget(
                path: path,
                displayName: url.lastPathComponent,
                category: "analyze_delete",
                size: Self.calculateSizeSync(at: url),
                disposition: .trash,
                riskLevel: .medium
            )
        }

        return await SafetyGuard.shared.execute(targets: targets, operationName: "analyze.trashBatch")
    }

    // MARK: - Insights

    private func insightEntries() async -> [AnalyzeEntry] {
        let home = NSHomeDirectory()
        var entries: [AnalyzeEntry] = []

        let insightPaths: [(name: String, path: String, oldDownloads: Bool)] = [
            ("iOS Backups", "\(home)/Library/Application Support/MobileSync/Backup", false),
            ("Old Downloads (90d+)", "\(home)/Downloads", true),
            ("System Logs", "\(home)/Library/Logs", false),
            ("Homebrew Cache", "\(home)/Library/Caches/Homebrew", false),
            ("Xcode DerivedData", "\(home)/Library/Developer/Xcode/DerivedData", false),
            ("Xcode Simulators", "\(home)/Library/Developer/CoreSimulator/Devices", false),
            ("Xcode Archives", "\(home)/Library/Developer/Xcode/Archives", false),
            ("JetBrains Cache", "\(home)/Library/Caches/JetBrains", false),
            ("Spotify Cache", "\(home)/Library/Application Support/Spotify/PersistentCache", false),
            ("Docker Data", "\(home)/Library/Containers/com.docker.docker/Data", false),
            ("pip Cache", "\(home)/Library/Caches/pip", false),
            ("Gradle Cache", "\(home)/.gradle/caches", false),
            ("CocoaPods Cache", "\(home)/Library/Caches/CocoaPods", false),
        ]

        await withTaskGroup(of: AnalyzeEntry?.self) { group in
            for item in insightPaths {
                group.addTask {
                    let url = URL(fileURLWithPath: item.path)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else {
                        return nil
                    }

                    let size: Int64
                    if item.oldDownloads {
                        size = Self.measureOldDownloads(at: url, daysOld: 90)
                    } else {
                        size = await Self.measureDirWithDu(at: url)
                    }

                    guard size > 0 else { return nil }

                    return AnalyzeEntry(
                        path: item.path,
                        name: item.name,
                        kind: .insight,
                        size: size,
                        lastAccess: nil,
                        cleanable: true
                    )
                }
            }

            for await entry in group {
                if let entry { entries.append(entry) }
            }
        }

        return entries
    }

    private nonisolated static func measureOldDownloads(at url: URL, daysOld: Int) -> Int64 {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(TimeInterval(-daysOld * 24 * 3600))

        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for item in items {
            guard let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey]) else { continue }
            let modDate = values.contentModificationDate ?? .distantPast
            guard modDate < cutoff else { continue }

            if values.isDirectory == true {
                total += calculateSizeSync(at: item)
            } else {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    private nonisolated static func measureDirWithDu(at url: URL) async -> Int64 {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/bin/du",
            arguments: ["-sk", url.path],
            timeout: 15
        ), result.success else {
            return calculateSizeSync(at: url)
        }

        let fields = result.stdout.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let first = fields.first, let kb = Int64(first) else {
            return calculateSizeSync(at: url)
        }
        return kb * 1024
    }

    // MARK: - Directory scanning

    private func scanEntries(in baseURL: URL) async -> [AnalyzeEntry] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [AnalyzeEntry] = []
        entries.reserveCapacity(children.count)

        await withTaskGroup(of: AnalyzeEntry?.self) { group in
            for child in children {
                group.addTask {
                    Self.buildAnalyzeEntry(for: child)
                }
            }

            for await entry in group {
                if let entry {
                    entries.append(entry)
                }
            }
        }

        return entries
    }

    private nonisolated static func buildAnalyzeEntry(for child: URL) -> AnalyzeEntry? {
        let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentAccessDateKey])
        let isDir = values?.isDirectory ?? false
        let kind: AnalyzeEntryKind = isDir ? .directory : .file
        let size = calculateSizeSync(at: child)

        guard size > 0 else { return nil }

        return AnalyzeEntry(
            path: child.path,
            name: child.lastPathComponent,
            kind: kind,
            size: size,
            lastAccess: values?.contentAccessDate,
            cleanable: isLikelyCleanableSync(path: child.path, isDirectory: isDir)
        )
    }

    private func scanLargeFiles(in baseURL: URL, limit: Int) async -> [LargeFileEntry] {
        await Task.detached(priority: .utility) {
            Self.scanLargeFilesSync(in: baseURL, limit: limit)
        }.value
    }

    private nonisolated static func scanLargeFilesSync(in baseURL: URL, limit: Int) -> [LargeFileEntry] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [LargeFileEntry] = []

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else {
                continue
            }

            let size = Int64(values.fileSize ?? 0)
            guard size >= 100 * 1_000_000 else { continue }

            let ext = url.pathExtension.lowercased()
            let skipExts: Set<String> = ["swift", "go", "ts", "js", "py", "rs", "java", "kt", "c", "cpp", "h", "m"]
            guard !skipExts.contains(ext) else { continue }

            files.append(LargeFileEntry(path: url.path, name: url.lastPathComponent, size: size))
        }

        return Array(files.sorted { $0.size > $1.size }.prefix(limit))
    }

    private nonisolated static func isLikelyCleanableSync(path: String, isDirectory: Bool) -> Bool {
        let cleanableMarkers = [
            "/Caches/",
            "/Logs/",
            "/DerivedData",
            "/tmp/",
            "/.Trash",
            "/Saved Application State",
            "/CoreSimulator/Devices",
            "/Homebrew",
            "/JetBrains",
            "/CocoaPods",
            "/.gradle",
            "/.cargo",
            "/pip/"
        ]

        if cleanableMarkers.contains(where: { path.contains($0) }) {
            return true
        }

        if !isDirectory {
            return path.hasSuffix(".log") || path.hasSuffix(".tmp") || path.hasSuffix(".cache")
        }

        return false
    }

    nonisolated static func calculateSizeSync(at url: URL) -> Int64 {
        let fileManager = FileManager.default
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
}

@Observable
@MainActor
final class AnalyzeFeatureViewModel {
    var currentPath: String = NSHomeDirectory()
    var snapshot: AnalyzeSnapshot?
    var isScanning: Bool = false
    var showLargeFiles: Bool = false
    var selectedEntryIDs: Set<UUID> = []
    var selectedLargeFileIDs: Set<UUID> = []
    var lastDeletionResult: CleanupExecutionResult?
    var confirmationPaths: [String]? = nil

    var pendingDeletion: [String] = []

    func scan(forceRefresh: Bool = false) {
        guard !isScanning else { return }
        isScanning = true

        Task {
            let snapshot = await AnalyzeService.shared.snapshot(for: currentPath, forceRefresh: forceRefresh)
            self.snapshot = snapshot
            self.selectedEntryIDs.removeAll()
            self.selectedLargeFileIDs.removeAll()
            self.isScanning = false
        }
    }

    func goTo(_ path: String) {
        currentPath = path
        scan(forceRefresh: false)
    }

    func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Analyze"

        if panel.runModal() == .OK, let url = panel.url {
            goTo(url.path)
        }
    }

    func perform(_ action: AnalyzeAction, on path: String) {
        Task {
            await AnalyzeService.shared.perform(action: action, path: path)
            if action == .trash {
                scan(forceRefresh: true)
            }
        }
    }

    func requestTrashSelection() {
        guard let snapshot else { return }

        let selectedPaths: [String]
        if showLargeFiles {
            selectedPaths = snapshot
                .largeFiles
                .filter { selectedLargeFileIDs.contains($0.id) }
                .map(\.path)
        } else {
            selectedPaths = snapshot
                .entries
                .filter { selectedEntryIDs.contains($0.id) }
                .map(\.path)
        }

        guard !selectedPaths.isEmpty else { return }
        pendingDeletion = selectedPaths
        confirmationPaths = selectedPaths
    }

    func confirmTrash() {
        let paths = pendingDeletion
        pendingDeletion = []
        confirmationPaths = nil

        guard !paths.isEmpty else { return }

        Task {
            let result = await AnalyzeService.shared.trash(paths: paths)
            self.lastDeletionResult = result
            self.scan(forceRefresh: true)
        }
    }

    func cancelTrash() {
        pendingDeletion = []
        confirmationPaths = nil
    }

    func toggleEntry(_ id: UUID) {
        if selectedEntryIDs.contains(id) {
            selectedEntryIDs.remove(id)
        } else {
            selectedEntryIDs.insert(id)
        }
    }

    func toggleLargeFile(_ id: UUID) {
        if selectedLargeFileIDs.contains(id) {
            selectedLargeFileIDs.remove(id)
        } else {
            selectedLargeFileIDs.insert(id)
        }
    }

    var selectedTotalSize: Int64 {
        guard let snapshot else { return 0 }
        if showLargeFiles {
            return snapshot.largeFiles
                .filter { selectedLargeFileIDs.contains($0.id) }
                .reduce(0) { $0 + $1.size }
        }
        return snapshot.entries
            .filter { selectedEntryIDs.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
}
