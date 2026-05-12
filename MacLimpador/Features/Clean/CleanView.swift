import SwiftUI

struct CleanView: View {
    @State private var viewModel = CleanViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .task {
            if viewModel.plan == nil {
                viewModel.scan()
            }
        }
        .confirmationDialog(
            "Move to Trash",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(viewModel.selectedTargets.count) item(s) to Trash", role: .destructive) {
                viewModel.confirmClean()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(viewModel.formattedSelectedTotalSize) of files to the Trash. You can recover items from the Trash.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.scan) {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(viewModel.isScanning || viewModel.isExecuting)

            Button(action: viewModel.runDryRun) {
                Label("Dry Run", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(viewModel.plan == nil || viewModel.isScanning || viewModel.isExecuting)

            Button(action: viewModel.requestClean) {
                Label("Clean Selected", systemImage: "trash")
            }
            .disabled(viewModel.selectedTargets.isEmpty || viewModel.isScanning || viewModel.isExecuting)
            .buttonStyle(.borderedProminent)

            Spacer()

            if viewModel.isScanning || viewModel.isExecuting {
                ProgressView()
                    .controlSize(.small)
            }

            Text("Selected: \(viewModel.formattedSelectedTotalSize)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if let plan = viewModel.plan {
            List {
                ForEach(groupedTargets(plan.targets), id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.targets) { target in
                            targetRow(target)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .overlay(alignment: .bottom) {
                summaryFooter
            }
        } else if viewModel.isScanning {
            ProgressView("Scanning cleanup targets...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("No cleanup plan", systemImage: "sparkles")
        }
    }

    private func targetRow(_ target: CleanupTarget) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.selectedTargetIDs.contains(target.id) },
                    set: { _ in viewModel.toggleSelection(for: target.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(target.displayName)
                    .lineLimit(1)
                Text(target.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(target.formattedSize)
                    .font(.system(.body, design: .monospaced))
                Text(target.riskLevel.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(target.riskLevel == .high ? .red : .secondary)
            }
        }
    }

    private var summaryFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dryRun = viewModel.dryRunReport {
                Text("Dry Run: \(dryRun.formattedTotalReclaimableSize) reclaimable across \(dryRun.targetCount) targets")
                    .font(.caption)
                if !dryRun.warnings.isEmpty {
                    Text(dryRun.warnings.prefix(2).joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            if let execution = viewModel.lastExecution {
                Text("Last clean: reclaimed \(execution.formattedReclaimedSize), deleted \(execution.deletedCount), failed \(execution.failedCount)")
                    .font(.caption)
                    .foregroundStyle(execution.failedCount > 0 ? .orange : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial)
    }

    private func groupedTargets(_ targets: [CleanupTarget]) -> [(key: String, targets: [CleanupTarget])] {
        let grouped = Dictionary(grouping: targets) { $0.category }
        return grouped
            .map { (key: $0.key.replacingOccurrences(of: "_", with: " ").capitalized, targets: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.key < $1.key }
    }
}
