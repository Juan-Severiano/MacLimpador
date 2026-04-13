import SwiftUI

struct UninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isScanning {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Buscando aplicativos e resíduos...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.apps.isEmpty {
                ContentUnavailableView("Nenhum aplicativo encontrado", systemImage: "app.dashed")
            } else {
                List {
                    ForEach($viewModel.apps) { $app in
                        HStack(spacing: 16) {
                            Toggle("", isOn: $app.isSelected)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.headline)
                                Text(app.bundleIdentifier ?? "Desconhecido")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(app.formattedSize)
                                    .font(.system(.body, design: .monospaced))
                                Text("\(app.residueURLs.count) resíduos")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
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
                        viewModel.uninstallSelected()
                    }) {
                        if viewModel.isUninstalling {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 100)
                        } else {
                            Text("Desinstalar Selecionados")
                                .frame(minWidth: 100)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isUninstalling || viewModel.totalSelectedSize == 0)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding()
            }
        }
        .navigationTitle("Desinstalador")
    }
}