import Foundation
import Observation

@Observable
final class StorageViewModel {
    var scanResults: [ScanResult] = []
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
    
    var categorySummary: [(StorageCategory, Int64, Int)] {
        var summary: [StorageCategory: (Int64, Int)] = [:]
        
        for result in scanResults {
            let current = summary[result.category] ?? (0, 0)
            summary[result.category] = (current.0 + result.size, current.1 + 1)
        }
        
        return StorageCategory.allCases.compactMap { category in
            guard let (size, count) = summary[category], count > 0 else {
                return nil
            }
            return (category, size, count)
        }.sorted { $0.1 > $1.1 }
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
        totalSizeFound = 0
        
        do {
            let results = try await scanner.scan()
            scanResults = results
            totalSizeFound = results.reduce(0) { $0 + $1.size }
            scanProgress = "Found \(results.count) items"
        } catch {
            errorMessage = error.localizedDescription
            scanProgress = "Scan failed"
        }
        
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
    
    func deleteItems(_ items: [ScanResult]) async throws -> Int64 {
        var freedSpace: Int64 = 0
        
        for item in items {
            let url = URL(fileURLWithPath: item.path)
            
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                freedSpace += item.size
                
                if let index = scanResults.firstIndex(where: { $0.id == item.id }) {
                    scanResults.remove(at: index)
                }
            } catch {
                continue
            }
        }
        
        totalSizeFound -= freedSpace
        return freedSpace
    }
}