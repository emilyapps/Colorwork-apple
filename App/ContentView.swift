// ContentView.swift
// Root navigation: NavigationSplitView on Mac/iPad, TabView on iPhone.

import SwiftUI
import SwiftData

// Each window owns its own PatternDocument — ensures new windows are independent.
struct WindowRootView: View {
    @State private var document    = PatternDocument()
    @State private var undoManager = UndoManager()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase)   private var scenePhase
    var body: some View {
        ContentView()
            .environment(document)
            .onAppear {
                undoManager.levelsOfUndo = 50
                document.undoManager = undoManager
            }
            .task {
                let store = PatternStore(context: modelContext)
                store.openInitialProject(into: document)
                // Autosave: write the open Project about once a second when it changed.
                while !Task.isCancelled {
                    store.autosave(document)
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { PatternStore(context: modelContext).autosave(document) }
            }
            .onDisappear { PatternStore(context: modelContext).autosave(document) }
            #if os(macOS)
            .focusedSceneValue(\.patternDocument, document)
            #endif
    }
}

struct ContentView: View {
    @Environment(PatternDocument.self) var doc
    @Environment(\.horizontalSizeClass) var sizeClass

    private enum Tab { case editor, library }
    @State private var tab: Tab = .editor

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
                TabView(selection: $tab) {
                    NavigationStack {
                        PatternEditorView()
                    }
                    .tabItem { Label("Editor", systemImage: "square.grid.3x3") }
                    .tag(Tab.editor)

                    NavigationStack {
                        LibraryView(onOpen: { tab = .editor })
                            .navigationTitle("Library")
                    }
                    .tabItem { Label("Library", systemImage: "folder") }
                    .tag(Tab.library)
                }
            }
        }
    }
    #endif
}

// MARK: - Project commands
// New Project, Rename, Duplicate, Save as Pattern — shared by the iOS title menu
// and the Mac toolbar menu / menu bar.

struct ProjectCommands: ViewModifier {
    @Environment(PatternDocument.self) var doc
    @Environment(\.modelContext) var modelContext
    var export: () -> Void

    @State private var patternName       = ""
    @State private var showPatternName   = false
    @State private var confirmReplace    = false
    @State private var renameText        = ""
    @State private var showRename        = false

    private var store: PatternStore { PatternStore(context: modelContext) }

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationTitle(doc.currentPatternName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbarTitleMenu { menuItems }
            #else
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Menu { menuItems } label: { Label("Project", systemImage: "doc") }
                }
            }
            .focusedSceneValue(\.savePatternAction, beginSaveAsPattern)
            .focusedSceneValue(\.newProjectAction, { store.newProject(into: doc) })
            .focusedSceneValue(\.duplicateProjectAction, { store.duplicateProject(doc) })
            #endif
            .alert("Rename Project", isPresented: $showRename) {
                TextField("Name", text: $renameText)
                Button("Rename") { store.rename(doc, to: renameText) }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Save as Pattern", isPresented: $showPatternName) {
                TextField("Name", text: $patternName)
                Button("Save") { checkAndSavePattern() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Opening a pattern starts a new project.")
            }
            .confirmationDialog("Replace the existing pattern \"\(patternName)\"?",
                                isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace", role: .destructive) { store.saveAsPattern(doc, name: patternName) }
            }
    }

    @ViewBuilder private var menuItems: some View {
        Button("New Project", systemImage: "plus") { store.newProject(into: doc) }
        Button("Rename…", systemImage: "pencil") {
            renameText = doc.currentPatternName
            showRename = true
        }
        Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicateProject(doc) }
        Button("Save as Pattern…", systemImage: "square.and.arrow.down") { beginSaveAsPattern() }
        Button("Export…", systemImage: "square.and.arrow.up") { export() }
    }

    private func beginSaveAsPattern() {
        patternName = doc.currentPatternName
        showPatternName = true
    }

    private func checkAndSavePattern() {
        let name = patternName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        patternName = name
        if store.pattern(named: name) != nil { confirmReplace = true }
        else { store.saveAsPattern(doc, name: name) }
    }
}

// MARK: - LibraryView

struct LibraryView: View {
    var onOpen: () -> Void = {}
    @Environment(PatternDocument.self) var doc
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @Query(sort: [SortDescriptor(\SDPattern.sortOrder),
                  SortDescriptor(\SDPattern.createdAt, order: .reverse)]) var patterns: [SDPattern]
    @Query(sort: [SortDescriptor(\SDProject.modifiedAt, order: .reverse),
                  SortDescriptor(\SDProject.createdAt, order: .reverse)]) var projects: [SDProject]
    @State private var selectedProjects = Set<UUID>()
    @State private var confirmBulkDelete = false
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    @State private var selectedTab = 0

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
        #if os(iOS)
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { _, mode in if !mode.isEditing { selectedProjects = [] } }
        .onChange(of: selectedTab) { _, _ in editMode = .inactive }
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
                .fontWeight(editMode.isEditing ? .semibold : .regular)
            }
            #endif
            if selectedTab == 1 {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Project", systemImage: "plus") {
                        PatternStore(context: modelContext).newProject(into: doc)
                        onOpen()
                    }
                }
            }
        }
    }

    private var patternList: some View {
        VStack(spacing: 0) {
            List {
                Section {
                ForEach(patterns) { p in
                    Button {
                        PatternStore(context: modelContext).startProject(from: p, into: doc)
                        onOpen()
                    } label: {
                        HStack(spacing: 10) {
                            thumbView(p.thumbnailData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text("\(p.gridW)×\(p.gridH)  \(p.symmetryGroup.uppercased())  \(dateString(p.createdAt))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            patternPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { idxs in
                    if let i = idxs.first { patternPendingDelete = patterns[i] }
                }
                .onMove(perform: movePatterns)
            } footer: {
                Text("Opening a pattern starts a new project.")
            }
            }

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
            List(selection: $selectedProjects) {
                ForEach(projects) { p in
                    Button {
                        PatternStore(context: modelContext).openProject(p, into: doc)
                        onOpen()
                    } label: {
                        HStack(spacing: 10) {
                            thumbView(p.thumbnailData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text("Edited " + dateString(p.modifiedAt ?? p.createdAt))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            projectPendingDelete = p
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .contextMenu {
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            PatternStore(context: modelContext).duplicate(p)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            projectPendingDelete = p
                        }
                    }
                }
            }
            #if os(iOS)
            if editMode.isEditing { bulkBar }
            #endif

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
                    let store = PatternStore(context: modelContext)
                    let wasOpen = p.id == doc.currentProjectID
                    try? store.deleteProject(p)
                    // The open Project is gone, so start a fresh one to autosave into.
                    if wasOpen { doc.currentProjectID = nil; store.newProject(into: doc) }
                }
                projectPendingDelete = nil
            }
        }
    }

    #if os(iOS)
    /// Edit-mode bar: select all, delete the selected Projects (Files/Photos style).
    private var bulkBar: some View {
        HStack {
            Button(selectedProjects.count == projects.count ? "Deselect All" : "Select All") {
                selectedProjects = selectedProjects.count == projects.count
                    ? [] : Set(projects.map(\.id))
            }
            Spacer()
            Button("Delete", role: .destructive) { confirmBulkDelete = true }
                .disabled(selectedProjects.isEmpty)
        }
        .padding()
        .background(.bar)
        .confirmationDialog(
            selectedProjects.count == 1 ? "Delete 1 project?" : "Delete \(selectedProjects.count) projects?",
            isPresented: $confirmBulkDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("This can't be undone. Patterns are not affected.")
        }
    }

    private func deleteSelected() {
        let doomed = projects.filter { selectedProjects.contains($0.id) }
        let store = PatternStore(context: modelContext)
        let openDeleted = doomed.contains { $0.id == doc.currentProjectID }
        store.deleteProjects(doomed)
        selectedProjects = []
        editMode = .inactive
        if openDeleted { doc.currentProjectID = nil; store.newProject(into: doc) }
    }
    #endif

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

    private func movePatterns(from offsets: IndexSet, to destination: Int) {
        var reordered = patterns
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (idx, p) in reordered.enumerated() { p.sortOrder = idx }
        try? modelContext.save()
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
