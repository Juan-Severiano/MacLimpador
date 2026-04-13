import Foundation
import AppKit

final class TrashMonitorService {
    static let shared = TrashMonitorService()
    
    private var stream: FSEventStreamRef?
    
    func startMonitoring() {
        let trashPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        let pathsToWatch = [trashPath] as CFArray
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        var streamContext = FSEventStreamContext(version: 0, info: context, retain: nil, release: nil, copyDescription: nil)
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<TrashMonitorService>.fromOpaque(info).takeUnretainedValue()
            
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            for path in paths {
                if path.hasSuffix(".app") {
                    monitor.handleTrashedApp(at: path)
                } else if path.hasSuffix(".app/") { // Sometimes directories come with trailing slash
                    let cleanPath = String(path.dropLast())
                    monitor.handleTrashedApp(at: cleanPath)
                }
            }
        }
        
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        
        stream = FSEventStreamCreate(kCFAllocatorDefault,
                                     callback,
                                     &streamContext,
                                     pathsToWatch,
                                     FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                     1.0,
                                     flags)
        
        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            print("Trash monitor started")
        }
    }
    
    func stopMonitoring() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func handleTrashedApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        
        // Wait a brief moment to ensure the app is fully moved
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard FileManager.default.fileExists(atPath: path) else { return }
            
            let name = url.deletingPathExtension().lastPathComponent
            let bundleId = Bundle(url: url)?.bundleIdentifier
            
            self.promptToCleanResidues(appName: name, bundleId: bundleId, appUrl: url)
        }
    }
    
    private func promptToCleanResidues(appName: String, bundleId: String?, appUrl: URL) {
        let alert = NSAlert()
        alert.messageText = "Aplicativo movido para a Lixeira"
        alert.informativeText = "O MacLimpador detectou que você apagou '\(appName)'. Deseja remover também os arquivos residuais associados a este aplicativo?"
        alert.addButton(withTitle: "Limpar Resíduos")
        alert.addButton(withTitle: "Ignorar")
        
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            cleanResidues(appName: appName, bundleId: bundleId)
        }
    }
    
    private func cleanResidues(appName: String, bundleId: String?) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        var residues: [URL] = []
        if let bundleId = bundleId {
            residues.append(contentsOf: [
                home.appendingPathComponent("Library/Application Support/\(bundleId)"),
                home.appendingPathComponent("Library/Caches/\(bundleId)"),
                home.appendingPathComponent("Library/Preferences/\(bundleId).plist"),
                home.appendingPathComponent("Library/Saved Application State/\(bundleId)")
            ])
        }
        residues.append(home.appendingPathComponent("Library/Application Support/\(appName)"))
        
        var deletedCount = 0
        for res in residues {
            if fileManager.fileExists(atPath: res.path) {
                do {
                    try fileManager.removeItem(at: res)
                    deletedCount += 1
                } catch {
                    print("Failed to delete \(res.path)")
                }
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Limpeza Concluída"
        alert.informativeText = "Foram removidos \(deletedCount) itens residuais do aplicativo \(appName)."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}