// ColorState.swift
// @Observable view-model for a single color (fill or bg).
// Maintains CMYK, HSL, and hex in sync.
// Mirrors the Python ColorPicker._updating flag pattern (pattern_generator.py:121).

import Foundation
import Observation

@Observable
final class ColorState {

    // MARK: Source of truth
    private(set) var hex: String

    // MARK: CMYK (0–100)
    var c: Double = 0
    var m: Double = 0
    var y: Double = 0
    var k: Double = 100

    // MARK: HSL  (h: 0–360, s/l: 0–100)
    var h: Double = 0
    var s: Double = 0
    var l: Double = 0

    // MARK: Re-entrancy guard (mirrors Python _updating flag)
    private var updateDepth = 0

    init(hex: String = "#1a1a2e") {
        self.hex = hex
        syncFromHex(hex)
    }

    // MARK: - External setters

    func setHex(_ newHex: String) {
        guard updateDepth == 0 else { return }
        guard newHex.count == 7, newHex.hasPrefix("#") else { return }
        guard ColorMath.hexToRGB(newHex) != nil else { return }
        updateDepth += 1
        defer { updateDepth -= 1 }
        hex = newHex
        syncCMYKFromHex()
        syncHSLFromHex()
    }

    func setCMYK(c: Double, m: Double, y: Double, k: Double) {
        guard updateDepth == 0 else { return }
        updateDepth += 1
        defer { updateDepth -= 1 }
        self.c = c; self.m = m; self.y = y; self.k = k
        hex = ColorMath.cmykToHex(c: c, m: m, y: y, k: k)
        syncHSLFromHex()
    }

    func setHSL(h: Double, s: Double, l: Double) {
        guard updateDepth == 0 else { return }
        updateDepth += 1
        defer { updateDepth -= 1 }
        self.h = h; self.s = s; self.l = l
        hex = ColorMath.hslToHex(h: h, s: s / 100, l: l / 100)
        syncCMYKFromHex()
    }

    // MARK: - Private sync helpers

    private func syncFromHex(_ hexStr: String) {
        syncCMYKFromHex(hexStr)
        syncHSLFromHex(hexStr)
    }

    private func syncCMYKFromHex(_ hexStr: String? = nil) {
        let src = hexStr ?? hex
        if let (c, m, y, k) = ColorMath.hexToCMYK(src) {
            self.c = c; self.m = m; self.y = y; self.k = k
        }
    }

    private func syncHSLFromHex(_ hexStr: String? = nil) {
        let src = hexStr ?? hex
        if let (r, g, b) = ColorMath.hexToRGB(src) {
            let (hv, sv, lv) = ColorMath.rgbToHSL(r: r, g: g, b: b)
            h = hv
            s = (sv * 100).rounded()
            l = (lv * 100).rounded()
        }
    }
}
