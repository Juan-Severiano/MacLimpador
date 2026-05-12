import SwiftUI

struct SmartScanReviewView: View {
    @Binding var result: SmartScanCategoryResult
    let onClean: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubcategoryId: UUID? = nil

    private var selectedSubcategory: SmartScanSubcategory? {
        guard let id = selectedSubcategoryId else { return nil }
        return result.subcategories.first(where: { $0.id == id })
    }

    private var selectedCount: Int {
        result.subcategories.filter(\.isSelected).count
    }

    private var selectedSize: Int64 {
        result.subcategories.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Voltar")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.bar)

                Spacer()

                Text("Gerenciador de Limpeza")
                    .font(.headline)

                Spacer()

                Menu("Ordenar por: Tamanho") {
                    Button("Tamanho") {}
                    Button("Nome") {}
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Three-column layout
            HStack(spacing: 0) {
                // Column 1: Categories (simplified — only one category per sheet)
                List(selection: .constant(result.id)) {
                    Label(result.category.title, systemImage: result.category.iconName)
                        .tag(result.id)
                }
                .listStyle(.sidebar)
                .frame(width: 180)

                Divider()

                // Column 2: Subcategories
                List(selection: $selectedSubcategoryId) {
                    ForEach(result.subcategories) { subcat in
                        SubcategoryRow(subcat: subcat, isSelected: subcat.id == selectedSubcategoryId) {
                            if let idx = result.subcategories.firstIndex(where: { $0.id == subcat.id }) {
                                result.subcategories[idx].isSelected.toggle()
                            }
                        }
                        .tag(subcat.id)
                    }
                }
                .listStyle(.plain)
                .frame(width: 240)
                .onAppear {
                    if selectedSubcategoryId == nil {
                        selectedSubcategoryId = result.subcategories.first?.id
                    }
                }

                Divider()

                // Column 3: Items
                if let subcat = selectedSubcategory {
                    ItemsListView(subcat: subcat, result: $result)
                } else {
                    ContentUnavailableView("Selecione uma subcategoria", systemImage: "folder")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom bar
            HStack {
                if selectedCount == 0 {
                    Text("Nenhum item selecionado")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(selectedCount) categorias selecionadas")
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .fontWeight(.semibold)
                }

                Spacer()

                Button("Limpar Selecionados") {
                    onClean()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(result.category.color)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 460)
    }
}

// MARK: - Subcategory Row

private struct SubcategoryRow: View {
    let subcat: SmartScanSubcategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { subcat.isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(systemName: subcat.iconName)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(subcat.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(subcat.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Items List

private struct ItemsListView: View {
    let subcat: SmartScanSubcategory
    @Binding var result: SmartScanCategoryResult

    private var subcatIndex: Int? {
        result.subcategories.firstIndex(where: { $0.id == subcat.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subcat.name)
                        .font(.title3.bold())
                    Text(subcat.formattedSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Selecionar Todos") {
                        toggleAll(selected: true)
                    }
                    Button("Desmarcar Todos") {
                        toggleAll(selected: false)
                    }
                } label: {
                    Label("Selecionar:", systemImage: "checkmark.circle")
                        .font(.subheadline)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if subcat.items.isEmpty {
                ContentUnavailableView("Nenhum item encontrado", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(subcat.items) { item in
                        ItemRow(item: item) { isSelected in
                            setItemSelected(item: item, selected: isSelected)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleAll(selected: Bool) {
        guard let ci = subcatIndex else { return }
        for i in result.subcategories[ci].items.indices {
            result.subcategories[ci].items[i].isSelected = selected
        }
    }

    private func setItemSelected(item: SmartScanItem, selected: Bool) {
        guard let ci = subcatIndex,
              let ii = result.subcategories[ci].items.firstIndex(where: { $0.id == item.id }) else { return }
        result.subcategories[ci].items[ii].isSelected = selected
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: SmartScanItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { item.isSelected }, set: onToggle))
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(systemName: item.path.hasDirectoryPath ? "folder.fill" : "doc.fill")
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(item.path.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
