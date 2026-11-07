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
                .font(Self.labelFont)
                .frame(minWidth: Self.labelWidth, alignment: .leading)
                .fixedSize()
            Text(formatMin)
                .font(Self.rangeFont)
                .foregroundStyle(.secondary)
                #if os(iOS)
                .frame(minWidth: 34, alignment: .trailing)
                #endif
            Slider(value: $value, in: range, step: step)
                #if os(macOS)
                .frame(maxWidth: 120)
                #endif
            Text(formatMax)
                .font(Self.rangeFont)
                .foregroundStyle(.secondary)
                #if os(iOS)
                .frame(minWidth: 34, alignment: .leading)
                #endif
            TextField(placeholder, text: $textInput)
                .font(Self.valueFont)
                #if os(iOS)
                .frame(width: 60)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                #else
                .frame(width: 42)
                #endif
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
                        #if os(iOS)
                        textInput = ""                    // typing replaces; the value shows as placeholder
                        #else
                        textInput = formatValue(value)   // show current value when entering field
                        #endif
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

    // iPhone sheets: body-size rows like the rest of the Form, slider fills the row.
    // Mac sidebar: compact.
    #if os(iOS)
    private static let labelFont: Font = .body
    private static let rangeFont: Font = .caption
    private static let valueFont: Font = .body.monospacedDigit()
    private static let labelWidth: CGFloat = 52
    #else
    private static let labelFont: Font = .caption2.weight(.semibold)
    private static let rangeFont: Font = .caption2
    private static let valueFont: Font = .caption2.monospaced()
    private static let labelWidth: CGFloat = 44
    #endif

    /// While the field is cleared for typing, the current value shows faintly.
    private var placeholder: String { focused ? formatValue(value) : "" }

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
