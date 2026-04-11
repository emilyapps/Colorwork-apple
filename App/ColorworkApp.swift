// ColorworkApp.swift
// @main entry point. Configures SwiftData container and injects PatternDocument.

import SwiftUI
import SwiftData

@main
struct ColorworkApp: App {

    private let modelContainer: ModelContainer = {
        let schema = Schema([SDPattern.self, SDProject.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                            cloudKitDatabase: .automatic)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            WindowRootView()
                .modelContainer(modelContainer)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands { ColorworkCommands() }
        #endif
    }
}
