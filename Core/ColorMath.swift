// ColorMath.swift
// Port of all color utility functions from pattern_core.py lines 70–152.
// Pure Swift, no UI framework imports.

import Foundation
import SwiftUI

// MARK: - ColorMath

enum ColorMath {

    // MARK: CMYK ↔ Hex
    // Port of pattern_core.py:cmyk_to_hex

    static func cmykToHex(c: Double, m: Double, y: Double, k: Double) -> String {
        let r = Int((255 * (1 - c / 100) * (1 - k / 100)).rounded())
        let g = Int((255 * (1 - m / 100) * (1 - k / 100)).rounded())
        let b = Int((255 * (1 - y / 100) * (1 - k / 100)).rounded())
        return String(format: "#%02x%02x%02x",
                      min(255, max(0, r)),
                      min(255, max(0, g)),
                      min(255, max(0, b)))
    }

    /// Port of pattern_core.py:hex_to_cmyk. Returns nil for invalid input.
    static func hexToCMYK(_ hex: String) -> (c: Double, m: Double, y: Double, k: Double)? {
        guard let (r, g, b) = hexToRGB(hex) else { return nil }
        let r_ = Double(r) / 255, g_ = Double(g) / 255, b_ = Double(b) / 255
        let k_ = 1 - max(r_, g_, b_)
        if k_ == 1 { return (0, 0, 0, 100) }
        let inv = 1 - k_
        let c_ = (1 - r_ - k_) / inv
        let m_ = (1 - g_ - k_) / inv
        let y_ = (1 - b_ - k_) / inv
        return (c: (c_ * 100).rounded(), m: (m_ * 100).rounded(),
                y: (y_ * 100).rounded(), k: (k_ * 100).rounded())
    }

    // MARK: Hex ↔ RGB

    /// Port of pattern_core.py:_hex_to_rgb
    static func hexToRGB(_ hex: String) -> (r: Int, g: Int, b: Int)? {
        let h = hex.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6 else { return nil }
        guard let ri = Int(h.prefix(2), radix: 16),
              let gi = Int(h.dropFirst(2).prefix(2), radix: 16),
              let bi = Int(h.dropFirst(4).prefix(2), radix: 16) else { return nil }
        return (ri, gi, bi)
    }

    // MARK: RGB ↔ HSL

    /// Port of pattern_core.py:_rgb_to_hsl. Returns (h: 0–360, s: 0–1, l: 0–1)
    static func rgbToHSL(r: Int, g: Int, b: Int) -> (h: Double, s: Double, l: Double) {
        let r = Double(r) / 255, g = Double(g) / 255, b = Double(b) / 255
        let cmax = max(r, g, b), cmin = min(r, g, b)
        let delta = cmax - cmin
        let l = (cmax + cmin) / 2
        let s: Double = delta == 0 ? 0 : delta / (1 - abs(2 * l - 1))
        let h: Double
        if delta == 0 {
            h = 0
        } else if cmax == r {
            h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
        } else if cmax == g {
            h = 60 * ((b - r) / delta + 2)
        } else {
            h = 60 * ((r - g) / delta + 4)
        }
        return ((h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360), s, l)
    }

    /// Port of pattern_core.py:_hsl_to_hex. s and l are 0–1, h is 0–360.
    static func hslToHex(h: Double, s: Double, l: Double) -> String {
        let h = h.truncatingRemainder(dividingBy: 360)
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case 0   ..< 60:  (r1, g1, b1) = (c, x, 0)
        case 60  ..< 120: (r1, g1, b1) = (x, c, 0)
        case 120 ..< 180: (r1, g1, b1) = (0, c, x)
        case 180 ..< 240: (r1, g1, b1) = (0, x, c)
        case 240 ..< 300: (r1, g1, b1) = (x, 0, c)
        default:           (r1, g1, b1) = (c, 0, x)
        }
        return String(format: "#%02x%02x%02x",
                      Int(((r1 + m) * 255).rounded()),
                      Int(((g1 + m) * 255).rounded()),
                      Int(((b1 + m) * 255).rounded()))
    }

    // MARK: Contrast (WCAG)

    /// Port of pattern_core.py:_relative_luminance
    static func relativeLuminance(_ hex: String) -> Double {
        guard let (r, g, b) = hexToRGB(hex) else { return 0 }
        func lin(_ c: Int) -> Double {
            let v = Double(c) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Port of pattern_core.py:_contrast_ratio
    static func contrastRatio(_ hex1: String, _ hex2: String) -> Double {
        let l1 = relativeLuminance(hex1), l2 = relativeLuminance(hex2)
        let hi = max(l1, l2), lo = min(l1, l2)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// "#000000" or "#ffffff", whichever contrasts more with the background.
    static func contrastInkHex(for hex: String) -> String {
        contrastRatio(hex, "#000000") >= contrastRatio(hex, "#ffffff") ? "#000000" : "#ffffff"
    }

    // MARK: Harmony

    /// 7 harmony colours: complement, 2× split, 2× analogous, 2× triadic.
    /// Port of pattern_core.py:_harmony_colors
    static func harmonyColors(fill: String) -> [String] {
        guard let (r, g, b) = hexToRGB(fill) else { return Array(repeating: "#888888", count: 7) }
        let (h, s, l) = rgbToHSL(r: r, g: g, b: b)
        let sHarm = max(0.30, s * 0.85)
        let lHarm = l > 0.55 ? max(0.10, l - 0.50) : min(0.92, l + 0.45)
        return [180, 150, 210, 30, 330, 120, 240].map { off in
            hslToHex(h: (h + Double(off)).truncatingRemainder(dividingBy: 360),
                     s: sHarm, l: lHarm)
        }
    }

    // MARK: SwiftUI convenience

    static func color(from hex: String) -> Color {
        guard let (r, g, b) = hexToRGB(hex) else { return .gray }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Returns "#rrggbb" from a SwiftUI Color by resolving in sRGB.
    static func hex(from color: Color) -> String {
        let resolved = color.resolve(in: .init())
        let r = Int((resolved.red   * 255).rounded())
        let g = Int((resolved.green * 255).rounded())
        let b = Int((resolved.blue  * 255).rounded())
        return String(format: "#%02x%02x%02x",
                      min(255, max(0, r)),
                      min(255, max(0, g)),
                      min(255, max(0, b)))
    }

    /// Choose black or white for readable text on a colored background.
    static func contrastForeground(for hex: String) -> Color {
        guard let (r, g, b) = hexToRGB(hex) else { return .black }
        let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        return luminance > 140 ? .black : .white
    }
}
