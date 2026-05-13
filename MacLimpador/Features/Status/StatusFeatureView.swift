import SwiftUI

struct StatusFeatureView: View {
    @State private var viewModel = StatusFeatureViewModel()
    @State private var sortByCPU: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snapshot = viewModel.snapshot {
                    healthCard(snapshot)
                    metricsGrid(snapshot)
                    processTable(snapshot)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Collecting system status...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(16)
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Health Card

    private func healthCard(_ snap: StatusSnapshot) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(healthColor(snap.healthScore))
                        .frame(width: 6, height: 6)
                    Text("HEALTH")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(healthColor(snap.healthScore))
                    Text(snap.hardwareSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(snap.healthScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(snap.healthMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(healthColor(snap.healthScore))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        statPill("CPU \(Int(snap.cpuUsagePercent))%")
                        statPill("Mem \(Int(snap.memoryUsedPercent))% · \(snap.memoryPressureLevel)")
                    }
                    HStack(spacing: 8) {
                        statPill("Disk \(Int(snap.disk.totalBytes > 0 ? Double(snap.disk.usedBytes) / Double(snap.disk.totalBytes) * 100 : 0))% · \(ByteCountFormatter.string(fromByteCount: snap.disk.freeBytes, countStyle: .file)) free")
                        statPill("up \(snap.formattedUptime)")
                    }
                }
            }
            .padding(18)

            Spacer(minLength: 0)

            PlanetView(type: .sun, size: 100)
                .padding(12)
                .opacity(0.9)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.65))
    }

    // MARK: - Metrics Grid

    private func metricsGrid(_ snap: StatusSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(
                label: "CPU", labelColor: .teal,
                value: String(format: "%.1f", snap.cpuUsagePercent), unit: "%",
                subtitle: String(format: "Load %.2f · %.2f · %.2f", snap.cpuLoadAvg1, snap.cpuLoadAvg5, snap.cpuLoadAvg15),
                chart: { SparklineView(values: viewModel.cpuHistory, color: .teal) },
                bar: nil
            )

            metricCard(
                label: "MEMORY", labelColor: .purple,
                value: String(format: "%.0f", snap.memoryUsedPercent), unit: "%",
                subtitle: "\(ByteCountFormatter.string(fromByteCount: snap.memoryUsedBytes, countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: snap.memoryTotalBytes, countStyle: .memory))",
                chart: { SparklineView(values: viewModel.memHistory, color: .purple) },
                bar: (snap.memoryUsedPercent, 100, .purple)
            )

            metricCard(
                label: "GPU", labelColor: .orange,
                value: snap.gpuUsagePercent.map { String(format: "%.0f", $0) } ?? "--",
                unit: snap.gpuUsagePercent != nil ? "%" : "",
                subtitle: snap.gpuName ?? "Apple Silicon",
                chart: { SparklineView(values: viewModel.gpuHistory, color: .orange) },
                bar: snap.gpuUsagePercent.map { ($0, 100, Color.orange) }
            )

            metricCard(
                label: "DISK", labelColor: .blue,
                value: String(format: "%.0f", snap.disk.totalBytes > 0 ? Double(snap.disk.usedBytes) / Double(snap.disk.totalBytes) * 100 : 0),
                unit: "%",
                subtitle: "\(ByteCountFormatter.string(fromByteCount: snap.disk.freeBytes, countStyle: .file)) free · R \(formatMBps(snap.diskReadMBps)) W \(formatMBps(snap.diskWriteMBps))",
                chart: { SparklineView(values: viewModel.diskReadHistory, color: .blue) },
                bar: snap.disk.totalBytes > 0 ? (Double(snap.disk.usedBytes) / Double(snap.disk.totalBytes) * 100, 100, .blue) : nil
            )

            metricCard(
                label: "NETWORK", labelColor: .green,
                value: formatMBps(snap.network.downloadMBps),
                unit: "",
                subtitle: "↓ \(formatMBps(snap.network.downloadMBps)) · ↑ \(formatMBps(snap.network.uploadMBps))",
                chart: { SparklineView(values: viewModel.netDownHistory, color: .green) },
                bar: nil
            )

            if let battery = snap.batteryPercent {
                metricCard(
                    label: "BATTERY", labelColor: batteryColor(battery, snap.batteryCharging),
                    value: String(format: "%.0f", battery), unit: "%",
                    subtitle: batterySubtitle(snap),
                    chart: { MiniBarView(value: battery, total: 100, color: batteryColor(battery, snap.batteryCharging)).padding(.vertical, 4) },
                    bar: (battery, 100, batteryColor(battery, snap.batteryCharging))
                )
            }
        }
    }

    private func metricCard<C: View>(
        label: String,
        labelColor: Color,
        value: String,
        unit: String,
        subtitle: String,
        @ViewBuilder chart: () -> C,
        bar: (value: Double, total: Double, color: Color)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(labelColor).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(labelColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 3)
                }
            }

            chart()
                .frame(height: 36)

            if let bar {
                MiniBarView(value: bar.value, total: bar.total, color: bar.color)
            }

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Process Table

    private func processTable(_ snap: StatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { sortByCPU = true }) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: { sortByCPU = true }) {
                    HStack(spacing: 2) {
                        Text("CPU")
                        if sortByCPU { Image(systemName: "chevron.down").font(.system(size: 8)) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(sortByCPU ? .white : .secondary)
                }
                .buttonStyle(.plain)
                Button(action: { sortByCPU = false }) {
                    HStack(spacing: 2) {
                        Text("MEM")
                        if !sortByCPU { Image(systemName: "chevron.down").font(.system(size: 8)) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(!sortByCPU ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            let sorted = sortByCPU
                ? snap.topProcesses.sorted { $0.cpuPercent > $1.cpuPercent }
                : snap.topProcesses.sorted { $0.memoryMB > $1.memoryMB }

            ForEach(Array(sorted.prefix(12).enumerated()), id: \.element.id) { idx, proc in
                processRow(proc, index: idx)
            }
        }
    }

    private func processRow(_ proc: StatusProcess, index: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(cpuBarColor(proc.cpuPercent))
                .frame(width: 6, height: 6)

            Text(proc.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cpuBarColor(proc.cpuPercent).opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cpuBarColor(proc.cpuPercent))
                        .frame(width: max(0, geo.size.width * CGFloat(min(proc.cpuPercent / 100, 1))))
                }
            }
            .frame(width: 60, height: 5)

            Text(String(format: "%.1f", proc.cpuPercent))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 36, alignment: .trailing)

            Text(proc.memoryMB >= 1024
                ? String(format: "%.1f GB", proc.memoryMB / 1024)
                : String(format: "%.0f MB", proc.memoryMB))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(index.isMultiple(of: 2) ? cardBackground.opacity(0.5) : Color.clear)
    }

    // MARK: - Helpers

    private var cardBackground: Color {
        Color(red: 0.14, green: 0.12, blue: 0.10)
    }

    private func healthColor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 75..<90: return Color(red: 0.6, green: 0.9, blue: 0.4)
        case 60..<75: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func cpuBarColor(_ cpu: Double) -> Color {
        if cpu > 80 { return .red }
        if cpu > 50 { return .orange }
        return Color(red: 0.42, green: 0.68, blue: 0.87)
    }

    private func batteryColor(_ percent: Double, _ charging: Bool?) -> Color {
        if charging == true { return .green }
        if percent < 20 { return .red }
        if percent < 40 { return .orange }
        return Color(red: 0.42, green: 0.82, blue: 0.64)
    }

    private func batterySubtitle(_ snap: StatusSnapshot) -> String {
        var parts: [String] = []
        if snap.batteryCharging == true { parts.append("Charging") } else { parts.append("On battery") }
        if let health = snap.batteryHealth { parts.append(health) }
        if let cycles = snap.batteryCycles { parts.append("\(cycles) cycles") }
        return parts.joined(separator: " · ")
    }

    private func formatMBps(_ value: Double) -> String {
        if value < 0.001 { return "< 1 KB/s" }
        if value < 1 { return String(format: "%.0f KB/s", value * 1000) }
        return String(format: "%.2f MB/s", value)
    }
}
