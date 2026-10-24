// StitchToolPicker.swift
// Row of paint tools: color, then one button per Stitch drawn with its CYC symbol.
// Shared by the macOS canvas header and the iPhone tool bar.

import SwiftUI

struct StitchToolPicker: View {
    @Environment(PatternDocument.self) var doc

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                toolButton(.color, help: "Paint colors") {
                    Image(systemName: "paintbrush.pointed")
                }
                Divider().frame(height: 22)
                ForEach(Stitch.allCases, id: \.self) { stitch in
                    toolButton(.stitch(stitch), help: stitch.displayName) {
                        StitchSymbolView(stitch: stitch)
                    }
                    .disabled(!doc.stitchToolsEnabled)
                }
            }
            .padding(.horizontal, 4)
        }
        .help(doc.stitchToolsEnabled ? "" : "Stitches need C1 symmetry for now")
    }

    private func toolButton<Label: View>(_ tool: PatternDocument.PaintTool, help: String,
                                         @ViewBuilder label: () -> Label) -> some View {
        let selected = doc.paintTool == tool
        return Button { doc.paintTool = tool } label: {
            label()
                .frame(width: 26, height: 26)
                .background(selected ? Color.accentColor.opacity(0.25) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A Stitch's CYC symbol in a small bordered cell.
struct StitchSymbolView: View {
    let stitch: Stitch

    var body: some View {
        Canvas { ctx, size in
            let cs = min(size.width, size.height)
            ctx.stroke(Path(CGRect(x: 0, y: 0, width: cs, height: cs)),
                       with: .color(.secondary), lineWidth: 1)
            for stroke in stitch.symbol {
                switch stroke {
                case .line(let a, let b):
                    var path = Path()
                    path.move(to: CGPoint(x: a.x * cs, y: a.y * cs))
                    path.addLine(to: CGPoint(x: b.x * cs, y: b.y * cs))
                    ctx.stroke(path, with: .color(.primary), lineWidth: 1.5)
                case .circle(let c, let r, let filled):
                    let path = Path(ellipseIn: CGRect(x: (c.x - r) * cs, y: (c.y - r) * cs,
                                                      width: 2 * r * cs, height: 2 * r * cs))
                    if filled { ctx.fill(path, with: .color(.primary)) }
                    else      { ctx.stroke(path, with: .color(.primary), lineWidth: 1.5) }
                }
            }
        }
        .frame(width: 20, height: 20)
    }
}
