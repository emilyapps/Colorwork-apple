// ColorPickerSheetView.swift
// Color controls panel: Fill/Bg toggle, swatch, hex field, and tab switcher.
// Embedded inside ColorSheetView which provides the NavigationStack and header.

import SwiftUI

struct ColorPickerSheetView: View {
    @Environment(PatternDocument.self) var doc

    @State private var selectedTab       = 0  // 0=Palette, 1=CMYK, 2=Compare
    @State private var activeTarget      = ColorTarget.fill
    @State private var colorsOnOpen: (fill: String, bg: String)? = nil

    enum ColorTarget { case fill, bg }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Fill and Background side by side, like Keynote's fill/stroke wells:
            // tap one to edit it; its hex can be typed directly.
            HStack(spacing: 12) {
                colorWell(.fill, label: "Fill")
                colorWell(.bg, label: "Background")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            Picker("Choose from", selection: $selectedTab) {
                Text("Palette").tag(0)
                Text("Custom").tag(1)
                Text("Compare").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case 1:
                    customPicker
                case 2:
                    ScrollView {
                        ColorCompareView(editingFill: activeTarget == .fill)
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
        .onAppear  { colorsOnOpen = (doc.fillColor.hex, doc.bgColor.hex) }
        .onDisappear {
            if let snap = colorsOnOpen,
               snap.fill != doc.fillColor.hex || snap.bg != doc.bgColor.hex {
                let old = snap
                doc.undoManager?.registerUndo(withTarget: doc) { d in
                    d.fillColor.setHex(old.fill)
                    d.bgColor.setHex(old.bg)
                    d.rebuildDescriptors()
                }
                doc.undoManager?.setActionName("Change Color")
            }
            colorsOnOpen = nil
        }
    }

    private var activeColor: ColorState {
        activeTarget == .fill ? doc.fillColor : doc.bgColor
    }

    private func state(_ t: ColorTarget) -> ColorState { t == .fill ? doc.fillColor : doc.bgColor }

    private func colorWell(_ t: ColorTarget, label: String) -> some View {
        let isActive = activeTarget == t
        return VStack(alignment: .leading, spacing: 6) {
            Button { activeTarget = t } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorMath.color(from: state(t).hex))
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: isActive ? 3 : 0)
                        .padding(-3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label) color")
            .accessibilityAddTraits(isActive ? .isSelected : [])
            HStack(spacing: 4) {
                Text(label).font(.subheadline.weight(isActive ? .semibold : .regular))
                Spacer(minLength: 4)
                hexField(t)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func hexField(_ t: ColorTarget) -> some View {
        HStack(spacing: 1) {
            Text("#").foregroundStyle(.secondary)
            TextField("rrggbb", text: Binding(
                get: { String(state(t).hex.dropFirst()).uppercased() },
                set: { v in
                    let candidate = "#" + v.trimmingCharacters(in: .whitespaces).lowercased()
                    if candidate.count == 7, ColorMath.hexToRGB(candidate) != nil {
                        state(t).setHex(candidate); doc.rebuildDescriptors()
                    }
                }))
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
            .autocorrectionDisabled()
            .frame(width: 66)
            .onTapGesture { activeTarget = t }
        }
        .font(.footnote.monospaced())
    }

    /// Apple's color picker (grid, spectrum, sliders, eyedropper, saved colors).
    private var customPicker: some View {
        VStack(spacing: 12) {
            ColorPicker(selection: Binding(
                get: { ColorMath.color(from: activeColor.hex) },
                set: { c in
                    activeColor.setHex(ColorMath.hex(from: c)); doc.rebuildDescriptors()
                }), supportsOpacity: false) {
                Text("Choose a custom \(activeTarget == .fill ? "fill" : "background") color")
            }
            Text("Grid, spectrum and sliders, plus an eyedropper for matching a yarn photo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - iOS sheet wrapper

struct ColorSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PatternDocument.self) var doc
    /// Colors when the sheet opened, so Cancel can put them back.
    @State private var onOpen: (fill: String, bg: String)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ColorPreviewView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                Divider()
                ColorPickerSheetView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Colors")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Cancel restores both colors; the inner view then sees no change
                // and registers no undo step. Done keeps them (one undo step).
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let o = onOpen {
                            doc.fillColor.setHex(o.fill)
                            doc.bgColor.setHex(o.bg)
                            doc.rebuildDescriptors()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { if onOpen == nil { onOpen = (doc.fillColor.hex, doc.bgColor.hex) } }
    }
}
