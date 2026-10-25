// TilingSettingsView.swift
// Tiling sidebar tab: repeat options, strip width, repeat types,
// brick offset, and preview cell size.

import SwiftUI

struct TilingSettingsView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        if doc.kind == .wedge { radialRepeatForm } else { tilingForm }
    }

    /// A Wedge repeats N times around a circle; border strips and planar repeats don't apply.
    private var radialRepeatForm: some View {
        @Bindable var doc = doc
        return Form {
            Section("Radial Repeat") {
                IntSliderView(label: "N", range: 1...60, value: $doc.radialRepeat)
            }
        }
        .formStyle(.grouped)
    }

    private var tilingForm: some View {
        @Bindable var doc = doc
        return Form {
            Section("Repeat") {
                Toggle("Horizontal", isOn: $doc.tiling.hRepeat)
                if doc.tiling.hRepeat {
                    repeatTypeRow(label: "Horizontal repeat type", binding: $doc.tiling.horizontalRepeatType,
                                  allowed: doc.allowedRepeatTypes(horizontal: true))
                }
                Toggle("Vertical", isOn: $doc.tiling.vRepeat)
                if doc.tiling.vRepeat {
                    repeatTypeRow(label: "Vertical repeat type", binding: $doc.tiling.verticalRepeatType,
                                  allowed: doc.allowedRepeatTypes(horizontal: false))
                }
                if !doc.limitingStitches.isEmpty {
                    Text("Some repeat types are unavailable: "
                         + doc.limitingStitches.map(\.displayName).joined(separator: ", ")
                         + (doc.limitingStitches.count == 1 ? " has" : " have")
                         + " no matching stitch under them yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                IntSliderView(label: "Copies", range: 2...5, value: $doc.tiling.nCopies)
            }
            Section("Border Strip") {
                IntSliderView(label: "Width", range: 0...9, value: $doc.tiling.stripWidth)
                Toggle("Reflect across vertical axis", isOn: $doc.tiling.stripReflectsAcrossVerticalAxis)
                Toggle("Reflect across horizontal axis", isOn: $doc.tiling.stripReflectsAcrossHorizontalAxis)
            }
            Section("Brick Offset") {
                IntSliderView(label: "Row →", range: 0...25, value: $doc.tiling.rowOffset)
                IntSliderView(label: "Col ↓", range: 0...25, value: $doc.tiling.colOffset)
            }
        }
        .formStyle(.grouped)
        .onChange(of: doc.tiling) { _, _ in doc.rebuildDescriptors() }
    }

    /// Side-by-side copies reflect across a vertical axis; stacked copies across a horizontal one.
    private func repeatTypeRow(label: String, binding: Binding<RepeatType>, allowed: [RepeatType]) -> some View {
        Picker(label, selection: binding) {
            ForEach(allowed, id: \.self) { type in
                switch type {
                case .translation: Text("Translate").tag(type)
                case .reflection:  Text("Reflect").tag(type)
                case .rotation:    Text("180°").tag(type)
                }
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - iOS sheet wrapper (not used on macOS)

struct TilingSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PatternDocument.self) var doc

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if doc.kind == .wedge { WedgePreviewView() } else { TilingPreviewView() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                TilingSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: doc.kind == .wedge ? 120 : 300)
            }
            .navigationTitle(doc.kind == .tile ? "Tiling"
                             : doc.wedgeView == .chart ? "Chart View" : "Circular View")
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
}
