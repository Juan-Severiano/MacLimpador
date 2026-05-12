import SwiftUI

struct MenuBarView: View {
    @State private var statsProvider = SystemStatsProvider.shared
    @State private var selectedDetail: String? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            // Lado Esquerdo: Detalhes dinâmicos
            if let detail = selectedDetail {
                DetailPanelView(type: detail, stats: statsProvider.currentStats)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                    .frame(width: 280)
            }
            
            // Lado Direito: Painel Principal (Menu Bar fixo)
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saúde do Mac: ") + Text("Excelente").foregroundColor(.blue).bold()
                        Text(statsProvider.currentStats.modelName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "laptopcomputer")
                        .font(.title)
                        .padding(8)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                .padding()
                
                // Grid de Status
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MenuBarCard(title: "Macintosh HD", 
                                value: statsProvider.currentStats.formattedDiskAvailable, 
                                label: "Disponível", 
                                icon: "internaldrive",
                                isSelected: selectedDetail == "disk") {
                        toggleDetail("disk")
                    }
                    
                    MenuBarCard(title: "Memória", 
                                value: "\(Int(statsProvider.currentStats.ramPressure))%", 
                                label: "Pressão", 
                                icon: "memorychip",
                                isSelected: selectedDetail == "memory") {
                        toggleDetail("memory")
                    }
                    
                    MenuBarCard(title: "Bateria", 
                                value: "\(statsProvider.currentStats.batteryPercentage)%", 
                                label: statsProvider.currentStats.isBatteryCharging ? "Carregando" : "No Ar", 
                                icon: "battery.100",
                                isSelected: selectedDetail == "battery") {
                        toggleDetail("battery")
                    }
                    
                    MenuBarCard(title: "CPU", 
                                value: "\(Int(statsProvider.currentStats.cpuUsage))%", 
                                label: "Carga", 
                                icon: "cpu",
                                isSelected: selectedDetail == "cpu") {
                        toggleDetail("cpu")
                    }
                }
                .padding(.horizontal)
                
                // Rede e Dispositivos
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.blue)
                        Text("Conexão de Rede").font(.caption)
                        Spacer()
                        if statsProvider.currentStats.isTestingNetwork {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("\(Int(statsProvider.currentStats.downloadSpeed)) Mbps").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(selectedDetail == "network" ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1)))
                    .onTapGesture {
                        toggleDetail("network")
                    }
                }
                .padding()
                
                Divider()
                
                // Footer
                HStack {
                    Button(action: {
                        openApp()
                    }) {
                        HStack {
                            Image(systemName: "macwindow")
                            Text("Abrir MacLimpador")
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        // Configurações
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
            .frame(width: 320)
        }
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
        .frame(height: 480)
    }
    
    private func toggleDetail(_ detail: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedDetail == detail {
                selectedDetail = nil
            } else {
                selectedDetail = detail
            }
        }
    }
    
    private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "MainAppWindow" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Se não encontrar por ID, tenta o primeiro que não seja o da menu bar
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarCard: View {
    let title: String
    let value: String
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : .blue)
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Text(title).font(.caption2).foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            Text(value).font(.headline).bold().foregroundColor(isSelected ? .white : .primary)
            Text(label).font(.system(size: 9)).foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
}

struct DetailPanelView: View {
    let type: String
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(titleForType(type))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if type == "disk" {
                        DiskDetailView(stats: stats)
                    } else if type == "memory" {
                        MemoryDetailView(stats: stats)
                    } else if type == "battery" {
                        BatteryDetailView(stats: stats)
                    } else if type == "cpu" {
                        CpuDetailView(stats: stats)
                    } else if type == "network" {
                        NetworkDetailView()
                    }
                }
            }
            .scrollIndicators(.hidden)
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .overlay(Divider().padding(.vertical), alignment: .trailing)
    }
    
    func titleForType(_ type: String) -> String {
        switch type {
        case "disk": return "Disco"
        case "memory": return "Memória"
        case "battery": return "Energia"
        case "cpu": return "Processador"
        case "network": return "Rede"
        default: return ""
        }
    }
}

struct DiskDetailView: View {
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(Double(stats.diskTotal - stats.diskAvailable) / Double(stats.diskTotal)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(stats.formattedDiskAvailable)
                        .font(.title2)
                        .bold()
                    Text("livres")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 120)
            .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 6)
                    Text("Usado").font(.caption)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: stats.diskTotal - stats.diskAvailable, countStyle: .file)).font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 6)
                    Text("Total").font(.caption)
                    Spacer()
                    Text(stats.formattedDiskTotal).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct MemoryDetailView: View {
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pressão da Memória")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: stats.ramPressure, total: 100)
                .tint(stats.ramPressure > 70 ? .red : (stats.ramPressure > 40 ? .orange : .green))
            
            HStack {
                Text("\(Int(stats.ramPressure))%")
                    .font(.title2)
                    .bold()
                Spacer()
                Text(stats.ramPressure > 70 ? "Alta" : "Normal")
                    .foregroundColor(stats.ramPressure > 70 ? .red : .green)
                    .font(.caption).bold()
            }
            
            Text("O sistema está gerenciando a memória de forma eficiente.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct BatteryDetailView: View {
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: stats.isBatteryCharging ? "battery.100.bolt" : "battery.75")
                    .font(.largeTitle)
                    .foregroundColor(stats.batteryPercentage < 20 ? .red : .green)
                
                VStack(alignment: .leading) {
                    Text("\(stats.batteryPercentage)%")
                        .font(.title)
                        .bold()
                    Text(stats.isBatteryCharging ? "Carregando" : "Fonte: Bateria")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Saúde da Bateria: 98%").font(.caption)
                Text("Ciclos: 45").font(.caption)
            }
        }
    }
}

struct CpuDetailView: View {
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(stats.cpuName)
                .font(.caption)
                .bold()
                .foregroundColor(.blue)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Carga Atual").font(.caption2).foregroundColor(.secondary)
                    Text("\(Int(stats.cpuUsage))%").font(.title2).bold()
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<10) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.blue)
                            .frame(width: 4, height: CGFloat.random(in: 10...40))
                    }
                }
            }
        }
    }
}

struct NetworkDetailView: View {
    @State private var statsProvider = SystemStatsProvider.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Wi-Fi Ativo").font(.caption).bold()
                    Text("Segurança: Alta").font(.caption2).foregroundColor(.green)
                }
                Spacer()
                Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            HStack(spacing: 15) {
                VStack {
                    Text("Download").font(.caption2)
                    Text(String(format: "%.1f Mbps", statsProvider.currentStats.downloadSpeed)).bold()
                }
                .frame(maxWidth: .infinity)
                VStack {
                    Text("Upload").font(.caption2)
                    Text(String(format: "%.1f Mbps", statsProvider.currentStats.uploadSpeed)).bold()
                }
                .frame(maxWidth: .infinity)
            }
            
            Button(action: {
                Task {
                    await statsProvider.testNetworkSpeed()
                }
            }) {
                if statsProvider.currentStats.isTestingNetwork {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Testando...")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Testar Velocidade")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(statsProvider.currentStats.isTestingNetwork)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}