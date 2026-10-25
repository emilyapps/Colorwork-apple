// RenderDescriptor.swift
// Device-independent drawing descriptors.
// Swift port of the descriptor dicts in pattern_core.py lines 255–428.

import CoreGraphics

// MARK: - Layout constants (mirror pattern_core.py)

enum Layout {
    static let padding: CGFloat = 20   // margin around tile on all sides
    static let numW:    CGFloat = 26   // extra right margin for row numbers
    static let numH:    CGFloat = 16   // extra bottom margin for col numbers
    static let stripBG   = "#e8e8e8"
    static let stripLine = "#aaaaaa"
}

// MARK: - RenderDescriptor

enum RenderDescriptor {
    struct RectInfo {
        let x, y, w, h: CGFloat
        let fill: String
        let outline: String
        let outlineWidth: CGFloat
        let cell: CellIndex?
        let region: CellRegion?
    }
    struct TextInfo {
        let x, y: CGFloat
        let text: String
        let fontSize: CGFloat
        let fill: String
    }
    struct LineInfo {
        let x1, y1, x2, y2: CGFloat
        let fill: String
        let width: CGFloat
    }

    struct CircleInfo {
        let cx, cy, r: CGFloat
        let fill: String
        let filled: Bool
        let width: CGFloat      // stroke width when not filled
    }

    case rect(RectInfo)
    case text(TextInfo)
    case line(LineInfo)
    case circle(CircleInfo)
}

// MARK: - DescriptorBuilder

enum DescriptorBuilder {

    /// A Stitch's CYC symbol scaled into the cell at (x0, y0).
    static func symbolDescriptors(_ stitch: Stitch, x0: CGFloat, y0: CGFloat,
                                  cellSize cs: CGFloat, ink: String) -> [RenderDescriptor] {
        let width = max(1, cs * 0.05)
        return stitch.symbol.map { stroke in
            switch stroke {
            case .line(let a, let b):
                return .line(.init(x1: x0 + a.x * cs, y1: y0 + a.y * cs,
                                   x2: x0 + b.x * cs, y2: y0 + b.y * cs,
                                   fill: ink, width: width))
            case .circle(let c, let r, let filled):
                return .circle(.init(cx: x0 + c.x * cs, cy: y0 + c.y * cs, r: r * cs,
                                     fill: ink, filled: filled, width: width))
            }
        }
    }

    // MARK: tile_canvas_size — port of pattern_core.py:tile_canvas_size
    static func tileCanvasSize(H: Int, W: Int, cellSize: CGFloat, hOn: Bool, vOn: Bool, stripWidth: Int) -> CGSize {
        let exC = hOn ? CGFloat(stripWidth) : 0
        let exR = vOn ? CGFloat(stripWidth) : 0
        let width  = (CGFloat(W) + exC) * cellSize + 2 * Layout.padding + Layout.numW
        let height = (CGFloat(H) + exR) * cellSize + 2 * Layout.padding + Layout.numH
        return CGSize(width: width, height: height)
    }

    // MARK: get_tile_descriptors — port of pattern_core.py:get_tile_descriptors
    static func tileDescriptors(
        grid: [[Bool]], H: Int, W: Int, cellSize: CGFloat,
        fillColor: String, bgColor: String,
        domainCells: Set<CellIndex>, showDomain: Bool,
        colStrip: [[Bool]], rowStrip: [[Bool]], corner: [[Bool]],
        hOn: Bool, vOn: Bool, stripWidth: Int,
        stitches: [[Stitch]] = []
    ) -> [RenderDescriptor] {
        let cs = cellSize
        let sw = stripWidth
        var out = [RenderDescriptor]()

        func safeGet(_ arr: [[Bool]], _ r: Int, _ c: Int) -> Bool {
            guard r >= 0, r < arr.count, c >= 0, c < (arr.first?.count ?? 0) else { return false }
            return arr[r][c]
        }

        // Tile cells
        for r in 0 ..< H {
            for c in 0 ..< W {
                let x0 = Layout.padding + CGFloat(c) * cs
                let y0 = Layout.padding + CGFloat(r) * cs
                let fill = safeGet(grid, r, c) ? fillColor : bgColor
                let cell = CellIndex(row: r, col: c)
                let (ol, ow): (String, CGFloat) = showDomain && domainCells.contains(cell)
                    ? ("#e63946", 2) : ("#cccccc", 1)
                out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                       fill: fill, outline: ol, outlineWidth: ow,
                                       cell: cell, region: .tile)))
                if r < stitches.count, c < stitches[r].count {
                    out += symbolDescriptors(stitches[r][c], x0: x0, y0: y0, cellSize: cs,
                                             ink: ColorMath.contrastInkHex(for: fill))
                }
            }
        }

        // Col strip (right of tile)
        if hOn {
            for r in 0 ..< H {
                for sc in 0 ..< sw {
                    let x0 = Layout.padding + CGFloat(W + sc) * cs
                    let y0 = Layout.padding + CGFloat(r) * cs
                    let fill = safeGet(colStrip, r, sc) ? fillColor : Layout.stripBG
                    out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                           fill: fill, outline: Layout.stripLine, outlineWidth: 1,
                                           cell: CellIndex(row: r, col: sc), region: .colStrip)))
                }
            }
        }

        // Row strip (below tile)
        if vOn {
            for sr in 0 ..< sw {
                for c in 0 ..< W {
                    let x0 = Layout.padding + CGFloat(c) * cs
                    let y0 = Layout.padding + CGFloat(H + sr) * cs
                    let fill = safeGet(rowStrip, sr, c) ? fillColor : Layout.stripBG
                    out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                           fill: fill, outline: Layout.stripLine, outlineWidth: 1,
                                           cell: CellIndex(row: sr, col: c), region: .rowStrip)))
                }
            }
        }

        // Corner
        if hOn && vOn {
            for sr in 0 ..< sw {
                for sc in 0 ..< sw {
                    let x0 = Layout.padding + CGFloat(W + sc) * cs
                    let y0 = Layout.padding + CGFloat(H + sr) * cs
                    let fill = safeGet(corner, sr, sc) ? fillColor : Layout.stripBG
                    out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                           fill: fill, outline: Layout.stripLine, outlineWidth: 1,
                                           cell: CellIndex(row: sr, col: sc), region: .corner)))
                }
            }
        }

        // Numbers
        let exC = sw
        let exR = sw
        let totalCols = W + (hOn ? exC : 0)
        let totalRows = H + (vOn ? exR : 0)
        let numSize = max(7, min(10, Int(cs) / 4))
        let numFS = CGFloat(numSize)

        // Column numbers (bottom margin)
        let numY = Layout.padding + CGFloat(totalRows) * cs + Layout.numH / 2 + 1
        for c in 0 ..< W {
            out.append(.text(.init(
                x: Layout.padding + CGFloat(c) * cs + cs / 2, y: numY,
                text: "\(totalCols - c)", fontSize: numFS, fill: "#777777")))
        }
        if hOn {
            for sc in 0 ..< exC {
                out.append(.text(.init(
                    x: Layout.padding + CGFloat(W + sc) * cs + cs / 2, y: numY,
                    text: "\(exC - sc)", fontSize: numFS, fill: "#777777")))
            }
        }

        // Row numbers (right margin)
        let numX = Layout.padding + CGFloat(totalCols) * cs + Layout.numW / 2 + 1
        for r in 0 ..< H {
            out.append(.text(.init(
                x: numX, y: Layout.padding + CGFloat(r) * cs + cs / 2,
                text: "\(totalRows - r)", fontSize: numFS, fill: "#777777")))
        }
        if vOn {
            for sr in 0 ..< exR {
                out.append(.text(.init(
                    x: numX, y: Layout.padding + CGFloat(H + sr) * cs + cs / 2,
                    text: "\(exR - sr)", fontSize: numFS, fill: "#777777")))
            }
        }

        return out
    }

    // MARK: get_tiling_descriptors — port of pattern_core.py:get_tiling_descriptors
    static func tilingDescriptors(
        tilingGrid: [[Bool]],
        fillColor: String, bgColor: String,
        hRepeat: Bool, vRepeat: Bool, stripWidth: Int,
        hType: RepeatType, vType: RepeatType,
        nCopies: Int, W: Int, H: Int,
        rowOffset: Int, colOffset: Int,
        cellSize: CGFloat, padding: CGFloat = 1
    ) -> (descriptors: [RenderDescriptor], rows: Int, cols: Int) {
        let cs = cellSize
        let rows = tilingGrid.count
        let cols = rows > 0 ? tilingGrid[0].count : 0
        var out = [RenderDescriptor]()

        for r in 0 ..< rows {
            for c in 0 ..< cols {
                let x0 = padding + CGFloat(c) * cs
                let y0 = padding + CGFloat(r) * cs
                let fill = tilingGrid[r][c] ? fillColor : bgColor
                out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                       fill: fill, outline: "#cccccc", outlineWidth: 1,
                                       cell: nil, region: nil)))
            }
        }

        // Boundary lines between repeat units (only without brick offset)
        if rowOffset == 0 && colOffset == 0 {
            let sw = stripWidth
            let nh = hRepeat ? nCopies : 1
            let nv = vRepeat ? nCopies : 1
            let unitW = W + (hRepeat ? sw : 0)
            let unitH = H + (vRepeat ? sw : 0)
            let totalW = CGFloat(cols) * cs + 2 * padding
            let totalH = CGFloat(rows) * cs + 2 * padding

            for hi in 1 ..< nh {
                let lx = padding + CGFloat(hi * unitW) * cs
                out.append(.line(.init(x1: lx, y1: 0, x2: lx, y2: totalH,
                                       fill: "#888888", width: 1)))
            }
            for vi in 1 ..< nv {
                let ly = padding + CGFloat(vi * unitH) * cs
                out.append(.line(.init(x1: 0, y1: ly, x2: totalW, y2: ly,
                                       fill: "#888888", width: 1)))
            }
        }

        return (out, rows, cols)
    }
}
