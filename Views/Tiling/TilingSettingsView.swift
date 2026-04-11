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

    // MARK: - Repeat toggles

    private var repeatSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Repeat")
            Toggle("Horizontal", isOn: $doc.tiling.hRepeat)
                .font(.system(size: 14))
            if doc.tiling.hRepeat {
                symmetryRow(label: "H", binding: $doc.tiling.hType)
            }
            Toggle("Vertical", isOn: $doc.tiling.vRepeat)
                .font(.system(size: 14))
            if doc.tiling.vRepeat {
                symmetryRow(label: "V", binding: $doc.tiling.vType)
            }
            IntSliderView(label: "Copies", range: 2...5, value: $doc.tiling.nCopies)
        }
    }

    // MARK: - Strip width + symmetry

    private var stripSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Border Strip")
            IntSliderView(label: "Width", range: 0...9, value: $doc.tiling.stripWidth)
            Toggle("Reflect H", isOn: $doc.tiling.stripHReflect)
                .font(.system(size: 14))
            Toggle("Reflect V", isOn: $doc.tiling.stripVReflect)
                .font(.system(size: 14))
}
    }


    private func symmetryRow(label: String, binding: Binding<RepeatType>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Picker(label, selection: binding) {
                Text("Transl.").tag(RepeatType.translation)
                Text("Reflect.").tag(RepeatType.reflection)
                Text("180°").tag(RepeatType.rotation)
            }
            .pickerStyle(.segmented)
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
            .font(.system(size: 12, weight: .semibold))
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
