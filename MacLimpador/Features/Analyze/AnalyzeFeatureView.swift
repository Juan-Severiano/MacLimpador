import SwiftUI

struct AnalyzeFeatureView: View {
    @State private var viewModel = AnalyzeFeatureViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.3)
            if let snapshot = viewModel.snapshot {
                mainContent(snapshot)
            } else if viewModel.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing disk…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Pick a folder to analyze", systemImage: "internaldrive")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel.snapshot == nil {
                viewModel.scan()
            }
        }
        .confirmationDialog(
            "Move to Trash",
            isPresented: .init(
                get: { viewModel.confirmationPaths != nil },
                set: { if !$0 { viewModel.cancelTrash() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move \(viewModel.pendingDeletion.count) item(s) to Trash", role: .destructive) {
                viewModel.confirmTrash()
            }
            Button("Cancel", role: .cancel) { viewModel.cancelTrash() }
        } message: {
            Text("Items will be moved to Trash. You can recover them later.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { viewModel.goTo(NSHomeDirectory()) }) {
                Label("Home", systemImage: "house")
                    .font(.system(size: 12))
            }
            .disabled(viewModel.isScanning)

            if viewModel.currentPath != NSHomeDirectory() {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(URL(fileURLWithPath: viewModel.currentPath).lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }

            Spacer()

            if let snapshot = viewModel.snapshot {
                diskUsageBar(snapshot)
                    .frame(width: 200)
            }

            Button(action: { viewModel.scan(forceRefresh: true) }) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning)
            .help("Refresh")

            Button(action: viewModel.pickDirectory) {
                Image(systemName: "folder.badge.plus")
            }
            .disabled(viewModel.isScanning)
            .help("Pick Folder")

            if viewModel.isScanning { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func diskUsageBar(_ snapshot: AnalyzeSnapshot) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                Text(snapshot.formattedTotalSize)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("/ \(ByteCountFormatter.string(fromByteCount: snapshot.diskTotalBytes, countStyle: .file)) used")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                    Capsule().fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(snapshot.diskUsedPercent), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Main Content (Two-Panel)

    private func mainContent(_ snapshot: AnalyzeSnapshot) -> some View {
        let regularEntries = snapshot.entries.filter { $0.kind != .insight }
        let insights = snapshot.entries.filter { $0.kind == .insight }

        return HStack(spacing: 0) {
            // Left Sidebar
            sidebar(snapshot: snapshot, entries: regularEntries, insights: insights)
                .frame(width: 260)

            Divider().opacity(0.3)

            // Right: Treemap or Large Files
            if viewModel.showLargeFiles {
                largeFilesList(snapshot.largeFiles)
            } else {
                treemapPanel(entries: regularEntries)
            }
        }
    }

    // MARK: - Sidebar

    private func sidebar(snapshot: AnalyzeSnapshot, entries: [AnalyzeEntry], insights: [AnalyzeEntry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Planet + counts
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PlanetView(type: .jupiter, size: 60)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(entries.count) items")
                                .font(.system(size: 12, weight: .semibold))
                            Text(snapshot.formattedTotalSize)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Divider().opacity(0.3)

                // Mode selector
                Picker("Mode", selection: $viewModel.showLargeFiles) {
                    Text("Contents").tag(false)
                    Text("Large Files").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)

                // Insights
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden Space")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)

                        ForEach(insights) { entry in
                            sidebarInsightRow(entry, total: snapshot.totalSize)
                        }
                    }
                }

                // Directory list
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentPath == NSHomeDirectory() ? "Home Directory" : "Contents")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)

                        ForEach(entries) { entry in
                            sidebarEntryRow(entry, total: snapshot.totalSize)
                        }
                    }
                }

                // Trash selected
                if !viewModel.selectedEntryIDs.isEmpty {
                    Button(action: viewModel.requestTrashSelection) {
                        Label("Trash Selected (\(viewModel.selectedEntryIDs.count))", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.horizontal, 14)
                }

                Spacer(minLength: 20)
            }
        }
    }

    private func sidebarEntryRow(_ entry: AnalyzeEntry, total: Int64) -> some View {
        let fraction = total > 0 ? Double(entry.size) / Double(total) : 0

        return Button(action: {
            if entry.kind == .directory { viewModel.goTo(entry.path) }
        }) {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { viewModel.selectedEntryIDs.contains(entry.id) },
                    set: { _ in viewModel.toggleEntry(entry.id) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Image(systemName: entry.kind == .directory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(entry.kind == .directory ? .orange.opacity(0.8) : .secondary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.08)).frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5).fill(Color.orange.opacity(0.6))
                                .frame(width: max(0, geo.size.width * CGFloat(fraction)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }

                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func sidebarInsightRow(_ entry: AnalyzeEntry, total: Int64) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
                .frame(width: 14)
            Text(entry.name)
                .font(.system(size: 11))
                .lineLimit(1)
            Spacer()
            Text(entry.formattedSize)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggleEntry(entry.id) }
    }

    // MARK: - Treemap

    private func treemapPanel(entries: [AnalyzeEntry]) -> some View {
        let items = entries.enumerated().map { (idx, entry) in
            TreemapItem(
                name: entry.name,
                path: entry.path,
                size: max(entry.size, 1),
                color: Color.treemapColor(at: idx)
            )
        }

        return Group {
            if items.isEmpty {
                ContentUnavailableView("No items", systemImage: "folder")
            } else {
                TreemapView(items: items) { path in
                    viewModel.goTo(path)
                }
                .padding(8)
            }
        }
    }

    // MARK: - Large Files List

    private func largeFilesList(_ files: [LargeFileEntry]) -> some View {
        List(files) { file in
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).lineLimit(1)
                    Text(file.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Reveal") { viewModel.perform(.reveal, on: file.path) }.buttonStyle(.link)
                    Button("Preview") { viewModel.perform(.preview, on: file.path) }.buttonStyle(.link)
                }

                Text(file.formattedSize)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .listStyle(.inset)
    }
}
