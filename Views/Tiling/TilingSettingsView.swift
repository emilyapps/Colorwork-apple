// TilingSettingsView.swift
// Tiling sidebar tab: repeat options, strip width, repeat types,
// brick offset, and preview cell size.

import SwiftUI

struct TilingSettingsView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                repeatSection
                Divider()
                stripSection
                Divider()
                brickSection
            }
            .padding(10)
        }
        .onChange(of: doc.tiling) { _, _ in doc.rebuildDescriptors() }
    }

    // MARK: - Repeat toggles + type pickers

    private var repeatSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Repeat")
            Toggle("Horizontal", isOn: $doc.tiling.hRepeat)
            if doc.tiling.hRepeat {
                repeatTypePicker(label: "H Type", binding: $doc.tiling.hType)
            }
            Toggle("Vertical", isOn: $doc.tiling.vRepeat)
            if doc.tiling.vRepeat {
                repeatTypePicker(label: "V Type", binding: $doc.tiling.vType)
            }
        }
    }

    private func repeatTypePicker(label: String, binding: Binding<RepeatType>) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Picker(label, selection: binding) {
                Text("Transl.").tag(RepeatType.translation)
                Text("Reflect.").tag(RepeatType.reflection)
                Text("180°").tag(RepeatType.rotation)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
    }

    // MARK: - Strip width + copies

    private var stripSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Border Strip")
            IntSliderView(label: "Width", range: 0...9,  value: $doc.tiling.stripWidth)
            IntSliderView(label: "Copies", range: 2...5, value: $doc.tiling.nCopies)
        }
    }

    // MARK: - Brick offset

    private var brickSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Brick Offset")
            IntSliderView(label: "Row →", range: 0...25, value: $doc.tiling.rowOffset)
            IntSliderView(label: "Col ↓", range: 0...25, value: $doc.tiling.colOffset)
        }
    }

    // MARK: - Preview cell size

    private var previewSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Preview")
            LabeledSliderView(
                label: "px",
                range: 4...24,
                step: 1,
                value: Binding(
                    get: { doc.tiling.previewCellSize },
                    set: { doc.tiling.previewCellSize = $0; doc.scheduleTilingRebuild() }))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - iOS sheet wrapper (not used on macOS)

struct TilingSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PatternDocument.self) var doc

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                TilingSettingsView().frame(maxWidth: 300)
                Divider()
                TilingPreviewView().frame(maxWidth: .infinity)
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
