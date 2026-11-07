// PatternEditorView.swift
// macOS: sidebar (290px) + dual canvas (pattern left, tiling right)
// iOS:   canvas full-screen + toolbar buttons opening sheets

import SwiftUI
import UniformTypeIdentifiers

struct PatternEditorView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showControls     = false
    @State private var showColors       = false
    @State private var showTiling       = false
    @State private var showExportPicker = false

    var body: some View {
        Group {
            #if os(macOS)
            macLayout
            #else
            iphoneLayout
            #endif
        }
        .modifier(ProjectCommands(export: export))
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
                    HStack {
                        Text("Pattern")
                            .font(.footnote.weight(.semibold))
                        StitchToolPicker()
                    }
                    .padding([.top, .leading], 8)
                    GridCanvasView()
                }
                .frame(minWidth: 300, idealWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text(doc.kind == .tile ? "Tiling Preview"
                         : doc.wedgeView == .chart ? "Chart View" : "Circular View")
                        .font(.footnote.weight(.semibold))
                        .padding([.top, .leading], 8)
                    if doc.kind == .wedge { WedgePreviewView() } else { TilingPreviewView() }
                }
                .frame(minWidth: 300, idealWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Generate") { doc.generate() }
                Button("Clear")    { doc.clear() }
                Button("Fit to Screen", systemImage: "arrow.up.left.and.arrow.down.right") { doc.fitCellSize() }
            }
        }
    }
    #endif

    // MARK: - iPhone: canvas + toolbar sheets

    #if os(iOS)
    private var iphoneLayout: some View {
        VStack(spacing: 0) {
            GridCanvasView()
                .ignoresSafeArea(edges: .horizontal)
                .frame(maxHeight: .infinity)

            Divider()

            StitchBar()
                .padding(.horizontal)
                .padding(.vertical, 2)

            Divider()

            // Bottom toolbar: frequent sheets plus Generate; rare actions in the ⋯ menu.
            HStack(spacing: 0) {
                toolbarButton("Generate", "wand.and.stars") { doc.generate() }
                toolbarButton("Settings", "slider.horizontal.3") { showControls.toggle() }
                toolbarButton("Colors", "paintpalette") { showColors.toggle() }
                toolbarButton("Tiling", "square.grid.3x3") { showTiling.toggle() }
                Menu {
                    Button("Fit to Screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                        doc.fitCellSize()
                    }
                    Button("Clear", systemImage: "trash", role: .destructive) { doc.clear() }
                } label: {
                    toolbarLabel("More", "ellipsis.circle")
                }
            }
            .padding(.horizontal, 4)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button("Undo", systemImage: "arrow.uturn.backward") { doc.undo() }
                    .disabled(!doc.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { doc.redo() }
                    .disabled(!doc.canRedo)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export", systemImage: "square.and.arrow.up") { export() }
            }
        }
        .confirmationDialog("Export As", isPresented: $showExportPicker) {
            Button("PDF")  { shareFile(format: .pdf) }
            Button("PNG")  { shareFile(format: .png) }
            Button("SVG")  { shareFile(format: .svg) }
        }
        .sheet(isPresented: $showControls) {
            NavigationStack {
                ControlPanelView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showControls = false }
                        }
                    }
            }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showColors) {
            ColorSheetView()
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

    #if os(iOS)
    private func toolbarButton(_ title: String, _ icon: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) { toolbarLabel(title, icon) }
    }

    /// Icon over a short caption, 44pt+ tall, scaling with Dynamic Type.
    private func toolbarLabel(_ title: String, _ icon: String) -> some View {
        // Like system toolbars: at accessibility sizes the caption is dropped
        // and a long press shows the name in the Large Content Viewer.
        VStack(spacing: 2) {
            Image(systemName: icon).font(.title3)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            if !typeSize.isAccessibilitySize {
                Text(title).font(.caption2).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityShowsLargeContentViewer {
            Image(systemName: icon)
            Text(title)
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
