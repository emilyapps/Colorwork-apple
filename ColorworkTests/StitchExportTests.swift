// StitchExportTests.swift
// Exports draw the same stitch symbols and legend as the canvas, and all-knit
// Patterns export exactly as before stitches existed.

import CoreGraphics
import Foundation
import Testing
@testable import Colorwork

struct StitchExportTests {

    private func laceDoc() -> PatternDocument {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.grid[0][0] = true                     // fill cell
        doc.grid[0][1] = false                    // background cell
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 0))
        doc.paintStitch(.purl, at: CellIndex(row: 0, col: 1))
        return doc
    }

    // MARK: Legend

    @Test func legendIsAbsentForAllKnitPatterns() {
        #expect(DescriptorBuilder.legendStitches(Stitch.allKnit(rows: 4, cols: 4)).isEmpty)
    }

    @Test func legendListsExactlyTheStitchesUsedInCatalogOrder() {
        var stitches = Stitch.allKnit(rows: 2, cols: 3)
        stitches[0][0] = .yarnOver
        stitches[1][2] = .purl
        stitches[1][1] = .ssk
        #expect(DescriptorBuilder.legendStitches(stitches) == [.knit, .purl, .ssk, .yarnOver])
    }

    @Test func svgExportShowsSymbolsWithCanvasContrastAndALegend() throws {
        let doc = laceDoc()
        let svg = String(decoding: try SVGExporter.export(doc: doc), as: UTF8.self)

        let ink = ColorMath.contrastInkHex(for: doc.fillColor.hex)
        #expect(svg.contains("<line") && svg.contains("stroke=\"\(ink)\""))   // k2tog on a fill cell
        #expect(svg.contains("<circle"))                                       // purl dot
        for name in ["Knit", "Purl", "k2tog"] {
            #expect(svg.contains("text-anchor=\"start\" dominant-baseline=\"middle\">\(name)</text>"))
        }
        #expect(!svg.contains(">ssk</text>"))
    }

    @Test func legendListsNoStitchOnlyWhenTheChartHasIt() throws {
        let svg = String(decoding: try SVGExporter.export(doc: laceDoc()), as: UTF8.self)
        #expect(svg.contains(">No stitch</text>"))                 // k2tog ends a column

        let doc = PatternDocument()
        doc.paintStitch(.purl, at: CellIndex(row: 0, col: 0))
        let purlOnly = String(decoding: try SVGExporter.export(doc: doc), as: UTF8.self)
        #expect(!purlOnly.contains(">No stitch</text>"))
    }

    @Test func exportsUseTheCanvasDescriptors() {
        let doc = laceDoc()
        doc.showDomain = false
        doc.rebuildDescriptors()
        let export = ExportTile.make(doc)
        #expect(export.size == doc.tileCanvasSize)
        #expect(export.descriptors.count == doc.tileDescriptors.count)
    }

    // MARK: PDF pages

    @MainActor
    @Test func pdfIsTwoLetterPages() async throws {
        let doc = PatternDocument()
        doc.tiling.hRepeat = true
        doc.tiling.nCopies = 2
        doc.rebuildDescriptors()
        while doc.isComputingTiling { try await Task.sleep(for: .milliseconds(20)) }

        let data = try PDFExporter.export(doc: doc)
        let pdf = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(pdf.numberOfPages == 2)
        for i in 1 ... pdf.numberOfPages {
            #expect(pdf.page(at: i)?.getBoxRect(.mediaBox).size == CGSize(width: 612, height: 792))
        }
    }

    @Test func tiledPageUsesTheChartsScaleWhenItFitsAndShrinksWhenItDoesNot() {
        let chartScale: CGFloat = 1.5
        #expect(PDFExporter.fitScale(CGSize(width: 200, height: 100), maxScale: chartScale) == chartScale)
        #expect(PDFExporter.fitScale(CGSize(width: 2000, height: 100), maxScale: chartScale) < chartScale)
    }

    // MARK: All-knit Patterns are unchanged

    @Test func allKnitExportIsUnchanged() throws {
        let doc = PatternDocument()
        let before = DescriptorBuilder.tileDescriptors(
            grid: doc.grid, H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex,
            domainCells: doc.domainSet, showDomain: false,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip, corner: doc.corner,
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat, stripWidth: doc.tiling.stripWidth)
        let beforeSize = DescriptorBuilder.tileCanvasSize(
            H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat, stripWidth: doc.tiling.stripWidth)

        let export = ExportTile.make(doc)
        #expect(export.size == beforeSize)
        #expect(export.descriptors.count == before.count)

        let svg = String(decoding: try SVGExporter.export(doc: doc), as: UTF8.self)
        #expect(!svg.contains("<line") && !svg.contains("<circle"))
    }
}
