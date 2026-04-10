// SVGExporter.swift
// Renders the tile pattern to an SVG string.
// SVG uses top-left origin natively — no Y-flip needed.

import CoreGraphics
import Foundation

enum SVGExporter {

    static func export(doc: PatternDocument) throws -> Data {
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

        let w = tileSize.width
        let h = tileSize.height
        var lines: [String] = []
        lines.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(f(w))\" height=\"\(f(h))\" viewBox=\"0 0 \(f(w)) \(f(h))\">")

        for descriptor in tileDescs {
            switch descriptor {
            case .rect(let r):
                var el = "  <rect x=\"\(f(r.x))\" y=\"\(f(r.y))\" width=\"\(f(r.w))\" height=\"\(f(r.h))\" fill=\"\(r.fill)\""
                if r.outlineWidth > 0 {
                    el += " stroke=\"\(r.outline)\" stroke-width=\"\(f(r.outlineWidth))\""
                } else {
                    el += " stroke=\"none\""
                }
                el += "/>"
                lines.append(el)

            case .line(let l):
                lines.append("  <line x1=\"\(f(l.x1))\" y1=\"\(f(l.y1))\" x2=\"\(f(l.x2))\" y2=\"\(f(l.y2))\" stroke=\"\(l.fill)\" stroke-width=\"\(f(l.width))\"/>")

            case .text(let t):
                let escaped = t.text
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                lines.append("  <text x=\"\(f(t.x))\" y=\"\(f(t.y))\" font-size=\"\(f(t.fontSize))\" font-family=\"Helvetica, sans-serif\" fill=\"\(t.fill)\" text-anchor=\"middle\" dominant-baseline=\"middle\">\(escaped)</text>")
            }
        }

        lines.append("</svg>")
        let svg = lines.joined(separator: "\n")
        guard let data = svg.data(using: .utf8) else { throw ExportError.renderingFailed }
        return data
    }

    private static func f(_ v: CGFloat) -> String {
        String(format: "%.2f", v)
    }
}
