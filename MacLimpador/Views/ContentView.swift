import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    
    var body: some View {
        Group {
            if viewModel.isFDAAuthorized {
                MainSplitView(viewModel: viewModel)
            } else {
                OnboardingView(contentViewModel: viewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkFDAAuthorization()
        }
    }
}