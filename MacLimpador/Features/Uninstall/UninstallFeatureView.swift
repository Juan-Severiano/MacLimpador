import SwiftUI

struct UninstallFeatureView: View {
    @State private var viewModel = UninstallFeatureViewModel()
    @State private var showConfirmation = false
    @State private var hasScanned = false

    var body: some View {
        ZStack {
            if !hasScanned && viewModel.candidates.isEmpty && !viewModel.isScanning {
                landing
            } else {
                VStack(spacing: 0) {
                    actionBar
                    Divider().opacity(0.3)
                    content
                }
                .task {
                    if viewModel.candidates.isEmpty { viewModel.scan() }
                }
            }
        }
        .confirmationDialog(
            "Uninstall Apps",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall \(viewModel.selectedCount) app(s)", role: .destructive) {
                viewModel.execute()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(viewModel.formattedSelectedTotalSize) (apps + residues) to the Trash.")
        }
    }

    // MARK: - Landing Page

    private var landing: some View {
        PlanetLandingView(
            planet: .mars,
            haiku: [
                "Red sands bury old traces.",
                "A great wind opens the road."
            ],
            ctaLabel: "Pick apps",
            isLoading: viewModel.isScanning
        ) {
            hasScanned = true
            viewModel.scan()
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            TextField("Search apps", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Button(action: viewModel.scan) {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning || viewModel.isExecuting)

            Button {
                showConfirmation = true
            } label: {
                Label("Uninstall Selected", systemImage: "trash")
            }
            .disabled(viewModel.selectedIDs.isEmpty || viewModel.isScanning || viewModel.isExecuting)
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Spacer()

            if viewModel.isScanning || viewModel.isExecuting {
                ProgressView().controlSize(.small)
            }

            Text("Selected: \(viewModel.formattedSelectedTotalSize)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning && viewModel.candidates.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning installed apps…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredCandidates.isEmpty {
            ContentUnavailableView("No apps found", systemImage: "app.dashed")
        } else {
            List(viewModel.filteredCandidates) { candidate in
                appRow(candidate)
            }
            .listStyle(.inset)
            .overlay(alignment: .bottom) {
                if let result = viewModel.executionResult {
                    resultFooter(result)
                }
            }
        }
    }

    private func appRow(_ candidate: UninstallCandidate) -> some View {
        DisclosureGroup {
            if candidate.residueTargets.isEmpty {
                Text("No residues found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            } else {
                ForEach(candidate.residueTargets) { residue in
                    HStack {
                        Image(systemName: "doc.badge.minus")
                            .foregroundStyle(residue.riskLevel == .high ? .red : .secondary)
                            .padding(.leading, 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(residue.displayName).font(.caption)
                            Text(residue.path)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(residue.formattedSize).font(.caption).foregroundStyle(.secondary)
                        if residue.riskLevel == .high {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).font(.caption)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.selectedIDs.contains(candidate.id) },
                        set: { _ in viewModel.toggleSelection(candidate.id) }
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()

                Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.appPath))
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.appName).lineLimit(1)
                    Text(candidate.bundleIdentifier ?? "Unknown Bundle ID")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(candidate.formattedTotalSize)
                        .font(.system(.body, design: .monospaced))
                    Text("\(candidate.residueTargets.count) residue(s)")
                        .font(.caption2)
                        .foregroundStyle(candidate.residueTargets.isEmpty ? Color.secondary : Color.orange)
                }
            }
        }
    }

    private func resultFooter(_ result: UninstallExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last uninstall: reclaimed \(result.formattedReclaimedSize), removed apps \(result.removedApps), residues \(result.removedResidues)")
            if !result.warnings.isEmpty {
                Text(result.warnings.prefix(2).joined(separator: " • "))
                    .foregroundStyle(.orange).lineLimit(2)
            }
        }
        .font(.caption)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}
