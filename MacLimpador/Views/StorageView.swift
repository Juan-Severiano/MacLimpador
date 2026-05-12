import SwiftUI

struct StorageView: View {
    @State private var viewModel = StorageViewModel()
    @State private var viewMode: FileViewMode = .list
    @State private var isScanning: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            StorageToolbar(viewModel: viewModel, viewMode: $viewMode, isScanning: $isScanning)
            
            Divider()
            
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
        List(selection: Binding(get: { viewModel.selectedCategory }, set: { viewModel.selectCategory($0) })) {
            Section("Categorias") {
                ForEach(StorageCategory.allCases) { category in
                    let summary = viewModel.categorySummary.first(where: { $0.category == category })
                    SidebarCategoryRow(category: category, summary: summary)
                        .tag(category)
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
        VStack(spacing: 0) {
            if isScanning && viewModel.scanResults.isEmpty {
                initialScanningView
            } else if !isScanning && viewModel.filteredResults.isEmpty {
                emptyView
            } else {
                selectionHeader
                
                if viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
    }
    
    private var selectionHeader: some View {
        HStack {
            Button(action: {
                if viewModel.selectedItemIds.count == viewModel.filteredResults.count {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAllFiltered()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.selectedItemIds.count == viewModel.filteredResults.count ? "checkmark.square.fill" : (viewModel.selectedItemIds.isEmpty ? "square" : "minus.square.fill"))
                    Text(viewModel.selectedItemIds.count == viewModel.filteredResults.count ? "Desmarcar Todos" : "Selecionar Todos")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Spacer()
            
            if !viewModel.selectedItemIds.isEmpty {
                Text("\(viewModel.selectedItemIds.count) selecionados")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .background(Color.secondary.opacity(0.05))
    }
    
    private var initialScanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Iniciando análise...")
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
        List {
            ForEach(viewModel.filteredResults) { item in
                FileListRow(result: item, isSelected: viewModel.selectedItemIds.contains(item.id)) {
                    viewModel.toggleSelection(for: item.id)
                }
            }
        }
        .listStyle(.inset)
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                ForEach(viewModel.filteredResults) { item in
                    FileGridItem(result: item, isSelected: viewModel.selectedItemIds.contains(item.id)) {
                        viewModel.toggleSelection(for: item.id)
                    }
                }
            }
            .padding()
        }
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
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await viewModel.startScan() } }) {
                Label("Escanear", systemImage: "magnifyingglass")
            }
            .disabled(isScanning)
            
            if isScanning {
                ProgressView()
                    .controlSize(.small)
                Text(viewModel.scanProgress)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }
            
            Picker("", selection: $viewMode) {
                ForEach(FileViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            
            Button(action: { 
                Task { 
                    await viewModel.deleteHighConfidenceItems() 
                } 
            }) {
                Label("Limpeza Inteligente", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(viewModel.scanResults.filter({ $0.confidence > 0.8 }).isEmpty)

            Spacer()
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Deletar Selecionados", systemImage: "trash")
            }
            .disabled(viewModel.selectedItemIds.isEmpty)
            .foregroundStyle(.red)
        }
        .padding()
        .controlSize(.regular)
        .confirmationDialog(
            "Tem certeza?",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Deletar \(viewModel.selectedItemIds.count) itens", role: .destructive) {
                    Task {
                        await viewModel.deleteSelectedItems()
                    }
                }
                Button("Cancelar", role: .cancel) { }
            },
            message: {
                Text("Esta ação moverá os arquivos selecionados para a Lixeira.")
            }
        )
    }
}

struct SidebarCategoryRow: View {
    let category: StorageCategory
    let summary: StorageViewModel.CategorySummaryItem?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .foregroundStyle(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.subheadline)
                
                if let summary = summary {
                    Text("\(summary.count) itens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let summary = summary {
                Text(summary.formattedSize)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var color: Color {
        switch category {
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
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            Image(systemName: result.category.iconName)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .lineLimit(1)
                    .font(.body)
                
                Text(result.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.formattedSize)
                    .font(.system(.body, design: .monospaced))
                
                ConfidenceView(confidence: result.confidence)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
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

struct FileGridItem: View {
    let result: ScanResult
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Spacer()
                ConfidenceView(confidence: result.confidence)
            }
            
            Image(systemName: result.category.iconName)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
            
            Text(result.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
            
            Text(result.formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onToggle()
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