// SymmetryGroup.swift
// Direct port of the six orbit functions from pattern_core.py lines 34–57.

import Foundation

// MARK: - CellIndex

struct CellIndex: Hashable, Codable {
    let row: Int
    let col: Int
}

// MARK: - CellRegion

enum CellRegion: String, Codable {
    case tile
    case colStrip
    case rowStrip
    case corner
}

// MARK: - SymmetryGroup

enum SymmetryGroup: String, CaseIterable, Codable {
    case c1, d1, d1h, c2, d2, c4, d4

    // MARK: Orbit — returns all cells equivalent to (r,c) under this group
    func orbit(_ r: Int, _ c: Int, H: Int, W: Int) -> Set<CellIndex> {
        let N = H
        switch self {
        case .c1:
            return [CellIndex(row: r, col: c)]

        case .d1:
            return [CellIndex(row: r, col: c),
                    CellIndex(row: r, col: W - 1 - c)]

        case .d1h:
            return [CellIndex(row: r,     col: c),
                    CellIndex(row: H-1-r, col: c)]

        case .c2:
            return [CellIndex(row: r,     col: c),
                    CellIndex(row: H-1-r, col: W-1-c)]

        case .d2:
            return [CellIndex(row: r,     col: c),
                    CellIndex(row: H-1-r, col: W-1-c),
                    CellIndex(row: r,     col: W-1-c),
                    CellIndex(row: H-1-r, col: c)]

        case .c4:
            return [CellIndex(row: r,     col: c),
                    CellIndex(row: c,     col: N-1-r),
                    CellIndex(row: N-1-r, col: N-1-c),
                    CellIndex(row: N-1-c, col: r)]

        case .d4:
            return [CellIndex(row: r,     col: c),
                    CellIndex(row: c,     col: N-1-r),
                    CellIndex(row: N-1-r, col: N-1-c),
                    CellIndex(row: N-1-c, col: r),
                    CellIndex(row: r,     col: N-1-c),
                    CellIndex(row: N-1-r, col: c),
                    CellIndex(row: c,     col: r),
                    CellIndex(row: N-1-c, col: N-1-r)]
        }
    }

    // MARK: UI helpers

    var rotationFactor: Int {
        switch self {
        case .c1, .d1, .d1h: return 1
        case .c2, .d2:        return 2
        case .c4, .d4:        return 4
        }
    }

    var hasReflection: Bool {
        switch self {
        case .c1, .c2, .c4:    return false
        case .d1, .d1h, .d2, .d4: return true
        }
    }

    /// True when the grid must be square (4× symmetry)
    var requiresSquare: Bool {
        self == .c4 || self == .d4
    }

    var displayName: String {
        switch self {
        case .d1:  return "D1V"
        case .d1h: return "D1H"
        default:   return rawValue.uppercased()
        }
    }

    // MARK: Reflection axis

    enum ReflectionAxis { case none, vertical, horizontal }

    var reflectionAxis: ReflectionAxis {
        switch self {
        case .d1:            return .vertical
        case .d1h:           return .horizontal
        case .c1, .c2, .c4: return .none
        case .d2, .d4:       return .vertical   // both axes; .vertical as representative
        }
    }

    static func from(rotation: Int, axis: ReflectionAxis) -> SymmetryGroup {
        switch (rotation, axis) {
        case (1, .none):       return .c1
        case (1, .vertical):   return .d1
        case (1, .horizontal): return .d1h
        case (2, .none):       return .c2
        case (2, _):           return .d2
        case (4, .none):       return .c4
        default:               return .d4
        }
    }

    // Legacy — kept for any call sites that use Bool reflection
    static func from(rotation: Int, reflection: Bool) -> SymmetryGroup {
        from(rotation: rotation, axis: reflection ? .vertical : .none)
    }
}
