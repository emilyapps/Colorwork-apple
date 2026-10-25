// PDFExporter.swift
// Renders pattern or pattern+tiling to PDF/PNG using CoreGraphics.
// A single Y-flip CGAffineTransform handles PDF's bottom-left origin.

import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Error

enum ExportError: Error {
    case renderingFailed
}

// MARK: - Format + dispatcher

enum ExportFormat { case pdf, png, svg }

enum Exporter {
    static func exportData(doc: PatternDocument, format: ExportFormat) throws -> Data {
        switch format {
        case .pdf: return try PDFExporter.export(doc: doc)
        case .png: return try PNGExporter.export(doc: doc)
        case .svg: return try SVGExporter.export(doc: doc)
        }
    }
}

// MARK: - PDF

enum PDFExporter {

    /// US Letter, in points, with half-inch margins.
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 36

    /// Scale for drawing content of `size` inside the page margins, capped at `maxScale`.
    static func fitScale(_ size: CGSize, maxScale: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
        let box = CGSize(width: pageSize.width - 2 * margin, height: pageSize.height - 2 * margin)
        return min(maxScale, box.width / size.width, box.height / size.height)
    }

    /// Page 1 is the chart with its legend; page 2 is the tiled pattern drawn with the same
    /// cell size as page 1 when it fits, smaller when it doesn't. Both are Letter pages.
    static func export(doc: PatternDocument, includeTiling: Bool = true) throws -> Data {
        let (tileSize, tileDescs) = ExportTile.make(doc)

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderingFailed
        }

        // ---- Page 1: Tile ----
        let tileScale = fitScale(tileSize)
        drawPage(tileDescs, size: tileSize, scale: tileScale, into: ctx)

        // ---- Page 2: Tiled pattern (optional) ----
        if includeTiling && doc.tilingRows > 0 && doc.tilingCols > 0 {
            let cs = CGFloat(doc.cellSize)
            let pad: CGFloat = 1
            let tiling = DescriptorBuilder.tilingDescriptors(
                tilingGrid: doc.tilingGrid,
                fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex,
                hRepeat: doc.tiling.hRepeat, vRepeat: doc.tiling.vRepeat,
                stripWidth: doc.tiling.stripWidth,
                horizontal: doc.tiling.horizontalRepeatType, vertical: doc.tiling.verticalRepeatType,
                nCopies: doc.tiling.nCopies, W: doc.W, H: doc.H,
                rowOffset: doc.tiling.rowOffset, colOffset: doc.tiling.colOffset,
                cellSize: cs, padding: pad, stitchGrid: doc.tilingStitchGrid,
                noStitchGrid: doc.tilingNoStitchGrid)
            let size = CGSize(width: CGFloat(tiling.cols) * cs + 2 * pad,
                              height: CGFloat(tiling.rows) * cs + 2 * pad)
            drawPage(tiling.descriptors, size: size, scale: fitScale(size, maxScale: tileScale), into: ctx)
        }

        ctx.closePDF()
        return data as Data
    }

    /// One Letter page with the content scaled, centered horizontally and top-aligned.
    /// The Y-flip maps top-left-origin descriptors into PDF's bottom-left origin.
    private static func drawPage(_ descriptors: [RenderDescriptor], size: CGSize, scale: CGFloat,
                                 into ctx: CGContext) {
        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageSize.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: (pageSize.width - size.width * scale) / 2, y: margin)
        ctx.scaleBy(x: scale, y: scale)
        renderDescriptors(descriptors, into: ctx)
        ctx.restoreGState()
        ctx.endPDFPage()
    }
}

// MARK: - PNG

enum PNGExporter {

    /// Renders the tile as a PNG at the given pixel scale (default 2×).
    static func export(doc: PatternDocument, scale: CGFloat = 2) throws -> Data {
        let (tileSize, tileDescs) = ExportTile.make(doc)

        let pixelW = Int(tileSize.width  * scale)
        let pixelH = Int(tileSize.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelW, height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: pixelW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ExportError.renderingFailed }

        ctx.scaleBy(x: scale, y: scale)
        // Flip Y so top-left-origin descriptors render correctly in bitmap space
        ctx.translateBy(x: 0, y: tileSize.height)
        ctx.scaleBy(x: 1, y: -1)

        renderDescriptors(tileDescs, into: ctx)

        guard let cgImage = ctx.makeImage() else { throw ExportError.renderingFailed }

        #if os(macOS)
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.renderingFailed
        }
        return data
        #else
        guard let data = UIImage(cgImage: cgImage).pngData() else {
            throw ExportError.renderingFailed
        }
        return data
        #endif
    }
}

// MARK: - Shared tile layout

/// The tile page shared by every export: the canvas's descriptors, stitches and legend
/// included, without the domain highlight.
enum ExportTile {
    static func make(_ doc: PatternDocument) -> (size: CGSize, descriptors: [RenderDescriptor]) {
        let size = DescriptorBuilder.tileCanvasSize(
            H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth, stitches: doc.stitches)
        let descriptors = DescriptorBuilder.tileDescriptors(
            grid: doc.grid, H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex,
            domainCells: doc.domainSet, showDomain: false,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip, corner: doc.corner,
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth, stitches: doc.stitches,
            noStitch: ShapingResolver.resolve(doc.stitches).noStitch)
        return (size, descriptors)
    }
}

// MARK: - Shared CoreGraphics helpers

private func renderDescriptors(_ descriptors: [RenderDescriptor], into ctx: CGContext) {
    for descriptor in descriptors {
        switch descriptor {
        case .rect(let r):
            let rect = CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
            if let fill = cgColor(r.fill) {
                ctx.setFillColor(fill)
                ctx.fill(rect)
            }
            if r.outlineWidth > 0, let stroke = cgColor(r.outline) {
                ctx.setStrokeColor(stroke)
                ctx.setLineWidth(r.outlineWidth)
                ctx.stroke(rect)
            }
        case .text(let t):
            drawText(t.text, at: CGPoint(x: t.x, y: t.y),
                     fontSize: t.fontSize, hexColor: t.fill, leading: t.leading, ctx: ctx)
        case .line(let l):
            if let stroke = cgColor(l.fill) {
                ctx.setStrokeColor(stroke)
                ctx.setLineWidth(l.width)
                ctx.move(to: CGPoint(x: l.x1, y: l.y1))
                ctx.addLine(to: CGPoint(x: l.x2, y: l.y2))
                ctx.strokePath()
            }
        case .circle(let c):
            if let color = cgColor(c.fill) {
                let rect = CGRect(x: c.cx - c.r, y: c.cy - c.r, width: 2 * c.r, height: 2 * c.r)
                if c.filled {
                    ctx.setFillColor(color)
                    ctx.fillEllipse(in: rect)
                } else {
                    ctx.setStrokeColor(color)
                    ctx.setLineWidth(c.width)
                    ctx.strokeEllipse(in: rect)
                }
            }
        }
    }
}

private func cgColor(_ hex: String) -> CGColor? {
    guard let (r, g, b) = ColorMath.hexToRGB(hex) else { return nil }
    return CGColor(red: CGFloat(r) / 255,
                   green: CGFloat(g) / 255,
                   blue: CGFloat(b) / 255,
                   alpha: 1)
}

private func drawText(_ text: String, at point: CGPoint,
                       fontSize: CGFloat, hexColor: String, leading: Bool = false, ctx: CGContext) {
    guard let color = cgColor(hexColor) else { return }
    let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName:            font,
        kCTForegroundColorAttributeName: color,
    ]
    let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, [])

    // The context has a Y-flip applied, which also flips CoreText glyphs (upside-down
    // and mirrored). Fix: translate to the target point, locally un-flip, then draw
    // with a normal text matrix so glyphs render correctly.
    ctx.saveGState()
    ctx.translateBy(x: point.x, y: point.y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textMatrix = .identity
    let cx = leading ? bounds.origin.x : bounds.origin.x + bounds.width / 2
    let cy = bounds.origin.y + bounds.height / 2
    ctx.textPosition = CGPoint(x: -cx, y: -cy)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}
