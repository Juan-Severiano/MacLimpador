import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let color: Color
    var lineWidth: CGFloat = 1.5
    var fillOpacity: Double = 0.15

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = max(maxVal - minVal, 0.001)

            func point(index: Int) -> CGPoint {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let normalized = CGFloat((values[index] - minVal) / range)
                let y = size.height - normalized * size.height * 0.9 - size.height * 0.05
                return CGPoint(x: x, y: y)
            }

            var linePath = Path()
            linePath.move(to: point(index: 0))
            for i in 1..<values.count {
                let prev = point(index: i - 1)
                let curr = point(index: i)
                let ctrl = CGPoint(x: (prev.x + curr.x) / 2, y: prev.y)
                let ctrl2 = CGPoint(x: (prev.x + curr.x) / 2, y: curr.y)
                linePath.addCurve(to: curr, control1: ctrl, control2: ctrl2)
            }

            var fillPath = linePath
            let last = point(index: values.count - 1)
            let first = point(index: 0)
            fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
            fillPath.addLine(to: CGPoint(x: first.x, y: size.height))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .color(color.opacity(fillOpacity)))
            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
        }
    }
}

struct MiniBarView: View {
    let value: Double
    let total: Double
    let color: Color

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(value / total, 1.0))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.15))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}
