import SwiftUI

struct SmartScanView: View {
    @State private var viewModel = SmartScanViewModel()
    @State private var showingReview: SmartScanCategoryResult? = nil

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                SmartScanLandingView(onScan: { viewModel.startScan() })
            case .scanning(let progress, let step):
                SmartScanProgressView(progress: progress, step: step)
            case .results:
                SmartScanResultsView(
                    viewModel: viewModel,
                    onReview: { showingReview = $0 }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $showingReview) { result in
            SmartScanReviewView(
                result: binding(for: result),
                onClean: { viewModel.clean(categoryResult: result) }
            )
        }
    }

    private func binding(for result: SmartScanCategoryResult) -> Binding<SmartScanCategoryResult> {
        Binding(
            get: { viewModel.categoryResults.first(where: { $0.id == result.id }) ?? result },
            set: { newVal in
                if let idx = viewModel.categoryResults.firstIndex(where: { $0.id == result.id }) {
                    viewModel.categoryResults[idx] = newVal
                }
            }
        )
    }
}

// MARK: - Landing

struct SmartScanLandingView: View {
    let onScan: () -> Void

    private let features = [
        ("magnifyingglass.circle.fill", "Varredura Rápida", "Cache, logs e arquivos desnecessários"),
        ("gearshape.2.fill",            "Tune-up do Sistema", "Otimize e libere espaço de forma inteligente"),
        ("shield.checkered",            "Verificação Completa", "Lixeiras, e-mails e binários extras"),
    ]

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.28, green: 0.18, blue: 0.58), Color(red: 0.18, green: 0.12, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 140, height: 140)
                    Image(systemName: "sparkles")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 32)

                // Title
                Text("Smart Scan")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Varredura inteligente que cuida do essencial.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 40)

                // Feature list
                VStack(spacing: 16) {
                    ForEach(features, id: \.1) { icon, title, subtitle in
                        HStack(spacing: 16) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(.purple.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 48)

                Spacer()

                // Scan button
                Button(action: onScan) {
                    Text("Escanear")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 160, height: 160)
                        .background(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 0.65, green: 0.35, blue: 0.95), Color(red: 0.45, green: 0.20, blue: 0.75)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .shadow(color: .purple.opacity(0.6), radius: 20, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Progress

struct SmartScanProgressView: View {
    let progress: Double
    let step: String

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.28, green: 0.18, blue: 0.58), Color(red: 0.18, green: 0.12, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Spinning ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 6)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: max(0.05, progress))
                        .stroke(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)

                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }

                VStack(spacing: 8) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: progress)

                    Text(step)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: step)
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Results

struct SmartScanResultsView: View {
    var viewModel: SmartScanViewModel
    let onReview: (SmartScanCategoryResult) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if viewModel.nonEmptyResults.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Seu Mac está limpo!")
                            .font(.title.bold())
                        Text("Nenhum arquivo desnecessário foi encontrado.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.formattedTotalSize) de arquivos desnecessários")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Revisar Tudo") {
                                // Navigate to full review
                            }
                            .buttonStyle(.bordered)

                            Button("Limpar Tudo") {
                                viewModel.cleanAll()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isCleaning)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal)

                // Cards grid
                if !viewModel.nonEmptyResults.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.nonEmptyResults) { result in
                            SmartScanResultCard(
                                result: result,
                                onReview: { onReview(result) },
                                onClean: { viewModel.clean(categoryResult: result) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Freed space banner
                if viewModel.freedSpace > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(viewModel.formattedFreedSpace) liberados")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Start Over
                Button("Nova Varredura") {
                    viewModel.reset()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Result Card

struct SmartScanResultCard: View {
    let result: SmartScanCategoryResult
    let onReview: () -> Void
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.formattedSize)
                        .font(.title3.bold())
                    Text(result.category.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: result.category.iconName)
                    .font(.title2)
                    .foregroundStyle(result.category.color)
                    .frame(width: 40, height: 40)
                    .background(result.category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(result.category.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 8) {
                Button("Revisar", action: onReview)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("Limpar", action: onClean)
                    .buttonStyle(.borderedProminent)
                    .tint(result.category.color)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(minHeight: 160)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}
