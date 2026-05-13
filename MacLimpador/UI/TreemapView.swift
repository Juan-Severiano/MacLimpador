import SwiftUI

struct TreemapItem: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let color: Color

    init(id: UUID = UUID(), name: String, path: String, size: Int64, color: Color) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.color = color
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct TreemapView: View {
    let items: [TreemapItem]
    var onTap: ((String) -> Void)?

    @State private var rects: [(item: TreemapItem, rect: CGRect)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                let computed = computeRects(for: items, in: CGRect(origin: .zero, size: geo.size))
                ForEach(computed, id: \.item.id) { entry in
                    treemapCell(entry.item, in: entry.rect)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func treemapCell(_ item: TreemapItem, in rect: CGRect) -> some View {
        Button(action: { onTap?(item.path) }) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.color.opacity(0.85))
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                if rect.width > 60 && rect.height > 40 {
                    VStack(alignment: .leading, spacing: 2) {
                        if rect.height > 60 {
                            Image(systemName: "folder.fill")
                                .font(.system(size: min(rect.width * 0.12, 16)))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 0)
                        Text(item.name)
                            .font(.system(size: max(min(rect.width * 0.1, 13), 9), weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(item.formattedSize)
                            .font(.system(size: max(min(rect.width * 0.08, 11), 8)))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: max(0, rect.width - 1), height: max(0, rect.height - 1))
        .offset(x: rect.minX + 0.5, y: rect.minY + 0.5)
    }

    // MARK: - Squarified Treemap Algorithm

    private func computeRects(for items: [TreemapItem], in bounds: CGRect) -> [(item: TreemapItem, rect: CGRect)] {
        guard !items.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }
        let total = items.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0 else { return [] }
        return squarify(items: items, totalSize: total, bounds: bounds)
    }

    private func squarify(items: [TreemapItem], totalSize: Double, bounds: CGRect) -> [(item: TreemapItem, rect: CGRect)] {
        guard !items.isEmpty else { return [] }

        var results: [(item: TreemapItem, rect: CGRect)] = []
        var remaining = items
        var currentBounds = bounds

        while !remaining.isEmpty {
            let isWide = currentBounds.width >= currentBounds.height
            let span: Double = isWide ? Double(currentBounds.height) : Double(currentBounds.width)

            var row: [TreemapItem] = []
            var rowSize: Double = 0

            for item in remaining {
                let itemSize = Double(item.size)
                let newRowSize = rowSize + itemSize
                let newRatio = worstRatio(row: row + [item], rowSize: newRowSize, span: span, total: totalSize, bounds: currentBounds)

                if row.isEmpty || newRatio <= worstRatio(row: row, rowSize: rowSize, span: span, total: totalSize, bounds: currentBounds) {
                    row.append(item)
                    rowSize += itemSize
                } else {
                    break
                }
            }

            let (rowRects, nextBounds) = layoutRow(
                row: row,
                rowSize: rowSize,
                totalSize: totalSize,
                bounds: currentBounds,
                isWide: isWide
            )
            results.append(contentsOf: rowRects)
            currentBounds = nextBounds
            remaining.removeFirst(row.count)
        }

        return results
    }

    private func worstRatio(row: [TreemapItem], rowSize: Double, span: Double, total: Double, bounds: CGRect) -> Double {
        guard !row.isEmpty, rowSize > 0 else { return .infinity }
        let area = Double(bounds.width * bounds.height)
        let rowArea = rowSize / total * area
        let rowThick = rowArea / span
        return row.map { item -> Double in
            let itemArea = Double(item.size) / rowSize * rowArea
            let w = itemArea / rowThick
            return max(rowThick / w, w / rowThick)
        }.max() ?? .infinity
    }

    private func layoutRow(
        row: [TreemapItem],
        rowSize: Double,
        totalSize: Double,
        bounds: CGRect,
        isWide: Bool
    ) -> (rects: [(item: TreemapItem, rect: CGRect)], nextBounds: CGRect) {
        let area = Double(bounds.width * bounds.height)
        let rowArea = rowSize / totalSize * area
        let thickness = isWide ? rowArea / Double(bounds.height) : rowArea / Double(bounds.width)

        var rects: [(item: TreemapItem, rect: CGRect)] = []
        var offset: CGFloat = 0

        for item in row {
            let fraction = Double(item.size) / rowSize
            if isWide {
                let h = CGFloat(fraction) * bounds.height
                let rect = CGRect(x: bounds.minX, y: bounds.minY + offset, width: CGFloat(thickness), height: h)
                rects.append((item: item, rect: rect))
                offset += h
            } else {
                let w = CGFloat(fraction) * bounds.width
                let rect = CGRect(x: bounds.minX + offset, y: bounds.minY, width: w, height: CGFloat(thickness))
                rects.append((item: item, rect: rect))
                offset += w
            }
        }

        let nextBounds: CGRect
        if isWide {
            nextBounds = CGRect(
                x: bounds.minX + CGFloat(thickness),
                y: bounds.minY,
                width: max(0, bounds.width - CGFloat(thickness)),
                height: bounds.height
            )
        } else {
            nextBounds = CGRect(
                x: bounds.minX,
                y: bounds.minY + CGFloat(thickness),
                width: bounds.width,
                height: max(0, bounds.height - CGFloat(thickness))
            )
        }

        return (rects, nextBounds)
    }
}

// MARK: - Color Palette

extension Color {
    static let treemapPalette: [Color] = [
        Color(red: 0.94, green: 0.76, blue: 0.54), // warm sand
        Color(red: 0.42, green: 0.68, blue: 0.87), // sky blue
        Color(red: 0.87, green: 0.47, blue: 0.42), // terracotta
        Color(red: 0.56, green: 0.42, blue: 0.87), // lavender
        Color(red: 0.42, green: 0.82, blue: 0.64), // mint
        Color(red: 0.87, green: 0.73, blue: 0.35), // gold
        Color(red: 0.65, green: 0.42, blue: 0.60), // mauve
        Color(red: 0.42, green: 0.65, blue: 0.42), // sage
    ]

    static func treemapColor(at index: Int) -> Color {
        treemapPalette[index % treemapPalette.count]
    }
}
