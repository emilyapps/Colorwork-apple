// ContentView.swift
// Root navigation: NavigationSplitView on Mac/iPad, TabView on iPhone.

import SwiftUI
import SwiftData

// Each window owns its own PatternDocument — ensures new windows are independent.
struct WindowRootView: View {
    @State private var document    = PatternDocument()
    @State private var undoManager = UndoManager()

    var body: some View {
        ContentView()
            .environment(document)
            .onAppear {
                undoManager.levelsOfUndo = 50
                document.undoManager = undoManager
            }
            #if os(macOS)
            .focusedSceneValue(\.patternDocument, document)
            #endif
    }
}

struct ContentView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        #if os(macOS)
        macContent
        #else
        adaptiveContent
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var macContent: some View {
        PatternEditorView()
            .navigationTitle(doc.currentPatternName)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    saveLoadMenu
                }
            }
            .focusedSceneValue(\.savePatternAction, {
                saveName = doc.currentPatternName == "Untitled" ? "" : doc.currentPatternName
                saveType = .pattern
                showSaveAlert = true
            })
            .focusedSceneValue(\.saveProjectAction, {
                saveName = doc.currentPatternName == "Untitled" ? "" : doc.currentPatternName
                saveType = .project
                showSaveAlert = true
            })
    }
    #endif

    // MARK: - iOS adaptive

    #if os(iOS)
    private var adaptiveContent: some View {
        Group {
            if sizeClass == .regular {
                // iPad: use split view
                NavigationSplitView {
                    LibraryView()
                } detail: {
                    PatternEditorView()
                }
            }
            else {
                // iPhone: tab bar
                TabView {
                    NavigationStack {
                        PatternEditorView()
                            .navigationTitle(doc.currentPatternName)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    saveLoadMenu
                                }
                            }
                    }
                    .tabItem { Label("Editor", systemImage: "square.grid.3x3") }

                    NavigationStack {
                        LibraryView()
                            .navigationTitle("Library")
                    }
                    .tabItem { Label("Library", systemImage: "folder") }
                }
            }
        }
    }
    #endif

    // MARK: - Persistence actions

    private enum SaveType { case pattern, project }

    @State private var saveName      = ""
    @State private var showSaveAlert = false
    @State private var saveType: SaveType = .pattern

    private var saveLoadMenu: some View {
        Menu {
            Button("Save Pattern…") {
                saveName  = doc.currentPatternName == "Untitled" ? "" : doc.currentPatternName
                saveType  = .pattern
                showSaveAlert = true
            }
            Button("Save Project…") {
                saveName  = doc.currentPatternName == "Untitled" ? "" : doc.currentPatternName
                saveType  = .project
                showSaveAlert = true
            }
        } label: {
            Label("Library", systemImage: "folder")
        }
        .alert(saveType == .pattern ? "Save Pattern" : "Save Project",
               isPresented: $showSaveAlert) {
            TextField("Name", text: $saveName)
            Button("Save") { commitSave() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func commitSave() {
        let name = saveName.isEmpty
            ? (saveType == .pattern ? "Pattern" : "Project")
            : saveName
        let store = PatternStore(context: modelContext)
        switch saveType {
        case .pattern: try? store.savePattern(from: doc, name: name)
        case .project: try? store.saveProject(from: doc, name: name)
        }
    }
}

// MARK: - LibraryView

struct LibraryView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @Query(sort: \SDPattern.createdAt, order: .reverse) var patterns: [SDPattern]
    @Query(sort: \SDProject.createdAt, order: .reverse) var projects: [SDProject]

    @State private var selectedTab = 0
    @State private var saveName    = ""
    @State private var statusMsg   = ""
    @FocusState private var nameFieldFocused: Bool

    @State private var patternPendingDelete: SDPattern? = nil
    @State private var projectPendingDelete: SDProject? = nil

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Patterns").tag(0)
                Text("Projects").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                patternList
            } else {
                projectList
            }
        }
        .navigationTitle("Library")
    }

    private var patternList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(patterns) { p in
                    Button {
                        PatternStore(context: modelContext).loadPattern(p, into: doc)
                        statusMsg = "Loaded \(p.name)"
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            thumbView(p.thumbnailData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text("\(p.gridW)×\(p.gridH)  \(p.symmetryGroup.uppercased())  \(dateString(p.createdAt))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            patternPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { idxs in
                    if let i = idxs.first { patternPendingDelete = patterns[i] }
                }
            }

            Divider()

            VStack(spacing: 8) {
                TextField("Name…", text: $saveName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFieldFocused)
                Button("Save Pattern") {
                    nameFieldFocused = false
                    let name = saveName.isEmpty ? "Pattern" : saveName
                    try? PatternStore(context: modelContext).savePattern(from: doc, name: name)
                    statusMsg = "Saved \(name)"
                    saveName = ""
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                if !statusMsg.isEmpty {
                    Text(statusMsg).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .confirmationDialog(
            "Delete \"\(patternPendingDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { patternPendingDelete != nil },
                set: { if !$0 { patternPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = patternPendingDelete {
                    try? PatternStore(context: modelContext).deletePattern(p)
                }
                patternPendingDelete = nil
            }
        }
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(projects) { p in
                    Button {
                        try? PatternStore(context: modelContext).loadProject(p, into: doc)
                        statusMsg = "Loaded \(p.name)"
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            thumbView(p.thumbnailData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text(dateString(p.createdAt))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            projectPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { idxs in
                    if let i = idxs.first { projectPendingDelete = projects[i] }
                }
            }

            Divider()

            VStack(spacing: 8) {
                TextField("Name…", text: $saveName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Project") {
                    let name = saveName.isEmpty ? "Project" : saveName
                    try? PatternStore(context: modelContext).saveProject(from: doc, name: name)
                    statusMsg = "Saved \(name)"
                    saveName = ""
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                if !statusMsg.isEmpty {
                    Text(statusMsg).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .confirmationDialog(
            "Delete \"\(projectPendingDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { projectPendingDelete != nil },
                set: { if !$0 { projectPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = projectPendingDelete {
                    try? PatternStore(context: modelContext).deleteProject(p)
                }
                projectPendingDelete = nil
            }
        }
    }

    @ViewBuilder
    private func thumbView(_ data: Data?, size: CGFloat) -> some View {
        Group {
            #if os(iOS)
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFit()
            } else { placeholderThumb }
            #else
            if let d = data, let img = NSImage(data: d) {
                Image(nsImage: img).resizable().scaledToFit()
            } else { placeholderThumb }
            #endif
        }
        .frame(width: size, height: size)
        .cornerRadius(4)
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .overlay(Image(systemName: "squareshape.split.3x3").foregroundStyle(.secondary))
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
