import Foundation

enum NavigationItem: Hashable, Identifiable, CaseIterable {
    case dashboard
    case storage
    case memory
    case cpu
    case uninstaller
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .storage: return "Armazenamento"
        case .memory: return "Memória"
        case .cpu: return "CPU"
        case .uninstaller: return "Desinstalar Apps"
        }
    }
    
    var subtitle: String {
        switch self {
        case .dashboard: return "Visão geral do sistema"
        case .storage: return "Limpe arquivos e libere espaço"
        case .memory: return "Otimize a memória RAM"
        case .cpu: return "Performance do processador"
        case .uninstaller: return "Remova aplicativos"
        }
    }
    
    var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .storage: return "externaldrive.fill"
        case .memory: return "memorychip.fill"
        case .cpu: return "cpu.fill"
        case .uninstaller: return "x.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .dashboard: return "blue"
        case .storage: return "green"
        case .memory: return "purple"
        case .cpu: return "orange"
        case .uninstaller: return "red"
        }
    }
}