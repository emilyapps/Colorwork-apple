// TilingEngine.swift
// Port of transformed_tile and build_tiling_grid from pattern_core.py lines 186–252.

import Foundation

// MARK: - RepeatType

enum RepeatType: String, CaseIterable, Codable {
    case translation
    case reflection
    case rotation
}

// MARK: - TilingEngine

enum TilingEngine {

    // MARK: transformed_tile

    /// Compute the flipR/flipC flags for repeat position (hi, vi).
    private static func flipFlags(
        hType: RepeatType, vType: RepeatType,
        hi: Int, vi: Int
    ) -> (flipR: Bool, flipC: Bool) {
        var flipR = false
        var flipC = false
        if hType == .reflection && hi % 2 == 1 {
            flipC.toggle()
        } else if hType == .rotation && hi % 2 == 1 {
            flipR.toggle()
            flipC.toggle()
        }
        if vType == .reflection && vi % 2 == 1 {
            flipR.toggle()
        } else if vType == .rotation && vi % 2 == 1 {
            flipR.toggle()
            flipC.toggle()
        }
        return (flipR, flipC)
    }

    /// Return the tile (possibly flipped) for repeat position (hi, vi).
    /// Port of pattern_core.py:transformed_tile
    static func transformedTile(
        _ tile: [[Bool]],
        H: Int, W: Int,
        hType: RepeatType, vType: RepeatType,
        hi: Int, vi: Int
    ) -> [[Bool]] {
        let (flipR, flipC) = flipFlags(hType: hType, vType: vType, hi: hi, vi: vi)
        guard flipR || flipC else { return tile }

        var result = Array(repeating: Array(repeating: false, count: W), count: H)
        for r in 0 ..< H {
            for c in 0 ..< W {
                result[r][c] = tile[flipR ? H-1-r : r][flipC ? W-1-c : c]
            }
        }
        return result
    }

    // MARK: build_tiling_grid

    /// Assemble a full tiling as a 2-D Bool grid.
    /// Port of pattern_core.py:build_tiling_grid
    static func buildTilingGrid(
        tile: [[Bool]], H: Int, W: Int,
        colStrip: [[Bool]], rowStrip: [[Bool]], corner: [[Bool]],
        hRepeat: Bool, vRepeat: Bool,
        stripWidth: Int,
        hType: RepeatType, vType: RepeatType,
        nH: Int = 3, nV: Int = 3,
        rowOffset: Int = 0, colOffset: Int = 0
    ) -> [[Bool]] {
        let sw = stripWidth
        let nh = hRepeat ? nH : 1
        let nv = vRepeat ? nV : 1
        let uw = W + (hRepeat ? sw : 0)
        let uh = H + (vRepeat ? sw : 0)
        let totalW = nh * uw
        let totalH = nv * uh

        var result = Array(repeating: Array(repeating: false, count: totalW), count: totalH)

        func get(_ arr: [[Bool]], _ r: Int, _ c: Int) -> Bool {
            guard r >= 0, r < arr.count, c >= 0, c < (arr.first?.count ?? 0) else { return false }
            return arr[r][c]
        }

        func set(_ y: Int, _ x: Int, _ val: Bool) {
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

                let t = transformedTile(tile, H: H, W: W, hType: hType, vType: vType, hi: hi, vi: vi)
                let (flipR, flipC) = flipFlags(hType: hType, vType: vType, hi: hi, vi: vi)

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
