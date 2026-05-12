import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case clean
    case uninstall
    case analyze
    case status
    case optimize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "Clean"
        case .uninstall: return "Uninstall"
        case .analyze: return "Analyze"
        case .status: return "Status"
        case .optimize: return "Optimize"
        }
    }

    var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .uninstall: return "xmark.bin.fill"
        case .analyze: return "internaldrive"
        case .status: return "waveform.path.ecg"
        case .optimize: return "bolt.fill"
        }
    }
}

struct AppShellView: View {
    @State private var selectedSection: AppSection = .clean
    @State private var showingSettings: Bool = false

    var body: some View {
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
        .navigationTitle(selectedSection.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(AppSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 560)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}

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
                        Task {
                            whitelist = await SafetyGuard.shared.currentWhitelist()
                        }
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
                        guard !newWhitelistEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
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
            Text(label)
                .font(.caption)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
