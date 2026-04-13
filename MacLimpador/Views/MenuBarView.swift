import SwiftUI

struct MenuBarView: View {
    @State private var statsProvider = SystemStatsProvider.shared
    @State private var selectedDetail: String? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            // Lado Esquerdo: Detalhes dinâmicos
            if let detail = selectedDetail {
                DetailPanelView(type: detail, stats: statsProvider.currentStats)
                    .transition(.move(edge: .leading))
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
                        withAnimation { selectedDetail = (selectedDetail == "disk" ? nil : "disk") }
                    }
                    
                    MenuBarCard(title: "Memória", 
                                value: "\(Int(statsProvider.currentStats.ramPressure))%", 
                                label: "Pressão", 
                                icon: "memorychip",
                                isSelected: selectedDetail == "memory") {
                        withAnimation { selectedDetail = (selectedDetail == "memory" ? nil : "memory") }
                    }
                    
                    MenuBarCard(title: "Bateria", 
                                value: "\(statsProvider.currentStats.batteryPercentage)%", 
                                label: statsProvider.currentStats.isBatteryCharging ? "Carregando" : "No Ar", 
                                icon: "battery.100",
                                isSelected: selectedDetail == "battery") {
                        withAnimation { selectedDetail = (selectedDetail == "battery" ? nil : "battery") }
                    }
                    
                    MenuBarCard(title: "CPU", 
                                value: "\(Int(statsProvider.currentStats.cpuUsage))%", 
                                label: "Carga", 
                                icon: "cpu",
                                isSelected: selectedDetail == "cpu") {
                        withAnimation { selectedDetail = (selectedDetail == "cpu" ? nil : "cpu") }
                    }
                }
                .padding(.horizontal)
                
                // Rede e Dispositivos
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "wifi")
                        Text("Wi-Fi").font(.caption)
                        Spacer()
                        Text("Conectado").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
                    .onTapGesture {
                        withAnimation { selectedDetail = (selectedDetail == "network" ? nil : "network") }
                    }
                }
                .padding()
                
                Divider()
                
                // Footer
                HStack {
                    Button(action: {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
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
            Text(titleForType(type))
                .font(.title2)
                .bold()
                .padding(.top)
            
            if type == "disk" {
                DiskDetailView(stats: stats)
            } else if type == "network" {
                NetworkDetailView()
            } else {
                Text("Detalhes de \(type) em breve...")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .overlay(Divider().padding(.vertical), alignment: .trailing)
    }
    
    func titleForType(_ type: String) -> String {
        switch type {
        case "disk": return "Macintosh HD"
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                Circle()
                    .trim(from: 0, to: CGFloat(Double(stats.diskTotal - stats.diskAvailable) / Double(stats.diskTotal)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(stats.formattedDiskAvailable)
                        .font(.title)
                        .bold()
                    Text("de \(stats.formattedDiskTotal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 150)
            .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 8)
                    Text("Sistema")
                    Spacer()
                    Text("Aprox. 20 GB").foregroundColor(.secondary)
                }
                HStack {
                    Circle().fill(Color.orange).frame(width: 8)
                    Text("Aplicativos")
                    Spacer()
                    Text("Calculando...").foregroundColor(.secondary)
                }
            }
            .font(.caption)
            
            Button("Liberar Espaço") {
                // Ação
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
    }
}

struct NetworkDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("WPA2 Personal").font(.caption).bold()
                    Text("Segurança: Boa").font(.caption2).foregroundColor(.green)
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
                    Text("12 MB/s").bold()
                }
                .frame(maxWidth: .infinity)
                VStack {
                    Text("Upload").font(.caption2)
                    Text("2 MB/s").bold()
                }
                .frame(maxWidth: .infinity)
            }
            
            Button("Testar Velocidade") { }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
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