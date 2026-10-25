// ShapingResolver.swift
// Derives No Stitch cells from Shaping stitches (ADR 0002). No Stitch is never painted
// or saved; it is recomputed from the stitch grid whenever stitches change.

import Foundation

enum ShapingResolver {

    struct Result: Equatable {
        /// true where a Cell is No Stitch. Indexed like the stitch grid (row 0 is the top row).
        let noStitch: [[Bool]]
        /// Cells that exist in each row, indexed like the stitch grid.
        let liveStitchesPerRow: [Int]

        /// Stitches around (live cells × repeats) on row 1 and on every row where the count
        /// changes from the row below, bottom to top. Rows are chart rows (row 1 at the bottom).
        func totals(repeats: Int) -> [(row: Int, stitches: Int)] {
            let H = liveStitchesPerRow.count
            var out: [(row: Int, stitches: Int)] = []
            for chartRow in 1 ... max(1, H) where H > 0 {
                let live = liveStitchesPerRow[H - chartRow]
                if chartRow == 1 || live != liveStitchesPerRow[H - chartRow + 1] {
                    out.append((chartRow, live * repeats))
                }
            }
            return out
        }
    }

    /// Rows are resolved from row 1 (the bottom) upward. In each row, increases and decreases
    /// cancel one stitch for one, nearest first; only the leftovers are Shaping.
    /// - A Shaping decrease ends the nearest live column on the side opposite its Lean
    ///   (k2tog: left; ssk: right; centered double decrease: one each side; k3tog/sssk: two on
    ///   their side), from its own row to the top. A centered double decrease with one stitch
    ///   cancelled ends the column on the side away from the increase that cancelled it.
    /// - A Shaping increase makes its own column No Stitch from row 1 to the row below it.
    /// Columns wrap around, because the chart is one repeat and its edges meet the next copy.
    static func resolve(_ stitches: [[Stitch]]) -> Result {
        let H = stitches.count
        let W = stitches.first?.count ?? 0
        var noStitch = Array(repeating: Array(repeating: false, count: W), count: H)
        var shapingIncreases: [CellIndex] = []

        for r in stride(from: H - 1, through: 0, by: -1) {
            let row = cancel(stitches[r], live: noStitch[r].map { !$0 }, W: W)
            shapingIncreases += row.increases.map { CellIndex(row: r, col: $0) }

            for (c, sides) in row.decreases {
                for side in sides {
                    // Nearest column on this side that still exists and holds no shaping stitch.
                    var k = c
                    for _ in 1 ..< W {
                        k = (k + side + W) % W
                        if !noStitch[r][k] && stitches[r][k].stitchCountChange == 0 {
                            for above in 0 ... r { noStitch[above][k] = true }
                            break
                        }
                    }
                }
            }
        }

        for cell in shapingIncreases {
            for below in cell.row + 1 ..< H { noStitch[below][cell.col] = true }
        }

        let live = noStitch.map { row in row.filter { !$0 }.count }
        return Result(noStitch: noStitch, liveStitchesPerRow: live)
    }

    // MARK: Balanced cancellation

    /// Cancels a row's increases against its decreases, one stitch for one, nearest first.
    /// Returns the columns of Shaping increases, and for each Shaping decrease (in column
    /// order) the directions of the columns it ends.
    private static func cancel(_ row: [Stitch], live: [Bool], W: Int)
        -> (increases: [Int], decreases: [(col: Int, sides: [Int])])
    {
        var incs: [Int] = []          // one entry per stitch added
        var decs: [Int] = []          // one entry per stitch removed
        for c in 0 ..< W where live[c] {
            let change = row[c].stitchCountChange
            if change > 0 { incs += Array(repeating: c, count: change) }
            if change < 0 { decs += Array(repeating: c, count: -change) }
        }

        var cancellers: [Int: [Int]] = [:]       // decrease column → increase columns that cancelled it
        while !incs.isEmpty && !decs.isEmpty {
            var best = (i: 0, d: 0, dist: Int.max)
            for (i, ic) in incs.enumerated() {
                for (d, dc) in decs.enumerated() where distance(ic, dc, W: W) < best.dist {
                    best = (i, d, distance(ic, dc, W: W))
                }
            }
            cancellers[decs[best.d], default: []].append(incs[best.i])
            incs.remove(at: best.i)
            decs.remove(at: best.d)
        }

        var leftover: [Int: Int] = [:]
        for c in decs { leftover[c, default: 0] += 1 }
        let decreases = leftover.keys.sorted().map { c in
            (col: c, sides: endedSides(of: row[c], leftover: leftover[c]!, col: c,
                                       cancellers: cancellers[c] ?? [], W: W))
        }
        return (incs, decreases)
    }

    /// Column distance within the repeat, wrapping at the edges.
    private static func distance(_ a: Int, _ b: Int, W: Int) -> Int {
        let d = abs(a - b)
        return min(d, W - d)
    }

    /// The direction (-1 left, +1 right) of each column a decrease ends, given how many of
    /// its stitches are left over after cancellation.
    private static func endedSides(of stitch: Stitch, leftover: Int, col: Int,
                                   cancellers: [Int], W: Int) -> [Int] {
        switch stitch.lean {
        case .right:  return Array(repeating: -1, count: leftover)
        case .left:   return Array(repeating: +1, count: leftover)
        case .center:
            guard leftover == 1, let inc = cancellers.first else { return [-1, +1] }
            // Shortest signed offset to the increase, wrapping; end the other side.
            let offset = ((inc - col) % W + W + W / 2) % W - W / 2
            return [offset < 0 ? +1 : -1]
        case .none:   return []
        }
    }
}
