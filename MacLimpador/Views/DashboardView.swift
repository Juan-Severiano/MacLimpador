import SwiftUI
import Charts

struct DashboardView: View {
    @Bindable var contentViewModel: ContentViewModel
    @State private var statsProvider = SystemStatsProvider.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                
                if !contentViewModel.isFDAAuthorized {
                    permissionBanner
                }
                
                healthCardsSection
                
                quickActionsSection
                
                modulesSection
            }
            .padding(24)
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Olá!")
                    .font(.system(size: 36, weight: .bold))
                
                Text("Seu Mac está em \(healthStatus)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text(statsProvider.currentStats.modelName)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(healthGradient)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
        }
    }
    
    private var permissionBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                .font(.title)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Acesso Limitado")
                    .font(.headline)
                Text("O MacLimpador não tem acesso total ao disco. Algumas funções de limpeza podem não funcionar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Resolver") {
                contentViewModel.selectedItem = .settings
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var healthStatus: String {
        let score = calculateHealthScore()
        if score > 80 { return "ótimas condições" }
        if score > 60 { return "boas condições" }
        if score > 40 { return "condições regulares" }
        return "precisa de atenção"
    }
    
    private var healthGradient: LinearGradient {
        let score = calculateHealthScore()
        if score > 80 {
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if score > 60 {
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if score > 40 {
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func calculateHealthScore() -> Int {
        var score = 100
        if statsProvider.currentStats.diskAvailable < 50_000_000_000 { score -= 30 }
        if statsProvider.currentStats.ramPressure > 80 { score -= 30 }
        return max(0, score)
    }
    
    private var healthCardsSection: some View {
        HStack(spacing: 16) {
            HealthCard(
                title: "Armazenamento",
                value: statsProvider.currentStats.formattedDiskAvailable,
                subtitle: "livre de \(statsProvider.currentStats.formattedDiskTotal)",
                icon: "internaldrive.fill",
                color: storageColor,
                progress: storageProgress
            )
            
            HealthCard(
                title: "Memória RAM",
                value: "\(Int(statsProvider.currentStats.ramPressure))%",
                subtitle: "em uso",
                icon: "memorychip.fill",
                color: .purple,
                progress: statsProvider.currentStats.ramPressure / 100
            )
            
            HealthCard(
                title: "Bateria",
                value: "\(statsProvider.currentStats.batteryPercentage)%",
                subtitle: statsProvider.currentStats.isBatteryCharging ? "carregando" : "restante",
                icon: "battery.100",
                color: .green,
                progress: Double(statsProvider.currentStats.batteryPercentage) / 100
            )
        }
    }
    
    private var storageColor: Color {
        let free = statsProvider.currentStats.diskAvailable
        let total = statsProvider.currentStats.diskTotal
        let usedPercent = Double(total - free) / Double(total)
        
        if usedPercent > 0.9 { return .red }
        if usedPercent > 0.75 { return .orange }
        return .green
    }
    
    private var storageProgress: Double {
        let free = statsProvider.currentStats.diskAvailable
        let total = statsProvider.currentStats.diskTotal
        return Double(total - free) / Double(total)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ações Rápidas")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "Limpar Lixo", icon: "trash.fill", color: .red)
                QuickActionButton(title: "Cache Sistema", icon: "archivebox.fill", color: .orange)
                QuickActionButton(title: "Duplicados", icon: "doc.on.doc.fill", color: .blue)
                QuickActionButton(title: "Apps Antigos", icon: "app.badge.fill", color: .purple)
                QuickActionButton(title: "Logs", icon: "doc.text.fill", color: .gray)
                QuickActionButton(title: "Scan Total", icon: "magnifyingglass", color: .green)
            }
        }
    }
    
    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Explorar")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ModuleCard(item: .storage)
                ModuleCard(item: .memory)
                ModuleCard(item: .cpu)
                ModuleCard(item: .uninstaller)
            }
        }
    }
}

struct HealthCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(color)
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(0.3)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(isHovered ? 0.2 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ModuleCard: View {
    let item: NavigationItem
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(moduleColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundStyle(moduleColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(moduleColor.opacity(isHovered ? 0.3 : 0), lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var moduleColor: Color {
        switch item {
        case .storage: return .green
        case .memory: return .purple
        case .cpu: return .orange
        case .uninstaller: return .red
        default: return .blue
        }
    }
}
