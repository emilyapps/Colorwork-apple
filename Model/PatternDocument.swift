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
    var grid:     [[Bool]]   = []
    var stitches: [[Stitch]] = []   // parallel to grid; knit unless painted
    var H: Int = 8 {
        didSet {
            guard oldValue != H, !isMutatingInternally else { return }
            pushUndo("Resize Grid")
            resizeGrid()
        }
    }
    var W: Int = 8 {
        didSet {
            guard oldValue != W, !isMutatingInternally else { return }
            pushUndo("Resize Grid")
            resizeGrid()
        }
    }

    var symmetryGroup: SymmetryGroup = .d4 {
        didSet {
            if !isDowngrading { pushUndo("Change Symmetry") }
            if symmetryGroup.requiresSquare {
                isMutatingInternally = true
                W = H
                isMutatingInternally = false
            }
            resizeGrid()
        }
    }

    fileprivate var isMutatingInternally = false

    // MARK: - Paint tool
    enum PaintTool: Equatable {
        case color
        case stitch(Stitch)
    }
    var paintTool: PaintTool = .color

    /// Groups whose every Transformation has a Visual Equivalent for every stitch in the Pattern.
    var allowedSymmetryGroups: Set<SymmetryGroup> {
        let used = Set(stitches.joined())
        return Set(SymmetryGroup.allCases.filter { $0.allows(used) })
    }

    /// Repeat types offered for one direction, given the other direction's current type.
    func allowedRepeatTypes(horizontal: Bool) -> [RepeatType] {
        let used = Set(stitches.joined())
        return RepeatType.allCases.filter { type in
            horizontal
                ? TilingEngine.allows(horizontal: type, vertical: tiling.verticalRepeatType, stitches: used)
                : TilingEngine.allows(horizontal: tiling.horizontalRepeatType, vertical: type, stitches: used)
        }
    }

    /// Stitches in the Pattern that keep some groups from being offered, in catalog order.
    var limitingStitches: [Stitch] {
        let used = Set(stitches.joined())
        return Stitch.allCases.filter { used.contains($0) && !SymmetryGroup.d4.allows([$0]) }
    }

    /// Set when painting a stitch downgraded the Symmetry Group; the editor shows it, then clears it.
    var symmetryNotice: String?

    /// The downgrade is undone with the paint stroke it belongs to, so it pushes no undo of its own.
    private var isDowngrading = false

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
    private(set) var canRedo: Bool = false

    func pushUndo(_ name: String) {
        let snapshot = PatternSnapshot(from: self)
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.pushUndo(name)
            snapshot.apply(to: doc)
            doc.canUndo = doc.undoManager?.canUndo ?? false
            doc.canRedo = doc.undoManager?.canRedo ?? false
        }
        undoManager?.setActionName(name)
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
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
    private(set) var tilingStitchGrid: [[Stitch]] = []
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
        resizeStitches()
        domainCells      = result.domain
        domainSet        = Set(result.domain)
        cellToCanonical  = result.canonical
        resetStrips()
        rebuildTileDescriptors()
        scheduleTilingRebuild()
        fitCellSize()
        isDirty = true
    }

    func clear() {
        pushUndo("Clear")
        grid = PatternEngine.clearGrid(H: H, W: W)
        stitches = Stitch.allKnit(rows: H, cols: W)
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
                                            acrossVerticalAxis: tiling.stripReflectsAcrossVerticalAxis,
                                            acrossHorizontalAxis: tiling.stripReflectsAcrossHorizontalAxis)
        case .rowStrip:
            PatternEngine.toggleStripCell(row: cell.row, col: cell.col, in: &rowStrip)
            PatternEngine.applyStripReflect(row: cell.row, col: cell.col, in: &rowStrip,
                                            acrossVerticalAxis: tiling.stripReflectsAcrossVerticalAxis,
                                            acrossHorizontalAxis: tiling.stripReflectsAcrossHorizontalAxis)
        case .corner:
            PatternEngine.toggleStripCell(row: cell.row, col: cell.col, in: &corner)
            PatternEngine.applyStripReflect(row: cell.row, col: cell.col, in: &corner,
                                            acrossVerticalAxis: tiling.stripReflectsAcrossVerticalAxis,
                                            acrossHorizontalAxis: tiling.stripReflectsAcrossHorizontalAxis)
        }
        rebuildTileDescriptors()
        scheduleTilingRebuild()
        isDirty = true
    }

    /// Paints a Stitch into a tile Cell without touching color. Linked cells get the stitch's
    /// Visual Equivalent. If the current group doesn't allow the stitch, the group is downgraded
    /// first, with a notice. Border strips are color-only, so only the tile region takes stitches.
    func paintStitch(_ stitch: Stitch, at cell: CellIndex) {
        let used = Set(stitches.joined()).union([stitch])
        var changes: [String] = []
        if !symmetryGroup.allows([stitch]) {
            let old = symmetryGroup
            isDowngrading = true
            symmetryGroup = old.largestGroupAllowing(used)
            isDowngrading = false
            changes.append("symmetry from \(old.displayName) to \(symmetryGroup.displayName)")
        }
        // Repeat types follow the same rule; a disallowed one falls back to translation.
        if !TilingEngine.allows(horizontal: tiling.horizontalRepeatType, vertical: .translation, stitches: used) {
            tiling.horizontalRepeatType = .translation
            changes.append("the horizontal repeat to Translate")
        }
        if !TilingEngine.allows(horizontal: tiling.horizontalRepeatType, vertical: tiling.verticalRepeatType,
                                stitches: used) {
            tiling.verticalRepeatType = .translation
            changes.append("the vertical repeat to Translate")
        }
        if !changes.isEmpty {
            symmetryNotice = "Changed " + changes.joined(separator: " and ") + ": \(stitch.displayName) "
                + "has no matching stitch under those rotations or reflections yet. Undo to go back."
        }
        // The painted cell is written last, so a cell on an axis keeps the stitch you chose.
        let linked = symmetryGroup.linkedCells(cell.row, cell.col, H: H, W: W)
        for (member, t) in linked.filter({ $0.transformation != .identity })
                         + linked.filter({ $0.transformation == .identity }) {
            if let s = stitch.visualEquivalent(under: t) { stitches[member.row][member.col] = s }
        }
        rebuildDescriptors()
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

    private func resizeGrid() {
        let oldRows = grid.count
        let oldCols = grid.first?.count ?? 0
        if oldRows != H || oldCols != W {
            grid = (0 ..< H).map { r in
                (0 ..< W).map { c in
                    r < oldRows && c < oldCols ? grid[r][c] : false
                }
            }
            resetStrips()
        }
        resizeStitches()
        regenerateDomain()
        fitCellSize()
        rebuildDescriptors()
        isDirty = true
    }

    /// Keeps stitches where cells still exist; new cells are knit.
    private func resizeStitches() {
        let oldRows = stitches.count
        let oldCols = stitches.first?.count ?? 0
        guard oldRows != H || oldCols != W else { return }
        stitches = (0 ..< H).map { r in
            (0 ..< W).map { c in
                r < oldRows && c < oldCols ? stitches[r][c] : .knit
            }
        }
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
            stripWidth: tiling.stripWidth,
            stitches: stitches)
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
                horizontal: snap.tiling.horizontalRepeatType, vertical: snap.tiling.verticalRepeatType,
                nH: snap.tiling.nCopies, nV: snap.tiling.nCopies,
                rowOffset: snap.tiling.rowOffset, colOffset: snap.tiling.colOffset)
            // Strips are color-only, so their cells tile as knit.
            let stitchGrid = TilingEngine.buildTilingGrid(
                tile: snap.stitches, H: snap.H, W: snap.W,
                colStrip: [], rowStrip: [], corner: [], empty: Stitch.knit,
                hRepeat: snap.tiling.hRepeat, vRepeat: snap.tiling.vRepeat,
                stripWidth: snap.tiling.stripWidth,
                horizontal: snap.tiling.horizontalRepeatType, vertical: snap.tiling.verticalRepeatType,
                nH: snap.tiling.nCopies, nV: snap.tiling.nCopies,
                rowOffset: snap.tiling.rowOffset, colOffset: snap.tiling.colOffset,
                copy: { s, t in s.visualEquivalent(under: t) ?? s })
            guard !Task.isCancelled else { return }
            let cs = CGFloat(snap.tiling.previewCellSize)
            let (descs, rows, cols) = DescriptorBuilder.tilingDescriptors(
                tilingGrid: tg,
                fillColor: snap.fillHex, bgColor: snap.bgHex,
                hRepeat: snap.tiling.hRepeat, vRepeat: snap.tiling.vRepeat,
                stripWidth: snap.tiling.stripWidth,
                horizontal: snap.tiling.horizontalRepeatType, vertical: snap.tiling.verticalRepeatType,
                nCopies: snap.tiling.nCopies,
                W: snap.W, H: snap.H,
                rowOffset: snap.tiling.rowOffset, colOffset: snap.tiling.colOffset,
                cellSize: cs, stitchGrid: stitchGrid)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.tilingGrid        = tg
                self?.tilingStitchGrid  = stitchGrid
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
    let stitches: [[Stitch]]
    let H, W: Int
    let colStrip, rowStrip, corner: [[Bool]]
    let tiling: TilingSettings
    let fillHex, bgHex: String

    init(from doc: PatternDocument) {
        grid     = doc.grid
        stitches = doc.stitches
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
    var stitches:       [[Stitch]]?   // nil in snapshots saved before stitches existed
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
        stitches      = doc.stitches
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
        doc.symmetryNotice = nil
        doc.isMutatingInternally = true
        doc.H             = H
        doc.W             = W
        doc.symmetryGroup = symmetryGroup
        doc.isMutatingInternally = false
        doc.grid          = grid
        doc.stitches      = stitches ?? Stitch.allKnit(rows: H, cols: W)
        doc.tiling        = tiling    // must precede strips — didSet calls resetStrips() if stripWidth changed
        doc.colStrip      = colStrip
        doc.rowStrip      = rowStrip
        doc.corner        = corner
        doc.cellSize      = cellSize
        doc.density       = density
        doc.showDomain    = showDomain
        doc.fillColor.setHex(fillHex)
        doc.bgColor.setHex(bgHex)
        // Recompute domain from loaded grid dimensions + symmetry
        doc.regenerateDomain()
        doc.rebuildDescriptors()
    }
}
