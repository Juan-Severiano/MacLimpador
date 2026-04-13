import SwiftUI

struct DashboardView: View {
    @State private var statsProvider = SystemStatsProvider.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header com Info Real do Mac
                HStack {
                    VStack(alignment: .leading) {
                        Text("Saúde do Mac: ")
                            .font(.largeTitle)
                            .bold() +
                        Text("Excelente")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.blue)
                        
                        Text("\(statsProvider.currentStats.modelName) • \(statsProvider.currentStats.cpuName)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 80))
                        .padding()
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                }
                .padding(.horizontal)
                
                // Grid de Status Principal
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                    DashboardStatCard(title: "Armazenamento", 
                                     value: statsProvider.currentStats.formattedDiskAvailable, 
                                     detail: "de \(statsProvider.currentStats.formattedDiskTotal)", 
                                     icon: "internaldrive", 
                                     color: .blue)
                    
                    DashboardStatCard(title: "Memória RAM", 
                                     value: "\(Int(statsProvider.currentStats.ramPressure))%", 
                                     detail: "Pressão do Sistema", 
                                     icon: "memorychip", 
                                     color: .purple)
                    
                    DashboardStatCard(title: "Bateria", 
                                     value: "\(statsProvider.currentStats.batteryPercentage)%", 
                                     detail: statsProvider.currentStats.isBatteryCharging ? "Carregando" : "No Ar", 
                                     icon: "battery.100", 
                                     color: .green)
                    
                    DashboardStatCard(title: "CPU", 
                                     value: "\(Int(statsProvider.currentStats.cpuUsage))%", 
                                     detail: "Carga Atual", 
                                     icon: "cpu", 
                                     color: .orange)
                }
                .padding(.horizontal)
                
                // Seção "Buscando por lixo" estilizada
                VStack(alignment: .leading, spacing: 15) {
                    Text("Ações Recomendadas")
                        .font(.headline)
                        .padding(.leading)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Limpeza Inteligente")
                                .font(.title2)
                                .bold()
                            Text("Encontramos caches e arquivos antigos que podem ser removidos.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Escanear") {
                            // Navegar para limpeza
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(25)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}