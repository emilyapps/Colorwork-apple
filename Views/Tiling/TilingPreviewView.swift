// TilingPreviewView.swift
// Fills its container: cell size is computed to fit the available space.
// Draws directly from tilingGrid (no fixed descriptor pass).

import SwiftUI

struct TilingPreviewView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        GeometryReader { geo in
            if doc.isComputingTiling {
                ProgressView("Building…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if doc.tilingRows == 0 || doc.tilingCols == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Enable H or V repeat\nin the Tiling tab")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                let margin: CGFloat = 12
                let inner = CGSize(width:  geo.size.width  - margin * 2,
                                   height: geo.size.height - margin * 2)
                let cs = cellSize(for: inner)
                Canvas { ctx, _ in
                    drawGrid(ctx, cellSize: cs)
                }
                .frame(
                    width:  CGFloat(doc.tilingCols) * cs,
                    height: CGFloat(doc.tilingRows) * cs)
                .padding(margin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func cellSize(for size: CGSize) -> CGFloat {
        guard doc.tilingCols > 0, doc.tilingRows > 0 else { return 8 }
        let byW = size.width  / CGFloat(doc.tilingCols)
        let byH = size.height / CGFloat(doc.tilingRows)
        return max(1, min(byW, byH))
    }

    private func drawGrid(_ ctx: GraphicsContext, cellSize cs: CGFloat) {
        let fillColor = ColorMath.color(from: doc.fillColor.hex)
        let bgColor   = ColorMath.color(from: doc.bgColor.hex)
        let grid      = doc.tilingGrid

        for r in 0 ..< doc.tilingRows {
            for c in 0 ..< doc.tilingCols {
                let rect = CGRect(x: CGFloat(c) * cs, y: CGFloat(r) * cs, width: cs, height: cs)
                ctx.fill(Path(rect), with: .color(grid[r][c] ? fillColor : bgColor))
                if cs >= 4 {
                    ctx.stroke(Path(rect), with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
                }
            }
        }
    }
}
