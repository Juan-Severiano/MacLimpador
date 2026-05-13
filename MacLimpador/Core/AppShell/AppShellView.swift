import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case clean
    case uninstall
    case optimize
    case analyze
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "clean"
        case .uninstall: return "uninstall"
        case .optimize: return "optimize"
        case .analyze: return "analyze"
        case .status: return "status"
        }
    }

    var backgroundTint: Color {
        switch self {
        case .clean: return Color(red: 0.08, green: 0.13, blue: 0.24)
        case .uninstall: return Color(red: 0.20, green: 0.06, blue: 0.06)
        case .optimize: return Color(red: 0.06, green: 0.12, blue: 0.18)
        case .analyze: return Color(red: 0.15, green: 0.11, blue: 0.05)
        case .status: return Color(red: 0.12, green: 0.10, blue: 0.05)
        }
    }
}

struct AppShellView: View {
    @State private var selectedSection: AppSection = .clean
    @State private var showingSettings: Bool = false

    var body: some View {
        ZStack {
            selectedSection.backgroundTint
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: selectedSection)

            VStack(spacing: 0) {
                customTabBar

                Divider().opacity(0.2)

                Group {
                    switch selectedSection {
                    case .clean:
                        CleanView()
                    case .uninstall:
                        UninstallFeatureView()
                    case .analyze:
                        AnalyzeFeatureView()
                    case .status:
                        StatusFeatureView()
                    case .optimize:
                        OptimizeFeatureView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
                .frame(minWidth: 520, minHeight: 420)
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            // App icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.leading, 14)

            Spacer()

            // Tab pills
            HStack(spacing: 2) {
                ForEach(AppSection.allCases) { section in
                    tabPill(section)
                }
            }

            Spacer()

            // Settings
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
    }

    private func tabPill(_ section: AppSection) -> some View {
        let isSelected = selectedSection == section

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        }) {
            Text(section.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.65))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule().fill(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }
}

// MARK: - Settings

struct AppSettingsView: View {
    @State private var permissions = PermissionsService.shared
    @State private var whitelist: [String] = []
    @State private var newWhitelistEntry: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)

                HStack {
                    permissionBadge(label: "Full Disk Access", value: permissions.fullDiskAccessGranted)
                    permissionBadge(label: "Admin Privileges", value: permissions.adminPrivilegesAvailable)
                    permissionBadge(label: "Sandbox", value: permissions.isSandboxEnabled)
                }

                HStack(spacing: 12) {
                    Button("Refresh") {
                        permissions.refresh()
                        Task { whitelist = await SafetyGuard.shared.currentWhitelist() }
                    }
                    Button("Open Privacy Settings") {
                        permissions.openPrivacySettings()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Safety Whitelist")
                    .font(.headline)

                HStack {
                    TextField("/absolute/path", text: $newWhitelistEntry)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        guard !newWhitelistEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let entry = newWhitelistEntry
                        newWhitelistEntry = ""
                        Task {
                            await SafetyGuard.shared.addToWhitelist(path: entry)
                            whitelist = await SafetyGuard.shared.currentWhitelist()
                        }
                    }
                }

                List {
                    ForEach(whitelist, id: \.self) { item in
                        HStack {
                            Text(item)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                Task {
                                    await SafetyGuard.shared.removeFromWhitelist(path: item)
                                    whitelist = await SafetyGuard.shared.currentWhitelist()
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 180)
            }

            Spacer()
        }
        .padding(20)
        .task {
            permissions.refresh()
            whitelist = await SafetyGuard.shared.currentWhitelist()
        }
    }

    private func permissionBadge(label: String, value: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(value ? .green : .red)
            Text(label).font(.caption)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
