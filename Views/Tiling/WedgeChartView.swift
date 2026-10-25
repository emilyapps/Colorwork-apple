// WedgeChartView.swift
// A Wedge's Chart View: N repeats side by side, sized to fit, with stitch totals.

import SwiftUI

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
