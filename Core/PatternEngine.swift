// PatternEngine.swift
// Port of compute_fundamental_domain, generate_pattern, and cell-toggle logic
// from pattern_core.py lines 159–179.

import Foundation

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
    static func generatePattern(
        H: Int, W: Int,
        group: SymmetryGroup,
        density: Double
    ) -> (grid: [[Bool]], domain: [CellIndex], canonical: [CellIndex: CellIndex]) {
        let (domain, canonical) = computeDomain(H: H, W: W, group: group)
        var grid = Array(repeating: Array(repeating: false, count: W), count: H)
        for cell in domain {
            let filled = Double.random(in: 0 ..< 1) < density
            for member in group.orbit(cell.row, cell.col, H: H, W: W) {
                grid[member.row][member.col] = filled
            }
        }
        return (grid, domain, canonical)
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
        acrossVerticalAxis: Bool, acrossHorizontalAxis: Bool
    ) {
        let rows = strip.count
        let cols = strip.first?.count ?? 0
        guard row < rows, col < cols else { return }
        let val  = strip[row][col]
        let mr   = rows - 1 - row
        let mc   = cols - 1 - col

        if acrossVerticalAxis && mc != col              { strip[row][mc] = val }
        if acrossHorizontalAxis && mr != row            { strip[mr][col] = val }
        if acrossVerticalAxis && acrossHorizontalAxis && mr != row && mc != col { strip[mr][mc]  = val }
    }
}
