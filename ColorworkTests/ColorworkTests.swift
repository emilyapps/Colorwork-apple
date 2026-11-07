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
