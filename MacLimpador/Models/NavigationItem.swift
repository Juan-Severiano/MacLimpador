import Foundation

enum NavigationItem: Hashable, Identifiable, CaseIterable {
    case smartScan
    case dashboard
    case storage
    case memory
    case cpu
    case uninstaller
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .dashboard: return "Dashboard"
        case .storage: return "Armazenamento"
        case .memory: return "Memória"
        case .cpu: return "CPU"
        case .uninstaller: return "Desinstalar Apps"
        case .settings: return "Ajustes"
        }
    }

    var subtitle: String {
        switch self {
        case .smartScan: return "Varredura inteligente completa"
        case .dashboard: return "Visão geral do sistema"
        case .storage: return "Limpe arquivos e libere espaço"
        case .memory: return "Otimize a memória RAM"
        case .cpu: return "Performance do processador"
        case .uninstaller: return "Remova aplicativos"
        case .settings: return "Permissões e Preferências"
        }
    }

    var iconName: String {
        switch self {
        case .smartScan: return "sparkles"
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .storage: return "externaldrive.fill"
        case .memory: return "memorychip.fill"
        case .cpu: return "cpu.fill"
        case .uninstaller: return "x.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: String {
        switch self {
        case .smartScan: return "purple"
        case .dashboard: return "blue"
        case .storage: return "green"
        case .memory: return "indigo"
        case .cpu: return "orange"
        case .uninstaller: return "red"
        case .settings: return "gray"
        }
    }
}