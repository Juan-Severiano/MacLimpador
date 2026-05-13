import SwiftUI

enum PlanetType {
    case earth, mars, jupiter, sun, saturn

    var gradient: AnyShapeStyle {
        switch self {
        case .earth:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color(red: 0.60, green: 0.83, blue: 0.97),
                    Color(red: 0.17, green: 0.58, blue: 0.29),
                    Color(red: 0.08, green: 0.28, blue: 0.62),
                    Color(red: 0.05, green: 0.18, blue: 0.45),
                ],
                center: .init(x: 0.35, y: 0.3),
                startRadius: 0,
                endRadius: 200
            ))
        case .mars:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color(red: 0.97, green: 0.60, blue: 0.38),
                    Color(red: 0.82, green: 0.35, blue: 0.15),
                    Color(red: 0.55, green: 0.18, blue: 0.05),
                    Color(red: 0.35, green: 0.10, blue: 0.03),
                ],
                center: .init(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: 200
            ))
        case .jupiter:
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.80, blue: 0.60),
                    Color(red: 0.80, green: 0.60, blue: 0.40),
                    Color(red: 0.93, green: 0.80, blue: 0.60),
                    Color(red: 0.75, green: 0.52, blue: 0.30),
                    Color(red: 0.93, green: 0.80, blue: 0.60),
                    Color(red: 0.80, green: 0.60, blue: 0.40),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .sun:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.50),
                    Color(red: 1.0, green: 0.75, blue: 0.15),
                    Color(red: 0.95, green: 0.45, blue: 0.10),
                    Color(red: 0.75, green: 0.22, blue: 0.05),
                ],
                center: .init(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: 200
            ))
        case .saturn:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.88, blue: 0.70),
                    Color(red: 0.80, green: 0.72, blue: 0.52),
                    Color(red: 0.65, green: 0.58, blue: 0.38),
                ],
                center: .init(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: 200
            ))
        }
    }

    var glowColor: Color {
        switch self {
        case .earth: return .blue
        case .mars: return .red
        case .jupiter: return .orange
        case .sun: return .yellow
        case .saturn: return Color(red: 0.8, green: 0.72, blue: 0.52)
        }
    }
}

struct PlanetView: View {
    let type: PlanetType
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(type.glowColor.opacity(0.25))
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.18)

            // Planet body
            Circle()
                .fill(type.gradient)
                .frame(width: size, height: size)
                .overlay {
                    // Atmosphere rim
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: size * 0.06
                        )
                }
                .overlay {
                    // Jupiter bands overlay
                    if type == .jupiter {
                        jupiterBands
                            .clipShape(Circle())
                    }
                }
                .shadow(color: type.glowColor.opacity(0.4), radius: size * 0.12, x: -size * 0.06, y: size * 0.06)
        }
    }

    private var jupiterBands: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(i.isMultiple(of: 2)
                        ? Color(red: 0.88, green: 0.74, blue: 0.53).opacity(0.6)
                        : Color(red: 0.72, green: 0.52, blue: 0.30).opacity(0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: size / 8)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Landing Header

struct PlanetLandingView: View {
    let planet: PlanetType
    let haiku: [String]
    let ctaLabel: String
    let isLoading: Bool
    let onCTA: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            PlanetView(type: planet, size: 200)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isLoading)

            VStack(spacing: 6) {
                ForEach(haiku, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Button(action: onCTA) {
                HStack {
                    if isLoading {
                        ProgressView().controlSize(.small).tint(.black)
                    }
                    Text(ctaLabel)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 220, height: 44)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
