// PatternEditorView.swift
// macOS: sidebar (290px) + dual canvas (pattern left, tiling right)
// iOS:   canvas full-screen + toolbar buttons opening sheets

import SwiftUI
import UniformTypeIdentifiers

struct PatternEditorView: View {
    @Environment(PatternDocument.self) var doc
    @State private var showControls     = false
    @State private var showColors       = false
    @State private var showTiling       = false
    @State private var showExportPicker = false

    var body: some View {
        #if os(macOS)
        macLayout
        #else
        iphoneLayout
        #endif
    }

    // MARK: - macOS: sidebar + pattern + tiling

    #if os(macOS)
    private var macLayout: some View {
        HStack(spacing: 0) {
            // Left sidebar with 4 tabs
            SidebarView()
            Divider()
            // Main area: pattern canvas + tiling preview side by side
            HSplitView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pattern")
                        .font(.system(size: 13, weight: .semibold))
                        .padding([.top, .leading], 8)
                    GridCanvasView()
                }
                .frame(minWidth: 300, idealWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tiling Preview")
                        .font(.system(size: 13, weight: .semibold))
                        .padding([.top, .leading], 8)
                    TilingPreviewView()
                }
                .frame(minWidth: 300, idealWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export…") { export() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
    #endif

    // MARK: - iPhone: canvas + toolbar sheets

    #if os(iOS)
    private var iphoneLayout: some View {
        ZStack {
            GridCanvasView()
                .ignoresSafeArea(edges: .horizontal)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("", systemImage: "slider.horizontal.3") { showControls.toggle() }
                Spacer()
                Button("", systemImage: "paintpalette")        { showColors.toggle() }
                Spacer()
                Button("", systemImage: "square.grid.3x3")     { showTiling.toggle() }
                Spacer()
                Button("", systemImage: "square.and.arrow.up") { export() }
            }
        }
        .confirmationDialog("Export As", isPresented: $showExportPicker) {
            Button("PDF")  { shareFile(format: .pdf) }
            Button("PNG")  { shareFile(format: .png) }
            Button("SVG")  { shareFile(format: .svg) }
        }
        .sheet(isPresented: $showControls) {
            ControlPanelView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showColors) {
            ColorPickerSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTiling) {
            TilingSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    #endif

    // MARK: - Export

    private func export() {
        #if os(macOS)
        ExportPanel.show(doc: doc)
        #else
        showExportPicker = true
        #endif
    }

    #if os(iOS)
    private func shareFile(format: ExportFormat) {
        guard let data = try? Exporter.exportData(doc: doc, format: format) else { return }
        let ext: String
        switch format {
        case .pdf: ext = "pdf"
        case .png: ext = "png"
        case .svg: ext = "svg"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("colorwork-pattern.\(ext)")
        try? data.write(to: url)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
    #endif
}
