// ColorPickerSheetView.swift
// Tabbed color picker sheet combining CMYK, HSL, palette, and compare views.

import SwiftUI

struct ColorPickerSheetView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab = 0  // 0=CMYK, 1=HSL, 2=Palette, 3=Compare
    @State private var activeTarget = ColorTarget.fill

    enum ColorTarget { case fill, bg }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fill / BG selector
                Picker("Color", selection: $activeTarget) {
                    Text("Fill").tag(ColorTarget.fill)
                    Text("Background").tag(ColorTarget.bg)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                // Current color swatch + hex
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorMath.color(from: activeColor.hex))
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1))
                    VStack(alignment: .leading) {
                        Text(activeColor.hex.uppercased())
                            .font(.system(size: 14, design: .monospaced))
                        hexField
                    }
                    Spacer()
                }
                .padding()

                Divider()

                // Tabs
                TabView(selection: $selectedTab) {
                    CMYKSlidersView(colorState: activeColor, label: "")
                        .padding()
                        .tabItem { Label("CMYK", systemImage: "slider.horizontal.3") }
                        .tag(0)

                    HSLSlidersView(colorState: activeColor, label: "")
                        .padding()
                        .tabItem { Label("HSL", systemImage: "circle.hexagongrid") }
                        .tag(1)

                    NamedPaletteView(target: activeTarget == .fill ? .fill : .bg)
                        .padding()
                        .tabItem { Label("Palette", systemImage: "paintpalette") }
                        .tag(2)

                    ColorCompareView()
                        .padding()
                        .tabItem { Label("Compare", systemImage: "chart.bar") }
                        .tag(3)
                }
                .onChange(of: activeColor.hex) { _, _ in doc.rebuildDescriptors() }
            }
            .navigationTitle("Colors")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
