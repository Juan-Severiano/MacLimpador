import SwiftUI

struct LargeFilesView: View {
    @State private var viewModel = LargeFilesViewModel()
    
    var body: some View {
        VStack {
            if viewModel.scannedDirectory == nil && !viewModel.isScanning {
                ContentUnavailableView(label: {
                    Label("Nenhuma pasta selecionada", systemImage: "magnifyingglass.circle")
                }, description: {
                    Text("Selecione uma pasta para buscar arquivos maiores que \(viewModel.minSizeMB)MB.")
                }, actions: {
                    Button("Selecionar Pasta") {
                        viewModel.selectDirectory()
                    }
                    .buttonStyle(.borderedProminent)
                })
            } else if viewModel.isScanning {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Escaneando arquivos grandes...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.files.isEmpty {
                ContentUnavailableView("Nenhum arquivo grande encontrado", systemImage: "checkmark.circle")
            } else {
                HStack {
                    Text("Pasta: \(viewModel.scannedDirectory?.lastPathComponent ?? "")")
                        .font(.headline)
                    Spacer()
                    Button("Mudar Pasta") {
                        viewModel.selectDirectory()
                    }
                }
                .padding()
                
                List {
                    ForEach($viewModel.files) { $file in
                        HStack(spacing: 16) {
                            Toggle("", isOn: $file.isSelected)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            
                            Image(systemName: "doc")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .font(.body)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(file.url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            
                            Spacer()
                            
                            Text(file.formattedSize)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Total Selecionado:")
                            .font(.title2)
                        Spacer()
                        Text(viewModel.formattedTotalSelectedSize)
                            .font(.title)
                            .bold()
                            .fontDesign(.monospaced)
                    }
                    
                    Button(action: {
                        viewModel.deleteSelected()
                    }) {
                        if viewModel.isDeleting {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 100)
                        } else {
                            Text("Apagar Selecionados")
                                .frame(minWidth: 100)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isDeleting || viewModel.totalSelectedSize == 0)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding()
            }
        }
        .navigationTitle("Arquivos Grandes")
    }
}