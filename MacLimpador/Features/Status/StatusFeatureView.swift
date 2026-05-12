import SwiftUI

struct StatusFeatureView: View {
    @State private var viewModel = StatusFeatureViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if let snapshot = viewModel.snapshot {
                    cards(snapshot)
                    processAlerts(snapshot)
                } else {
                    ProgressView("Collecting system status...")
                        .frame(maxWidth: .infinity, minHeight: 250)
                }
            }
            .padding(20)
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live Status")
                    .font(.title2.bold())
                if let snapshot = viewModel.snapshot {
                    Text("\(snapshot.hostName) • health \(snapshot.healthScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Circle()
                .fill(healthColor)
                .frame(width: 12, height: 12)
        }
    }

    private var healthColor: Color {
        guard let score = viewModel.snapshot?.healthScore else { return .gray }
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func cards(_ snapshot: StatusSnapshot) -> some View {
        let diskUsedPercent = snapshot.disk.totalBytes > 0
            ? (Double(snapshot.disk.usedBytes) / Double(snapshot.disk.totalBytes)) * 100
            : 0

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            statusCard(
                title: "CPU",
                value: String(format: "%.1f%%", snapshot.cpuUsagePercent),
                subtitle: "Usage",
                tint: .orange
            )

            statusCard(
                title: "Memory",
                value: String(format: "%.1f%%", snapshot.memoryUsedPercent),
                subtitle: "Used",
                tint: .purple
            )

            statusCard(
                title: "Disk",
                value: String(format: "%.1f%%", diskUsedPercent),
                subtitle: ByteCountFormatter.string(fromByteCount: snapshot.disk.freeBytes, countStyle: .file) + " free",
                tint: .blue
            )

            statusCard(
                title: "Network",
                value: String(format: "↓ %.2f MB/s", snapshot.network.downloadMBps),
                subtitle: String(format: "↑ %.2f MB/s", snapshot.network.uploadMBps),
                tint: .green
            )

            if let battery = snapshot.batteryPercent {
                statusCard(
                    title: "Battery",
                    value: String(format: "%.0f%%", battery),
                    subtitle: snapshot.batteryCharging == true ? "Charging" : "On battery",
                    tint: .mint
                )
            }
        }
    }

    private func statusCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func processAlerts(_ snapshot: StatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Process Alerts")
                .font(.headline)

            if snapshot.processAlerts.isEmpty {
                Text("No sustained high-CPU process detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.processAlerts) { alert in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("\(alert.processName) (pid \(alert.pid))")
                                .font(.subheadline)
                            Text(String(format: "%.1f%% CPU • %@", alert.cpuPercent, alert.message))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
