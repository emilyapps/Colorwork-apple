// ColorCompareView.swift
// Gradient between fill and bg, WCAG contrast ratio, and 7 harmony swatches.
// Mirrors the ColorComparePanel section of pattern_generator.py.

import SwiftUI

struct ColorCompareView: View {
    @Environment(PatternDocument.self) var doc
    /// Which color is being edited; suggestions are for the *other* one.
    var editingFill: Bool = true

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

            // Harmony swatches (applied to bg color)
            // Editing the fill → suggest backgrounds to go with it, and vice versa.
            Text(editingFill ? "Backgrounds to go with this fill — tap to use"
                             : "Fills to go with this background — tap to use")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, 6)
            let harmonies = ColorMath.harmonyColors(fill: editingFill ? doc.fillColor.hex : doc.bgColor.hex)
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(harmonies.enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorMath.color(from: hex))
                        .frame(height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                        .onTapGesture {
                            (editingFill ? doc.bgColor : doc.fillColor).setHex(hex)
                            doc.rebuildDescriptors()
                        }
                        .accessibilityLabel(editingFill ? "Use as background" : "Use as fill")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
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
