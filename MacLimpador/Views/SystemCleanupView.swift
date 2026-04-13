import SwiftUI

struct SystemCleanupView: View {
    @State private var viewModel = SystemCleanupViewModel()
    
    var body: some View {
        VStack {
            if viewModel.categories.isEmpty {
                ContentUnavailableView("Nenhuma categoria", systemImage: "tray")
            } else {
                List {
                    ForEach(viewModel.categories.indices, id: \.self) { index in
                        DisclosureGroup(
                            isExpanded: $viewModel.categories[index].isExpanded,
                            content: {
                                ForEach(viewModel.categories[index].items.indices, id: \.self) { itemIndex in
                                    HStack {
                                        Toggle("", isOn: $viewModel.categories[index].items[itemIndex].isSelected)
                                            .labelsHidden()
                                            .toggleStyle(.checkbox)
                                        
                                        Text(viewModel.categories[index].items[itemIndex].name)
                                            .font(.body)
                                        Spacer()
                                        Text(viewModel.categories[index].items[itemIndex].formattedSize)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 20)
                                    .padding(.vertical, 4)
                                }
                            },
                            label: {
                                HStack(spacing: 16) {
                                    Button(action: {
                                        viewModel.toggleCategorySelection(index: index)
                                    }) {
                                        Image(systemName: viewModel.categories[index].isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundColor(viewModel.categories[index].isSelected ? .accentColor : .secondary)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Image(systemName: viewModel.categories[index].icon)
                                        .foregroundColor(.accentColor)
                                        .font(.title2)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(viewModel.categories[index].name)
                                            .font(.headline)
                                        Text(viewModel.categories[index].description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.isScanning && !viewModel.categories[index].isCalculated {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text(viewModel.categories[index].formattedSize)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        )
                    }
                }
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Total a Limpar:")
                            .font(.title2)
                        Spacer()
                        if viewModel.isScanning {
                            ProgressView()
                        } else {
                            Text(viewModel.formattedTotalSize)
                                .font(.title)
                                .bold()
                                .fontDesign(.monospaced)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.startScan()
                        }) {
                            Text("Escanear")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isScanning || viewModel.isCleaning)
                        
                        Button(action: {
                            viewModel.cleanSelected()
                        }) {
                            if viewModel.isCleaning {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(minWidth: 100)
                            } else {
                                Text("Limpar")
                                    .frame(minWidth: 100)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.totalSize == 0)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding()
            }
        }
        .navigationTitle("Limpeza do Sistema")
        .onAppear {
            viewModel.startScan()
        }
    }
}