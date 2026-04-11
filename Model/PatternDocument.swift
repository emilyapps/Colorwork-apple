// PatternDocument.swift
// Central @Observable document model.  All mutable state lives here.
// Properties mirror the PatternApp tk.IntVar / tk.BooleanVar fields
// from pattern_generator.py.

import Foundation
import Observation
import CoreGraphics

@Observable
final class PatternDocument {

    // MARK: - Grid state
    var grid:   [[Bool]] = []
    var H: Int = 8 { didSet { if !isMutatingInternally && oldValue != H { pushUndo("Resize Grid") } } }
    var W: Int = 8 { didSet { if !isMutatingInternally && oldValue != W { pushUndo("Resize Grid") } } }

    var symmetryGroup: SymmetryGroup = .d4 {
        didSet {
            pushUndo("Change Symmetry")
            if symmetryGroup.requiresSquare {
                isMutatingInternally = true
                W = H
                isMutatingInternally = false
            }
            regenerateDomain()
        }
    }

    private var isMutatingInternally = false

    private(set) var domainCells:    [CellIndex] = []
    private(set) var domainSet:      Set<CellIndex> = []
    private(set) var cellToCanonical: [CellIndex: CellIndex] = [:]

    // MARK: - Strip state
    var colStrip: [[Bool]] = []
    var rowStrip: [[Bool]] = []
    var corner:   [[Bool]] = []

    // MARK: - Editor settings
    var cellSize:   Double = 40
    var density:    Double = 0.5
    var showDomain: Bool   = false

    // MARK: - Colors
    var fillColor = ColorState(hex: "#1a1a2e")
    var bgColor   = ColorState(hex: "#f5f0e8")

    // MARK: - Tiling
    var tiling = TilingSettings() {
        didSet {
            if oldValue.stripWidth != tiling.stripWidth { resetStrips() }
        }
    }

    // MARK: - Persistence metadata
    var currentPatternName: String = "Untitled"
    var isDirty:            Bool   = false

    // MARK: - Undo
    var undoManager: UndoManager?
    private(set) var canUndo: Bool = false

    func pushUndo(_ name: String) {
        let snapshot = PatternSnapshot(from: self)
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.pushUndo(name)
            snapshot.apply(to: doc)
            doc.canUndo = doc.undoManager?.canUndo ?? false
        }
        undoManager?.setActionName(name)
        canUndo = undoManager?.canUndo ?? false
    }

    // MARK: - Cached descriptors (invalidated when state changes)
    private(set) var tileDescriptors:   [RenderDescriptor] = []
    private(set) var tileCanvasSize:    CGSize = .zero

    // Runtime only — set by GridCanvasView, not persisted
    var canvasAvailableSize: CGSize = .zero

    func fitCellSize() {
        guard canvasAvailableSize.width > 0, canvasAvailableSize.height > 0 else { return }
        let fitW = (canvasAvailableSize.width  - 2 * Layout.padding - Layout.numW) / CGFloat(W)
        let fitH = (canvasAvailableSize.height - 2 * Layout.padding - Layout.numH) / CGFloat(H)
        let newSize = max(8, min(60, floor(min(fitW, fitH))))
        cellSize = Double(newSize)
        rebuildDescriptors()
    }

    // Tiling grid is computed on a background task
    private(set) var tilingGrid:        [[Bool]] = []
    private(set) var tilingDescriptors: [RenderDescriptor] = []
    private(set) var tilingRows:        Int = 0
    private(set) var tilingCols:        Int = 0
    private(set) var isComputingTiling: Bool = false

    // MARK: - Init

    init() {
        generate()
    }

    // MARK: - Actions

    func generate() {
        pushUndo("Generate")
        if symmetryGroup.requiresSquare {
            isMutatingInternally = true
            W = H
            isMutatingInternally = false
        }
        let result = PatternEngine.generatePattern(H: H, W: W, group: symmetryGroup, density: density)
        grid             = result.grid
        domainCells      = result.domain
        domainSet        = Set(result.domain)
        cellToCanonical  = result.canonical
        resetStrips()
        rebuildTileDescriptors()
        scheduleTilingRebuild()
        isDirty = true
    }

    func clear() {
        pushUndo("Clear")
        grid = PatternEngine.clearGrid(H: H, W: W)
        resetStrips()
        rebuildTileDescriptors()
        scheduleTilingRebuild()
        isDirty = true
    }

    func toggleCell(_ cell: CellIndex, region: CellRegion) {
        switch region {
        case .tile:
            PatternEngine.toggleCell(cell, in: &grid,
                                     canonical: cellToCanonical,
                                     group: symmetryGroup, H: H, W: W)
        case .colStrip:
            PatternEngine.toggleStripCell(row: cell.row, col: cell.col, in: &colStrip)
            PatternEngine.applyStripReflect(row: cell.row, col: cell.col, in: &colStrip,
                                            hReflect: tiling.stripHReflect, vReflect: tiling.stripVReflect)
        case .rowStrip:
            PatternEngine.toggleStripCell(row: cell.row, col: cell.col, in: &rowStrip)
            PatternEngine.applyStripReflect(row: cell.row, col: cell.col, in: &rowStrip,
                                            hReflect: tiling.stripHReflect, vReflect: tiling.stripVReflect)
        case .corner:
            PatternEngine.toggleStripCell(row: cell.row, col: cell.col, in: &corner)
            PatternEngine.applyStripReflect(row: cell.row, col: cell.col, in: &corner,
                                            hReflect: tiling.stripHReflect, vReflect: tiling.stripVReflect)
        }
        rebuildTileDescriptors()
        scheduleTilingRebuild()
        isDirty = true
    }

    // Called when colors, cell size, domain highlight, or tiling settings change
    func rebuildDescriptors() {
        rebuildTileDescriptors()
        scheduleTilingRebuild()
    }

    // MARK: - Private helpers

    func regenerateDomain() {
        let result = PatternEngine.computeDomain(H: H, W: W, group: symmetryGroup)
        domainCells     = result.domain
        domainSet       = Set(result.domain)
        cellToCanonical = result.canonical
    }

    private func resetStrips() {
        let sw = max(0, tiling.stripWidth)
        colStrip = PatternEngine.emptyStrip(rows: H, cols: sw)
        rowStrip = PatternEngine.emptyStrip(rows: sw, cols: W)
        corner   = PatternEngine.emptyStrip(rows: sw, cols: sw)
    }

    private func rebuildTileDescriptors() {
        let cs = CGFloat(cellSize)
        tileCanvasSize = DescriptorBuilder.tileCanvasSize(
            H: H, W: W, cellSize: cs,
            hOn: tiling.hRepeat, vOn: tiling.vRepeat,
            stripWidth: tiling.stripWidth)
        tileDescriptors = DescriptorBuilder.tileDescriptors(
            grid: grid, H: H, W: W, cellSize: cs,
            fillColor: fillColor.hex, bgColor: bgColor.hex,
            domainCells: domainSet, showDomain: showDomain,
            colStrip: colStrip, rowStrip: rowStrip, corner: corner,
            hOn: tiling.hRepeat, vOn: tiling.vRepeat,
            stripWidth: tiling.stripWidth)
    }

    private var tilingTask: Task<Void, Never>?

    func scheduleTilingRebuild() {
        tilingTask?.cancel()
        let snap = TilingSnapshot(from: self)
        isComputingTiling = true
        tilingTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let tg = TilingEngine.buildTilingGrid(
                tile: snap.grid, H: snap.H, W: snap.W,
                colStrip: snap.colStrip, rowStrip: snap.rowStrip, corner: snap.corner,
                hRepeat: snap.tiling.hRepeat, vRepeat: snap.tiling.vRepeat,
                stripWidth: snap.tiling.stripWidth,
                hType: snap.tiling.hType, vType: snap.tiling.vType,
                nH: snap.tiling.nCopies, nV: snap.tiling.nCopies,
                rowOffset: snap.tiling.rowOffset, colOffset: snap.tiling.colOffset)
            guard !Task.isCancelled else { return }
            let cs = CGFloat(snap.tiling.previewCellSize)
            let (descs, rows, cols) = DescriptorBuilder.tilingDescriptors(
                tilingGrid: tg,
                fillColor: snap.fillHex, bgColor: snap.bgHex,
                hRepeat: snap.tiling.hRepeat, vRepeat: snap.tiling.vRepeat,
                stripWidth: snap.tiling.stripWidth,
                hType: snap.tiling.hType, vType: snap.tiling.vType,
                nCopies: snap.tiling.nCopies,
                W: snap.W, H: snap.H,
                rowOffset: snap.tiling.rowOffset, colOffset: snap.tiling.colOffset,
                cellSize: cs)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.tilingGrid        = tg
                self?.tilingDescriptors = descs
                self?.tilingRows        = rows
                self?.tilingCols        = cols
                self?.isComputingTiling = false
            }
        }
    }
}

// MARK: - Snapshot for off-main-thread tiling computation

private struct TilingSnapshot {
    let grid: [[Bool]]
    let H, W: Int
    let colStrip, rowStrip, corner: [[Bool]]
    let tiling: TilingSettings
    let fillHex, bgHex: String

    init(from doc: PatternDocument) {
        grid     = doc.grid
        H        = min(doc.H, doc.grid.count)
        W        = min(doc.W, doc.grid.first?.count ?? 0)
        colStrip = doc.colStrip
        rowStrip = doc.rowStrip
        corner   = doc.corner
        tiling   = doc.tiling
        fillHex  = doc.fillColor.hex
        bgHex    = doc.bgColor.hex
    }
}

// MARK: - Codable snapshot for project save/load

struct PatternSnapshot: Codable {
    var H, W:           Int
    var symmetryGroup:  SymmetryGroup
    var grid:           [[Bool]]
    var colStrip:       [[Bool]]
    var rowStrip:       [[Bool]]
    var corner:         [[Bool]]
    var cellSize:       Double
    var density:        Double
    var showDomain:     Bool
    var fillHex:        String
    var bgHex:          String
    var tiling:         TilingSettings

    init(from doc: PatternDocument) {
        H             = doc.H
        W             = doc.W
        symmetryGroup = doc.symmetryGroup
        grid          = doc.grid
        colStrip      = doc.colStrip
        rowStrip      = doc.rowStrip
        corner        = doc.corner
        cellSize      = doc.cellSize
        density       = doc.density
        showDomain    = doc.showDomain
        fillHex       = doc.fillColor.hex
        bgHex         = doc.bgColor.hex
        tiling        = doc.tiling
    }

    func apply(to doc: PatternDocument) {
        doc.H             = H
        doc.W             = W
        doc.symmetryGroup = symmetryGroup
        doc.grid          = grid
        doc.colStrip      = colStrip
        doc.rowStrip      = rowStrip
        doc.corner        = corner
        doc.cellSize      = cellSize
        doc.density       = density
        doc.showDomain    = showDomain
        doc.fillColor.setHex(fillHex)
        doc.bgColor.setHex(bgHex)
        doc.tiling        = tiling
        // Recompute domain from loaded grid dimensions + symmetry
        doc.regenerateDomain()
        doc.rebuildDescriptors()
    }
}
