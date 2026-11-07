// PatternStore.swift
// CRUD operations over SwiftData.  Mirrors the public API of db.py.

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PatternStore {

    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Patterns

    func savePattern(from doc: PatternDocument, name: String) throws {
        let gridData = try encoder.encode(doc.grid)
        // Patterns store tile-only — no strips or tiling settings
        let thumb = Self.makeThumbnail(
            grid: doc.grid, H: doc.H, W: doc.W,
            fillHex: doc.fillColor.hex, bgHex: doc.bgColor.hex)

        let pattern = SDPattern(
            name:          name,
            gridW:         doc.W,
            gridH:         doc.H,
            symmetryGroup: doc.symmetryGroup.rawValue,
            fillColor:     doc.fillColor.hex,
            bgColor:       doc.bgColor.hex,
            fillDensity:   doc.density,
            gridData:      gridData,
            colStripData:  nil,
            rowStripData:  nil,
            cornerData:    nil,
            tilingData:    nil)
        pattern.thumbnailData = thumb
        pattern.stitchData    = try encoder.encode(doc.stitches)
        pattern.kind          = doc.kind.rawValue
        context.insert(pattern)
        try context.save()
    }

    func loadPattern(_ pattern: SDPattern, into doc: PatternDocument) {
        guard let grid = try? decoder.decode([[Bool]].self, from: pattern.gridData) else { return }
        // Patterns carry their Kind but not N, so the current Radial Repeat is kept.
        doc.kind          = pattern.kind.flatMap(PatternKind.init(rawValue:)) ?? .tile

        doc.H             = pattern.gridH
        doc.W             = pattern.gridW
        doc.symmetryGroup = SymmetryGroup(rawValue: pattern.symmetryGroup) ?? .d4
        doc.grid          = grid
        doc.stitches      = pattern.stitchData.flatMap { try? decoder.decode([[Stitch]].self, from: $0) }
            ?? Stitch.allKnit(rows: pattern.gridH, cols: pattern.gridW)
        doc.density       = pattern.fillDensity
        doc.fillColor.setHex(pattern.fillColor)
        doc.bgColor.setHex(pattern.bgColor)
        doc.currentPatternName = pattern.name
        // Patterns are tile-only — reset strips to empty, preserve current tiling settings
        let sw = doc.tiling.stripWidth
        doc.colStrip = PatternEngine.emptyStrip(rows: pattern.gridH, cols: sw)
        doc.rowStrip = PatternEngine.emptyStrip(rows: sw, cols: pattern.gridW)
        doc.corner   = PatternEngine.emptyStrip(rows: sw, cols: sw)

        doc.regenerateDomain()
        doc.rebuildDescriptors()
    }

    func listPatterns() throws -> [SDPattern] {
        let descriptor = FetchDescriptor<SDPattern>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func deletePattern(_ pattern: SDPattern) throws {
        context.delete(pattern)
        try context.save()
    }

    // MARK: - Projects

    @discardableResult
    func saveProject(from doc: PatternDocument, name: String) throws -> SDProject {
        let project = SDProject(name: name, data: Data())
        try write(doc, into: project)
        context.insert(project)
        try context.save()
        return project
    }

    /// Writes the document into an existing Project. Returns false when nothing changed.
    @discardableResult
    func updateProject(_ project: SDProject, from doc: PatternDocument) throws -> Bool {
        let data = try encoder.encode(PatternSnapshot(from: doc))
        guard data != project.data || project.name != doc.currentPatternName else { return false }
        try write(doc, into: project, data: data)
        try context.save()
        return true
    }

    private func write(_ doc: PatternDocument, into project: SDProject, data: Data? = nil) throws {
        project.data = try data ?? encoder.encode(PatternSnapshot(from: doc))
        project.name = doc.currentPatternName
        project.modifiedAt = Date()
        project.thumbnailData = Self.makeThumbnail(
            grid: doc.grid, H: doc.H, W: doc.W,
            fillHex: doc.fillColor.hex, bgHex: doc.bgColor.hex,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip,
            tiling: doc.kind == .tile ? doc.tiling : TilingSettings())
    }

    func project(id: UUID) -> SDProject? {
        try? context.fetch(FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == id })).first
    }

    func pattern(named name: String) -> SDPattern? {
        try? context.fetch(FetchDescriptor<SDPattern>(predicate: #Predicate { $0.name == name })).first
    }

    /// "Untitled", then "Untitled 2", "Untitled 3", … skipping names already used by Projects.
    func uniqueProjectName(_ base: String = "Untitled") -> String {
        let used = Set((try? listProjects())?.map(\.name) ?? [])
        if !used.contains(base) { return base }
        var n = 2
        while used.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    func loadProject(_ project: SDProject, into doc: PatternDocument) throws {
        let snapshot = try decoder.decode(PatternSnapshot.self, from: project.data)
        snapshot.apply(to: doc)
        doc.currentPatternName = project.name
    }

    func listProjects() throws -> [SDProject] {
        let descriptor = FetchDescriptor<SDProject>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func deleteProject(_ project: SDProject) throws {
        context.delete(project)
        try context.save()
    }

    // MARK: - Thumbnail

    private static func makeThumbnail(
        grid: [[Bool]], H: Int, W: Int,
        fillHex: String, bgHex: String,
        colStrip: [[Bool]] = [], rowStrip: [[Bool]] = [],
        tiling: TilingSettings = TilingSettings()
    ) -> Data? {
        let cs: CGFloat = 4
        let sw = tiling.stripWidth
        let hOn = tiling.hRepeat && sw > 0
        let vOn = tiling.vRepeat && sw > 0
        let pw = (CGFloat(W) + (hOn ? CGFloat(sw) : 0)) * cs
        let ph = (CGFloat(H) + (vOn ? CGFloat(sw) : 0)) * cs
        let descriptors = DescriptorBuilder.tileDescriptors(
            grid: grid, H: H, W: W, cellSize: cs,
            fillColor: fillHex, bgColor: bgHex,
            domainCells: [], showDomain: false,
            colStrip: colStrip, rowStrip: rowStrip, corner: [],
            hOn: hOn, vOn: vOn, stripWidth: sw)
        let view = Canvas { ctx, _ in
            for d in descriptors {
                if case .rect(let r) = d {
                    ctx.fill(Path(CGRect(
                        x: r.x - Layout.padding, y: r.y - Layout.padding,
                        width: r.w, height: r.h)),
                        with: .color(ColorMath.color(from: r.fill)))
                }
            }
        }
        .frame(width: pw, height: ph)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if os(macOS)
        return renderer.nsImage.flatMap {
            $0.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
            }
        }
        #else
        return renderer.uiImage.flatMap { $0.pngData() }
        #endif
    }
}

// MARK: - Project session (autosave model)
// The open Project is the working document and autosaves; opening a Pattern starts
// a new Project from it; a Pattern changes only through Save as Pattern.
// A new Project is not saved until it is changed, so unedited starts leave no clutter.

extension PatternStore {

    /// What counts as a change: the chart and its settings, not view-only state like zoom.
    func contentSignature(_ doc: PatternDocument) -> Data? {
        var snap = PatternSnapshot(from: doc)
        snap.cellSize = 0
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return try? e.encode(snap)
    }

    /// Saves the open Project if it changed. A pending (never-saved) Project is created
    /// the first time it differs from how it started.
    func autosave(_ doc: PatternDocument) {
        if let id = doc.currentProjectID {
            guard let project = project(id: id) else { return }
            try? updateProject(project, from: doc)
        } else if let base = doc.pendingBaseline,
                  contentSignature(doc) != base || doc.currentPatternName != doc.pendingName {
            doc.currentProjectID = (try? saveProject(from: doc, name: doc.currentPatternName))?.id
            doc.pendingBaseline = nil
        }
    }

    /// Marks the document as a new, unsaved Project.
    private func beginPending(_ doc: PatternDocument) {
        doc.currentProjectID = nil
        doc.currentPatternName = uniqueProjectName()
        doc.pendingName = doc.currentPatternName
        doc.pendingBaseline = contentSignature(doc)
        doc.resetUndo()
    }

    /// At launch: a fresh random chart, saved only once it is changed.
    func openInitialProject(into doc: PatternDocument) {
        // Older Projects have no edit date; use when they were made so sorting works.
        if let undated = try? context.fetch(FetchDescriptor<SDProject>(
            predicate: #Predicate { $0.modifiedAt == nil })), !undated.isEmpty {
            for p in undated { p.modifiedAt = p.createdAt }
            try? context.save()
        }
        beginPending(doc)
    }

    func openProject(_ project: SDProject, into doc: PatternDocument) {
        autosave(doc)
        try? loadProject(project, into: doc)
        doc.currentProjectID = project.id
        doc.pendingBaseline = nil
        doc.resetUndo()
    }

    /// Opening a Pattern starts a new Untitled Project from it; the Pattern is not changed.
    func startProject(from pattern: SDPattern, into doc: PatternDocument) {
        autosave(doc)
        loadPattern(pattern, into: doc)
        beginPending(doc)
    }

    /// New Project starts from a blank grid.
    func newProject(into doc: PatternDocument) {
        autosave(doc)
        PatternSnapshot(from: PatternDocument()).apply(to: doc)
        doc.clear()
        beginPending(doc)
    }

    /// Copies the open Project and switches to the copy.
    func duplicateProject(_ doc: PatternDocument) {
        autosave(doc)
        doc.currentPatternName = uniqueProjectName(doc.currentPatternName + " copy")
        doc.currentProjectID = (try? saveProject(from: doc, name: doc.currentPatternName))?.id
        doc.pendingBaseline = nil
        doc.resetUndo()
    }

    func duplicate(_ project: SDProject) {
        let copy = SDProject(name: uniqueProjectName(project.name + " copy"), data: project.data)
        copy.thumbnailData = project.thumbnailData
        copy.modifiedAt = Date()
        context.insert(copy)
        try? context.save()
    }

    func rename(_ doc: PatternDocument, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        doc.currentPatternName = trimmed
        autosave(doc)
    }

    func deleteProjects(_ projects: [SDProject]) {
        for p in projects { context.delete(p) }
        try? context.save()
    }

    /// Save as Pattern; replaces an existing Pattern of the same name, keeping its place in the list.
    func saveAsPattern(_ doc: PatternDocument, name: String) {
        let old = pattern(named: name)
        let order = old?.sortOrder
        if let old { context.delete(old) }
        try? savePattern(from: doc, name: name)
        if let order, let new = pattern(named: name) { new.sortOrder = order; try? context.save() }
    }
}
