// ControlPanelView.swift
// Symmetry, grid size, density, cell size controls.

import SwiftUI

struct ControlPanelView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        Form {
            Section("Pattern Kind") {
                Picker("Pattern Kind", selection: Binding(get: { doc.kind }, set: { doc.setKind($0) })) {
                    Text("Tile").tag(PatternKind.tile)
                    Text("Wedge").tag(PatternKind.wedge)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Symmetry") {
                HStack {
                    Text("Rotation")
                    Spacer()
                    Picker("Rotation", selection: rotationBinding) {
                        ForEach([1, 2, 4].filter { r in allowed.contains { $0.rotationFactor == r } }, id: \.self) {
                            Text("\($0)×").tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }
                if doc.symmetryGroup.rotationFactor == 1 {
                    HStack {
                        Text("Reflect")
                        Spacer()
                        Picker("Reflect", selection: axisBinding) {
                            Text("None").tag(SymmetryGroup.ReflectionAxis.none)
                            if allowed.contains(.d1) {
                                Text("V").tag(SymmetryGroup.ReflectionAxis.vertical)
                            }
                            if allowed.contains(.d1h) {
                                Text("H").tag(SymmetryGroup.ReflectionAxis.horizontal)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 140)
                    }
                } else {
                    Toggle("Reflect", isOn: reflectBinding)
                        .disabled(!allowed.contains(
                            .from(rotation: doc.symmetryGroup.rotationFactor, reflection: !doc.symmetryGroup.hasReflection)))
                }
                Text(doc.symmetryGroup.displayName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !doc.limitingStitches.isEmpty {
                    Text("Rotation and horizontal-axis reflection are unavailable: "
                         + doc.limitingStitches.map(\.displayName).joined(separator: ", ")
                         + (doc.limitingStitches.count == 1 ? " has" : " have")
                         + " no matching stitch under them yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Grid Size") {
                if doc.symmetryGroup.requiresSquare {
                    IntSliderView(label: "N", range: 2...25, value: Binding(
                        get: { doc.H },
                        set: { doc.H = $0; doc.W = $0 }))
                } else {
                    IntSliderView(label: "W", range: 2...25, value: $doc.W)
                    IntSliderView(label: "H", range: 2...50, value: $doc.H)
                }
            }

            Section("Fill Density") {
                LabeledSliderView(label: "ρ", range: 0.05...0.95, step: 0.01, value: $doc.density)
            }

            Section("Cell Size (px)") {
                LabeledSliderView(label: "px", range: 8...60, step: 1, value: $doc.cellSize)
                    .onChange(of: doc.cellSize) { _, _ in doc.rebuildDescriptors() }
            }

            Section {
                Toggle("Highlight Domain", isOn: $doc.showDomain)
                    .onChange(of: doc.showDomain) { _, _ in doc.rebuildDescriptors() }
            }
        }
        .formStyle(.grouped)
    }

    private var allowed: Set<SymmetryGroup> { doc.allowedSymmetryGroups }

    private var rotationBinding: Binding<Int> {
        Binding(
            get: { doc.symmetryGroup.rotationFactor },
            set: { doc.symmetryGroup = SymmetryGroup.from(rotation: $0, axis: doc.symmetryGroup.reflectionAxis) })
    }

    private var reflectBinding: Binding<Bool> {
        Binding(
            get: { doc.symmetryGroup.hasReflection },
            set: { doc.symmetryGroup = SymmetryGroup.from(rotation: doc.symmetryGroup.rotationFactor, reflection: $0) })
    }

    private var axisBinding: Binding<SymmetryGroup.ReflectionAxis> {
        Binding(
            get: { doc.symmetryGroup.reflectionAxis },
            set: { doc.symmetryGroup = SymmetryGroup.from(rotation: 1, axis: $0) })
    }
}
