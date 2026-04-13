import Foundation

enum NavigationItem: Hashable, Identifiable, CaseIterable {
    case dashboard
    case systemCleanup
    case largeFiles
    case uninstaller
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .systemCleanup: return "Limpeza do Sistema"
        case .largeFiles: return "Arquivos Grandes"
        case .uninstaller: return "Desinstalador"
        }
    }
    
    var iconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .systemCleanup: return "trash"
        case .largeFiles: return "doc.viewfinder"
        case .uninstaller: return "minus.rectangle"
        }
    }
}