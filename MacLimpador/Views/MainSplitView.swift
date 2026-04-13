import SwiftUI

struct MainSplitView: View {
    @Bindable var viewModel: ContentViewModel
    
    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $viewModel.selectedItem) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.iconName)
                }
            }
            .navigationTitle("MacLimpador")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            if let selected = viewModel.selectedItem {
                switch selected {
                case .dashboard:
                    DashboardView()
                case .systemCleanup:
                    SystemCleanupView()
                case .largeFiles:
                    LargeFilesView()
                case .uninstaller:
                    UninstallerView()
                }
            } else {
                Text("Selecione uma categoria")
                    .foregroundColor(.secondary)
            }
        }
    }
}