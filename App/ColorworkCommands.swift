// ColorworkCommands.swift
// macOS menu bar commands wired to the front window's PatternDocument.

#if os(macOS)
import SwiftUI

// MARK: - FocusedValues keys

private struct PatternDocumentKey: FocusedValueKey {
    typealias Value = PatternDocument
}

private struct SavePatternActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct NewProjectActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct DuplicateProjectActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var patternDocument: PatternDocument? {
        get { self[PatternDocumentKey.self] }
        set { self[PatternDocumentKey.self] = newValue }
    }
    var savePatternAction: (() -> Void)? {
        get { self[SavePatternActionKey.self] }
        set { self[SavePatternActionKey.self] = newValue }
    }
    var newProjectAction: (() -> Void)? {
        get { self[NewProjectActionKey.self] }
        set { self[NewProjectActionKey.self] = newValue }
    }
    var duplicateProjectAction: (() -> Void)? {
        get { self[DuplicateProjectActionKey.self] }
        set { self[DuplicateProjectActionKey.self] = newValue }
    }
}

// MARK: - Commands

struct ColorworkCommands: Commands {
    @FocusedValue(\.patternDocument)   var doc
    @FocusedValue(\.savePatternAction) var savePattern
    @FocusedValue(\.newProjectAction)       var newProject
    @FocusedValue(\.duplicateProjectAction) var duplicateProject

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { doc?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!(doc?.canUndo ?? false))
            Button("Redo") { doc?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!(doc?.canRedo ?? false))
        }

        CommandMenu("Pattern") {
            Button("Generate") { doc?.generate() }
                .keyboardShortcut("g", modifiers: .command)
            Button("Clear Grid") { doc?.clear() }
                .keyboardShortcut(.delete, modifiers: .command)
        }

        CommandGroup(after: .saveItem) {
            Button("New Project") { newProject?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Duplicate") { duplicateProject?() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Save as Pattern\u{2026}") { savePattern?() }
                .keyboardShortcut("s", modifiers: .command)
            Divider()
            Button("Export\u{2026}") { if let d = doc { ExportPanel.show(doc: d) } }
                .keyboardShortcut("e", modifiers: .command)
        }
    }
}
#endif
