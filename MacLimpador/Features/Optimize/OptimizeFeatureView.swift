import SwiftUI

struct OptimizeFeatureView: View {
    @State private var viewModel = OptimizeFeatureViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            List {
                ForEach(viewModel.plan.tasks) { task in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: task.state))
                            .foregroundStyle(color(for: task.state))
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.name)
                                .font(.headline)
                            Text(task.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(task.state.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(color(for: task.state))
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
            .overlay(alignment: .bottom) {
                if let result = viewModel.result {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed: \(result.successCount) success, \(result.skippedCount) skipped, \(result.failedCount) failed")
                        if !result.failures.isEmpty {
                            Text(result.failures.prefix(2).joined(separator: " • "))
                                .lineLimit(2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Toggle("Dry Run", isOn: $viewModel.dryRun)
                .toggleStyle(.switch)
                .frame(width: 130, alignment: .leading)

            Button(action: viewModel.resetPlan) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isRunning)

            Button(action: viewModel.execute) {
                Label(viewModel.dryRun ? "Run Dry Run" : "Optimize", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)

            Spacer()

            if viewModel.isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
    }

    private func icon(for state: OptimizeTaskState) -> String {
        switch state {
        case .pending: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func color(for state: OptimizeTaskState) -> Color {
        switch state {
        case .pending: return .secondary
        case .running: return .blue
        case .success: return .green
        case .skipped: return .orange
        case .failed: return .red
        }
    }
}
