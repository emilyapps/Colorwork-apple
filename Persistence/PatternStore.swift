// PatternStore.swift
// CRUD operations over SwiftData.  Mirrors the public API of db.py.

import Foundation
import SwiftData

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
        let gridData      = try encoder.encode(doc.grid)
        let colStripData  = try? encoder.encode(doc.colStrip)
        let rowStripData  = try? encoder.encode(doc.rowStrip)
        let cornerData    = try? encoder.encode(doc.corner)
        let tilingData    = try? encoder.encode(doc.tiling)

        let pattern = SDPattern(
            name:          name,
            gridW:         doc.W,
            gridH:         doc.H,
            symmetryGroup: doc.symmetryGroup.rawValue,
            fillColor:     doc.fillColor.hex,
            bgColor:       doc.bgColor.hex,
            fillDensity:   doc.density,
            gridData:      gridData,
            colStripData:  colStripData,
            rowStripData:  rowStripData,
            cornerData:    cornerData,
            tilingData:    tilingData)
        context.insert(pattern)
        try context.save()
    }

    func loadPattern(_ pattern: SDPattern, into doc: PatternDocument) {
        guard let grid = try? decoder.decode([[Bool]].self, from: pattern.gridData) else { return }
        let colStrip = (pattern.colStripData).flatMap { try? decoder.decode([[Bool]].self, from: $0) }
        let rowStrip = (pattern.rowStripData).flatMap { try? decoder.decode([[Bool]].self, from: $0) }
        let corner   = (pattern.cornerData  ).flatMap { try? decoder.decode([[Bool]].self, from: $0) }
        let tiling   = (pattern.tilingData  ).flatMap { try? decoder.decode(TilingSettings.self, from: $0) }

        doc.H             = pattern.gridH
        doc.W             = pattern.gridW
        doc.symmetryGroup = SymmetryGroup(rawValue: pattern.symmetryGroup) ?? .d4
        doc.grid          = grid
        doc.colStrip      = colStrip ?? PatternEngine.emptyStrip(rows: pattern.gridH, cols: tiling?.stripWidth ?? 1)
        doc.rowStrip      = rowStrip ?? PatternEngine.emptyStrip(rows: tiling?.stripWidth ?? 1, cols: pattern.gridW)
        doc.corner        = corner   ?? PatternEngine.emptyStrip(rows: tiling?.stripWidth ?? 1, cols: tiling?.stripWidth ?? 1)
        if let t = tiling { doc.tiling = t }
        doc.density       = pattern.fillDensity
        doc.fillColor.setHex(pattern.fillColor)
        doc.bgColor.setHex(pattern.bgColor)
        doc.currentPatternName = pattern.name

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

    func saveProject(from doc: PatternDocument, name: String) throws {
        let snapshot = PatternSnapshot(from: doc)
        let data = try encoder.encode(snapshot)
        let project = SDProject(name: name, data: data)
        context.insert(project)
        try context.save()
    }

    func loadProject(_ project: SDProject, into doc: PatternDocument) throws {
        let snapshot = try decoder.decode(PatternSnapshot.self, from: project.data)
        snapshot.apply(to: doc)
        doc.currentPatternName = project.name
    }

    func listProjects() throws -> [SDProject] {
        let descriptor = FetchDescriptor<SDProject>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func deleteProject(_ project: SDProject) throws {
        context.delete(project)
        try context.save()
    }
}
