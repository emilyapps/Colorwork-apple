// LabeledSliderView.swift
// Reusable labeled slider with an inline text field.
// Mirrors pattern_generator.py:make_slider_entry.

import SwiftUI

struct LabeledSliderView: View {
    let label:      String
    let range:      ClosedRange<Double>
    let step:       Double
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, alignment: .leading)
            Text(formatMin)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range, step: step)
            Text(formatMax)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            TextField("", value: $value, formatter: formatter)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 42)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .onChange(of: value) { _, v in
                    value = min(range.upperBound, max(range.lowerBound, v))
                }
        }
    }

    private var formatMin: String { step >= 1 ? "\(Int(range.lowerBound))" : String(format: "%.2f", range.lowerBound) }
    private var formatMax: String { step >= 1 ? "\(Int(range.upperBound))" : String(format: "%.2f", range.upperBound) }

    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.minimumFractionDigits = step < 1 ? 2 : 0
        f.maximumFractionDigits = step < 1 ? 2 : 0
        return f
    }
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
