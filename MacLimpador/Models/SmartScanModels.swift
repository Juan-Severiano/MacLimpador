import Foundation
import SwiftUI

enum SmartScanState {
    case idle
    case scanning(progress: Double, step: String)
    case results([SmartScanCategoryResult])
}

enum SmartScanCategory: String, CaseIterable, Identifiable {
    case systemJunk
    case mailAttachments
    case trashBins
    case universalBinaries

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemJunk: return "Lixo do Sistema"
        case .mailAttachments: return "Anexos de E-mail"
        case .trashBins: return "Lixeiras"
        case .universalBinaries: return "Binários Extra"
        }
    }

    var description: String {
        switch self {
        case .systemJunk: return "Arquivos desnecessários gerados pelo sistema e apps"
        case .mailAttachments: return "Anexos de e-mail que ocupam espaço em disco"
        case .trashBins: return "Arquivos aguardando exclusão permanente"
        case .universalBinaries: return "Código para arquiteturas não utilizadas no seu Mac"
        }
    }

    var iconName: String {
        switch self {
        case .systemJunk: return "gearshape.2.fill"
        case .mailAttachments: return "envelope.fill"
        case .trashBins: return "trash.fill"
        case .universalBinaries: return "cpu.fill"
        }
    }

    var color: Color {
        switch self {
        case .systemJunk: return .green
        case .mailAttachments: return .blue
        case .trashBins: return .orange
        case .universalBinaries: return .purple
        }
    }
}

struct SmartScanItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: URL
    let name: String
    let size: Int64
    var isSelected: Bool

    init(path: URL, name: String, size: Int64, isSelected: Bool = true) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.size = size
        self.isSelected = isSelected
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct SmartScanSubcategory: Identifiable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    var items: [SmartScanItem]
    var totalSize: Int64
    var isSelected: Bool

    init(name: String, iconName: String, items: [SmartScanItem], totalSize: Int64, isSelected: Bool = true) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.items = items
        self.totalSize = totalSize
        self.isSelected = isSelected
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct SmartScanCategoryResult: Identifiable, Sendable {
    let id: UUID
    let category: SmartScanCategory
    var subcategories: [SmartScanSubcategory]

    init(category: SmartScanCategory, subcategories: [SmartScanSubcategory]) {
        self.id = UUID()
        self.category = category
        self.subcategories = subcategories
    }

    var totalSize: Int64 {
        subcategories.reduce(0) { $0 + $1.totalSize }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var selectedSize: Int64 {
        subcategories.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    var isEmpty: Bool { totalSize == 0 }
}

struct SmartScanProgress: Sendable {
    let categoryResult: SmartScanCategoryResult
    let progress: Double
    let currentStep: String
}
