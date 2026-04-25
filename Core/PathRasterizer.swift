// PathRasterizer.swift
// Deterministic rasterization of geometric primitives into the symmetry grid.
//
// Architecture:
//   • ShapePrimitive — a geometric test: is this cell inside the shape?
//   • FillMode — how matched cells are filled (solid or checkerboard)
//   • RasterLayer — one primitive + one fill mode
//   • PathRasterizer.rasterize() — evaluates layers per domain cell,
//     propagates results through symmetry orbits, returns the full grid.
//
// Two families of primitives:
//   Domain-space: Nordic star, pinwheel arm — tests use domain (r,c) directly.
//                 These are only meaningful with their required symmetry group.
//   Cartesian:    Heart, disk, ring, dots — tests use normalized (x,y) in [-1,1]²
//                 relative to grid center; work with any symmetry group.

import Foundation

// MARK: - ShapePrimitive

enum ShapePrimitive {

    /// 8-pointed Nordic star. Domain-space test; requires D4 symmetry.
    /// Arms follow the two edges of the triangular D4 domain:
    ///   cardinal arms  → near the horizontal edge (r ≈ 0)
    ///   diagonal arms  → near the hypotenuse     (r ≈ c)
    /// - armWidth: normalized arm thickness, 0.1 = hairline … 0.4 = bold
    /// - size:     how far arms reach from center, 0.3 = short … 1.0 = full grid
    case nordicStar(armWidth: Double, size: Double)

    /// Pinwheel blade. Domain-space test; requires C4 symmetry.
    /// Fills a tapered arm that widens toward the outer edge so the four
    /// C4-rotated copies sweep like propeller blades.
    /// - armWidth: base width of the blade (normalized)
    /// - size:     radial reach of the blade, 0.0–1.0
    case pinwheelArm(armWidth: Double, size: Double)

    /// Heart shape via implicit Cartesian curve.
    /// f(x,y) = (x²+y²−1)³ − x²y³ ≤ 0 → inside heart (point at bottom).
    /// - centerX/Y: normalized position, 0.5 = grid center
    /// - scale:     0.1 = tiny … 1.0 = fills grid
    case heart(centerX: Double, centerY: Double, scale: Double)

    /// Filled disk.
    /// - centerX/Y: normalized, 0.5 = grid center
    /// - radius:    as fraction of half-grid, 1.0 = touches edges
    case disk(centerX: Double, centerY: Double, radius: Double)

    /// Annular ring between two radii.
    /// - innerR/outerR: fractions of half-grid, 0.0–1.0
    case ring(centerX: Double, centerY: Double, innerR: Double, outerR: Double)

    /// Ring of equally-spaced filled dots.
    /// - count:      number of dots
    /// - ringRadius: distance of dot centers from the layer center (fraction of half-grid)
    /// - dotRadius:  radius of each dot (fraction of half-grid)
    case dots(centerX: Double, centerY: Double,
              count: Int, ringRadius: Double, dotRadius: Double)
}

// MARK: - FillMode

enum FillMode {
    /// Every matched cell is filled.
    case solid
    /// Only cells where (row + col) is even are filled — produces a
    /// checkerboard texture inside the shape boundary.
    case checker
}

// MARK: - RasterLayer

struct RasterLayer {
    let shape: ShapePrimitive
    let fillMode: FillMode

    init(_ shape: ShapePrimitive, fill: FillMode = .solid) {
        self.shape    = shape
        self.fillMode = fill
    }
}

// MARK: - PathRasterizer

enum PathRasterizer {

    /// Rasterize `layers` into an H×W grid using the given symmetry group.
    ///
    /// Steps:
    ///   1. For each layer, determine which cells are inside the shape by
    ///      evaluating domain cells and propagating through orbits.
    ///   2. Apply fill mode in full-grid coordinates (so checker aligns
    ///      consistently across the whole pattern, not just the domain).
    ///   3. OR all layers together into the final grid.
    ///
    /// Returns the same tuple shape as PatternEngine.generatePattern so
    /// callers can swap it in without changing downstream state.
    static func rasterize(
        layers: [RasterLayer],
        H: Int, W: Int,
        group: SymmetryGroup
    ) -> (grid: [[Bool]], domain: [CellIndex], canonical: [CellIndex: CellIndex]) {

        let (domain, canonical) = PatternEngine.computeDomain(H: H, W: W, group: group)
        var result = Array(repeating: Array(repeating: false, count: W), count: H)

        for layer in layers {

            // Pass 1 — build a shape-mask for the whole grid via domain + orbit propagation
            var mask = Array(repeating: Array(repeating: false, count: W), count: H)
            for cell in domain {
                let inShape = isInShape(row: cell.row, col: cell.col,
                                        H: H, W: W, shape: layer.shape)
                for member in group.orbit(cell.row, cell.col, H: H, W: W) {
                    mask[member.row][member.col] = inShape
                }
            }

            // Pass 2 — apply fill mode using full-grid (r,c), then OR into result
            for r in 0 ..< H {
                for c in 0 ..< W {
                    guard mask[r][c] else { continue }
                    let filled: Bool
                    switch layer.fillMode {
                    case .solid:   filled = true
                    case .checker: filled = (r + c) % 2 == 0
                    }
                    if filled { result[r][c] = true }
                }
            }
        }

        return (result, domain, canonical)
    }

    // MARK: - Shape tests

    private static func isInShape(row: Int, col: Int, H: Int, W: Int,
                                   shape: ShapePrimitive) -> Bool {
        switch shape {

        // ── Domain-space tests ─────────────────────────────────────────────

        case .nordicStar(let armWidth, let size):
            // Derived from the "star-4x-with-reflection" 13×13 reference pattern.
            //
            // The arm is a diagonal band in domain space OFFSET from the hypotenuse r=c.
            // In the 13×13 reference the filled cells satisfy:
            //   1 ≤ c−r ≤ 3  (the band, offset from diagonal)
            //   3 ≤ c   ≤ 5  (the radial extent)
            // plus a center cell at (6,6).
            //
            // Integer arithmetic avoids floating-point boundary misses that occur
            // when normalized thresholds land exactly on a cell's normC value.
            let halfN   = Double(max(H, W)) / 2.0
            let minBand = max(1, Int((armWidth / 2.0   * halfN).rounded()))
            let maxBand =        Int((armWidth * 1.5   * halfN).rounded())
            let minC    = max(1, Int(((size - armWidth) * halfN).rounded()))
            let maxC    =        Int((size              * halfN).rounded())
            let band    = col - row
            let onArm   = band >= minBand && band <= maxBand
                       && col  >= minC    && col  <= maxC
            // Center: innermost diagonal domain cells map to the star's center diamond.
            let centerC = max(0, Int(halfN.rounded()) - 1)
            let onCenter = col >= centerC && row >= centerC
            return onArm || onCenter

        case .pinwheelArm(let armWidth, let size):
            // Works in the C4 domain. The arm tapers from zero width at the
            // center to armWidth at the outer edge, giving a propeller-blade silhouette.
            let halfN     = Double(max(H, W)) / 2.0
            let normC     = Double(col) / halfN
            let normR     = Double(row) / halfN
            guard normC > 0.05, normC < size else { return false }
            let localWidth = armWidth * normC   // widens with distance
            return normR < localWidth

        // ── Cartesian tests ────────────────────────────────────────────────

        case .heart(let cx, let cy, let scale):
            // Map grid cell to normalized math coordinates (y points upward).
            // Implicit curve: f(x,y) = (x²+y²−1)³ − x²y³ ≤ 0 → inside heart.
            guard scale > 0 else { return false }
            let nx  = (Double(col) / Double(W) - cx) * 2.0 / scale
            let ny  = -(Double(row) / Double(H) - cy) * 2.0 / scale
            let nx2 = nx * nx
            let ny2 = ny * ny
            return pow(nx2 + ny2 - 1.0, 3.0) - nx2 * ny2 * ny <= 0

        case .disk(let cx, let cy, let radius):
            let dx = Double(col) / Double(W) - cx
            let dy = Double(row) / Double(H) - cy
            // Normalize so radius=1.0 just touches the nearest edge
            let scale = 0.5 / max(Double(H), Double(W)) * Double(max(H, W))
            let d = (dx*dx + dy*dy).squareRoot() / scale
            return d <= radius

        case .ring(let cx, let cy, let innerR, let outerR):
            let dx    = Double(col) / Double(W) - cx
            let dy    = Double(row) / Double(H) - cy
            let d     = (dx*dx + dy*dy).squareRoot() * 2.0  // 0–1 across half-grid
            return d >= innerR && d <= outerR

        case .dots(let cx, let cy, let count, let ringRadius, let dotRadius):
            guard count > 0 else { return false }
            let px = Double(col) / Double(W) - cx
            let py = -(Double(row) / Double(H) - cy)
            for i in 0 ..< count {
                let angle = 2.0 * .pi * Double(i) / Double(count)
                let dotX  = ringRadius * 0.5 * cos(angle)
                let dotY  = ringRadius * 0.5 * sin(angle)
                let dx    = px - dotX
                let dy    = py - dotY
                if (dx*dx + dy*dy).squareRoot() <= dotRadius * 0.5 { return true }
            }
            return false
        }
    }
}