//
//  ColorworkTests.swift
//  ColorworkTests
//
//  Created by Emily Stein on 4/7/26.
//

import Testing

struct ColorworkTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - Suggested partner colours

@testable import Colorwork

struct HarmonySuggestionTests {
    /// Light, dark, mid-tone, saturated and grey starting colours.
    static let bases = ["#1a1a2e", "#f5f0e8", "#ff0000", "#00ff00", "#808080",
                        "#ffff00", "#4682b4", "#000000", "#ffffff", "#c71585"]

    @Test("Every suggestion reaches at least AA contrast with the colour it pairs with",
          arguments: bases)
    func contrastAtLeastAA(base: String) {
        for h in ColorMath.harmonies(for: base) {
            #expect(ColorMath.contrastRatio(h.hex, base) >= 4.5, "\(h.name) \(h.hex) vs \(base)")
        }
    }

    @Test("Suggestions are muted (saturation at most 45%)", arguments: bases)
    func muted(base: String) throws {
        for h in ColorMath.harmonies(for: base) {
            let (r, g, b) = try #require(ColorMath.hexToRGB(h.hex))
            #expect(ColorMath.rgbToHSL(r: r, g: g, b: b).s <= 0.47, "\(h.name) \(h.hex)")
        }
    }

    @Test func sevenLabelledSuggestions() {
        let names = ColorMath.harmonies(for: "#1a1a2e").map(\.name)
        #expect(names == ["Complementary", "Split", "Split", "Analogous", "Analogous", "Triadic", "Triadic"])
    }
}

struct HarmonyContrastTargetTests {
    @Test("Suggestions reach the requested contrast when it is reachable",
          arguments: [3.0, 4.5, 7.0])
    func reachesTarget(target: Double) {
        // Mid-tones (e.g. steel blue) can't reach 7:1 against anything; light and dark can.
        let bases = target >= 7 ? ["#1a1a2e", "#f5f0e8"] : ["#1a1a2e", "#f5f0e8", "#4682b4"]
        for base in bases {
            for h in ColorMath.harmonies(for: base, contrast: target) {
                #expect(ColorMath.contrastRatio(h.hex, base) >= target, "\(h.name) \(h.hex) vs \(base) @ \(target)")
            }
        }
    }

    @Test func unreachableTargetFallsBackToMostContrast() {
        // Steel blue can't reach 7:1; it falls back to the most contrast it can get.
        for h in ColorMath.harmonies(for: "#4682b4", contrast: 7) {
            #expect(ColorMath.contrastRatio(h.hex, "#4682b4") >= 4.0)
        }
    }
}

// MARK: - Resizing and symmetry changes keep the drawing

struct CentredResizeTests {
    @Test("Same parity pads or crops evenly")
    func sameParity() {
        #expect(PatternEngine.centredIndexMap(from: 4, to: 6) == [nil, 0, 1, 2, 3, nil])
        #expect(PatternEngine.centredIndexMap(from: 6, to: 4) == [1, 2, 3, 4])
    }

    @Test("Even to odd adds a blank centre strip")
    func evenToOdd() {
        #expect(PatternEngine.centredIndexMap(from: 4, to: 5) == [0, 1, nil, 2, 3])
        #expect(PatternEngine.centredIndexMap(from: 4, to: 7) == [nil, 0, 1, nil, 2, 3, nil])
        #expect(PatternEngine.centredIndexMap(from: 6, to: 3) == [2, nil, 3])
    }

    @Test("Odd to even removes the centre strip")
    func oddToEven() {
        #expect(PatternEngine.centredIndexMap(from: 5, to: 4) == [0, 1, 3, 4])
        #expect(PatternEngine.centredIndexMap(from: 5, to: 6) == [nil, 0, 1, 3, 4, nil])
    }

    @Test("Every size keeps a mirror-symmetric drawing mirror-symmetric", arguments: 2 ... 12)
    func staysSymmetric(m: Int) {
        let base = [true, false, true, true, false, true]   // symmetric, n = 6
        let row = PatternEngine.centredResize([base], rows: 1, cols: m, blank: false)[0]
        #expect(row == row.reversed(), "\(row)")
    }

    @Test func growShrinkGrowFromTheSameBaseIsLossless() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.H = 6; doc.W = 6
        doc.endReshape()
        doc.toggleCell(CellIndex(row: 0, col: 0), region: .tile)
        let before = doc.grid
        doc.H = 3; doc.W = 3          // the corner cell falls off…
        doc.H = 6; doc.W = 6          // …and comes back
        #expect(doc.grid == before)
    }
}

struct SymmetryCompletionTests {
    @Test func moreSymmetryFillsEveryCopy() {
        var g = Array(repeating: Array(repeating: false, count: 4), count: 4)
        g[0][1] = true
        let done = PatternEngine.completed(g, under: .d4)
        for cell in SymmetryGroup.d4.orbit(0, 1, H: 4, W: 4) { #expect(done[cell.row][cell.col]) }
    }

    @Test func goingBackRestoresTheOriginal() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.H = 6; doc.W = 6
        doc.endReshape()
        doc.toggleCell(CellIndex(row: 0, col: 1), region: .tile)
        let before = doc.grid
        doc.symmetryGroup = .d4
        #expect(doc.grid != before)
        doc.symmetryGroup = .c1
        #expect(doc.grid == before)
    }
}
