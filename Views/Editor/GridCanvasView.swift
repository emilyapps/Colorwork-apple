// GridCanvasView.swift
// SwiftUI Canvas that renders RenderDescriptors for the tile and strips.
// Handles tap and drag-to-paint cell toggling.

import SwiftUI

struct GridCanvasView: View {
    @Environment(PatternDocument.self) var doc

    // Track cells already toggled in the current drag gesture
    @State private var dragVisited = Set<CellIndex>()
    @State private var dragRegion: CellRegion? = nil

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Canvas { ctx, _ in
                draw(ctx)
            }
            .frame(width:  doc.tileCanvasSize.width,
                   height: doc.tileCanvasSize.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in handleDrag(at: value.location) }
                    .onEnded   { _ in endDrag() }
            )
        }
    }

    // MARK: - Drawing

    private func draw(_ ctx: GraphicsContext) {
        for descriptor in doc.tileDescriptors {
            switch descriptor {
            case .rect(let r):
                let rect = CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
                ctx.fill(Path(rect), with: .color(ColorMath.color(from: r.fill)))
                if r.outlineWidth > 0 {
                    ctx.stroke(Path(rect),
                               with: .color(ColorMath.color(from: r.outline)),
                               lineWidth: r.outlineWidth)
                }
            case .text(let t):
                ctx.draw(
                    Text(t.text)
                        .font(.system(size: t.fontSize))
                        .foregroundColor(ColorMath.color(from: t.fill)),
                    at: CGPoint(x: t.x, y: t.y),
                    anchor: .center)
            case .line(let l):
                var path = Path()
                path.move(to: CGPoint(x: l.x1, y: l.y1))
                path.addLine(to: CGPoint(x: l.x2, y: l.y2))
                ctx.stroke(path,
                           with: .color(ColorMath.color(from: l.fill)),
                           lineWidth: l.width)
            }
        }
    }

    // MARK: - Interaction

    private func handleDrag(at point: CGPoint) {
        guard let (cell, region) = cellAt(point: point) else { return }

        // Lock region for the whole drag gesture
        if dragRegion == nil { dragRegion = region }
        guard region == dragRegion else { return }

        let key = CellIndex(row: cell.row, col: cell.col)
        guard !dragVisited.contains(key) else { return }
        dragVisited.insert(key)
        doc.toggleCell(cell, region: region)
    }

    private func endDrag() {
        dragVisited.removeAll()
        dragRegion = nil
    }

    // MARK: - Hit testing

    private func cellAt(point: CGPoint) -> (CellIndex, CellRegion)? {
        let cs  = CGFloat(doc.cellSize)
        let pad = Layout.padding
        let sw  = doc.tiling.stripWidth

        let px = point.x - pad
        let py = point.y - pad
        guard px >= 0, py >= 0 else { return nil }

        let col = Int(px / cs)
        let row = Int(py / cs)

        let H = doc.H, W = doc.W

        if row < H && col < W {
            return (CellIndex(row: row, col: col), .tile)
        }
        if doc.tiling.hRepeat && row < H && col >= W && col < W + sw {
            return (CellIndex(row: row, col: col - W), .colStrip)
        }
        if doc.tiling.vRepeat && row >= H && row < H + sw && col < W {
            return (CellIndex(row: row - H, col: col), .rowStrip)
        }
        if doc.tiling.hRepeat && doc.tiling.vRepeat
            && row >= H && row < H + sw && col >= W && col < W + sw {
            return (CellIndex(row: row - H, col: col - W), .corner)
        }
        return nil
    }
}
