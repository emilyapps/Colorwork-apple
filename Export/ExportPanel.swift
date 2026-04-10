// ExportPanel.swift
// Shows a macOS NSSavePanel with an embedded format picker (PDF / PNG / SVG).
// The format dropdown updates the filename extension live as the user switches.

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

enum ExportPanel {

    static func show(doc: PatternDocument) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "colorwork-pattern.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.isExtensionHidden = false

        // Build the "Format:" accessory view
        let label = NSTextField(labelWithString: "Format:")
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["PDF", "PNG", "SVG"])

        let stack = NSStackView(views: [label, popup])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        panel.accessoryView = stack

        // Handler updates the panel's type + filename when the selection changes.
        // Retained by the panel via objc_setAssociatedObject so it outlives this stack frame.
        let handler = ExportFormatHandler(panel: panel, popup: popup)
        popup.target = handler
        popup.action = #selector(ExportFormatHandler.formatChanged(_:))
        objc_setAssociatedObject(panel, &ExportFormatHandler.retainKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Exporter.exportData(doc: doc, format: handler.selectedFormat) else { return }
            try? data.write(to: url)
        }
    }
}

// MARK: - Format handler

private final class ExportFormatHandler: NSObject {
    static var retainKey = "ExportFormatHandler"

    private weak var panel: NSSavePanel?
    private weak var popup: NSPopUpButton?
    private let exts = ["pdf", "png", "svg"]
    private let utis: [UTType] = [
        .pdf,
        .png,
        UTType("public.svg-image") ?? .data,
    ]

    init(panel: NSSavePanel, popup: NSPopUpButton) {
        self.panel = panel
        self.popup = popup
    }

    var selectedFormat: ExportFormat {
        switch popup?.indexOfSelectedItem ?? 0 {
        case 1: return .png
        case 2: return .svg
        default: return .pdf
        }
    }

    @objc func formatChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        panel?.allowedContentTypes = [utis[idx]]
        guard let panel else { return }
        // Strip old extension and add new one
        let ext = exts[idx]
        var base = panel.nameFieldStringValue
        for e in exts where base.hasSuffix(".\(e)") {
            base = String(base.dropLast(e.count + 1))
            break
        }
        panel.nameFieldStringValue = "\(base).\(ext)"
    }
}
#endif
