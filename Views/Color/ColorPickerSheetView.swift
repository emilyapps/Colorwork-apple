// ColorPickerSheetView.swift
// Compact vertical color sheet for iOS.
// No NavigationStack or TabView chrome — keeps height small enough
// that the pattern remains visible above the sheet at .medium detent.

import SwiftUI

struct ColorPickerSheetView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab  = 0  // 0=Palette, 1=CMYK, 2=Compare
    @State private var activeTarget = ColorTarget.fill

    enum ColorTarget { case fill, bg }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("Colors").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Fill / Background picker
            Picker("Color", selection: $activeTarget) {
                Text("Fill").tag(ColorTarget.fill)
                Text("Background").tag(ColorTarget.bg)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Swatch + hex
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorMath.color(from: activeColor.hex))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeColor.hex.uppercased())
                        .font(.system(size: 13, design: .monospaced))
                    hexField
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Palette").tag(0)
                Text("CMYK").tag(1)
                Text("Compare").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            Group {
                switch selectedTab {
                case 1:
                    ScrollView {
                        CMYKSlidersView(colorState: activeColor, label: "CMYK")
                            .padding(.horizontal)
                    }
                case 2:
                    ScrollView {
                        ColorCompareView()
                            .padding(.horizontal)
                    }
                default:
                    NamedPaletteView(target: activeTarget == .fill ? .fill : .bg)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: activeColor.hex) { _, _ in doc.rebuildDescriptors() }
    }

    private var activeColor: ColorState {
        activeTarget == .fill ? doc.fillColor : doc.bgColor
    }

    private var hexField: some View {
        HStack(spacing: 4) {
            Text("#").foregroundStyle(.secondary)
            TextField("rrggbb", text: Binding(
                get: { String(activeColor.hex.dropFirst()) },
                set: { v in
                    let candidate = "#" + v.trimmingCharacters(in: .whitespaces).lowercased()
                    if candidate.count == 7 { activeColor.setHex(candidate); doc.rebuildDescriptors() }
                }))
            .font(.system(size: 13, design: .monospaced))
            .frame(width: 80)
        }
    }
}
