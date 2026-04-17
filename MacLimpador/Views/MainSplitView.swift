import SwiftUI

struct MainSplitView: View {
    @Bindable var viewModel: ContentViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: viewModel)
        } detail: {
            DetailView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct SidebarView: View {
    @Bindable var viewModel: ContentViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedItem) {
            Section("Principal") {
                ForEach(NavigationItem.allCases) { item in
                    NavigationLink(value: item) {
                        SidebarItemView(item: item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MacLimpador")
    }
}

struct SidebarItemView: View {
    let item: NavigationItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DetailView: View {
    @Bindable var viewModel: ContentViewModel
    
    var body: some View {
        Group {
            if let selected = viewModel.selectedItem {
                switch selected {
                case .dashboard:
                    DashboardView()
                case .storage:
                    StorageView()
                case .memory:
                    MemoryDashboardView()
                case .cpu:
                    CPUDashboardView()
                case .uninstaller:
                    UninstallerView()
                }
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Selecione uma opção no menu")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Escolha uma categoria do menu lateral para começar")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
    }
}

struct MemoryDashboardView: View {
    @State private var memoryInfo: MemoryInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeaderView(title: "Memória", subtitle: "Otimize a memória RAM", icon: "memorychip.fill", color: .purple)
                
                if let memory = memoryInfo {
                    MemoryRingView(used: memory.used, total: memory.total, free: memory.free, wired: memory.wired, compressed: memory.compressed)
                        .frame(height: 200)
                    
                    MemoryStatsGrid(memory: memory)
                }
                
                Spacer()
            }
            .padding()
        }
        .task {
            await loadMemoryInfo()
        }
    }
    
    private func loadMemoryInfo() async {
        memoryInfo = MemoryInfo(
            total: 16_000_000_000,
            used: 8_500_000_000,
            free: 7_500_000_000,
            wired: 2_000_000_000,
            compressed: 1_500_000_000
        )
    }
}

struct MemoryInfo {
    let total: Int64
    let used: Int64
    let free: Int64
    let wired: Int64
    let compressed: Int64
    
    var usedPercentage: Double {
        Double(used) / Double(total)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }
}

struct MemoryRingView: View {
    let used: Int64
    let total: Int64
    let free: Int64
    let wired: Int64
    let compressed: Int64
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 20
            let lineWidth: CGFloat = 24
            
            let usedAngle = Angle(degrees: 360 * Double(used) / Double(total))
            
            // Background ring
            var backgroundPath = Path()
            backgroundPath.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(backgroundPath, with: .color(.gray.opacity(0.2)), lineWidth: lineWidth)
            
            // Used ring
            var usedPath = Path()
            usedPath.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: usedAngle - .degrees(90), clockwise: false)
            context.stroke(usedPath, with: .color(.purple), lineWidth: lineWidth)
        }
        .overlay(alignment: .center) {
            VStack(spacing: 4) {
                Text("USADO")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: used, countStyle: .file))
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
    }
}

struct MemoryStatsGrid: View {
    let memory: MemoryInfo
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MemoryStatCard(title: "Livre", value: memory.formattedFree, icon: "checkmark.circle.fill", color: .green)
            MemoryStatCard(title: "Wired", value: ByteCountFormatter.string(fromByteCount: memory.wired, countStyle: .file), icon: "lock.fill", color: .orange)
            MemoryStatCard(title: "Comprimido", value: ByteCountFormatter.string(fromByteCount: memory.compressed, countStyle: .file), icon: "archivebox.fill", color: .blue)
            MemoryStatCard(title: "Total", value: memory.formattedTotal, icon: "internaldrive.fill", color: .purple)
        }
    }
}

struct MemoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CPUDashboardView: View {
    @State private var cpuUsage: Double = 0
    @State private var cpuTemp: Double = 45
    @State private var cpuCount: Int = 8
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeaderView(title: "CPU", subtitle: "Monitoramento do processador", icon: "cpu.fill", color: .orange)
                
                CPUGaugeView(usage: cpuUsage)
                    .frame(height: 200)
                
                VStack(spacing: 16) {
                    CPUStatRow(title: "Uso", value: "\(Int(cpuUsage))%")
                    CPUStatRow(title: "Temperatura", value: "\(Int(cpuTemp))°C")
                    CPUStatRow(title: "Núcleos", value: "\(cpuCount)")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
        }
    }
}

struct CPUGaugeView: View {
    let usage: Double
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 20
            
            var bgPath = Path()
            bgPath.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(bgPath, with: .color(.gray.opacity(0.2)), lineWidth: 20)
            
            var fgPath = Path()
            fgPath.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * usage / 100), clockwise: false)
            context.stroke(fgPath, with: .color(.orange), lineWidth: 20)
        }
        .overlay(alignment: .center) {
            VStack(spacing: 4) {
                Text("CPU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(usage))%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
        }
    }
}

struct CPUStatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct HeaderView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}