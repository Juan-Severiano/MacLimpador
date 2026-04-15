import SwiftUI

struct StorageView: View {
    @State private var viewModel = StorageViewModel()
    @State private var currentPath: String = "/"
    @State private var viewMode: FileViewMode = .list
    @State private var isScanning: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            StorageToolbar(viewModel: viewModel, viewMode: $viewMode, isScanning: $isScanning)
            
            HSplitView {
                categorySidebar
                    .frame(minWidth: 200, maxWidth: 280)
                
                fileContentView
            }
        }
        .navigationTitle("Armazenamento")
        .task {
            await startScan()
        }
    }
    
    private var categorySidebar: some View {
        List {
            Section("Categorias") {
                ForEach(viewModel.categorySummary) { item in
                    SidebarCategoryRow(summary: item)
                }
            }
            
            Section {
                HStack {
                    Text("Total")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.formattedTotalSize)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
    }
    
    private var fileContentView: some View {
        Group {
            if isScanning {
                scanningView
            } else if viewModel.filteredResults.isEmpty {
                emptyView
            } else {
                if viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analisando arquivos...")
                .font(.headline)
            
            Text(viewModel.scanProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Nenhum arquivo encontrado")
                .font(.headline)
            
            Text("Clique em 'Escanear' para encontrar arquivos")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button(action: { Task { await startScan() } }) {
                Label("Escanear Agora", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        List(viewModel.filteredResults) { item in
            FileListRow(result: item)
        }
    }
    
    private var gridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
            ForEach(viewModel.filteredResults) { item in
                FileGridItem(result: item)
            }
        }
        .padding()
    }
    
    private func startScan() async {
        isScanning = true
        await viewModel.startScan()
        isScanning = false
    }
}

enum FileViewMode: String, CaseIterable {
    case list = "Lista"
    case grid = "Grade"
}

struct StorageToolbar: View {
    @Bindable var viewModel: StorageViewModel
    @Binding var viewMode: FileViewMode
    @Binding var isScanning: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: { Task { await viewModel.startScan() } }) {
                Label("Escanear", systemImage: "magnifyingglass")
            }
            .disabled(isScanning)
            
            Picker("Visualização", selection: $viewMode) {
                ForEach(FileViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            
            Spacer()
            
            if !viewModel.filteredResults.isEmpty {
                Text("\(viewModel.filteredResults.count) itens")
                    .foregroundStyle(.secondary)
            }
            
            Button(action: {}) {
                Label("Mover", systemImage: "externaldrive")
            }
            .disabled(viewModel.filteredResults.isEmpty)
            
            Button(action: {}) {
                Label("Deletar", systemImage: "trash")
            }
            .disabled(viewModel.filteredResults.isEmpty)
            .foregroundStyle(.red)
        }
        .padding()
    }
}

struct SidebarCategoryRow: View {
    let summary: StorageViewModel.CategorySummaryItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: summary.category.iconName)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.category.rawValue)
                    .font(.subheadline)
                
                Text("\(summary.count) itens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(summary.formattedSize)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private var color: Color {
        switch summary.category {
        case .junk: return .red
        case .orphaned: return .orange
        case .package: return .blue
        case .cache: return .purple
        case .log: return .gray
        case .duplicate: return .yellow
        case .temporary: return .cyan
        case .largeFile: return .green
        }
    }
}

struct FileListRow: View {
    let result: ScanResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.category.iconName)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .lineLimit(1)
                
                Text(result.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(result.formattedSize)
                    .font(.system(.body, design: .monospaced))
                
                ConfidenceView(confidence: result.confidence)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch result.category {
        case .junk: return .red
        case .orphaned: return .orange
        case .package: return .blue
        case .cache: return .purple
        case .log: return .gray
        case .duplicate: return .yellow
        case .temporary: return .cyan
        case .largeFile: return .green
        }
    }
}

struct FileGridItem: View {
    let result: ScanResult
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: result.category.iconName)
                .font(.title)
                .foregroundStyle(iconColor)
            
            Text(result.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(result.formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 100)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.05))
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var iconColor: Color {
        switch result.category {
        case .junk: return .red
        case .orphaned: return .orange
        case .package: return .blue
        case .cache: return .purple
        case .log: return .gray
        case .duplicate: return .yellow
        case .temporary: return .cyan
        case .largeFile: return .green
        }
    }
}

struct ConfidenceView: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
        }
    }
    
    private var confidenceColor: Color {
        if confidence > 0.7 { return .green }
        if confidence > 0.4 { return .orange }
        return .red
    }
}