// StitchExportTests.swift
// Exports draw the same stitch symbols and legend as the canvas, and all-knit
// Patterns export exactly as before stitches existed.

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

    @Test func exportsUseTheCanvasDescriptors() {
        let doc = laceDoc()
        doc.showDomain = false
        doc.rebuildDescriptors()
        let export = ExportTile.make(doc)
        #expect(export.size == doc.tileCanvasSize)
        #expect(export.descriptors.count == doc.tileDescriptors.count)
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
