import SwiftUI
import Charts



struct StorageView: View {
    @State private var viewModel = StorageViewModel()
    @State private var selectedItems = Set<ScanResult>()
    @State private var showDeleteConfirmation = false
    @State private var showRelocation = false
    
    var body: some View {
        NavigationSplitView {
            categorySidebar
        } detail: {
            resultsList
        }
        .navigationTitle("Storage")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { Task { await viewModel.startScan() } }) {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(viewModel.isScanning)
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            deleteConfirmationSheet
        }
        .sheet(isPresented: $showRelocation) {
            relocationSheet
        }
    }
    
    private var categorySidebar: some View {
        List {
            Section("Categories") {
                ForEach(viewModel.categorySummary) { item in
                    CategoryRow(summary: item)
                }
            }
            
            Section("Total") {
                HStack {
                    Text("Space Found")
                    Spacer()
                    Text(viewModel.formattedTotalSize)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
    
    private var resultsList: some View {
        List {
            if viewModel.isScanning {
                ProgressView(viewModel.scanProgress)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.filteredResults.isEmpty {
                ContentUnavailableView(
                    "No Items Found",
                    systemImage: "externaldrive.badge.questionmark",
                    description: Text("Run a scan to find cleanup candidates")
                )
            } else {
                ForEach(viewModel.filteredResults) { result in
                    ScanResultRow(result: result)
                }
            }
        }
        .listStyle(.inset)
    }
    
    private var deleteConfirmationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Delete \(selectedItems.count) Items?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This will free up \(calculateSelectedSize())")
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel") {
                    showDeleteConfirmation = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Move to Trash") {
                    Task {
                        try? await viewModel.deleteItems(Array(selectedItems))
                        selectedItems.removeAll()
                        showDeleteConfirmation = false
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(width: 320, height: 220)
    }
    
    private var relocationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("Move to External Drive")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a destination to move selected files")
                .foregroundStyle(.secondary)
            
            Button("Choose Location...") {
                // File relocation logic
            }
        }
        .padding(40)
        .frame(width: 320, height: 220)
    }
    
    private func calculateSelectedSize() -> String {
        let size = selectedItems.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct CategoryRow: View {
    let summary: StorageViewModel.CategorySummaryItem
    
    var body: some View {
        HStack {
            Image(systemName: summary.category.iconName)
                .foregroundStyle(categoryColor)
            
            VStack(alignment: .leading) {
                Text(summary.category.rawValue)
                Text("\(summary.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(summary.formattedSize)
                .fontWeight(.medium)
        }
    }
    
    private var categoryColor: Color {
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

struct ScanResultRow: View {
    let result: ScanResult
    
    var body: some View {
        HStack {
            Image(systemName: result.category.iconName)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading) {
                Text(result.name)
                Text(result.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(result.formattedSize)
                    .fontWeight(.medium)
                
                Text(result.confidencePercentage)
                    .font(.caption)
                    .foregroundStyle(confidenceColor)
            }
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
    
    private var confidenceColor: Color {
        if result.confidence > 0.7 { return .green }
        if result.confidence > 0.4 { return .orange }
        return .red
    }
}