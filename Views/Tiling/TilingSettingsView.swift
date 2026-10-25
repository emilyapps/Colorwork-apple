// TilingSettingsView.swift
// Tiling sidebar tab: repeat options, strip width, repeat types,
// brick offset, and preview cell size.

import SwiftUI

struct TilingSettingsView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        Form {
            Section("Repeat") {
                Toggle("Horizontal", isOn: $doc.tiling.hRepeat)
                if doc.tiling.hRepeat {
                    repeatTypeRow(label: "Side by side", binding: $doc.tiling.horizontalRepeatType,
                                  allowed: doc.allowedRepeatTypes(horizontal: true))
                }
                Toggle("Vertical", isOn: $doc.tiling.vRepeat)
                if doc.tiling.vRepeat {
                    repeatTypeRow(label: "Stacked", binding: $doc.tiling.verticalRepeatType,
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
                case .rotation:    Text("Half-turn").tag(type)
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
                TilingPreviewView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                TilingSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: 300)
            }
            .navigationTitle("Tiling")
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
