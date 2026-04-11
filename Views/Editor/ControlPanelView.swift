// ControlPanelView.swift
// Symmetry, grid size, density, cell size controls.

import SwiftUI

struct ControlPanelView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        Form {
            Section("Symmetry") {
                HStack {
                    Text("Rotation")
                    Spacer()
                    Picker("Rotation", selection: rotationBinding) {
                        Text("1×").tag(1)
                        Text("2×").tag(2)
                        Text("4×").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }
                Toggle("Reflect", isOn: reflectBinding)
                Text(doc.symmetryGroup.displayName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Section("Grid Size") {
                if doc.symmetryGroup.requiresSquare {
                    IntSliderView(label: "N", range: 2...25, value: Binding(
                        get: { doc.H },
                        set: { doc.H = $0; doc.W = $0 }))
                } else {
                    IntSliderView(label: "W", range: 2...25, value: $doc.W)
                    IntSliderView(label: "H", range: 2...25, value: $doc.H)
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

    private var rotationBinding: Binding<Int> {
        Binding(
            get: { doc.symmetryGroup.rotationFactor },
            set: { doc.symmetryGroup = SymmetryGroup.from(rotation: $0, reflection: doc.symmetryGroup.hasReflection) })
    }

    private var reflectBinding: Binding<Bool> {
        Binding(
            get: { doc.symmetryGroup.hasReflection },
            set: { doc.symmetryGroup = SymmetryGroup.from(rotation: doc.symmetryGroup.rotationFactor, reflection: $0) })
    }
}
