// ControlPanelView.swift
// Symmetry, grid size, density, cell size controls.

import SwiftUI

struct ControlPanelView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        Form {
            Section("Pattern Class") {
                Picker("Class", selection: Binding(
                    get: { doc.patternClass },
                    set: { cls in
                        doc.patternClass = cls
                        if let cls { doc.symmetryGroup = cls.definition.symmetryGroup }
                    }
                )) {
                    Text("None").tag(PatternClass?.none)
                    ForEach(PatternClass.allCases, id: \.self) { cls in
                        Text(cls.definition.displayName).tag(PatternClass?.some(cls))
                    }
                }
                .pickerStyle(.menu)
            }

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
                if doc.symmetryGroup.rotationFactor == 1 {
                    HStack {
                        Text("Reflect")
                        Spacer()
                        Picker("Reflect", selection: axisBinding) {
                            Text("None").tag(SymmetryGroup.ReflectionAxis.none)
                            Text("V").tag(SymmetryGroup.ReflectionAxis.vertical)
                            Text("H").tag(SymmetryGroup.ReflectionAxis.horizontal)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 140)
                    }
                } else {
                    Toggle("Reflect", isOn: reflectBinding)
                }
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

            // MARK: - Debug: PathRasterizer tests
            Section("Debug: Rasterizer") {
                Button("Nordic Star") {
                    doc.symmetryGroup = .d4
                    doc.H = 18; doc.W = 18   // 13 matches reference pattern
                    doc.generateFromLayers([
                        RasterLayer(.nordicStar(armWidth: 0.308, size: 0.769))
                    ])
                }
                Button("Nordic Star + Checker Center") {
                    doc.symmetryGroup = .d4
                    doc.H = 25; doc.W = 25
                    doc.generateFromLayers([
                        RasterLayer(.nordicStar(armWidth: 0.308, size: 0.769)),
                        RasterLayer(.disk(centerX: 0.5, centerY: 0.5, radius: 0.35), fill: .checker)
                    ])
                }
                Button("Heart") {
                    doc.symmetryGroup = .d1
                    doc.H = 16; doc.W = 16
                    doc.generateFromLayers([
                        RasterLayer(.heart(centerX: 0.5, centerY: 0.5, scale: 0.7))
                    ])
                }
                Button("Heart + Dots") {
                    doc.symmetryGroup = .d1
                    doc.H = 20; doc.W = 20
                    doc.generateFromLayers([
                        RasterLayer(.heart(centerX: 0.5, centerY: 0.5, scale: 0.5)),
                        RasterLayer(.dots(centerX: 0.5, centerY: 0.5,
                                          count: 8, ringRadius: 0.75, dotRadius: 0.08))
                    ])
                }
                Button("Pinwheel") {
                    doc.symmetryGroup = .c4
                    doc.H = 16; doc.W = 16
                    doc.generateFromLayers([
                        RasterLayer(.pinwheelArm(armWidth: 0.3, size: 0.9))
                    ])
                }
            }
        }
        .formStyle(.grouped)
    }

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
