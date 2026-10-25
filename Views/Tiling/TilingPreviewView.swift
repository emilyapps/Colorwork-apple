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
        let stitches  = doc.tilingStitchGrid
        let inkOnFill = ColorMath.color(from: ColorMath.contrastInkHex(for: doc.fillColor.hex))
        let inkOnBg   = ColorMath.color(from: ColorMath.contrastInkHex(for: doc.bgColor.hex))

        for r in 0 ..< doc.tilingRows {
            for c in 0 ..< doc.tilingCols {
                let rect = CGRect(x: CGFloat(c) * cs, y: CGFloat(r) * cs, width: cs, height: cs)
                ctx.fill(Path(rect), with: .color(grid[r][c] ? fillColor : bgColor))
                if cs >= 4 {
                    ctx.stroke(Path(rect), with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
                }
                if cs >= 6, r < stitches.count, c < stitches[r].count {
                    drawSymbol(stitches[r][c], in: ctx, at: rect.origin, cellSize: cs,
                               ink: grid[r][c] ? inkOnFill : inkOnBg)
                }
            }
        }
    }

    private func drawSymbol(_ stitch: Stitch, in ctx: GraphicsContext, at o: CGPoint,
                            cellSize cs: CGFloat, ink: Color) {
        let width = max(0.75, cs * 0.05)
        for stroke in stitch.symbol {
            switch stroke {
            case .line(let a, let b):
                var path = Path()
                path.move(to: CGPoint(x: o.x + a.x * cs, y: o.y + a.y * cs))
                path.addLine(to: CGPoint(x: o.x + b.x * cs, y: o.y + b.y * cs))
                ctx.stroke(path, with: .color(ink), lineWidth: width)
            case .circle(let center, let r, let filled):
                let path = Path(ellipseIn: CGRect(x: o.x + (center.x - r) * cs, y: o.y + (center.y - r) * cs,
                                                  width: 2 * r * cs, height: 2 * r * cs))
                if filled { ctx.fill(path, with: .color(ink)) }
                else      { ctx.stroke(path, with: .color(ink), lineWidth: width) }
            }
        }
    }
}
