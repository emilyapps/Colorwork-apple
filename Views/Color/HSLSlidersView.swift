// HSLSlidersView.swift
// HSL sliders for a single ColorState.

import SwiftUI

struct HSLSlidersView: View {
    let colorState: ColorState
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            LabeledSliderView(
                label: "H",
                range: 0...360,
                step: 1,
                value: Binding(
                    get: { colorState.h },
                    set: { colorState.setHSL(h: $0, s: colorState.s, l: colorState.l) }))
            LabeledSliderView(
                label: "S",
                range: 0...100,
                step: 1,
                value: Binding(
                    get: { colorState.s },
                    set: { colorState.setHSL(h: colorState.h, s: $0, l: colorState.l) }))
            LabeledSliderView(
                label: "L",
                range: 0...100,
                step: 1,
                value: Binding(
                    get: { colorState.l },
                    set: { colorState.setHSL(h: colorState.h, s: colorState.s, l: $0) }))
        }
    }
}
