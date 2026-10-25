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
    }

    /// For now every decrease is Shaping. A decrease ends the nearest live column on the side
    /// opposite its Lean (k2tog: left; ssk: right; centered double decrease: one each side;
    /// k3tog/sssk: two on their side), from its own row to the top of the chart. Rows are
    /// resolved from row 1 (the bottom) upward, so lower decreases claim columns first.
    /// Columns wrap around, because the chart is one repeat and its edges meet the next copy.
    static func resolve(_ stitches: [[Stitch]]) -> Result {
        let H = stitches.count
        let W = stitches.first?.count ?? 0
        var noStitch = Array(repeating: Array(repeating: false, count: W), count: H)

        for r in stride(from: H - 1, through: 0, by: -1) {
            for c in 0 ..< W where !noStitch[r][c] {
                for side in endedSides(of: stitches[r][c]) {
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

        let live = noStitch.map { row in row.filter { !$0 }.count }
        return Result(noStitch: noStitch, liveStitchesPerRow: live)
    }

    /// The direction (-1 left, +1 right) of each column a stitch ends.
    private static func endedSides(of stitch: Stitch) -> [Int] {
        guard stitch.stitchCountChange < 0 else { return [] }
        switch stitch.lean {
        case .right:  return Array(repeating: -1, count: -stitch.stitchCountChange)
        case .left:   return Array(repeating: +1, count: -stitch.stitchCountChange)
        case .center: return [-1, +1]
        case .none:   return []
        }
    }
}
