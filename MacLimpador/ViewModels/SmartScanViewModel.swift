import Foundation
import SwiftUI

@Observable
@MainActor
final class SmartScanViewModel {
    var state: SmartScanState = .idle
    var categoryResults: [SmartScanCategoryResult] = []
    var totalJunkSize: Int64 = 0
    var freedSpace: Int64 = 0
    var isCleaning: Bool = false

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalJunkSize, countStyle: .file)
    }

    var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file)
    }

    var nonEmptyResults: [SmartScanCategoryResult] {
        categoryResults.filter { !$0.isEmpty }
    }

    func startScan() {
        categoryResults = []
        totalJunkSize = 0
        freedSpace = 0
        state = .scanning(progress: 0, step: "Iniciando varredura...")

        Task {
            let stream = await SmartScanService.shared.scan()
            for await progress in stream {
                categoryResults.append(progress.categoryResult)
                totalJunkSize = categoryResults.reduce(0) { $0 + $1.totalSize }
                state = .scanning(progress: progress.progress, step: progress.currentStep)
            }
            state = .results(categoryResults)
        }
    }

    func reset() {
        state = .idle
        categoryResults = []
        totalJunkSize = 0
        freedSpace = 0
    }

    func clean(categoryResult: SmartScanCategoryResult) {
        guard let index = categoryResults.firstIndex(where: { $0.id == categoryResult.id }) else { return }
        isCleaning = true

        Task {
            let freed = await SmartScanService.shared.deleteItems(in: categoryResult)
            self.freedSpace += freed
            self.categoryResults.remove(at: index)
            self.totalJunkSize = self.categoryResults.reduce(0) { $0 + $1.totalSize }
            self.isCleaning = false
        }
    }

    func cleanAll() {
        isCleaning = true
        let results = categoryResults

        Task {
            var totalFreed: Int64 = 0
            for result in results {
                let freed = await SmartScanService.shared.deleteItems(in: result)
                totalFreed += freed
            }
            self.freedSpace += totalFreed
            self.categoryResults = []
            self.totalJunkSize = 0
            self.isCleaning = false
        }
    }

    func toggleSubcategory(categoryId: UUID, subcategoryId: UUID) {
        guard let ci = categoryResults.firstIndex(where: { $0.id == categoryId }),
              let si = categoryResults[ci].subcategories.firstIndex(where: { $0.id == subcategoryId }) else { return }
        categoryResults[ci].subcategories[si].isSelected.toggle()
        totalJunkSize = categoryResults.reduce(0) { $0 + $1.totalSize }
    }
}
