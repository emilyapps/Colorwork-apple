// ColorCompareView.swift
// Gradient between fill and bg, WCAG contrast ratio, and 7 harmony swatches.
// Mirrors the ColorComparePanel section of pattern_generator.py.

import SwiftUI

struct ColorCompareView: View {
    @Environment(PatternDocument.self) var doc
    /// Which color is being edited; suggestions are for the *other* one.
    var editingFill: Bool = true
    /// How much contrast suggestions aim for: 3 (AA Large) up to 15. Remembered.
    @AppStorage("suggestionContrast") private var targetContrast = 4.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Gradient fill → bg
            Text("Blend from fill to background").font(.subheadline).foregroundStyle(.secondary)
            gradientStrip

            // Contrast ratio
            let ratio = ColorMath.contrastRatio(doc.fillColor.hex, doc.bgColor.hex)
            HStack {
                Text(String(format: "Contrast: %.1f:1", ratio))
                    .font(.subheadline)
                Spacer()
                Text(wcagLabel(ratio))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(wcagColor(ratio).opacity(0.2))
                    .cornerRadius(4)
            }

            // Editing the fill → suggest backgrounds to go with it, and vice versa.
            Text(editingFill ? "Backgrounds to go with this fill — tap to use"
                             : "Fills to go with this background — tap to use")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, 6)
            let base = editingFill ? doc.fillColor.hex : doc.bgColor.hex   // the colour being edited
            HStack(spacing: 8) {
                Text("Aim for").font(.subheadline)
                Text("3").font(.caption).foregroundStyle(.secondary)
                Slider(value: $targetContrast, in: 3...15, step: 0.5)
                    .accessibilityLabel("Suggestion contrast")
                    .accessibilityValue(String(format: "%.1f to 1", targetContrast))
                Text("15").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f:1", targetContrast))
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 44, alignment: .trailing)
            }
            let harmonies = ColorMath.harmonies(for: base, contrast: targetContrast)
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 6), count: 4),
                      alignment: .leading, spacing: 10) {
                ForEach(Array(harmonies.enumerated()), id: \.offset) { _, harmony in
                    suggestion(harmony, against: base)
                }
            }
        }
    }

    private func suggestion(_ harmony: ColorMath.Harmony, against other: String) -> some View {
        let ratio = ColorMath.contrastRatio(harmony.hex, other)
        return VStack(alignment: .leading, spacing: 3) {
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorMath.color(from: harmony.hex))
                .frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3), lineWidth: 0.5))
            Text(harmony.name).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
            Text(String(format: "%.1f:1", ratio)).font(.caption2).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            (editingFill ? doc.bgColor : doc.fillColor).setHex(harmony.hex)
            doc.rebuildDescriptors()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(harmony.name), contrast \(String(format: "%.1f", ratio)) to 1")
        .accessibilityHint(editingFill ? "Uses it as the background" : "Uses it as the fill")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Gradient strip (60 interpolated steps)

    private var gradientStrip: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard let (fr, fg, fb) = ColorMath.hexToRGB(doc.fillColor.hex),
                      let (br, bg_, bb) = ColorMath.hexToRGB(doc.bgColor.hex) else { return }
                let steps = 60
                let sw = size.width / CGFloat(steps)
                for i in 0 ..< steps {
                    let t = Double(i) / Double(steps - 1)
                    let r = Int((Double(fr) + t * Double(br - fr)).rounded())
                    let g = Int((Double(fg) + t * Double(bg_ - fg)).rounded())
                    let b = Int((Double(fb) + t * Double(bb - fb)).rounded())
                    let hex = String(format: "#%02x%02x%02x", r, g, b)
                    ctx.fill(Path(CGRect(x: CGFloat(i) * sw, y: 0, width: sw + 1, height: size.height)),
                             with: .color(ColorMath.color(from: hex)))
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func wcagLabel(_ ratio: Double) -> String {
        if ratio >= 7    { return "AAA" }
        if ratio >= 4.5  { return "AA" }
        if ratio >= 3    { return "AA Large" }
        return "Fail"
    }

    private func wcagColor(_ ratio: Double) -> Color {
        if ratio >= 4.5 { return .green }
        if ratio >= 3   { return .yellow }
        return .red
    }
}
