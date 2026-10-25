// RenderDescriptor.swift
// Device-independent drawing descriptors.
// Swift port of the descriptor dicts in pattern_core.py lines 255–428.

import CoreGraphics

// MARK: - Layout constants (mirror pattern_core.py)

enum Layout {
    static let padding: CGFloat = 20   // margin around tile on all sides
    static let numW:    CGFloat = 26   // extra right margin for row numbers
    static let numH:    CGFloat = 16   // extra bottom margin for col numbers
    static let totalsW: CGFloat = 84   // extra right margin for a Wedge's stitch totals
    static let stripBG   = "#e8e8e8"
    static let stripLine = "#aaaaaa"
    static let noStitchFill = "#bdbdbd"     // CYC: gray squares where stitches don't exist

    // Legend below the column numbers (fixed size, independent of cell size)
    static let legendGap:    CGFloat = 10
    static let legendRow:    CGFloat = 20
    static let legendBox:    CGFloat = 16
    static let legendColumn: CGFloat = 180
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
        var leading = false     // x is the left edge instead of the center
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

    struct PolygonInfo {
        let points: [CGPoint]
        let fill: String
        let outline: String?
        let outlineWidth: CGFloat
    }

    case rect(RectInfo)
    case text(TextInfo)
    case line(LineInfo)
    case circle(CircleInfo)
    case polygon(PolygonInfo)
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
    static func tileCanvasSize(H: Int, W: Int, cellSize: CGFloat, hOn: Bool, vOn: Bool, stripWidth: Int,
                               stitches: [[Stitch]] = [], showsTotals: Bool = false) -> CGSize {
        let exC = hOn ? CGFloat(stripWidth) : 0
        let exR = vOn ? CGFloat(stripWidth) : 0
        let width  = (CGFloat(W) + exC) * cellSize + 2 * Layout.padding + Layout.numW
            + (showsTotals ? Layout.totalsW : 0)
        let height = (CGFloat(H) + exR) * cellSize + 2 * Layout.padding + Layout.numH
        let gaps = ShapingResolver.resolve(stitches).noStitch.joined().contains(true)
        return CGSize(width: width,
                      height: height + legendHeight(legendStitches(stitches), width: width, noStitch: gaps))
    }

    // MARK: Legend

    /// The stitches a chart's legend lists, in catalog order: none for an all-knit Pattern,
    /// otherwise every stitch used, knit included.
    static func legendStitches(_ stitches: [[Stitch]]) -> [Stitch] {
        let used = Set(stitches.joined())
        guard used.contains(where: { $0 != .knit }) else { return [] }
        return Stitch.allCases.filter(used.contains)
    }

    private static func legendColumns(width: CGFloat) -> Int {
        max(1, Int((width - 2 * Layout.padding) / Layout.legendColumn))
    }

    /// A No Stitch entry follows the stitches whenever the chart has No Stitch cells,
    /// which needs a decrease, so it never appears without stitches.
    static func legendHeight(_ legend: [Stitch], width: CGFloat, noStitch: Bool = false) -> CGFloat {
        guard !legend.isEmpty else { return 0 }
        let entries = legend.count + (noStitch ? 1 : 0)
        let rows = (entries + legendColumns(width: width) - 1) / legendColumns(width: width)
        return Layout.legendGap + CGFloat(rows) * Layout.legendRow
    }

    /// One symbol box and name per stitch, in columns, starting at y0.
    static func legendDescriptors(_ legend: [Stitch], y0: CGFloat, width: CGFloat,
                                  noStitch: Bool = false) -> [RenderDescriptor] {
        guard !legend.isEmpty else { return [] }
        let columns = legendColumns(width: width)
        let box = Layout.legendBox
        let entries: [Stitch?] = legend + (noStitch ? [nil] : [])
        var out = [RenderDescriptor]()
        for (i, stitch) in entries.enumerated() {
            let x = Layout.padding + CGFloat(i % columns) * Layout.legendColumn
            let y = y0 + Layout.legendGap + CGFloat(i / columns) * Layout.legendRow
            out.append(.rect(.init(x: x, y: y, w: box, h: box,
                                   fill: stitch == nil ? Layout.noStitchFill : "#ffffff",
                                   outline: "#999999", outlineWidth: 1, cell: nil, region: nil)))
            if let stitch { out += symbolDescriptors(stitch, x0: x, y0: y, cellSize: box, ink: "#000000") }
            out.append(.text(.init(x: x + box + 6, y: y + box / 2, text: stitch?.displayName ?? "No stitch",
                                   fontSize: 11, fill: "#333333", leading: true)))
        }
        return out
    }

    // MARK: get_tile_descriptors — port of pattern_core.py:get_tile_descriptors
    static func tileDescriptors(
        grid: [[Bool]], H: Int, W: Int, cellSize: CGFloat,
        fillColor: String, bgColor: String,
        domainCells: Set<CellIndex>, showDomain: Bool,
        colStrip: [[Bool]], rowStrip: [[Bool]], corner: [[Bool]],
        hOn: Bool, vOn: Bool, stripWidth: Int,
        stitches: [[Stitch]] = [], noStitch: [[Bool]] = [],
        totals: [(row: Int, stitches: Int)] = []
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
                let gap = safeGet(noStitch, r, c)
                let fill = gap ? Layout.noStitchFill : safeGet(grid, r, c) ? fillColor : bgColor
                let cell = CellIndex(row: r, col: c)
                let (ol, ow): (String, CGFloat) = showDomain && domainCells.contains(cell)
                    ? ("#e63946", 2) : ("#cccccc", 1)
                out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                       fill: fill, outline: ol, outlineWidth: ow,
                                       cell: cell, region: .tile)))
                if !gap, r < stitches.count, c < stitches[r].count {
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

        // Stitch totals (Wedges), right of the row numbers, bottom to top; a label that would
        // overlap the one below it moves up just enough.
        let totalsFS = max(8, min(11, cs))
        var lowestFreeY = CGFloat.greatestFiniteMagnitude
        for total in totals {
            let y = min(Layout.padding + CGFloat(totalRows - total.row) * cs + cs / 2, lowestFreeY)
            lowestFreeY = y - totalsFS - 1
            out.append(.text(.init(x: numX + Layout.numW / 2 + 4, y: y,
                                   text: "Row \(total.row): \(total.stitches)",
                                   fontSize: totalsFS, fill: "#555555", leading: true)))
        }

        // Legend
        let width = CGFloat(totalCols) * cs + 2 * Layout.padding + Layout.numW
        out += legendDescriptors(legendStitches(stitches),
                                 y0: Layout.padding + CGFloat(totalRows) * cs + Layout.numH,
                                 width: width, noStitch: noStitch.joined().contains(true))

        return out
    }

    // MARK: Wedge Chart View

    static let chartTotalsWidth: CGFloat = 84

    /// A Wedge's Chart View: N copies side by side, No Stitch gray, with the stitch total
    /// at the right of row 1 and of every row where the count changes.
    static func wedgeChartDescriptors(
        grid: [[Bool]], stitches: [[Stitch]], shaping: ShapingResolver.Result,
        repeats: Int, cellSize cs: CGFloat, fillColor: String, bgColor: String,
        padding: CGFloat = 1
    ) -> (descriptors: [RenderDescriptor], size: CGSize) {
        let H = grid.count
        let W = grid.first?.count ?? 0
        var out = [RenderDescriptor]()
        for n in 0 ..< repeats {
            for r in 0 ..< H {
                for c in 0 ..< W {
                    let x0 = padding + CGFloat(n * W + c) * cs
                    let y0 = padding + CGFloat(r) * cs
                    let gap = shaping.noStitch[r][c]
                    let fill = gap ? Layout.noStitchFill : grid[r][c] ? fillColor : bgColor
                    out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs, fill: fill,
                                           outline: "#cccccc", outlineWidth: cs >= 4 ? 0.5 : 0,
                                           cell: nil, region: nil)))
                    if !gap && cs >= 6 {
                        out += symbolDescriptors(stitches[r][c], x0: x0, y0: y0, cellSize: cs,
                                                 ink: ColorMath.contrastInkHex(for: fill))
                    }
                }
            }
        }
        let chartW = CGFloat(repeats * W) * cs
        let chartH = CGFloat(H) * cs
        for n in 1 ..< max(1, repeats) {
            let x = padding + CGFloat(n * W) * cs
            out.append(.line(.init(x1: x, y1: padding, x2: x, y2: padding + chartH,
                                   fill: "#888888", width: 1)))
        }
        // Bottom to top; a label that would overlap the one below it moves up just enough.
        let fontSize = max(8, min(11, cs))
        var lowestFreeY = CGFloat.greatestFiniteMagnitude
        for total in shaping.totals(repeats: repeats) {
            let y = min(padding + CGFloat(H - total.row) * cs + cs / 2, lowestFreeY)
            lowestFreeY = y - fontSize - 1
            out.append(.text(.init(x: padding + chartW + 6, y: y,
                                   text: "Row \(total.row): \(total.stitches)",
                                   fontSize: fontSize, fill: "#555555", leading: true)))
        }
        // Room below the chart for the row-1 label, which is centered on the bottom row.
        return (out, CGSize(width: chartW + 2 * padding + chartTotalsWidth,
                            height: chartH + 2 * padding + fontSize / 2))
    }

    // MARK: get_tiling_descriptors — port of pattern_core.py:get_tiling_descriptors
    static func tilingDescriptors(
        tilingGrid: [[Bool]],
        fillColor: String, bgColor: String,
        hRepeat: Bool, vRepeat: Bool, stripWidth: Int,
        horizontal: RepeatType, vertical: RepeatType,
        nCopies: Int, W: Int, H: Int,
        rowOffset: Int, colOffset: Int,
        cellSize: CGFloat, padding: CGFloat = 1,
        stitchGrid: [[Stitch]] = [], noStitchGrid: [[Bool]] = []
    ) -> (descriptors: [RenderDescriptor], rows: Int, cols: Int) {
        let cs = cellSize
        let rows = tilingGrid.count
        let cols = rows > 0 ? tilingGrid[0].count : 0
        var out = [RenderDescriptor]()

        for r in 0 ..< rows {
            for c in 0 ..< cols {
                let x0 = padding + CGFloat(c) * cs
                let y0 = padding + CGFloat(r) * cs
                let gap = r < noStitchGrid.count && c < noStitchGrid[r].count && noStitchGrid[r][c]
                let fill = gap ? Layout.noStitchFill : tilingGrid[r][c] ? fillColor : bgColor
                out.append(.rect(.init(x: x0, y: y0, w: cs, h: cs,
                                       fill: fill, outline: "#cccccc", outlineWidth: 1,
                                       cell: nil, region: nil)))
                if !gap, r < stitchGrid.count, c < stitchGrid[r].count {
                    out += symbolDescriptors(stitchGrid[r][c], x0: x0, y0: y0, cellSize: cs,
                                             ink: ColorMath.contrastInkHex(for: fill))
                }
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
