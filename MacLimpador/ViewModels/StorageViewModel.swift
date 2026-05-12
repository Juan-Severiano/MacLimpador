import Foundation
import Observation

@Observable
final class StorageViewModel {
    var scanResults: [ScanResult] = []
    var selectedItemIds = Set<UUID>()
    var isScanning: Bool = false
    var scanProgress: String = ""
    var totalSizeFound: Int64 = 0
    var selectedCategory: StorageCategory?
    var errorMessage: String?
    
    private let scanner = StorageScanner.shared
    
    var filteredResults: [ScanResult] {
        guard let category = selectedCategory else {
            return scanResults
        }
        return scanResults.filter { $0.category == category }
    }
    
    var categorySummary: [CategorySummaryItem] {
        var summary: [StorageCategory: (Int64, Int)] = [:]
        
        for result in scanResults {
            let current = summary[result.category] ?? (0, 0)
            summary[result.category] = (current.0 + result.size, current.1 + 1)
        }
        
        return StorageCategory.allCases.compactMap { category in
            guard let (size, count) = summary[category], count > 0 else {
                return nil
            }
            return CategorySummaryItem(category: category, size: size, count: count)
        }.sorted { $0.size > $1.size }
    }
    
    struct CategorySummaryItem: Identifiable {
        let id = UUID()
        let category: StorageCategory
        let size: Int64
        let count: Int
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeFound, countStyle: .file)
    }
    
    @MainActor
    func startScan() async {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = "Starting scan..."
        errorMessage = nil
        scanResults = []
        selectedItemIds = []
        totalSizeFound = 0
        
        for await newResults in await scanner.scan() {
            scanResults.append(contentsOf: newResults)
            totalSizeFound = scanResults.reduce(0) { $0 + $1.size }
            scanProgress = "Found \(scanResults.count) items..."
        }
        
        scanProgress = "Scan complete. Found \(scanResults.count) items"
        isScanning = false
    }
    
    func cancelScan() {
        scanner.cancelScan()
        isScanning = false
        scanProgress = "Scan cancelled"
    }
    
    func selectCategory(_ category: StorageCategory?) {
        selectedCategory = category
    }
    
    func toggleSelection(for id: UUID) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }
    
    func selectAllFiltered() {
        for item in filteredResults {
            selectedItemIds.insert(item.id)
        }
    }
    
    func deselectAll() {
        selectedItemIds.removeAll()
    }
    
    @MainActor
    func deleteSelectedItems() async -> Int64 {
        let itemsToDelete = scanResults.filter { selectedItemIds.contains($0.id) }
        let freed = await performDeletion(on: itemsToDelete)
        selectedItemIds.removeAll()
        return freed
    }
    
    @MainActor
    func deleteHighConfidenceItems() async -> Int64 {
        let itemsToDelete = scanResults.filter { $0.confidence > 0.8 }
        return await performDeletion(on: itemsToDelete)
    }
    
    @MainActor
    private func performDeletion(on items: [ScanResult]) async -> Int64 {
        var freedSpace: Int64 = 0
        
        for item in items {
            let url = URL(fileURLWithPath: item.path)
            
            do {
                // For MVP, we use trashItem which is safer
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                freedSpace += item.size
                
                if let index = scanResults.firstIndex(where: { $0.id == item.id }) {
                    scanResults.remove(at: index)
                }
            } catch {
                print("Failed to delete \(item.path): \(error.localizedDescription)")
                continue
            }
        }
        
        totalSizeFound -= freedSpace
        return freedSpace
    }
}
