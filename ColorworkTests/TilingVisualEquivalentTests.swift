// TilingVisualEquivalentTests.swift
// Planar Repeats follow the Visual Equivalents rule (ADR 0001): reflected copies show
// equivalent stitches, and repeat types with no equivalents are unavailable.

import Foundation
import Testing
@testable import Colorwork

struct TilingVisualEquivalentTests {

    // MARK: Which Transformations the copies get

    @Test(arguments: [
        (RepeatType.translation, RepeatType.translation, [Transformation.identity]),
        (.reflection,  .translation, [.identity, .verticalAxisReflection]),
        (.translation, .reflection,  [.identity, .horizontalAxisReflection]),
        (.rotation,    .translation, [.identity, .halfTurn]),
        (.reflection,  .reflection,  [.identity, .verticalAxisReflection, .horizontalAxisReflection, .halfTurn]),
    ])
    func copiesGetTheTransformationsOfTheirRepeatTypes(horizontal: RepeatType, vertical: RepeatType,
                                                       expected: [Transformation]) {
        #expect(TilingEngine.copyTransformations(horizontal: horizontal, vertical: vertical) == Set(expected))
    }

    // MARK: Allowed repeat types

    @Test func colorworkAllowsEveryRepeatType() {
        for h in RepeatType.allCases {
            for v in RepeatType.allCases {
                #expect(TilingEngine.allows(horizontal: h, vertical: v, stitches: [.knit, .purl]))
            }
        }
    }

    @Test func shapingStitchesAllowOnlyTranslationAndSideBySideReflection() {
        let lace: [Stitch] = [.knit, .yarnOver, .k2tog]
        #expect(TilingEngine.allows(horizontal: .translation, vertical: .translation, stitches: lace))
        #expect(TilingEngine.allows(horizontal: .reflection, vertical: .translation, stitches: lace))
        #expect(!TilingEngine.allows(horizontal: .rotation, vertical: .translation, stitches: lace))
        #expect(!TilingEngine.allows(horizontal: .translation, vertical: .reflection, stitches: lace))
        #expect(!TilingEngine.allows(horizontal: .translation, vertical: .rotation, stitches: lace))
        // Reflecting both ways gives diagonal copies a half-turn.
        #expect(!TilingEngine.allows(horizontal: .reflection, vertical: .reflection, stitches: lace))
    }

    @Test func removingTheLastShapingStitchMakesRepeatTypesAvailableAgain() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 0))
        #expect(doc.allowedRepeatTypes(horizontal: true) == [.translation, .reflection])
        #expect(doc.allowedRepeatTypes(horizontal: false) == [.translation])

        doc.paintStitch(.knit, at: CellIndex(row: 0, col: 0))
        #expect(doc.allowedRepeatTypes(horizontal: true) == RepeatType.allCases)
        #expect(doc.allowedRepeatTypes(horizontal: false) == RepeatType.allCases)
    }

    // MARK: Reflected copies show Visual Equivalents

    @Test func sideBySideReflectedCopiesShowTheMirrorStitch() {
        let tile: [[Stitch]] = [[.k2tog, .knit, .m1r]]
        let tiled = TilingEngine.buildTilingGrid(
            tile: tile, H: 1, W: 3, colStrip: [], rowStrip: [], corner: [], empty: Stitch.knit,
            hRepeat: true, vRepeat: false, stripWidth: 0,
            horizontal: .reflection, vertical: .translation, nH: 2, nV: 1,
            copy: { s, t in s.visualEquivalent(under: t) ?? s })
        #expect(tiled == [[.k2tog, .knit, .m1r, .m1l, .knit, .ssk]])
    }

    // MARK: Painting a stitch the repeat doesn't allow

    @Test func paintingAShapingStitchResetsADisallowedRepeatAndOneUndoRestoresIt() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.tiling.verticalRepeatType = .rotation
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.undoManager = undo

        undo.beginUndoGrouping()
        doc.pushUndo("Paint")            // the canvas does this at the start of a drag
        doc.paintStitch(.ssk, at: CellIndex(row: 1, col: 1))
        undo.endUndoGrouping()

        #expect(doc.tiling.verticalRepeatType == .translation)
        #expect(doc.symmetryNotice != nil)

        undo.undo()
        #expect(doc.tiling.verticalRepeatType == .rotation)
        #expect(doc.stitches[1][1] == .knit)
    }

    // MARK: Saved Projects

    @Test func projectsSavedWithOldSettingNamesStillLoad() throws {
        let json = """
        {"hRepeat":true,"vRepeat":true,"hType":"reflection","vType":"rotation","stripWidth":2,
         "stripHReflect":true,"stripVReflect":false,"rowOffset":0,"colOffset":0,
         "nCopies":3,"previewCellSize":8}
        """
        let t = try JSONDecoder().decode(TilingSettings.self, from: Data(json.utf8))
        #expect(t.horizontalRepeatType == .reflection)
        #expect(t.verticalRepeatType == .rotation)
        #expect(t.stripReflectsAcrossVerticalAxis)
        #expect(!t.stripReflectsAcrossHorizontalAxis)

        let roundTrip = try JSONDecoder().decode(TilingSettings.self, from: JSONEncoder().encode(t))
        #expect(roundTrip == t)
    }
}
