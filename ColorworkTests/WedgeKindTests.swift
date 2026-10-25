// WedgeKindTests.swift
// The Wedge Pattern Kind: switching Kind, its symmetry rule, hidden strips, Radial Repeat
// totals, and how Kind and N are saved.

import Foundation
import SwiftData
import Testing
@testable import Colorwork

@MainActor
struct WedgeKindTests {

    private func undoable(_ doc: PatternDocument) -> UndoManager {
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.undoManager = undo
        return undo
    }

    // MARK: Switching Kind

    @Test func switchingFromAD4TileToAWedgeDowngradesToD1VAndOneUndoRestoresBoth() {
        let doc = PatternDocument()
        let undo = undoable(doc)
        #expect(doc.symmetryGroup == .d4)

        undo.beginUndoGrouping(); doc.setKind(.wedge); undo.endUndoGrouping()
        #expect(doc.kind == .wedge)
        #expect(doc.symmetryGroup == .d1)
        #expect(doc.symmetryNotice != nil)

        undo.undo()
        #expect(doc.kind == .tile)
        #expect(doc.symmetryGroup == .d4)
    }

    @Test func switchingBackToATileIsOneUndoableStep() {
        let doc = PatternDocument()
        doc.setKind(.wedge)
        let undo = undoable(doc)
        undo.beginUndoGrouping(); doc.setKind(.tile); undo.endUndoGrouping()
        #expect(doc.kind == .tile)
        undo.undo()
        #expect(doc.kind == .wedge)
    }

    @Test func aWedgeOffersOnlyC1AndD1V() {
        let doc = PatternDocument()
        doc.setKind(.wedge)
        #expect(doc.allowedSymmetryGroups == [.c1, .d1])
    }

    @Test(arguments: [(SymmetryGroup.d2, SymmetryGroup.d1), (.c4, .c1), (.c2, .c1), (.d1h, .c1), (.d1, .d1)])
    func tileToWedgeDowngradeTable(from: SymmetryGroup, to: SymmetryGroup) {
        let doc = PatternDocument()
        doc.symmetryGroup = from
        doc.setKind(.wedge)
        #expect(doc.symmetryGroup == to)
    }

    // MARK: Border strips

    @Test func borderStripsAreHiddenOnAWedgeAndComeBackOnATile() {
        let doc = PatternDocument()
        doc.tiling.hRepeat = true
        doc.tiling.vRepeat = true
        doc.rebuildDescriptors()
        func stripCells() -> Int {
            doc.tileDescriptors.filter {
                if case .rect(let r) = $0 { return r.region == .colStrip || r.region == .rowStrip }
                return false
            }.count
        }
        let before = stripCells()
        #expect(before > 0)

        doc.setKind(.wedge)
        #expect(stripCells() == 0)

        doc.setKind(.tile)
        #expect(stripCells() == before)
    }

    // MARK: Radial Repeat totals

    @Test func yokeTotalsAtTwentyOneRepeats() {
        let H = 32, W = 12
        var s = Stitch.allKnit(rows: H, cols: W)
        for (row, cols) in [(2, [5, 6]), (5, [3, 8]), (8, [1, 10]), (32, [0, 11])] {
            for c in cols { s[H - row][c] = .m1l }
        }
        let totals = ShapingResolver.resolve(s).totals(repeats: 21)
        #expect(totals.map(\.row) == [1, 2, 5, 8, 32])
        #expect(totals.map(\.stitches) == [84, 126, 168, 210, 252])
    }

    // MARK: Saving

    private func store() throws -> PatternStore {
        let schema = Schema([SDPattern.self, SDProject.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return PatternStore(context: ModelContext(container))
    }

    @Test func patternsSaveKindButLoadingKeepsTheCurrentRepeatCount() throws {
        let store = try store()
        let doc = PatternDocument()
        doc.setKind(.wedge)
        doc.radialRepeat = 21
        try store.savePattern(from: doc, name: "crown")

        let other = PatternDocument()
        other.radialRepeat = 9
        store.loadPattern(try #require(store.listPatterns().first), into: other)
        #expect(other.kind == .wedge)
        #expect(other.radialRepeat == 9)
    }

    @Test func projectsSaveKindAndRepeatCount() throws {
        let store = try store()
        let doc = PatternDocument()
        doc.setKind(.wedge)
        doc.radialRepeat = 21
        try store.saveProject(from: doc, name: "yoke")

        let other = PatternDocument()
        try store.loadProject(try #require(store.listProjects().first), into: other)
        #expect(other.kind == .wedge)
        #expect(other.radialRepeat == 21)
    }

    @Test func savesFromBeforeWedgesLoadAsTiles() throws {
        let store = try store()
        let wedge = PatternDocument()
        wedge.setKind(.wedge)
        try store.savePattern(from: wedge, name: "old")
        let saved = try #require(store.listPatterns().first)
        saved.kind = nil                                   // as saved before Kind existed

        let doc = PatternDocument()
        doc.setKind(.wedge)
        store.loadPattern(saved, into: doc)
        #expect(doc.kind == .tile)

        var snapshot = PatternSnapshot(from: wedge)
        snapshot.kind = nil
        snapshot.radialRepeat = nil
        let old = try JSONDecoder().decode(PatternSnapshot.self, from: JSONEncoder().encode(snapshot))
        old.apply(to: doc)
        #expect(doc.kind == .tile)
    }

    @Test func undoDoesNotRollBackTheRepeatCount() {
        let doc = PatternDocument()
        doc.setKind(.wedge)
        let undo = undoable(doc)
        undo.beginUndoGrouping(); doc.pushUndo("Paint"); doc.paintStitch(.purl, at: CellIndex(row: 0, col: 0)); undo.endUndoGrouping()
        doc.radialRepeat = 21
        undo.undo()
        #expect(doc.radialRepeat == 21)
    }
}
