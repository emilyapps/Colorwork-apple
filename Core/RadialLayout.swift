// RadialLayout.swift
// The Circular View of a Wedge: one ring of stitches per row, around a center, with
// No Stitch removed — the finished crown or yoke seen from above.

import CoreGraphics
import Foundation

enum RadialLayout {

    struct Ring: Equatable {
        /// Chart row (row 1 is the first row knit).
        let chartRow: Int
        /// 0 is the innermost ring.
        let index: Int
        /// Grid columns of one repeat's live cells, in knitting order (chart column 1 first).
        let columns: [Int]
        /// Stitches around: live cells × repeats.
        let stitchCount: Int
    }

    /// Row 1 sits at the center when stitch counts grow from row 1 to the top (a yoke or
    /// crown knit outward), and outside when they shrink; `flipped` reverses that.
    static func rowOneAtCenter(_ shaping: ShapingResolver.Result, flipped: Bool) -> Bool {
        let live = shaping.liveStitchesPerRow
        let grows = (live.first ?? 0) >= (live.last ?? 0)      // top row vs row 1
        return grows != flipped
    }

    static func rings(_ shaping: ShapingResolver.Result, repeats: Int, flipped: Bool) -> [Ring] {
        let H = shaping.noStitch.count
        let W = shaping.noStitch.first?.count ?? 0
        let centerIsRowOne = rowOneAtCenter(shaping, flipped: flipped)
        return (1 ... max(1, H)).compactMap { chartRow in
            guard H > 0 else { return nil }
            let r = H - chartRow
            let columns = stride(from: W - 1, through: 0, by: -1).filter { !shaping.noStitch[r][$0] }
            return Ring(chartRow: chartRow,
                        index: centerIsRowOne ? chartRow - 1 : H - chartRow,
                        columns: columns,
                        stitchCount: columns.count * repeats)
        }
    }

    /// Fraction of the radius left empty at the center.
    static let holeFraction: CGFloat = 0.12

    /// Each stitch as a ring segment, filled with its cell's color, inside `size`.
    static func descriptors(grid: [[Bool]], shaping: ShapingResolver.Result, repeats: Int,
                            flipped: Bool, size: CGSize, fillColor: String, bgColor: String)
        -> [RenderDescriptor]
    {
        let H = grid.count
        guard H > 0, repeats > 0 else { return [] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 - 1
        let hole = outer * holeFraction
        let band = (outer - hole) / CGFloat(H)
        var out = [RenderDescriptor]()
        let all = rings(shaping, repeats: repeats, flipped: flipped).filter { $0.stitchCount > 0 }

        // Outline every stitch or none: outlining only the roomier rings leaves a visible
        // edge where the outlines stop. Outline only if even the tightest ring has room.
        let outline = all.allSatisfy { ring in
            2 * CGFloat.pi / CGFloat(ring.stitchCount) * (hole + CGFloat(ring.index + 1) * band) >= 4
        }

        for ring in all {
            let rIn = hole + CGFloat(ring.index) * band
            let rOut = rIn + band
            let step = 2 * CGFloat.pi / CGFloat(ring.stitchCount)
            for k in 0 ..< ring.stitchCount {
                let col = ring.columns[k % ring.columns.count]
                let fill = grid[H - ring.chartRow][col] ? fillColor : bgColor
                // Clockwise from the top.
                let a0 = -CGFloat.pi / 2 + CGFloat(k) * step
                out.append(.polygon(.init(points: segment(center: center, rIn: rIn, rOut: rOut,
                                                          from: a0, to: a0 + step),
                                          fill: fill, outline: outline ? "#cccccc" : nil,
                                          outlineWidth: 0.5)))
            }
        }
        return out
    }

    /// An annular sector as a polygon, with enough points along each arc to look round.
    private static func segment(center c: CGPoint, rIn: CGFloat, rOut: CGFloat,
                                from a0: CGFloat, to a1: CGFloat) -> [CGPoint] {
        let n = max(1, Int(((a1 - a0) * rOut / 3).rounded(.up)))
        func point(_ r: CGFloat, _ a: CGFloat) -> CGPoint { CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)) }
        let outerArc = (0 ... n).map { point(rOut, a0 + (a1 - a0) * CGFloat($0) / CGFloat(n)) }
        let innerArc = (0 ... n).reversed().map { point(rIn, a0 + (a1 - a0) * CGFloat($0) / CGFloat(n)) }
        return outerArc + innerArc
    }
}
