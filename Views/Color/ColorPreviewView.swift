// ColorPreviewView.swift
// Read-only Canvas that renders the base tile grid (doc.grid) scaled to fit.
// Reacts to fill/bg color changes via doc.fillColor / doc.bgColor.
// Mirrors TilingPreviewView but draws the H×W tile rather than the tiling expansion.

import SwiftUI

struct ColorPreviewView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = 12
            let inner = CGSize(width:  geo.size.width  - margin * 2,
                               height: geo.size.height - margin * 2)
            let cs = cellSize(for: inner)
            Canvas { ctx, _ in drawGrid(ctx, cellSize: cs) }
                .frame(width:  CGFloat(doc.W) * cs,
                       height: CGFloat(doc.H) * cs)
                .padding(margin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func cellSize(for size: CGSize) -> CGFloat {
        guard doc.W > 0, doc.H > 0 else { return 8 }
        return max(1, min(size.width / CGFloat(doc.W), size.height / CGFloat(doc.H)))
    }

    private func drawGrid(_ ctx: GraphicsContext, cellSize cs: CGFloat) {
        let fillColor = ColorMath.color(from: doc.fillColor.hex)
        let bgColor   = ColorMath.color(from: doc.bgColor.hex)
        let grid      = doc.grid

        for r in 0 ..< doc.H {
            for c in 0 ..< doc.W {
                let rect = CGRect(x: CGFloat(c) * cs, y: CGFloat(r) * cs, width: cs, height: cs)
                ctx.fill(Path(rect), with: .color(grid[r][c] ? fillColor : bgColor))
                if cs >= 4 {
                    ctx.stroke(Path(rect), with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
                }
            }
        }
    }
}
