// NamedPaletteView.swift
// The matplotlib / CSS4 named colors in their original order. The current color is
// ringed and its name shown above the grid. Tapping a swatch sets the fill or bg color.

import SwiftUI

struct NamedPaletteView: View {
    @Environment(PatternDocument.self) var doc
    var target: ColorTarget = .fill

    enum ColorTarget { case fill, bg }

    @State private var hoveredHex: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name of the current (or, on the Mac, hovered) color; fixed height so nothing shifts.
            Text(caption)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(CSS4Colors.sorted, id: \.hex) { swatchCell($0) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var currentHex: String {
        (target == .fill ? doc.fillColor.hex : doc.bgColor.hex).lowercased()
    }

    private var caption: String {
        if let h = hoveredHex { return h }
        let hex = currentHex
        if let entry = CSS4Colors.sorted.first(where: { $0.hex.lowercased() == hex }) {
            return "\(entry.name)  \(hex.uppercased())"
        }
        return "Custom  \(hex.uppercased())"
    }

    private func swatchCell(_ entry: CSS4ColorEntry) -> some View {
        let selected = entry.hex.lowercased() == currentHex
        return RoundedRectangle(cornerRadius: 3)
            .fill(ColorMath.color(from: entry.hex))
            .frame(height: 22)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.secondary.opacity(0.2), lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: selected ? 2.5 : 0)
                .padding(-2))
            .contentShape(Rectangle())
            .onTapGesture {
                switch target {
                case .fill: doc.fillColor.setHex(entry.hex)
                case .bg:   doc.bgColor.setHex(entry.hex)
                }
                doc.rebuildDescriptors()
            }
            #if os(macOS)
            .onHover { inside in hoveredHex = inside ? "\(entry.name)  \(entry.hex.uppercased())" : nil }
            #endif
            .help(entry.name)
            .accessibilityElement()
            .accessibilityLabel(entry.name)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
