// WedgeChartView.swift
// A Wedge's previews: the Chart View (N repeats side by side, with stitch totals) and the
// Circular View (rings seen from above), with a switch between them.

import SwiftUI

/// Chart/Circular switch, Flip for the Circular View, and the chosen preview.
struct WedgePreviewView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        VStack(spacing: 6) {
            HStack {
                Picker("Wedge view", selection: $doc.wedgeView) {
                    Text("Chart").tag(WedgeView.chart)
                    Text("Circular").tag(WedgeView.circular)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
                if doc.wedgeView == .circular {
                    Button { doc.circularFlipped.toggle() } label: {
                        Label("Flip", systemImage: "arrow.up.arrow.down.circle")
                    }
                    .help("Swap which end of the chart is at the center")
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            if doc.wedgeView == .chart { WedgeChartView() } else { CircularView() }
        }
    }
}

/// The Circular View: each row a ring of its live stitches, No Stitch removed.
struct CircularView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        GeometryReader { geo in
            let side = max(0, min(geo.size.width, geo.size.height) - 24)
            let rings = RadialLayout.descriptors(
                grid: doc.grid, shaping: ShapingResolver.resolve(doc.stitches),
                repeats: doc.radialRepeat, flipped: doc.circularFlipped,
                size: CGSize(width: side, height: side),
                fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex)
            Canvas { ctx, _ in drawMerged(rings, in: ctx) }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Thousands of segments drawn one by one overwhelm the renderer, so segments are
    /// merged into one path per color and one outline path.
    private func drawMerged(_ descriptors: [RenderDescriptor], in ctx: GraphicsContext) {
        var fills: [String: Path] = [:]
        var outlines = Path()
        var outlineColor: String?
        var outlineWidth: CGFloat = 0.5
        for case .polygon(let p) in descriptors {
            var segment = Path()
            segment.addLines(p.points)
            segment.closeSubpath()
            fills[p.fill, default: Path()].addPath(segment)
            if let outline = p.outline {
                outlines.addPath(segment)
                outlineColor = outline
                outlineWidth = p.outlineWidth
            }
        }
        for (hex, path) in fills { ctx.fill(path, with: .color(ColorMath.color(from: hex))) }
        if let outlineColor {
            ctx.stroke(outlines, with: .color(ColorMath.color(from: outlineColor)), lineWidth: outlineWidth)
        }
    }
}

struct WedgeChartView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = 12
            let cs = cellSize(for: CGSize(width: geo.size.width - 2 * margin,
                                          height: geo.size.height - 2 * margin))
            let chart = DescriptorBuilder.wedgeChartDescriptors(
                grid: doc.grid, stitches: doc.stitches,
                shaping: ShapingResolver.resolve(doc.stitches),
                repeats: doc.radialRepeat, cellSize: cs,
                fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex)
            Canvas { ctx, _ in drawDescriptors(chart.descriptors, in: ctx) }
                .frame(width: chart.size.width, height: chart.size.height)
                .padding(margin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cellSize(for size: CGSize) -> CGFloat {
        let cols = CGFloat(max(1, doc.W * doc.radialRepeat))
        let rows = CGFloat(max(1, doc.H))
        let byW = (size.width - 2 - DescriptorBuilder.chartTotalsWidth) / cols
        let byH = (size.height - 2) / rows
        return max(1, min(byW, byH))
    }
}
