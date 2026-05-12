import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class PermissionsService {
    static let shared = PermissionsService()

    var fullDiskAccessGranted: Bool = false
    var adminPrivilegesAvailable: Bool = false
    var isSandboxEnabled: Bool = false
    var lastCheckedAt: Date?

    private init() {
        refresh()
    }

    func refresh() {
        isSandboxEnabled = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        fullDiskAccessGranted = checkFullDiskAccess()

        Task {
            let hasAdmin = await checkAdminPrivileges()
            self.adminPrivilegesAvailable = hasAdmin
            self.lastCheckedAt = Date()
        }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func checkFullDiskAccess() -> Bool {
        let probes: [String] = [
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
            NSHomeDirectory() + "/Library/Mail",
            NSHomeDirectory() + "/Library/Messages"
        ]

        return probes.contains { FileManager.default.isReadableFile(atPath: $0) }
    }

    private func checkAdminPrivileges() async -> Bool {
        do {
            let result = try await SystemCommandExecutor.shared.run("/usr/bin/sudo", arguments: ["-n", "true"], timeout: 2)
            return result.success
        } catch {
            return false
        }
    }
}
