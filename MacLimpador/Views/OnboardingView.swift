import SwiftUI

struct OnboardingView: View {
    let contentViewModel: ContentViewModel
    @State private var viewModel = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Acesso Total ao Disco")
                .font(.title)
                .bold()
            
            Text("Para uma limpeza completa, o MacLimpador precisa de acesso ao disco.\n\n1. Clique no botão abaixo para abrir os Ajustes.\n2. Se o app não estiver na lista, arraste o ícone do MacLimpador para dentro da janela de Acesso Total ao Disco.")
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
            
            #if DEBUG
            Button("Ignorar (Apenas Debug/TestFlight)") {
                hasCompletedOnboarding = true
                contentViewModel.isFDAAuthorized = true
            }
            .buttonStyle(.link)
            .foregroundColor(.secondary)
            #else
            // No Release/TestFlight, se o usuário insistir que já ativou, deixamos passar
            // pois o Sandbox pode estar mascarando o resultado do teste.
            Button("Já ativei e quero continuar") {
                hasCompletedOnboarding = true
                contentViewModel.isFDAAuthorized = true
            }
            .buttonStyle(.link)
            .padding(.top, 10)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
