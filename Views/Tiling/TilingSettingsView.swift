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
                    symmetryRow(label: "H type", binding: $doc.tiling.hType)
                }
                Toggle("Vertical", isOn: $doc.tiling.vRepeat)
                if doc.tiling.vRepeat {
                    symmetryRow(label: "V type", binding: $doc.tiling.vType)
                }
                IntSliderView(label: "Copies", range: 2...5, value: $doc.tiling.nCopies)
            }
            Section("Border Strip") {
                IntSliderView(label: "Width", range: 0...9, value: $doc.tiling.stripWidth)
                Toggle("Reflect H", isOn: $doc.tiling.stripHReflect)
                Toggle("Reflect V", isOn: $doc.tiling.stripVReflect)
            }
            Section("Brick Offset") {
                IntSliderView(label: "Row →", range: 0...25, value: $doc.tiling.rowOffset)
                IntSliderView(label: "Col ↓", range: 0...25, value: $doc.tiling.colOffset)
            }
        }
        .formStyle(.grouped)
        .onChange(of: doc.tiling) { _, _ in doc.rebuildDescriptors() }
    }

    private func symmetryRow(label: String, binding: Binding<RepeatType>) -> some View {
        Picker(label, selection: binding) {
            Text("Transl.").tag(RepeatType.translation)
            Text("Reflect.").tag(RepeatType.reflection)
            Text("180°").tag(RepeatType.rotation)
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
