// LabeledSliderView.swift
// Reusable labeled slider with an inline text field.
// Mirrors pattern_generator.py:make_slider_entry.

import SwiftUI

struct LabeledSliderView: View {
    let label:      String
    let range:      ClosedRange<Double>
    let step:       Double
    @Binding var value: Double

    @State  private var textInput:  String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 44, alignment: .leading)
            Text(formatMin)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range, step: step)
                .frame(maxWidth: 120)
            Text(formatMax)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("", text: $textInput)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 42)
                #if os(iOS)
                // The number pad has no Return key, so use the numbers keyboard, whose
                // Return key reads "done" and commits the value.
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .autocorrectionDisabled()
                #endif
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit  { commit() }
                .onChange(of: focused) { _, isNowFocused in
                    if isNowFocused {
                        textInput = formatValue(value)   // show current value when entering field
                    } else {
                        commit()                          // parse + clamp when leaving field
                    }
                }
                .onChange(of: value) { _, v in
                    if !focused { textInput = formatValue(v) }  // keep in sync when slider moves
                }
                .onAppear { textInput = formatValue(value) }
        }
    }

    private func commit() {
        let parsed = step < 1 ? Double(textInput) : Double(textInput).map { Double(Int($0.rounded())) }
        if let d = parsed {
            value = min(range.upperBound, max(range.lowerBound, d))
        }
        textInput = formatValue(value)
    }

    private func formatValue(_ v: Double) -> String {
        step < 1 ? String(format: "%.2f", v) : "\(Int(v.rounded()))"
    }

    private var formatMin: String { step >= 1 ? "\(Int(range.lowerBound))" : String(format: "%.2f", range.lowerBound) }
    private var formatMax: String { step >= 1 ? "\(Int(range.upperBound))" : String(format: "%.2f", range.upperBound) }
}

// MARK: - Integer convenience

struct IntSliderView: View {
    let label:  String
    let range:  ClosedRange<Int>
    @Binding var value: Int

    var body: some View {
        LabeledSliderView(
            label: label,
            range: Double(range.lowerBound) ... Double(range.upperBound),
            step: 1,
            value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }))
    }
}
