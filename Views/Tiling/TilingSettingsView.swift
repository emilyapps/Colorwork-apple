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
                    .disabled(!anyRepeat)
            }
            Section("Border Strip") {
                IntSliderView(label: "Width", range: 0...9, value: $doc.tiling.stripWidth)
                Group {
                    Toggle("Reflect across vertical axis", isOn: $doc.tiling.stripReflectsAcrossVerticalAxis)
                    Toggle("Reflect across horizontal axis", isOn: $doc.tiling.stripReflectsAcrossHorizontalAxis)
                }
                .disabled(doc.tiling.stripWidth == 0)
                // iOS dims only the switch of a disabled Toggle; fade the label to match the sliders.
                .opacity(doc.tiling.stripWidth == 0 || !anyRepeat ? 0.4 : 1)
            }
            .disabled(!anyRepeat)   // strips are only drawn alongside repeated copies
            Section("Brick Offset") {
                // An offset of a full chart width (or height) is the same as none.
                IntSliderView(label: "Row →", range: 0...max(1, doc.W - 1), value: $doc.tiling.rowOffset)
                IntSliderView(label: "Col ↓", range: 0...max(1, doc.H - 1), value: $doc.tiling.colOffset)
            }
            .disabled(!anyRepeat)
        }
        .formStyle(.grouped)
        .onChange(of: doc.tiling) { _, _ in doc.rebuildDescriptors() }
        .onChange(of: doc.W) { _, w in doc.tiling.rowOffset = min(doc.tiling.rowOffset, max(0, w - 1)) }
        .onChange(of: doc.H) { _, h in doc.tiling.colOffset = min(doc.tiling.colOffset, max(0, h - 1)) }
    }

    /// Copies, border strips and brick offset only mean something once copies are being made.
    private var anyRepeat: Bool { doc.tiling.hRepeat || doc.tiling.vRepeat }

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
            // Preview on top at a fixed share (like Photos' edit view); the settings get
            // the rest, so they stay reachable at the medium detent.
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Group {
                        if doc.kind == .wedge { WedgePreviewView() } else { TilingPreviewView() }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: previewHeight(in: geo.size))
                    Divider()
                    TilingSettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(doc.kind == .tile ? "Tiling"
                             : doc.wedgeView == .chart ? "Chart View" : "Circular View")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .cancelDoneToolbar()
        }
    }

    /// About 40% of the sheet, never taller than the sheet is wide; a Wedge keeps a little
    /// more room since its settings are one row.
    private func previewHeight(in size: CGSize) -> CGFloat {
        let share: CGFloat = doc.kind == .wedge ? 0.65 : 0.4
        return min(size.width, size.height * share)
    }
}
