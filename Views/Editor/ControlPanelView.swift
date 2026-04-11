// ControlPanelView.swift
// Symmetry, grid size, density, cell size controls + Generate/Clear buttons.

import SwiftUI

struct ControlPanelView: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        @Bindable var doc = doc
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                symmetrySection
                Divider()
                gridSizeSection
                Divider()
                densitySection
                Divider()
                cellSizeSection
                Divider()
                domainToggle
            }
            .padding(12)
        }
    }

    // MARK: - Symmetry

    private var symmetrySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Symmetry").font(.headline)
            HStack {
                Text("Rotation").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Rotation", selection: rotationBinding) {
                    Text("1×").tag(1)
                    Text("2×").tag(2)
                    Text("4×").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }
            HStack {
                Text("Reflect").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: reflectBinding)
                    .labelsHidden()
                    .disabled(rotationBinding.wrappedValue == 4 ? false : false)
            }
            Text(doc.symmetryGroup.displayName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
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

    // MARK: - Grid size

    private var gridSizeSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 6) {
            Text("Grid Size").font(.headline)
            if doc.symmetryGroup.requiresSquare {
                IntSliderView(label: "N", range: 2...25, value: Binding(
                    get: { doc.H },
                    set: { doc.H = $0; doc.W = $0 }))
            } else {
                IntSliderView(label: "W", range: 2...25, value: $doc.W)
                IntSliderView(label: "H", range: 2...25, value: $doc.H)
            }
        }
    }

    // MARK: - Density

    private var densitySection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 4) {
            Text("Fill Density").font(.headline)
            LabeledSliderView(label: "ρ", range: 0.05...0.95, step: 0.01, value: $doc.density)
        }
    }

    // MARK: - Cell size

    private var cellSizeSection: some View {
        @Bindable var doc = doc
        return VStack(alignment: .leading, spacing: 4) {
            Text("Cell Size (px)").font(.headline)
            LabeledSliderView(label: "px", range: 8...60, step: 1, value: $doc.cellSize)
                .onChange(of: doc.cellSize) { _, _ in doc.rebuildDescriptors() }
        }
    }

    // MARK: - Domain highlight

    private var domainToggle: some View {
        @Bindable var doc = doc
        return Toggle("Highlight Domain", isOn: $doc.showDomain)
            .onChange(of: doc.showDomain) { _, _ in doc.rebuildDescriptors() }
    }

}
