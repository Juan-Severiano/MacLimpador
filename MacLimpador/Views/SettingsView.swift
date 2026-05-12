import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ContentViewModel
    @State private var onboardingViewModel = OnboardingViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HeaderView(title: "Ajustes", subtitle: "Gerencie permissões e preferências", icon: "gearshape.fill", color: .gray)
                
                permissionSection
                
                aboutSection
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Segurança e Privacidade")
                .font(.headline)
            
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isFDAAuthorized ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: viewModel.isFDAAuthorized ? "lock.open.fill" : "lock.fill")
                            .font(.title3)
                            .foregroundStyle(viewModel.isFDAAuthorized ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acesso Total ao Disco")
                            .font(.headline)
                        Text(viewModel.isFDAAuthorized ? "Autorizado" : "Acesso Limitado")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !viewModel.isFDAAuthorized {
                        Button("Configurar") {
                            onboardingViewModel.openSystemSettingsForFDA()
                            onboardingViewModel.revealAppInFinder()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                }
                .padding(16)
                
                if !viewModel.isFDAAuthorized {
                    Divider()
                        .padding(.leading, 76)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Para que o MacLimpador consiga encontrar e remover arquivos em pastas protegidas do sistema, ele precisa desta permissão.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            viewModel.checkFDAAuthorization()
                        }) {
                            Label("Verificar Novamente", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    .padding(16)
                    .padding(.leading, 60)
                }
            }
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isFDAAuthorized ? Color.clear : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sobre")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Versão")
                    Spacer()
                    Text("1.0.0 (MVP)")
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Text("Desenvolvedor")
                    Spacer()
                    Text("Juan Sev")
                        .foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Caminho da Instalação")
                    Text(Bundle.main.bundlePath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
