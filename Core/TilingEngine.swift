// TilingEngine.swift
// Port of transformed_tile and build_tiling_grid from pattern_core.py lines 186–252.

import Foundation

// MARK: - RepeatType

/// How alternate copies of a Tile are placed. In a horizontal repeat (copies side by side)
/// `.reflection` is a reflection across a vertical axis; in a vertical repeat (copies stacked)
/// it is a reflection across a horizontal axis. `.rotation` is a half-turn either way.
enum RepeatType: String, CaseIterable, Codable {
    case translation
    case reflection
    case rotation
}

// MARK: - TilingEngine

enum TilingEngine {

    // MARK: Transformations of copies

    /// Compute the flipR/flipC flags for repeat position (hi, vi).
    private static func flipFlags(
        horizontal: RepeatType, vertical: RepeatType,
        hi: Int, vi: Int
    ) -> (flipR: Bool, flipC: Bool) {
        var flipR = false
        var flipC = false
        if horizontal == .reflection && hi % 2 == 1 {
            flipC.toggle()
        } else if horizontal == .rotation && hi % 2 == 1 {
            flipR.toggle()
            flipC.toggle()
        }
        if vertical == .reflection && vi % 2 == 1 {
            flipR.toggle()
        } else if vertical == .rotation && vi % 2 == 1 {
            flipR.toggle()
            flipC.toggle()
        }
        return (flipR, flipC)
    }

    /// Every Transformation applied to some copy of the Tile, including combinations
    /// (e.g. reflecting both ways gives the diagonal copies a half-turn).
    static func copyTransformations(horizontal: RepeatType, vertical: RepeatType) -> Set<Transformation> {
        var result = Set<Transformation>()
        for hi in 0 ... 1 {
            for vi in 0 ... 1 {
                let (r, c) = flipFlags(horizontal: horizontal, vertical: vertical, hi: hi, vi: vi)
                result.insert(.flipping(rows: r, cols: c))
            }
        }
        return result
    }

    /// True when every stitch has a Visual Equivalent in every copy these repeat types make (ADR 0001).
    static func allows(horizontal: RepeatType, vertical: RepeatType, stitches: some Sequence<Stitch>) -> Bool {
        let used = Set(stitches)
        return copyTransformations(horizontal: horizontal, vertical: vertical).allSatisfy { $0.allows(used) }
    }

    // MARK: transformed_tile

    /// Return the tile (possibly flipped) for repeat position (hi, vi), passing each cell
    /// through `copy` with the Transformation applied.
    /// Port of pattern_core.py:transformed_tile
    static func transformedTile<Cell>(
        _ tile: [[Cell]],
        H: Int, W: Int,
        horizontal: RepeatType, vertical: RepeatType,
        hi: Int, vi: Int,
        copy: (Cell, Transformation) -> Cell = { cell, _ in cell }
    ) -> [[Cell]] {
        let (flipR, flipC) = flipFlags(horizontal: horizontal, vertical: vertical, hi: hi, vi: vi)
        guard flipR || flipC else { return tile }
        let t = Transformation.flipping(rows: flipR, cols: flipC)
        return (0 ..< H).map { r in
            (0 ..< W).map { c in copy(tile[flipR ? H-1-r : r][flipC ? W-1-c : c], t) }
        }
    }

    // MARK: build_tiling_grid

    /// Assemble a full tiling of colors as a 2-D Bool grid.
    static func buildTilingGrid(
        tile: [[Bool]], H: Int, W: Int,
        colStrip: [[Bool]], rowStrip: [[Bool]], corner: [[Bool]],
        hRepeat: Bool, vRepeat: Bool,
        stripWidth: Int,
        horizontal: RepeatType, vertical: RepeatType,
        nH: Int = 3, nV: Int = 3,
        rowOffset: Int = 0, colOffset: Int = 0
    ) -> [[Bool]] {
        buildTilingGrid(tile: tile, H: H, W: W, colStrip: colStrip, rowStrip: rowStrip, corner: corner,
                        empty: false, hRepeat: hRepeat, vRepeat: vRepeat, stripWidth: stripWidth,
                        horizontal: horizontal, vertical: vertical, nH: nH, nV: nV,
                        rowOffset: rowOffset, colOffset: colOffset)
    }

    /// Assemble a full tiling as a 2-D grid of any cell type. Transformed copies pass each
    /// tile cell through `copy`; strips are copied by position only.
    /// Port of pattern_core.py:build_tiling_grid
    static func buildTilingGrid<Cell>(
        tile: [[Cell]], H: Int, W: Int,
        colStrip: [[Cell]], rowStrip: [[Cell]], corner: [[Cell]],
        empty: Cell,
        hRepeat: Bool, vRepeat: Bool,
        stripWidth: Int,
        horizontal: RepeatType, vertical: RepeatType,
        nH: Int = 3, nV: Int = 3,
        rowOffset: Int = 0, colOffset: Int = 0,
        copy: (Cell, Transformation) -> Cell = { cell, _ in cell }
    ) -> [[Cell]] {
        let sw = stripWidth
        let nh = hRepeat ? nH : 1
        let nv = vRepeat ? nV : 1
        let uw = W + (hRepeat ? sw : 0)
        let uh = H + (vRepeat ? sw : 0)
        let totalW = nh * uw
        let totalH = nv * uh

        var result = Array(repeating: Array(repeating: empty, count: totalW), count: totalH)

        func get(_ arr: [[Cell]], _ r: Int, _ c: Int) -> Cell {
            guard r >= 0, r < arr.count, c >= 0, c < (arr.first?.count ?? 0) else { return empty }
            return arr[r][c]
        }

        func set(_ y: Int, _ x: Int, _ val: Cell) {
            guard y >= 0, y < totalH, x >= 0, x < totalW else { return }
            result[y][x] = val
        }

        let hiRange = rowOffset != 0 ? (-1 ..< nh + 1) : (0 ..< nh)
        let viRange = colOffset != 0 ? (-1 ..< nv + 1) : (0 ..< nv)

        for vi in viRange {
            for hi in hiRange {
                let x0 = hi * uw + (uw == 0 ? 0 : ((vi * rowOffset) % uw + uw) % uw)
                let y0 = vi * uh + (uh == 0 ? 0 : ((hi * colOffset) % uh + uh) % uh)
                if x0 >= totalW || x0 + uw <= 0 { continue }
                if y0 >= totalH || y0 + uh <= 0 { continue }

                let t = transformedTile(tile, H: H, W: W, horizontal: horizontal, vertical: vertical,
                                        hi: hi, vi: vi, copy: copy)
                let (flipR, flipC) = flipFlags(horizontal: horizontal, vertical: vertical, hi: hi, vi: vi)

                for r in 0 ..< H {
                    for c in 0 ..< W {
                        set(y0 + r, x0 + c, t[r][c])
                    }
                }
                if hRepeat && sw > 0 {
                    for r in 0 ..< H {
                        for sc in 0 ..< sw {
                            set(y0 + r, x0 + W + sc,
                                get(colStrip, flipR ? H-1-r : r, flipC ? sw-1-sc : sc))
                        }
                    }
                }
                if vRepeat && sw > 0 {
                    for sr in 0 ..< sw {
                        for c in 0 ..< W {
                            set(y0 + H + sr, x0 + c,
                                get(rowStrip, flipR ? sw-1-sr : sr, flipC ? W-1-c : c))
                        }
                    }
                }
                if hRepeat && vRepeat && sw > 0 {
                    for sr in 0 ..< sw {
                        for sc in 0 ..< sw {
                            set(y0 + H + sr, x0 + W + sc,
                                get(corner, flipR ? sw-1-sr : sr, flipC ? sw-1-sc : sc))
                        }
                    }
                }
            }
        }
        return result
    }
}
