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

private struct SaveProjectActionKey: FocusedValueKey {
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
    var saveProjectAction: (() -> Void)? {
        get { self[SaveProjectActionKey.self] }
        set { self[SaveProjectActionKey.self] = newValue }
    }
}

// MARK: - Commands

struct ColorworkCommands: Commands {
    @FocusedValue(\.patternDocument)   var doc
    @FocusedValue(\.savePatternAction) var savePattern
    @FocusedValue(\.saveProjectAction) var saveProject

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { doc?.undoManager?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!(doc?.canUndo ?? false))
            Button("Redo") { doc?.undoManager?.redo() }
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
            Button("Save Pattern\u{2026}") { savePattern?() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Save Project\u{2026}") { saveProject?() }
            Divider()
            Button("Export\u{2026}") { if let d = doc { ExportPanel.show(doc: d) } }
                .keyboardShortcut("e", modifiers: .command)
        }
    }
}
#endif
