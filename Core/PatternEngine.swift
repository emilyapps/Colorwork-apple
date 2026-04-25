// PatternEngine.swift
// Port of compute_fundamental_domain, generate_pattern, and cell-toggle logic
// from pattern_core.py lines 159–179.

import Foundation

// MARK: - DomainBiasStrategy

/// Controls how fill probability is distributed across the fundamental domain.
/// Each case shifts per-cell probability up or down relative to the base density.
enum DomainBiasStrategy {
    /// No adjustment — pure random fill at the given density.
    case uniform
    /// Star: cells farther from center are more likely filled, creating radiating points.
    case outerEdge(strength: Double)
    /// Heart: cells inside the heart curve are more likely filled.
    case heartShape
    /// Pinwheel: cells along a diagonal arm are more likely filled;
    /// c4 rotation creates four sweeping arms.
    case diagonalArm(strength: Double)
}

enum PatternEngine {

    // MARK: - Domain

    /// Returns one canonical cell per orbit (first encountered in raster order).
    /// Port of pattern_core.py:compute_fundamental_domain
    static func computeDomain(H: Int, W: Int, group: SymmetryGroup)
        -> (domain: [CellIndex], canonical: [CellIndex: CellIndex])
    {
        var visited  = Set<CellIndex>()
        var domain   = [CellIndex]()
        var canonical = [CellIndex: CellIndex]()

        for r in 0 ..< H {
            for c in 0 ..< W {
                let cell = CellIndex(row: r, col: c)
                guard !visited.contains(cell) else { continue }
                let orb = group.orbit(r, c, H: H, W: W)
                visited.formUnion(orb)
                domain.append(cell)
                for member in orb {
                    canonical[member] = cell
                }
            }
        }
        return (domain, canonical)
    }

    // MARK: - Generate

    /// Randomly fill the fundamental domain at the given density and propagate
    /// each decision to all orbit-equivalent cells.
    /// Port of pattern_core.py:generate_pattern
    ///
    /// Pass a `bias` strategy to steer the spatial distribution of filled cells
    /// (e.g. toward outer edges for stars, or along arms for pinwheels).
    static func generatePattern(
        H: Int, W: Int,
        group: SymmetryGroup,
        density: Double,
        bias: DomainBiasStrategy = .uniform
    ) -> (grid: [[Bool]], domain: [CellIndex], canonical: [CellIndex: CellIndex]) {
        let (domain, canonical) = computeDomain(H: H, W: W, group: group)
        var grid = Array(repeating: Array(repeating: false, count: W), count: H)
        for cell in domain {
            let offset = biasOffset(row: cell.row, col: cell.col, H: H, W: W, strategy: bias)
            let p = min(1.0, max(0.0, density + offset))
            let filled = Double.random(in: 0 ..< 1) < p
            for member in group.orbit(cell.row, cell.col, H: H, W: W) {
                grid[member.row][member.col] = filled
            }
        }
        return (grid, domain, canonical)
    }

    // MARK: - Bias

    private static func biasOffset(
        row: Int, col: Int,
        H: Int, W: Int,
        strategy: DomainBiasStrategy
    ) -> Double {
        switch strategy {

        case .uniform:
            return 0.0

        case .outerEdge(let strength):
            // Cells farther from the grid center get a positive offset; center cells negative.
            let cy = Double(H) / 2.0
            let cx = Double(W) / 2.0
            let dist = ((Double(row) - cy) * (Double(row) - cy)
                      + (Double(col) - cx) * (Double(col) - cx)).squareRoot()
            let maxDist = (cy * cy + cx * cx).squareRoot()
            let normDist = maxDist > 0 ? dist / maxDist : 0
            return strength * (2.0 * normDist - 1.0)

        case .heartShape:
            // Map cell to normalized math coordinates (y points up, origin at heart center).
            // Heart center sits at ~42% down from the top so the point lands near the bottom.
            let x  = (Double(col) - Double(W) / 2.0) / (Double(W) * 0.45)
            let y  = -(Double(row) - Double(H) * 0.42) / (Double(H) * 0.42)
            let x2 = x * x
            let y2 = y * y
            // Implicit heart curve: f ≤ 0 → inside the heart.
            let f  = pow(x2 + y2 - 1.0, 3.0) - x2 * y2 * y
            return f <= 0 ? 0.35 : -0.35

        case .diagonalArm(let strength):
            // Cells along a northeast arm (−45° from horizontal) get a positive offset,
            // scaled by distance from center so the arm is stronger toward the edges.
            // c4 symmetry then rotates this arm into three others.
            let cy = Double(H) / 2.0
            let cx = Double(W) / 2.0
            let dy = Double(row) - cy
            let dx = Double(col) - cx
            let dist = (dy * dy + dx * dx).squareRoot()
            guard dist > 0.5 else { return 0.0 }
            let normDist = dist / (cy * cy + cx * cx).squareRoot()

            let armAngle  = -Double.pi / 4.0          // northeast
            var diff      = atan2(dy, dx) - armAngle
            while diff >  Double.pi { diff -= 2 * Double.pi }
            while diff < -Double.pi { diff += 2 * Double.pi }

            let halfWidth = Double.pi / 5.0            // ±36° arm width
            if abs(diff) < halfWidth {
                let fade = 1.0 - abs(diff) / halfWidth
                return fade * normDist * strength
            }
            return -strength * 0.25
        }
    }

    // MARK: - Toggle

    /// Toggle the canonical representative of the tapped cell and propagate
    /// to all orbit members. O(1) lookup via the precomputed canonical map.
    static func toggleCell(
        _ cell: CellIndex,
        in grid: inout [[Bool]],
        canonical: [CellIndex: CellIndex],
        group: SymmetryGroup,
        H: Int, W: Int
    ) {
        guard let canon = canonical[cell] else { return }
        let newValue = !grid[canon.row][canon.col]
        for member in group.orbit(canon.row, canon.col, H: H, W: W) {
            grid[member.row][member.col] = newValue
        }
    }

    // MARK: - Clear

    static func clearGrid(H: Int, W: Int) -> [[Bool]] {
        Array(repeating: Array(repeating: false, count: W), count: H)
    }

    // MARK: - Strip helpers

    static func emptyStrip(rows: Int, cols: Int) -> [[Bool]] {
        Array(repeating: Array(repeating: false, count: cols), count: rows)
    }

    static func toggleStripCell(
        row: Int, col: Int,
        in strip: inout [[Bool]]
    ) {
        guard row < strip.count, col < (strip.first?.count ?? 0) else { return }
        strip[row][col].toggle()
    }

    static func applyStripReflect(
        row: Int, col: Int,
        in strip: inout [[Bool]],
        hReflect: Bool, vReflect: Bool
    ) {
        let rows = strip.count
        let cols = strip.first?.count ?? 0
        guard row < rows, col < cols else { return }
        let val  = strip[row][col]
        let mr   = rows - 1 - row
        let mc   = cols - 1 - col

        if hReflect && mc != col                          { strip[row][mc] = val }
        if vReflect && mr != row                          { strip[mr][col] = val }
        if hReflect && vReflect && mr != row && mc != col { strip[mr][mc]  = val }
    }
}
