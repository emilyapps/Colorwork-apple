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
