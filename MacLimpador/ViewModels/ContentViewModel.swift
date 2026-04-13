import Foundation
import SwiftUI

@Observable
final class ContentViewModel {
    var selectedItem: NavigationItem? = .dashboard
    var isFDAAuthorized: Bool = false
    
    init() {
        checkFDAAuthorization()
    }
    
    func checkFDAAuthorization() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Messages")
        _ = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        isFDAAuthorized = FileManager.default.isReadableFile(atPath: url.path)
    }
}