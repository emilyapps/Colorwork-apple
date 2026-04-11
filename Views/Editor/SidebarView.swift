// SidebarView.swift
// 290px left sidebar with 4 tabs matching the Shiny layout:
// Pattern | Tiling | Colors | Library

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SidebarView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $selectedTab) {
                Text("Pattern").tag(0)
                Text("Tiling").tag(1)
                Text("Colors").tag(2)
                Text("Library").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: ControlPanelView()
                case 1: TilingSettingsView()
                case 2: ColorsSidebarView()
                case 3: SaveLoadSidebarView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 290)
    }
}

// MARK: - Colors tab (mirrors Shiny Colors tab)

struct ColorsSidebarView: View {
    @Environment(PatternDocument.self) var doc
    @State private var colorTab  = 1          // 0=Sliders, 1=Palette
    @State private var activeTarget = ColorTarget.fill

    enum ColorTarget { case fill, bg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // Fill / Bg target
                Picker("Editing", selection: $activeTarget) {
                    Text("Fill").tag(ColorTarget.fill)
                    Text("Background").tag(ColorTarget.bg)
                }
                .pickerStyle(.segmented)

                // Swatch + hex
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorMath.color(from: activeColor.hex))
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeColor.hex.uppercased())
                            .font(.system(size: 12, design: .monospaced))
                        hexField
                    }
                    Spacer()
                }

                Divider()

                // Sliders / Palette pill tabs
                Picker("", selection: $colorTab) {
                    Text("Sliders").tag(0)
                    Text("Palette").tag(1)
                }
                .pickerStyle(.segmented)

                if colorTab == 0 {
                    CMYKSlidersView(colorState: activeColor, label: "CMYK")
                    HSLSlidersView(colorState: activeColor, label: "HSL")
                } else {
                    NamedPaletteView(target: activeTarget == .fill ? .fill : .bg)
                        .frame(height: 240)
                }

                Divider()

                // Compare — always visible below pills (matches Shiny)
                ColorCompareView()

                Button("Reset to Defaults") {
                    doc.fillColor.setHex("#1a1a2e")
                    doc.bgColor.setHex("#f5f0e8")
                    doc.rebuildDescriptors()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
        }
        .onChange(of: activeColor.hex) { _, _ in doc.rebuildDescriptors() }
    }

    private var activeColor: ColorState {
        activeTarget == .fill ? doc.fillColor : doc.bgColor
    }

    private var hexField: some View {
        HStack(spacing: 2) {
            Text("#").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("rrggbb", text: Binding(
                get: { String(activeColor.hex.dropFirst()) },
                set: { v in
                    let candidate = "#" + v.trimmingCharacters(in: .whitespaces).lowercased()
                    if candidate.count == 7 {
                        activeColor.setHex(candidate)
                        doc.rebuildDescriptors()
                    }
                }))
            .font(.system(size: 12, design: .monospaced))
            .frame(width: 70)
        }
    }
}

// MARK: - Save/Load tab

struct SaveLoadSidebarView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.modelContext) var modelContext
    @State private var selectedTab = 0
    @State private var saveName    = ""
    @State private var statusMsg   = ""

    @State private var patternPendingDelete:  SDPattern? = nil
    @State private var projectPendingDelete:  SDProject? = nil
    @State private var lastLoadedPatternID:   UUID?      = nil
    @State private var lastLoadedProjectID:   UUID?      = nil

    @Query(sort: \SDPattern.createdAt, order: .reverse) var patterns: [SDPattern]
    @Query(sort: \SDProject.createdAt, order: .reverse) var projects: [SDProject]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Patterns").tag(0)
                Text("Projects").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            if selectedTab == 0 { patternTab } else { projectTab }
        }
    }

    // MARK: Pattern tab

    private var patternTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            List {
                ForEach(patterns) { p in
                    Button {
                        PatternStore(context: modelContext).loadPattern(p, into: doc)
                        lastLoadedPatternID = p.id
                        lastLoadedProjectID = nil
                        statusMsg = "Loaded \(p.name)"
                    } label: {
                        patternRowLabel(p)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            patternPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { idxs in
                    if let i = idxs.first { patternPendingDelete = patterns[i] }
                }
            }
            .frame(minHeight: 120, maxHeight: 200)
            .confirmationDialog(
                "Delete \"\(patternPendingDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { patternPendingDelete != nil },
                    set: { if !$0 { patternPendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let p = patternPendingDelete {
                        try? PatternStore(context: modelContext).deletePattern(p)
                    }
                    patternPendingDelete = nil
                }
            }

            Divider()

            VStack(spacing: 6) {
                TextField("Name…", text: $saveName)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 6) {
                    Button("Save") {
                        let name = saveName.isEmpty ? "Pattern" : saveName
                        try? PatternStore(context: modelContext).savePattern(from: doc, name: name)
                        statusMsg = "Saved \(name)"
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Export…") { export() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !statusMsg.isEmpty {
                    Text(statusMsg).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: Project tab

    private var projectTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            List {
                ForEach(projects) { p in
                    Button {
                        try? PatternStore(context: modelContext).loadProject(p, into: doc)
                        lastLoadedProjectID = p.id
                        lastLoadedPatternID = nil
                        statusMsg = "Loaded \(p.name)"
                    } label: {
                        projectRowLabel(p)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            projectPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { idxs in
                    if let i = idxs.first { projectPendingDelete = projects[i] }
                }
            }
            .frame(minHeight: 120, maxHeight: 200)
            .confirmationDialog(
                "Delete \"\(projectPendingDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { projectPendingDelete != nil },
                    set: { if !$0 { projectPendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let p = projectPendingDelete {
                        try? PatternStore(context: modelContext).deleteProject(p)
                    }
                    projectPendingDelete = nil
                }
            }

            Divider()

            VStack(spacing: 6) {
                TextField("Name…", text: $saveName)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 6) {
                    Button("Save") {
                        let name = saveName.isEmpty ? "Project" : saveName
                        try? PatternStore(context: modelContext).saveProject(from: doc, name: name)
                        statusMsg = "Saved \(name)"
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Export…") { export() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !statusMsg.isEmpty {
                    Text(statusMsg).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: Helpers

    private func patternRowLabel(_ p: SDPattern) -> some View {
        HStack(spacing: 8) {
            thumbView(p.thumbnailData, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 12, weight: .semibold))
                Text("\(p.gridW)×\(p.gridH) \(p.symmetryGroup.uppercased())")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if p.id == lastLoadedPatternID {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
    }

    private func projectRowLabel(_ p: SDProject) -> some View {
        HStack(spacing: 8) {
            thumbView(p.thumbnailData, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 12, weight: .semibold))
                Text(shortDate(p.createdAt)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if p.id == lastLoadedProjectID {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private func thumbView(_ data: Data?, size: CGFloat) -> some View {
        Group {
            if let d = data, let img = NSImage(data: d) {
                Image(nsImage: img).resizable().scaledToFit()
            } else { placeholderThumb }
        }
        .frame(width: size, height: size)
        .cornerRadius(4)
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .overlay(Image(systemName: "squareshape.split.3x3").foregroundStyle(.secondary))
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }

    private func export() {
        #if os(macOS)
        ExportPanel.show(doc: doc)
        #endif
    }
}
