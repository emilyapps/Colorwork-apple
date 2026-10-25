// PatternDocumentStitchTests.swift
// The stitch layer on a Pattern: independent of color, undoable, persistent.

import Foundation
import Testing
@testable import Colorwork

struct PatternDocumentStitchTests {

    @Test func newPatternIsAllKnit() {
        let doc = PatternDocument()
        #expect(doc.stitches.count == doc.H)
        #expect(doc.stitches.allSatisfy { $0.count == doc.W && $0.allSatisfy { $0 == .knit } })
    }

    @Test func stitchAndColorArePaintedIndependently() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        let cell = CellIndex(row: 2, col: 3)
        let colorBefore = doc.grid[2][3]

        doc.paintStitch(.k2tog, at: cell)
        #expect(doc.stitches[2][3] == .k2tog)
        #expect(doc.grid[2][3] == colorBefore)

        doc.toggleCell(cell, region: .tile)
        #expect(doc.grid[2][3] != colorBefore)
        #expect(doc.stitches[2][3] == .k2tog)
    }

    @Test func undoReversesAStitchPaint() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.undoManager = undo

        undo.beginUndoGrouping()
        doc.pushUndo("Paint")            // the canvas does this at the start of a drag
        doc.paintStitch(.ssk, at: CellIndex(row: 1, col: 1))
        undo.endUndoGrouping()

        undo.undo()
        #expect(doc.stitches[1][1] == .knit)
    }

    @Test func generateKeepsStitches() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.paintStitch(.yarnOver, at: CellIndex(row: 0, col: 0))
        doc.generate()
        #expect(doc.stitches[0][0] == .yarnOver)
    }

    @Test(arguments: SymmetryGroup.allCases)
    func knitAndPurlArePaintableInAnySymmetry(group: SymmetryGroup) {
        let doc = PatternDocument()
        doc.symmetryGroup = group
        #expect(doc.canPaint(.knit))
        #expect(doc.canPaint(.purl))
    }

    @Test func purlFillsEverySymmetricCopyOfTheCell() {
        let doc = PatternDocument()
        doc.symmetryGroup = .d4
        doc.paintStitch(.purl, at: CellIndex(row: 0, col: 1))

        let purls = doc.stitches.joined().filter { $0 == .purl }.count
        #expect(purls == 8)
        #expect(doc.stitches[0][doc.W - 2] == .purl)            // mirrored across the vertical axis
        #expect(doc.stitches[doc.H - 1][1] == .purl)            // mirrored across the horizontal axis
        #expect(doc.stitches[1][0] == .purl)                    // mirrored across the diagonal

        doc.paintStitch(.knit, at: CellIndex(row: doc.H - 1, col: 1))
        #expect(doc.stitches.joined().allSatisfy { $0 == .knit })
    }

    @Test func clearResetsStitchesToKnit() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.paintStitch(.purl, at: CellIndex(row: 0, col: 0))
        doc.clear()
        #expect(doc.stitches[0][0] == .knit)
    }
}
