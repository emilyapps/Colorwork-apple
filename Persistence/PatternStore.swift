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
        context.insert(pattern)
        try context.save()
    }

    func loadPattern(_ pattern: SDPattern, into doc: PatternDocument) {
        guard let grid = try? decoder.decode([[Bool]].self, from: pattern.gridData) else { return }

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

    func saveProject(from doc: PatternDocument, name: String) throws {
        let snapshot = PatternSnapshot(from: doc)
        let data = try encoder.encode(snapshot)
        let project = SDProject(name: name, data: data)
        project.thumbnailData = Self.makeThumbnail(
            grid: doc.grid, H: doc.H, W: doc.W,
            fillHex: doc.fillColor.hex, bgHex: doc.bgColor.hex,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip,
            tiling: doc.tiling)
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
