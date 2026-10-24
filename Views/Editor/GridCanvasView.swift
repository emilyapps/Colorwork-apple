// GridCanvasView.swift
// SwiftUI Canvas that renders RenderDescriptors for the tile and strips.
// Handles tap and drag-to-paint cell toggling.

import SwiftUI

struct GridCanvasView: View {
    @Environment(PatternDocument.self) var doc

    // Track cells already toggled in the current drag gesture
    @State private var dragVisited  = Set<CellIndex>()
    @State private var dragRegion:  CellRegion? = nil
    @State private var scaleBaseSize: Double = 0

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Canvas { ctx, _ in
                    draw(ctx)
                }
                .frame(width:  doc.tileCanvasSize.width,
                       height: doc.tileCanvasSize.height)
                .contentShape(Rectangle())
                #if os(iOS)
                .overlay(
                    GestureOverlayView(
                        onDragChanged:  { handleDrag(at: $0) },
                        onDragEnded:    endDrag,
                        onPinchChanged: { scale in
                            if scaleBaseSize == 0 { scaleBaseSize = doc.cellSize }
                            doc.cellSize = max(8, min(60, scaleBaseSize * scale))
                            doc.rebuildDescriptors()
                        },
                        onPinchEnded: { scaleBaseSize = 0 }
                    )
                )
                #else
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in handleDrag(at: value.location) }
                        .onEnded   { _ in endDrag() }
                        .simultaneously(with:
                            MagnificationGesture()
                                .onChanged { value in
                                    if scaleBaseSize == 0 { scaleBaseSize = doc.cellSize }
                                    let newSize = max(8, min(60, scaleBaseSize * value))
                                    doc.cellSize = newSize
                                    doc.rebuildDescriptors()
                                }
                                .onEnded { _ in scaleBaseSize = 0 }
                        )
                )
                #endif
            }
            .onAppear             { doc.canvasAvailableSize = geo.size; doc.fitCellSize() }
            .onChange(of: geo.size) { _, size in doc.canvasAvailableSize = size; doc.fitCellSize() }
        }
        .onChange(of: doc.H) { _, _ in doc.fitCellSize() }
        .onChange(of: doc.W) { _, _ in doc.fitCellSize() }
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
            case .circle(let c):
                let path = Path(ellipseIn: CGRect(x: c.cx - c.r, y: c.cy - c.r,
                                                  width: 2 * c.r, height: 2 * c.r))
                let color = ColorMath.color(from: c.fill)
                if c.filled { ctx.fill(path, with: .color(color)) }
                else        { ctx.stroke(path, with: .color(color), lineWidth: c.width) }
            }
        }
    }

    // MARK: - Interaction

    private func handleDrag(at point: CGPoint) {
        guard let (cell, region) = cellAt(point: point) else { return }

        // Lock region for the whole drag gesture
        if dragRegion == nil { dragRegion = region }

        // Push undo once at the start of each stroke
        if dragVisited.isEmpty { doc.pushUndo("Paint") }
        guard region == dragRegion else { return }

        let key = CellIndex(row: cell.row, col: cell.col)
        guard !dragVisited.contains(key) else { return }
        dragVisited.insert(key)
        switch doc.paintTool {
        case .color:
            doc.toggleCell(cell, region: region)
        case .stitch(let stitch):
            // Border strips are color-only
            if region == .tile && doc.stitchToolsEnabled { doc.paintStitch(stitch, at: cell) }
        }
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
