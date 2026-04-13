import SwiftUI

@main
struct MacLimpadorApp: App {
    init() {
        TrashMonitorService.shared.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        MenuBarExtra("MacLimpador", systemImage: "speedometer") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}