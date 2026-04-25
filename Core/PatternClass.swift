// PatternClass.swift
// Named pattern classes and their generation parameters.
// Each class maps to a symmetry group, density range, grid size range,
// and a DomainBiasStrategy that shapes the spatial distribution of filled cells.

import Foundation

// MARK: - PatternClass

enum PatternClass: String, CaseIterable, Codable {
    case star
    case heart
    case pinwheel
}

// MARK: - PatternClassDefinition

struct PatternClassDefinition {
    let symmetryGroup: SymmetryGroup
    let gridSizeRange: ClosedRange<Int>
    let densityRange:  ClosedRange<Double>
    let biasStrategy:  DomainBiasStrategy
    let displayName:   String
}

// MARK: - Per-class definitions

extension PatternClass {

    var definition: PatternClassDefinition {
        switch self {

        case .star:
            // d4 = 8-fold symmetry (4 rotations + 4 reflections).
            // outerEdge bias pushes fill toward the grid edges, forming radiating points.
            return PatternClassDefinition(
                symmetryGroup: .d4,
                gridSizeRange: 12...24,
                densityRange:  0.18...0.42,
                biasStrategy:  .outerEdge(strength: 0.35),
                displayName:   "Star"
            )

        case .heart:
            // d1 = bilateral (left-right) reflection — matches the heart's own symmetry.
            // heartShape bias fills cells inside the implicit heart curve.
            return PatternClassDefinition(
                symmetryGroup: .d1,
                gridSizeRange: 12...22,
                densityRange:  0.30...0.55,
                biasStrategy:  .heartShape,
                displayName:   "Heart"
            )

        case .pinwheel:
            // c4 = 4-fold rotation, no reflection — the asymmetry creates the spinning feel.
            // diagonalArm bias concentrates fill along a northeast arm; c4 makes four of them.
            return PatternClassDefinition(
                symmetryGroup: .c4,
                gridSizeRange: 12...20,
                densityRange:  0.22...0.44,
                biasStrategy:  .diagonalArm(strength: 0.38),
                displayName:   "Pinwheel"
            )
        }
    }

    // MARK: - Helpers for mapping LLM output → concrete parameters

    /// Map a style intensity (0 = most delicate, 1 = most bold) to a density value.
    func density(forStyleIntensity t: Double) -> Double {
        let r = definition.densityRange
        return r.lowerBound + t.clamped(to: 0...1) * (r.upperBound - r.lowerBound)
    }

    /// Map complexity 1–5 to a grid size. Always returns an even number
    /// (required for d4/c4 symmetry center alignment).
    func gridSize(forComplexity complexity: Int) -> Int {
        let r = definition.gridSizeRange
        let t = Double(complexity.clamped(to: 1...5) - 1) / 4.0
        let raw = Int((Double(r.lowerBound) + t * Double(r.upperBound - r.lowerBound)).rounded())
        return raw % 2 == 0 ? raw : raw + 1
    }
}

// MARK: - Comparable clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}