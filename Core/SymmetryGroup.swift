// SymmetryGroup.swift
// Symmetry Groups as sets of Transformations; orbits originally ported from pattern_core.py lines 34–57.

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

// MARK: - Transformation

/// One of the 8 symmetries of a square grid. Reflections are named by their axis;
/// turns are clockwise on screen. Turns and diagonal reflections need a square grid.
enum Transformation: CaseIterable {
    case identity
    case verticalAxisReflection, horizontalAxisReflection
    case diagonalAxisReflection, antiDiagonalAxisReflection
    case quarterTurn, halfTurn, threeQuarterTurn

    func apply(_ r: Int, _ c: Int, H: Int, W: Int) -> CellIndex {
        let N = H
        switch self {
        case .identity:                   return CellIndex(row: r,       col: c)
        case .verticalAxisReflection:     return CellIndex(row: r,       col: W - 1 - c)
        case .horizontalAxisReflection:   return CellIndex(row: H - 1 - r, col: c)
        case .halfTurn:                   return CellIndex(row: H - 1 - r, col: W - 1 - c)
        case .quarterTurn:                return CellIndex(row: c,       col: N - 1 - r)
        case .threeQuarterTurn:           return CellIndex(row: N - 1 - c, col: r)
        case .diagonalAxisReflection:     return CellIndex(row: c,       col: r)
        case .antiDiagonalAxisReflection: return CellIndex(row: N - 1 - c, col: N - 1 - r)
        }
    }
}

// MARK: - SymmetryGroup

enum SymmetryGroup: String, CaseIterable, Codable {
    case c1, d1, d1h, c2, d2, c4, d4

    // MARK: Transformations and linked cells

    /// The Transformations that make up this group.
    var transformations: [Transformation] {
        switch self {
        case .c1:  return [.identity]
        case .d1:  return [.identity, .verticalAxisReflection]
        case .d1h: return [.identity, .horizontalAxisReflection]
        case .c2:  return [.identity, .halfTurn]
        case .d2:  return [.identity, .halfTurn, .verticalAxisReflection, .horizontalAxisReflection]
        case .c4:  return [.identity, .quarterTurn, .halfTurn, .threeQuarterTurn]
        case .d4:  return [.identity, .quarterTurn, .halfTurn, .threeQuarterTurn,
                           .verticalAxisReflection, .horizontalAxisReflection,
                           .diagonalAxisReflection, .antiDiagonalAxisReflection]
        }
    }

    /// Every cell linked to (r,c), each with the Transformation that produced it.
    /// A cell on an axis appears more than once, under different Transformations.
    func linkedCells(_ r: Int, _ c: Int, H: Int, W: Int) -> [(cell: CellIndex, transformation: Transformation)] {
        transformations.map { ($0.apply(r, c, H: H, W: W), $0) }
    }

    /// All cells equivalent to (r,c) under this group.
    func orbit(_ r: Int, _ c: Int, H: Int, W: Int) -> Set<CellIndex> {
        Set(linkedCells(r, c, H: H, W: W).map(\.cell))
    }

    // MARK: Stitches (ADR 0001)

    /// True when every stitch has a Visual Equivalent under every Transformation in this group.
    func allows(_ stitches: some Sequence<Stitch>) -> Bool {
        let ts = transformations
        return Set(stitches).allSatisfy { s in ts.allSatisfy { s.visualEquivalent(under: $0) != nil } }
    }

    /// The largest group within this one that allows the stitches (C1 always does).
    func largestGroupAllowing(_ stitches: some Sequence<Stitch>) -> SymmetryGroup {
        let mine = Set(transformations)
        let distinct = Set(stitches)
        return SymmetryGroup.allCases
            .filter { Set($0.transformations).isSubset(of: mine) && $0.allows(distinct) }
            .max { $0.transformations.count < $1.transformations.count } ?? .c1
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
