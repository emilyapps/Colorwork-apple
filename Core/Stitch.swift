// Stitch.swift
// The Stitch Catalog: every stitch a knitter can paint into a Cell.
// No Stitch is not here — it is derived from Shaping, never painted (ADR 0002).

import CoreGraphics
import Foundation

// MARK: - Lean

/// The visual direction a stitch slants in the fabric.
enum Lean {
    case left, right, center, none
}

// MARK: - Stitch

enum Stitch: String, CaseIterable, Codable {
    case knit, purl
    case k2tog, ssk, centeredDoubleDecrease, k3tog, sssk
    case yarnOver, m1r, m1l

    var lean: Lean {
        switch self {
        case .knit, .purl, .yarnOver:  return .none
        case .k2tog, .k3tog, .m1r:     return .right
        case .ssk, .sssk, .m1l:        return .left
        case .centeredDoubleDecrease:  return .center
        }
    }

    /// How many stitches this stitch adds (+) or removes (−) from the row.
    var stitchCountChange: Int {
        switch self {
        case .knit, .purl:                           return 0
        case .k2tog, .ssk:                           return -1
        case .centeredDoubleDecrease, .k3tog, .sssk: return -2
        case .yarnOver, .m1r, .m1l:                  return 1
        }
    }

    var displayName: String {
        switch self {
        case .knit:                   return "Knit"
        case .purl:                   return "Purl"
        case .k2tog:                  return "k2tog"
        case .ssk:                    return "ssk"
        case .centeredDoubleDecrease: return "Centered double decrease"
        case .k3tog:                  return "k3tog"
        case .sssk:                   return "sssk"
        case .yarnOver:               return "Yarn over"
        case .m1r:                    return "M1R"
        case .m1l:                    return "M1L"
        }
    }

    /// CYC chart symbol, in unit-cell coordinates (0…1, y down).
    /// Left-leaning symbols are drawn as mirror images of their right-leaning partners.
    var symbol: [SymbolStroke] {
        switch self {
        case .knit:
            return []
        case .purl:
            return [.circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.12, filled: true)]
        case .k2tog:
            return [.line(CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.2))]
        case .centeredDoubleDecrease:
            return [.line(CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.5, y: 0.2)),
                    .line(CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0.8, y: 0.8)),
                    .line(CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0.5, y: 0.8))]
        case .k3tog:
            return [.line(CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.2)),
                    .line(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.8))]
        case .yarnOver:
            return [.circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.25, filled: false)]
        case .m1r:
            return [.line(CGPoint(x: 0.5, y: 0.8), CGPoint(x: 0.5, y: 0.2)),
                    .line(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.25))]
        case .ssk:  return Stitch.k2tog.symbol.map { $0.mirroredLeftRight }
        case .sssk: return Stitch.k3tog.symbol.map { $0.mirroredLeftRight }
        case .m1l:  return Stitch.m1r.symbol.map { $0.mirroredLeftRight }
        }
    }

    /// A rows × cols grid of plain knit stitches.
    static func allKnit(rows: Int, cols: Int) -> [[Stitch]] {
        Array(repeating: Array(repeating: .knit, count: cols), count: rows)
    }
}

// MARK: - SymbolStroke

/// One stroke of a chart symbol, in unit-cell coordinates.
enum SymbolStroke {
    case line(CGPoint, CGPoint)
    case circle(center: CGPoint, radius: CGFloat, filled: Bool)

    /// Mirror image across the cell's vertical center line.
    var mirroredLeftRight: SymbolStroke {
        func m(_ p: CGPoint) -> CGPoint { CGPoint(x: 1 - p.x, y: p.y) }
        switch self {
        case .line(let a, let b):                 return .line(m(a), m(b))
        case .circle(let c, let r, let filled):   return .circle(center: m(c), radius: r, filled: filled)
        }
    }
}
