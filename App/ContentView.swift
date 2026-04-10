// ContentView.swift
// Root navigation: NavigationSplitView on Mac/iPad, TabView on iPhone.

import SwiftUI
import SwiftData

// Each window owns its own PatternDocument — ensures new windows are independent.
struct WindowRootView: View {
    @State private var document = PatternDocument()
    var body: some View {
        ContentView()
            .environment(document)
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

    // MARK: - Save / Load menu

    private var saveLoadMenu: some View {
        Menu {
            Button("Save Pattern…")  { savePattern()  }
            Button("Save Project…")  { saveProject()  }
            Divider()
            Button("Load Pattern…")  { /* opens LibraryView sheet */ }
            Button("Load Project…")  { /* opens LibraryView sheet */ }
        } label: {
            Label("Library", systemImage: "folder")
        }
    }

    // MARK: - Persistence actions

    @State private var saveName = ""
    @State private var showSaveAlert = false

    private func savePattern() {
        let store = PatternStore(context: modelContext)
        let name  = doc.currentPatternName == "Untitled" ? "Pattern" : doc.currentPatternName
        try? store.savePattern(from: doc, name: name)
    }

    private func saveProject() {
        let store = PatternStore(context: modelContext)
        let name  = doc.currentPatternName == "Untitled" ? "Project" : doc.currentPatternName
        try? store.saveProject(from: doc, name: name)
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
        List {
            ForEach(patterns) { p in
                Button {
                    PatternStore(context: modelContext).loadPattern(p, into: doc)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.headline)
                        Text("\(p.gridW)×\(p.gridH)  \(p.symmetryGroup.uppercased())  \(dateString(p.createdAt))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idxs in
                for i in idxs {
                    try? PatternStore(context: modelContext).deletePattern(patterns[i])
                }
            }
        }
    }

    private var projectList: some View {
        List {
            ForEach(projects) { p in
                Button {
                    try? PatternStore(context: modelContext).loadProject(p, into: doc)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.headline)
                        Text(dateString(p.createdAt))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { idxs in
                for i in idxs {
                    try? PatternStore(context: modelContext).deleteProject(projects[i])
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
