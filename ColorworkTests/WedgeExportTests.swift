// WedgeExportTests.swift
// A Wedge exports like a Tile: page 1 is one charted repeat (with stitch totals), page 2
// its Circular View; PNG and SVG are one repeat. Tile export is unchanged.

import CoreGraphics
import Foundation
import Testing
@testable import Colorwork

@MainActor
struct WedgeExportTests {

    /// A small growing Wedge: one increase pair at chart row 3 of a 4×6 repeat.
    private func wedge(repeats: Int = 10) -> PatternDocument {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.H = 4; doc.W = 6
        doc.setKind(.wedge)
        doc.radialRepeat = repeats
        doc.paintStitch(.m1r, at: CellIndex(row: 1, col: 1))
        doc.paintStitch(.m1l, at: CellIndex(row: 1, col: 4))
        return doc
    }

    private func svg(_ doc: PatternDocument) throws -> String {
        String(decoding: try SVGExporter.export(doc: doc), as: UTF8.self)
    }

    @Test func wedgeChartShowsTotalsOnlyWhereTheCountChanges() throws {
        let doc = wedge()
        #expect(doc.wedgeTotals.map(\.row) == [1, 3])
        #expect(doc.wedgeTotals.map(\.stitches) == [40, 60])
        let s = try svg(doc)
        #expect(s.contains(">Row 1: 40</text>"))
        #expect(s.contains(">Row 3: 60</text>"))
        #expect(!s.contains(">Row 2: "))
    }

    @Test func totalsFollowTheRepeatCount() throws {
        let doc = wedge()
        doc.radialRepeat = 21
        #expect(try svg(doc).contains(">Row 3: 126</text>"))
    }

    @Test func wedgeSVGIsOneRepeatWithNoCircularView() throws {
        let doc = wedge()
        let s = try svg(doc)
        #expect(!s.contains("<polygon"))
        #expect(ExportTile.make(doc).size == doc.tileCanvasSize)
    }

    @Test func wedgePDFIsTheChartThenTheCircularView() throws {
        let doc = wedge()
        let data = try PDFExporter.export(doc: doc)
        let pdf = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(pdf.numberOfPages == 2)
        // The Circular View page draws far more than the chart page: one shape per stitch.
        let flipped = wedge()
        flipped.circularFlipped = true
        #expect(try PDFExporter.export(doc: flipped) != data)
    }

    @Test func tilesHaveNoTotals() throws {
        let doc = PatternDocument()
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 1))
        #expect(doc.wedgeTotals.isEmpty)
        #expect(!(try svg(doc)).contains(">Row "))
    }
}
