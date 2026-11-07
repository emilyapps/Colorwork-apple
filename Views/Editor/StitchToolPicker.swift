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
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func toolButton<Label: View>(_ tool: PatternDocument.PaintTool, help: String,
                                         @ViewBuilder label: () -> Label) -> some View {
        let selected = doc.paintTool == tool
        return Button { doc.paintTool = tool } label: {
            label()
                .frame(width: 26, height: 26)
                .background(selected ? Color.accentColor.opacity(0.25) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
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

// MARK: - iPhone stitch bar
// Brush, the 4 most recently used stitches, and More (a labelled grid of every stitch).
// Every target is at least 44pt (Apple HIG).

struct StitchBar: View {
    @Environment(PatternDocument.self) var doc
    @AppStorage("recentStitches") private var recentRaw = ""
    @State private var showAll = false

    private static let recentCount = 4

    private var recents: [Stitch] {
        var list = recentRaw.split(separator: ",").compactMap { Stitch(rawValue: String($0)) }
        for s in Stitch.allCases where list.count < Self.recentCount && !list.contains(s) {
            list.append(s)
        }
        return Array(list.prefix(Self.recentCount))
    }

    var body: some View {
        HStack(spacing: 6) {
            barButton(.color, label: "Paint colors") {
                Image(systemName: "paintbrush.pointed").font(.title3)
            }
            Divider().frame(height: 28)
            ForEach(recents, id: \.self) { stitch in
                barButton(.stitch(stitch), label: stitch.displayName) {
                    StitchSymbolView(stitch: stitch)
                }
            }
            Spacer(minLength: 0)
            Button { showAll = true } label: {
                Label("All", systemImage: "square.grid.2x2")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("All Stitches")
            .popover(isPresented: $showAll) {
                allStitches.presentationCompactAdaptation(.popover)
            }
        }
    }

    private var allStitches: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], spacing: 4) {
                ForEach(Stitch.allCases, id: \.self) { stitch in
                    Button { choose(stitch); showAll = false } label: {
                        HStack(spacing: 10) {
                            StitchSymbolView(stitch: stitch)
                            Text(stitch.displayName).foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                        .background(doc.paintTool == .stitch(stitch) ? Color.accentColor.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(doc.paintTool == .stitch(stitch) ? .isSelected : [])
                }
            }
            .padding()
        }
        .frame(minWidth: 320, idealHeight: 380)
        .presentationDetents([.height(380)])
    }

    private func choose(_ stitch: Stitch) {
        doc.paintTool = .stitch(stitch)
        var list = recentRaw.split(separator: ",").map(String.init).filter { $0 != stitch.rawValue }
        list.insert(stitch.rawValue, at: 0)
        recentRaw = list.prefix(8).joined(separator: ",")
    }

    private func barButton<L: View>(_ tool: PatternDocument.PaintTool, label: String,
                                    @ViewBuilder content: () -> L) -> some View {
        let selected = doc.paintTool == tool
        return Button {
            if case .stitch(let s) = tool { choose(s) } else { doc.paintTool = tool }
        } label: {
            content()
                .frame(width: 44, height: 44)
                .background(selected ? Color.accentColor.opacity(0.25) : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
