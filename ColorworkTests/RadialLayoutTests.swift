// RadialLayoutTests.swift
// The Circular View's rings: which end of the chart is at the center, flip, ring sizes,
// and that the view settings are saved in Projects but untouched by undo.

import Foundation
import SwiftData
import Testing
@testable import Colorwork

@MainActor
struct RadialLayoutTests {

    /// 4 rows, 4 columns; the live count grows from row 1 to the top via one increase.
    private func growing() -> ShapingResolver.Result {
        var s = Stitch.allKnit(rows: 4, cols: 4)
        s[1][1] = .m1r                       // chart row 3: column is No Stitch in rows 1–2
        return ShapingResolver.resolve(s)
    }

    /// Mirror image: shrinking from row 1 to the top via one decrease.
    private func shrinking() -> ShapingResolver.Result {
        var s = Stitch.allKnit(rows: 4, cols: 4)
        s[2][2] = .k2tog                     // chart row 2: ends a column from row 2 up
        return ShapingResolver.resolve(s)
    }

    private func innermost(_ rings: [RadialLayout.Ring]) -> Int {
        rings.first { $0.index == 0 }!.chartRow
    }

    @Test func growingCountsPutRowOneAtTheCenter() {
        #expect(innermost(RadialLayout.rings(growing(), repeats: 8, flipped: false)) == 1)
    }

    @Test func shrinkingCountsPutRowOneOutside() {
        #expect(innermost(RadialLayout.rings(shrinking(), repeats: 8, flipped: false)) == 4)
    }

    @Test func flipInvertsWhichEndIsAtTheCenter() {
        #expect(innermost(RadialLayout.rings(growing(), repeats: 8, flipped: true)) == 4)
        #expect(innermost(RadialLayout.rings(shrinking(), repeats: 8, flipped: true)) == 1)
    }

    @Test func ringSizesAreLiveStitchesTimesRepeats() {
        let rings = RadialLayout.rings(shrinking(), repeats: 21, flipped: false)
        #expect(rings.map(\.chartRow) == [1, 2, 3, 4])
        #expect(rings.map(\.stitchCount) == [84, 63, 63, 63])
        #expect(Set(rings.map(\.index)) == [0, 1, 2, 3])
    }

    @Test func noStitchCellsAreLeftOutOfTheRing() {
        let ring = RadialLayout.rings(shrinking(), repeats: 1, flipped: false).first { $0.chartRow == 2 }!
        #expect(ring.columns == [3, 2, 0])          // column 1 (grid col 1) ended by the k2tog
    }

    @Test func movingADecreaseChangesTheCircularView() {
        var a = Stitch.allKnit(rows: 4, cols: 6)
        a[2][2] = .k2tog
        var b = a
        b[2][2] = .knit
        b[2][4] = .k2tog
        let ringA = RadialLayout.rings(ShapingResolver.resolve(a), repeats: 8, flipped: false)
        let ringB = RadialLayout.rings(ShapingResolver.resolve(b), repeats: 8, flipped: false)
        #expect(ringA.map(\.columns) != ringB.map(\.columns))
    }

    // MARK: View settings

    @Test func viewSettingsAreSavedInProjects() throws {
        let schema = Schema([SDPattern.self, SDProject.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = PatternStore(context: ModelContext(container))
        let doc = PatternDocument()
        doc.setKind(.wedge)
        doc.wedgeView = .circular
        doc.circularFlipped = true
        try store.saveProject(from: doc, name: "crown")

        let other = PatternDocument()
        try store.loadProject(try #require(store.listProjects().first), into: other)
        #expect(other.wedgeView == .circular)
        #expect(other.circularFlipped)
    }

    @Test func undoDoesNotChangeViewSettings() {
        let doc = PatternDocument()
        doc.setKind(.wedge)
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.undoManager = undo
        undo.beginUndoGrouping(); doc.pushUndo("Paint"); doc.paintStitch(.purl, at: CellIndex(row: 0, col: 0)); undo.endUndoGrouping()
        doc.wedgeView = .circular
        doc.circularFlipped = true
        undo.undo()
        #expect(doc.wedgeView == .circular)
        #expect(doc.circularFlipped)
    }
}
