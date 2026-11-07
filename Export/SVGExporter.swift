// SVGExporter.swift
// Renders the tile pattern to an SVG string.
// SVG uses top-left origin natively — no Y-flip needed.

import CoreGraphics
import Foundation

enum SVGExporter {

    static func export(doc: PatternDocument) throws -> Data {
        let (tileSize, tileDescs) = ExportTile.make(doc)

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

            case .circle(let c):
                let paint = c.filled
                    ? "fill=\"\(c.fill)\" stroke=\"none\""
                    : "fill=\"none\" stroke=\"\(c.fill)\" stroke-width=\"\(f(c.width))\""
                lines.append("  <circle cx=\"\(f(c.cx))\" cy=\"\(f(c.cy))\" r=\"\(f(c.r))\" \(paint)/>")

            case .polygon(let p):
                let points = p.points.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " ")
                let stroke = p.outline.map { "stroke=\"\($0)\" stroke-width=\"\(f(p.outlineWidth))\"" } ?? "stroke=\"none\""
                lines.append("  <polygon points=\"\(points)\" fill=\"\(p.fill)\" \(stroke)/>")

            case .text(let t):
                let escaped = t.text
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                lines.append("  <text x=\"\(f(t.x))\" y=\"\(f(t.y))\" font-size=\"\(f(t.fontSize))\" font-family=\"Helvetica, sans-serif\" fill=\"\(t.fill)\" text-anchor=\"\(t.leading ? "start" : "middle")\" dominant-baseline=\"middle\">\(escaped)</text>")
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
