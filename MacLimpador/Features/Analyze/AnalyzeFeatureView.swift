import SwiftUI

struct AnalyzeFeatureView: View {
    @State private var viewModel = AnalyzeFeatureViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
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
            Button("Cancel", role: .cancel) {
                viewModel.cancelTrash()
            }
        } message: {
            let size = ByteCountFormatter.string(
                fromByteCount: viewModel.pendingDeletion.reduce(0) { total, path in
                    total + AnalyzeService.calculateSizeSync(at: URL(fileURLWithPath: path))
                },
                countStyle: .file
            )
            Text("This will move approximately \(size) to the Trash. You can recover items from the Trash.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.goTo(NSHomeDirectory()) }) {
                Label("Home", systemImage: "house")
            }
            .disabled(viewModel.isScanning)

            Button(action: viewModel.pickDirectory) {
                Label("Pick Folder", systemImage: "folder")
            }
            .disabled(viewModel.isScanning)

            Button(action: { viewModel.scan(forceRefresh: true) }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning)

            Picker("Mode", selection: $viewModel.showLargeFiles) {
                Text("Entries").tag(false)
                Text("Large Files").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Button(action: viewModel.requestTrashSelection) {
                Label("Trash Selected", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isTrashSelectionDisabled)

            Spacer()

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Text(viewModel.currentPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 320, alignment: .trailing)
        }
        .padding(12)
    }

    private var isTrashSelectionDisabled: Bool {
        if viewModel.showLargeFiles {
            return viewModel.selectedLargeFileIDs.isEmpty || viewModel.isScanning
        }
        return viewModel.selectedEntryIDs.isEmpty || viewModel.isScanning
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = viewModel.snapshot {
            List {
                if viewModel.showLargeFiles {
                    ForEach(snapshot.largeFiles) { file in
                        largeFileRow(file)
                    }
                } else {
                    let insights = snapshot.entries.filter { $0.kind == .insight }
                    let regular = snapshot.entries.filter { $0.kind != .insight }

                    if !insights.isEmpty {
                        Section("Hidden Space Insights") {
                            ForEach(insights) { entry in
                                insightRow(entry)
                            }
                        }
                    }

                    if !regular.isEmpty {
                        Section(viewModel.currentPath == NSHomeDirectory() ? "Home Directory" : "Contents") {
                            ForEach(regular) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .overlay(alignment: .bottom) {
                footer(snapshot)
            }
        } else if viewModel.isScanning {
            ProgressView("Analyzing disk...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("No analysis data", systemImage: "internaldrive")
        }
    }

    private func insightRow(_ entry: AnalyzeEntry) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.selectedEntryIDs.contains(entry.id) },
                    set: { _ in viewModel.toggleEntry(entry.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text("👀")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .lineLimit(1)
                Text(entry.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            entryActions(path: entry.path, isDirectory: true)

            Text(entry.formattedSize)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.orange)
        }
    }

    private func entryRow(_ entry: AnalyzeEntry) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.selectedEntryIDs.contains(entry.id) },
                    set: { _ in viewModel.toggleEntry(entry.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: entry.kind == .directory ? "folder.fill" : "doc.fill")
                .foregroundStyle(entry.kind == .directory ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .lineLimit(1)
                Text(entry.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if entry.kind == .directory {
                Button("Open") {
                    viewModel.goTo(entry.path)
                }
                .buttonStyle(.link)
            }

            entryActions(path: entry.path, isDirectory: entry.kind == .directory)

            Text(entry.formattedSize)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func largeFileRow(_ file: LargeFileEntry) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.selectedLargeFileIDs.contains(file.id) },
                    set: { _ in viewModel.toggleLargeFile(file.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: "doc.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                Text(file.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            entryActions(path: file.path, isDirectory: false)

            Text(file.formattedSize)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func entryActions(path: String, isDirectory: Bool) -> some View {
        HStack(spacing: 8) {
            Button("Reveal") { viewModel.perform(.reveal, on: path) }
                .buttonStyle(.link)
            if !isDirectory {
                Button("Preview") { viewModel.perform(.preview, on: path) }
                    .buttonStyle(.link)
            }
        }
    }

    private func footer(_ snapshot: AnalyzeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scanned: \(snapshot.formattedTotalSize) • Files: \(snapshot.totalFiles)")
                .font(.caption)
            if let deletion = viewModel.lastDeletionResult {
                Text("Last deletion: reclaimed \(deletion.formattedReclaimedSize), deleted \(deletion.deletedCount), failed \(deletion.failedCount)")
                    .font(.caption2)
                    .foregroundStyle(deletion.failedCount > 0 ? .orange : .secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}
