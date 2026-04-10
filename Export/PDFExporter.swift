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

    static func export(doc: PatternDocument, includeTiling: Bool = true) throws -> Data {
        let tileSize = DescriptorBuilder.tileCanvasSize(
            H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth)

        let tileDescs = DescriptorBuilder.tileDescriptors(
            grid: doc.grid, H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex,
            domainCells: doc.domainSet, showDomain: false,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip, corner: doc.corner,
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.renderingFailed
        }

        // ---- Page 1: Tile ----
        var mediaBox = CGRect(origin: .zero, size: tileSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderingFailed
        }

        ctx.beginPDFPage(nil)
        applyYFlip(ctx, pageHeight: tileSize.height)
        renderDescriptors(tileDescs, into: ctx)
        ctx.endPDFPage()

        // ---- Page 2: Tiling preview (optional) ----
        if includeTiling && !doc.tilingDescriptors.isEmpty {
            let cs     = CGFloat(doc.tiling.previewCellSize)
            let pad: CGFloat = 1
            let previewW = CGFloat(doc.tilingCols) * cs + 2 * pad
            let previewH = CGFloat(doc.tilingRows) * cs + 2 * pad
            var previewBox = CGRect(x: 0, y: 0, width: previewW, height: previewH)
            let mediaBoxData = NSData(bytes: &previewBox, length: MemoryLayout.size(ofValue: previewBox))
            ctx.beginPDFPage([kCGPDFContextMediaBox: mediaBoxData] as CFDictionary)
            applyYFlip(ctx, pageHeight: previewH)
            renderDescriptors(doc.tilingDescriptors, into: ctx)
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return data as Data
    }

    /// Y-flip so top-left-origin descriptors map into PDF's bottom-left origin.
    private static func applyYFlip(_ ctx: CGContext, pageHeight: CGFloat) {
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)
    }
}

// MARK: - PNG

enum PNGExporter {

    /// Renders the tile as a PNG at the given pixel scale (default 2×).
    static func export(doc: PatternDocument, scale: CGFloat = 2) throws -> Data {
        let tileSize = DescriptorBuilder.tileCanvasSize(
            H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth)

        let tileDescs = DescriptorBuilder.tileDescriptors(
            grid: doc.grid, H: doc.H, W: doc.W, cellSize: CGFloat(doc.cellSize),
            fillColor: doc.fillColor.hex, bgColor: doc.bgColor.hex,
            domainCells: doc.domainSet, showDomain: false,
            colStrip: doc.colStrip, rowStrip: doc.rowStrip, corner: doc.corner,
            hOn: doc.tiling.hRepeat, vOn: doc.tiling.vRepeat,
            stripWidth: doc.tiling.stripWidth)

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
                     fontSize: t.fontSize, hexColor: t.fill, ctx: ctx)
        case .line(let l):
            if let stroke = cgColor(l.fill) {
                ctx.setStrokeColor(stroke)
                ctx.setLineWidth(l.width)
                ctx.move(to: CGPoint(x: l.x1, y: l.y1))
                ctx.addLine(to: CGPoint(x: l.x2, y: l.y2))
                ctx.strokePath()
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
                       fontSize: CGFloat, hexColor: String, ctx: CGContext) {
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
    let cx = bounds.origin.x + bounds.width  / 2
    let cy = bounds.origin.y + bounds.height / 2
    ctx.textPosition = CGPoint(x: -cx, y: -cy)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}
