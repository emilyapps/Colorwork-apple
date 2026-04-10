// CMYKSlidersView.swift
// CMYK sliders (0–100 each) for a single ColorState.
// Mirrors the C/M/Y/K section of pattern_generator.py:ColorPicker.

import SwiftUI

struct CMYKSlidersView: View {
    let colorState: ColorState
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            ForEach(channels, id: \.0) { ch, getter, setter in
                LabeledSliderView(
                    label: ch,
                    range: 0...100,
                    step: 1,
                    value: Binding(get: getter, set: setter))
            }
        }
    }

    private var channels: [(String, () -> Double, (Double) -> Void)] {
        [
            ("C", { colorState.c }, { v in colorState.setCMYK(c: v, m: colorState.m, y: colorState.y, k: colorState.k) }),
            ("M", { colorState.m }, { v in colorState.setCMYK(c: colorState.c, m: v, y: colorState.y, k: colorState.k) }),
            ("Y", { colorState.y }, { v in colorState.setCMYK(c: colorState.c, m: colorState.m, y: v, k: colorState.k) }),
            ("K", { colorState.k }, { v in colorState.setCMYK(c: colorState.c, m: colorState.m, y: colorState.y, k: v) }),
        ]
    }
}
