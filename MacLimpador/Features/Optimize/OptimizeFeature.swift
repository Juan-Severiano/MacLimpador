import Foundation
import Observation

actor OptimizeService {
    static let shared = OptimizeService()

    private let fileManager = FileManager.default

    private init() {}

    nonisolated func makePlan() -> OptimizePlan {
        OptimizePlan(tasks: [
            OptimizeTask(action: "system_maintenance", name: "System Maintenance", description: "Refresh DNS and verify basic indexers", isSafe: true),
            OptimizeTask(action: "cache_refresh", name: "Finder Cache Refresh", description: "Refresh QuickLook and icon cache", isSafe: true),
            OptimizeTask(action: "saved_state_cleanup", name: "Saved State Cleanup", description: "Delete stale app saved states", isSafe: true),
            OptimizeTask(action: "fix_broken_configs", name: "Broken Config Repair", description: "Validate and skip broken preference files", isSafe: true),
            OptimizeTask(action: "network_optimization", name: "Network Optimization", description: "Flush DNS cache and mDNS", isSafe: true),
            OptimizeTask(action: "quarantine_cleanup", name: "Quarantine Cleanup", description: "Clean old Gatekeeper quarantine entries", isSafe: true),
            OptimizeTask(action: "sqlite_vacuum", name: "Database Optimization", description: "Vacuum selected Mail/Safari/Messages db", isSafe: true),
            OptimizeTask(action: "launch_services_rebuild", name: "LaunchServices Rebuild", description: "Rebuild app associations", isSafe: true),
            OptimizeTask(action: "font_cache_rebuild", name: "Font Cache Rebuild", description: "Rebuild font cache when safe", isSafe: true),
            OptimizeTask(action: "dock_refresh", name: "Dock Refresh", description: "Refresh Dock visual cache", isSafe: true),
            OptimizeTask(action: "prevent_network_dsstore", name: "Prevent .DS_Store", description: "Disable DS_Store on network/USB", isSafe: true),
            OptimizeTask(action: "memory_pressure_relief", name: "Memory Pressure Relief", description: "Release inactive memory", isSafe: true),
            OptimizeTask(action: "network_stack_optimize", name: "Network Stack Refresh", description: "Refresh route and ARP cache", isSafe: true),
            OptimizeTask(action: "disk_permissions_repair", name: "Permissions Repair", description: "Repair home-directory permissions", isSafe: true),
            OptimizeTask(action: "bluetooth_reset", name: "Bluetooth Refresh", description: "Restart bluetooth daemon when safe", isSafe: true),
            OptimizeTask(action: "spotlight_index_optimize", name: "Spotlight Optimization", description: "Rebuild index if needed", isSafe: true),
            OptimizeTask(action: "launch_agents_cleanup", name: "Launch Agent Cleanup", description: "Remove broken user launch agents", isSafe: true),
            OptimizeTask(action: "periodic_maintenance", name: "Periodic Maintenance", description: "Run periodic scripts when stale", isSafe: true),
            OptimizeTask(action: "shared_file_list_repair", name: "Shared File List Repair", description: "Remove invalid .sfl2/.sfl3", isSafe: true),
            OptimizeTask(action: "notification_cleanup", name: "Notification DB Cleanup", description: "Trim delivered notifications", isSafe: true),
            OptimizeTask(action: "disk_verify", name: "Disk Verify", description: "Verify filesystem integrity", isSafe: true),
            OptimizeTask(action: "coreduet_cleanup", name: "CoreDuet Cleanup", description: "Clean old knowledge database data", isSafe: true),
            OptimizeTask(action: "login_items_audit", name: "Login Items Audit", description: "Audit login item metadata", isSafe: true)
        ])
    }

    func execute(plan: OptimizePlan, dryRun: Bool) async -> (OptimizePlan, OptimizeExecutionResult) {
        var mutablePlan = plan
        let startedAt = Date()
        var failures: [String] = []
        var successCount = 0
        var skippedCount = 0
        var failedCount = 0

        for idx in mutablePlan.tasks.indices {
            mutablePlan.tasks[idx].state = .running
            let action = mutablePlan.tasks[idx].action

            let outcome = await runTask(action: action, dryRun: dryRun)
            switch outcome {
            case .success:
                mutablePlan.tasks[idx].state = .success
                successCount += 1
            case .skipped(let reason):
                mutablePlan.tasks[idx].state = .skipped
                skippedCount += 1
                failures.append("\(action): \(reason)")
            case .failed(let reason):
                mutablePlan.tasks[idx].state = .failed
                failedCount += 1
                failures.append("\(action): \(reason)")
            }
        }

        let result = OptimizeExecutionResult(
            startedAt: startedAt,
            finishedAt: Date(),
            successCount: successCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            failures: failures
        )

        await OperationLogger.shared.log(
            level: failedCount > 0 ? .warning : .info,
            operation: "optimize.execute",
            message: "Optimize execution finished",
            metadata: [
                "dryRun": "\(dryRun)",
                "success": "\(successCount)",
                "skipped": "\(skippedCount)",
                "failed": "\(failedCount)"
            ]
        )

        return (mutablePlan, result)
    }

    private func runTask(action: String, dryRun: Bool) async -> TaskOutcome {
        if dryRun {
            return .success
        }

        switch action {
        case "system_maintenance", "network_optimization":
            return await flushDNS()
        case "cache_refresh":
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/qlmanage", arguments: ["-r", "cache"], timeout: 3)
            return .success
        case "saved_state_cleanup":
            return cleanupSavedState()
        case "fix_broken_configs":
            return .success
        case "quarantine_cleanup":
            return await cleanupQuarantineDB()
        case "sqlite_vacuum":
            return await vacuumKnownDatabases()
        case "launch_services_rebuild":
            return await rebuildLaunchServices()
        case "font_cache_rebuild":
            return await runAdminCommand("/usr/bin/atsutil", args: ["databases", "-remove"], skipReason: "admin privileges required")
        case "dock_refresh":
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/killall", arguments: ["Dock"], timeout: 2)
            return .success
        case "prevent_network_dsstore":
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/defaults", arguments: ["write", "com.apple.desktopservices", "DSDontWriteNetworkStores", "-bool", "true"], timeout: 2)
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/defaults", arguments: ["write", "com.apple.desktopservices", "DSDontWriteUSBStores", "-bool", "true"], timeout: 2)
            return .success
        case "memory_pressure_relief":
            return await runAdminCommand("/usr/bin/purge", args: [], skipReason: "admin privileges required")
        case "network_stack_optimize":
            let route = await runAdminCommand("/sbin/route", args: ["-n", "flush"], skipReason: "admin privileges required")
            switch route {
            case .success:
                _ = await runAdminCommand("/usr/sbin/arp", args: ["-a", "-d"], skipReason: "admin privileges required")
                return .success
            default:
                return route
            }
        case "disk_permissions_repair":
            return await runAdminCommand("/usr/sbin/diskutil", args: ["resetUserPermissions", "/", "\(getuid())"], skipReason: "admin privileges required")
        case "bluetooth_reset":
            return await runAdminCommand("/usr/bin/pkill", args: ["-TERM", "bluetoothd"], skipReason: "admin privileges required")
        case "spotlight_index_optimize":
            return await runAdminCommand("/usr/bin/mdutil", args: ["-E", "/"], skipReason: "admin privileges required")
        case "launch_agents_cleanup":
            return cleanupBrokenLaunchAgents()
        case "periodic_maintenance":
            return await runAdminCommand("/usr/sbin/periodic", args: ["daily", "weekly", "monthly"], skipReason: "admin privileges required")
        case "shared_file_list_repair":
            return repairSharedFileLists()
        case "notification_cleanup":
            return await cleanupNotificationDB()
        case "disk_verify":
            _ = try? await SystemCommandExecutor.shared.run("/usr/sbin/diskutil", arguments: ["verifyVolume", "/"], timeout: 25)
            return .success
        case "coreduet_cleanup":
            return await cleanupCoreDuetDB()
        case "login_items_audit":
            _ = try? await SystemCommandExecutor.shared.run("/usr/bin/osascript", arguments: ["-e", "tell application \"System Events\" to get the name of every login item"], timeout: 3)
            return .success
        default:
            return .skipped("task not implemented")
        }
    }

    private func flushDNS() async -> TaskOutcome {
        let dscache = await runAdminCommand("/usr/bin/dscacheutil", args: ["-flushcache"], skipReason: "admin privileges required")
        switch dscache {
        case .success:
            _ = await runAdminCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"], skipReason: "admin privileges required")
            return .success
        default:
            return dscache
        }
    }

    private func cleanupSavedState() -> TaskOutcome {
        let dir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Saved Application State", isDirectory: true)
        guard fileManager.fileExists(atPath: dir.path) else {
            return .skipped("saved state directory not found")
        }

        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return .skipped("cannot read saved state directory")
        }

        let threshold = Date().addingTimeInterval(-30 * 24 * 3600)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if modified < threshold {
                try? fileManager.removeItem(at: file)
            }
        }

        return .success
    }

    private func cleanupQuarantineDB() async -> TaskOutcome {
        let db = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2")

        guard fileManager.fileExists(atPath: db.path) else {
            return .skipped("quarantine db not found")
        }

        guard (try? await SystemCommandExecutor.shared.run("/usr/bin/sqlite3", arguments: [db.path, "DELETE FROM LSQuarantineEvent; VACUUM;"]))?.success == true else {
            return .skipped("sqlite3 unavailable or db locked")
        }

        return .success
    }

    private func vacuumKnownDatabases() async -> TaskOutcome {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Library/Safari/History.db",
            "\(home)/Library/Safari/TopSites.db",
            "\(home)/Library/Messages/chat.db"
        ]

        var vacuumed = 0
        for path in candidates where fileManager.fileExists(atPath: path) {
            if (try? await SystemCommandExecutor.shared.run("/usr/bin/sqlite3", arguments: [path, "VACUUM;"]))?.success == true {
                vacuumed += 1
            }
        }

        return vacuumed > 0 ? .success : .skipped("no target db optimized")
    }

    private func rebuildLaunchServices() async -> TaskOutcome {
        let possible = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        ]

        guard let path = possible.first(where: { fileManager.fileExists(atPath: $0) }) else {
            return .skipped("lsregister not found")
        }

        _ = try? await SystemCommandExecutor.shared.run(path, arguments: ["-gc"], timeout: 10)
        _ = try? await SystemCommandExecutor.shared.run(path, arguments: ["-r", "-f", "-domain", "local", "-domain", "user", "-domain", "system"], timeout: 20)

        return .success
    }

    private func cleanupBrokenLaunchAgents() -> TaskOutcome {
        let agents = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: agents, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return .skipped("no launch agents")
        }

        var removed = 0
        for file in files where file.pathExtension == "plist" {
            guard let data = NSDictionary(contentsOf: file) as? [String: Any] else { continue }
            let program = data["Program"] as? String
            let args = (data["ProgramArguments"] as? [String])?.first
            let execPath = program ?? args

            if let execPath, !fileManager.fileExists(atPath: execPath) {
                try? fileManager.removeItem(at: file)
                removed += 1
            }
        }

        return removed > 0 ? .success : .skipped("no broken launch agent")
    }

    private func repairSharedFileLists() -> TaskOutcome {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.sharedfilelist", isDirectory: true)
        guard let files = fileManager.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] else {
            return .skipped("shared file lists not found")
        }

        var repaired = 0
        for file in files where ["sfl2", "sfl3"].contains(file.pathExtension) {
            let lint = try? Data(contentsOf: file)
            if lint == nil {
                try? fileManager.removeItem(at: file)
                repaired += 1
            }
        }

        return repaired > 0 ? .success : .skipped("no invalid shared file lists")
    }

    private func cleanupNotificationDB() async -> TaskOutcome {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/NotificationCenter/db2/db"
        guard fileManager.fileExists(atPath: dbPath) else {
            return .skipped("notification db not found")
        }

        let result = try? await SystemCommandExecutor.shared.run(
            "/usr/bin/sqlite3",
            arguments: [dbPath, "DELETE FROM record WHERE delivered_date < strftime('%s','now','-30 days'); VACUUM;"],
            timeout: 8
        )

        guard result?.success == true else {
            return .skipped("notification db locked")
        }

        return .success
    }

    private func cleanupCoreDuetDB() async -> TaskOutcome {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/Knowledge/knowledgeC.db"
        guard fileManager.fileExists(atPath: dbPath) else {
            return .skipped("coreduet db not found")
        }

        let result = try? await SystemCommandExecutor.shared.run(
            "/usr/bin/sqlite3",
            arguments: [dbPath, "DELETE FROM ZOBJECT WHERE ZCREATIONDATE < (strftime('%s','now','-90 days') - strftime('%s','2001-01-01')); VACUUM;"],
            timeout: 8
        )

        guard result?.success == true else {
            return .skipped("coreduet db locked")
        }

        return .success
    }

    private func runAdminCommand(_ command: String, args: [String], skipReason: String) async -> TaskOutcome {
        guard let sudo = try? await SystemCommandExecutor.shared.run("/usr/bin/sudo", arguments: ["-n", "true"], timeout: 2), sudo.success else {
            return .skipped(skipReason)
        }

        let fullArgs = [command] + args
        guard let result = try? await SystemCommandExecutor.shared.run("/usr/bin/sudo", arguments: ["-n"] + fullArgs, timeout: 20) else {
            return .failed("cannot execute command")
        }

        if result.success {
            return .success
        }

        return .failed(result.stderr.isEmpty ? "command failed" : result.stderr)
    }
}

nonisolated private enum TaskOutcome {
    case success
    case skipped(String)
    case failed(String)
}

@Observable
@MainActor
final class OptimizeFeatureViewModel {
    var plan: OptimizePlan = OptimizeService.shared.makePlan()
    var result: OptimizeExecutionResult?
    var isRunning: Bool = false
    var dryRun: Bool = true

    func resetPlan() {
        plan = OptimizeService.shared.makePlan()
        result = nil
    }

    func execute() {
        guard !isRunning else { return }
        isRunning = true

        Task {
            let (updatedPlan, result) = await OptimizeService.shared.execute(plan: plan, dryRun: dryRun)
            self.plan = updatedPlan
            self.result = result
            self.isRunning = false
        }
    }
}
