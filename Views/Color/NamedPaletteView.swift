// NamedPaletteView.swift
// LazyVGrid of CSS4 named color swatches.
// Tapping a swatch sets it as fill or bg color.

import SwiftUI

struct NamedPaletteView: View {
    @Environment(PatternDocument.self) var doc
    var target: ColorTarget = .fill

    enum ColorTarget { case fill, bg }

    @State private var hoveredHex: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Palette (\(target == .fill ? "Fill" : "Background"))")
                .font(.headline)
            // Fixed-height label so the grid doesn't shift on hover
            Text(hoveredHex ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(height: 14, alignment: .leading)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(CSS4Colors.sorted, id: \.hex) { entry in
                        swatchCell(name: entry.name, hex: entry.hex)
                    }
                }
            }
        }
    }

    private func swatchCell(name: String, hex: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(ColorMath.color(from: hex))
            .frame(height: 18)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.secondary.opacity(0.2), lineWidth: 0.5))
            .onTapGesture {
                switch target {
                case .fill: doc.fillColor.setHex(hex)
                case .bg:   doc.bgColor.setHex(hex)
                }
                doc.rebuildDescriptors()
            }
            #if os(macOS)
            .onHover { inside in hoveredHex = inside ? "\(name)  \(hex)" : nil }
            #endif
            .help(name)
    }
}
