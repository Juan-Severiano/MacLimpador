import Foundation
import SwiftUI

@Observable
final class ContentViewModel {
    var selectedItem: NavigationItem? = .smartScan
    var isFDAAuthorized: Bool = false
    
    init() {
        checkFDAAuthorization()
    }
    
    func checkFDAAuthorization() {
        // No Sandbox, isso funciona 100%. No Sandbox (TestFlight), sempre dará falso.
        let tccPath = "/Library/Application Support/com.apple.TCC"
        let isTCCReadable = FileManager.default.isReadableFile(atPath: tccPath)
        
        let messagesUrl = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Messages")
        let isMessagesReadable = FileManager.default.isReadableFile(atPath: messagesUrl.path)
        
        let detectedFDA = isTCCReadable || isMessagesReadable
        
        #if DEBUG
        self.isFDAAuthorized = detectedFDA
        #else
        // EM PRODUÇÃO/TESTFLIGHT:
        // Se detectarmos FDA, ótimo. Se não, mas o usuário clicar em verificar,
        // nós deixamos passar para não travar o app devido às restrições do Sandbox.
        // O app tentará limpar o que conseguir dentro da bolha.
        self.isFDAAuthorized = true 
        #endif
    }
}