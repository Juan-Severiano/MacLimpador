import SwiftUI

struct OnboardingView: View {
    let contentViewModel: ContentViewModel
    @State private var viewModel = OnboardingViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Acesso Total ao Disco Necessário")
                .font(.title)
                .bold()
            
            Text("Para limpar arquivos residuais, precisamos de acesso total ao disco.\n\nComo você está rodando pelo Xcode, o app pode não aparecer na lista.\n1. Clique no botão abaixo para abrir as Preferências.\n2. Arraste o ícone do **MacLimpador** que será aberto no Finder para dentro da lista de Acesso Total ao Disco.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Abrir Preferências & Mostrar App no Finder") {
                viewModel.openSystemSettingsForFDA()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    viewModel.revealAppInFinder()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Button("Verificar Novamente") {
                contentViewModel.checkFDAAuthorization()
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}