import SwiftUI
import Charts

struct DashboardView: View {
    @State private var statsProvider = SystemStatsProvider.shared
    @State private var selectedCategory: NavigationItem?
    @State private var isHovering: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                
                quickActionsSection
                
                statsGridSection
                
                recentActivitySection
            }
            .padding(24)
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Olá!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(healthEmoji)
                        .font(.title)
                }
                
                Text("Seu Mac está em \(healthStatus.rawValue.lowercased())")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("\(statsProvider.currentStats.modelName)")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            macIcon
        }
    }
    
    private var macIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [healthColor.opacity(0.3), healthColor.opacity(0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 120, height: 120)
            
            Image(systemName: "laptopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(healthColor)
        }
    }
    
    private var healthStatus: HealthStatus {
        let score = calculateHealthScore()
        if score > 80 { return .excellent }
        if score > 60 { return .good }
        if score > 40 { return .fair }
        return .poor
    }
    
    private var healthEmoji: String {
        switch healthStatus {
        case .excellent: return "😊"
        case .good: return "🙂"
        case .fair: return "😐"
        case .poor: return "😟"
        }
    }
    
    private var healthColor: Color {
        switch healthStatus {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private func calculateHealthScore() -> Int {
        var score = 100
        if statsProvider.currentStats.diskAvailable < 50_000_000_000 { score -= 30 }
        if statsProvider.currentStats.ramPressure > 80 { score -= 30 }
        return max(0, score)
    }
    
    private enum HealthStatus: String {
        case excellent = "Excelente"
        case good = "Bom"
        case fair = "Regular"
        case poor = "PrecisaAtenção"
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ações Rápidas")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(quickActions) { action in
                    QuickActionCard(action: action)
                }
            }
        }
    }
    
    private var quickActions: [QuickAction] {
        [
            QuickAction(id: "1", title: "Limpar Lixo", subtitle: "Esvazie a lixeira", icon: "trash.fill", color: .red),
            QuickAction(id: "2", title: "Cache do Sistema", subtitle: "Libere space", icon: "archivebox.fill", color: .orange),
            QuickAction(id: "3", title: "Duplicados", subtitle: "Encontre arquivos", icon: "doc.on.doc.fill", color: .blue),
            QuickAction(id: "4", title: "Apps Não Usados", subtitle: "Remova apps", icon: "app.badge.minus", color: .purple),
            QuickAction(id: "5", title: "Logs Antigos", subtitle: "Apague logs", icon: "doc.text.fill", color: .gray),
            QuickAction(id: "6", title: "Análise Total", subtitle: "Scan completo", icon: "magnifyingglass", color: .green)
        ]
    }
    
    private var statsGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visão Geral")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Armazenamento",
                    value: statsProvider.currentStats.formattedDiskAvailable,
                    subtitle: "livre de \(statsProvider.currentStats.formattedDiskTotal)",
                    icon: "internaldrive.fill",
                    color: storageColor,
                    progress: storageProgress
                )
                
                StatCard(
                    title: "Memória RAM",
                    value: "\(Int(statsProvider.currentStats.ramPressure))%",
                    subtitle: "em uso",
                    icon: "memorychip.fill",
                    color: .purple,
                    progress: statsProvider.currentStats.ramPressure / 100
                )
            }
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
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Módulos")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(NavigationItem.allCases.filter { $0 != .dashboard }) { item in
                    ModuleCard(item: item)
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
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
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottom) {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .frame(height: geometry.size.height * progress)
                    .opacity(0.15)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct QuickAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct QuickActionCard: View {
    let action: QuickAction
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: action.icon)
                .font(.title2)
                .foregroundStyle(action.color)
            
            Text(action.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(action.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(action.color.opacity(isHovered ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(action.color.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
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
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundStyle(moduleColor)
                .frame(width: 48, height: 48)
                .background(moduleColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
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
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
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