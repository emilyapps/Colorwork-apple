// StitchPersistenceTests.swift
// Stitches survive save/load, and saves from before stitches existed still load.

import Foundation
import SwiftData
import Testing
@testable import Colorwork

struct StitchPersistenceTests {

    private func docWithStitch() -> PatternDocument {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        doc.paintStitch(.k2tog, at: CellIndex(row: 3, col: 4))
        return doc
    }

    @Test func projectSnapshotRoundTripKeepsStitches() throws {
        let data = try JSONEncoder().encode(PatternSnapshot(from: docWithStitch()))
        let loaded = PatternDocument()
        try JSONDecoder().decode(PatternSnapshot.self, from: data).apply(to: loaded)
        #expect(loaded.stitches[3][4] == .k2tog)
    }

    @Test func projectSavedBeforeStitchesLoadsAsAllKnit() throws {
        let data = try JSONEncoder().encode(PatternSnapshot(from: docWithStitch()))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "stitches")
        let legacy = try JSONSerialization.data(withJSONObject: json)

        let loaded = PatternDocument()
        try JSONDecoder().decode(PatternSnapshot.self, from: legacy).apply(to: loaded)
        #expect(loaded.stitches.count == loaded.H)
        #expect(loaded.stitches.allSatisfy { $0.count == loaded.W && $0.allSatisfy { $0 == .knit } })
    }

    @MainActor
    private func makeStore() throws -> (PatternStore, ModelContext) {
        let container = try ModelContainer(
            for: SDPattern.self, SDProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        return (PatternStore(context: context), context)
    }

    @MainActor
    @Test func savedPatternRoundTripKeepsStitches() throws {
        let (store, _) = try makeStore()
        try store.savePattern(from: docWithStitch(), name: "lace")
        let saved = try #require(try store.listPatterns().first)

        let loaded = PatternDocument()
        store.loadPattern(saved, into: loaded)
        #expect(loaded.stitches[3][4] == .k2tog)
    }

    @MainActor
    @Test func patternSavedBeforeStitchesLoadsAsAllKnit() throws {
        let (store, context) = try makeStore()
        let legacy = SDPattern(
            name: "old", gridW: 8, gridH: 8, symmetryGroup: "d4",
            fillColor: "#000000", bgColor: "#ffffff", fillDensity: 0.5,
            gridData: try JSONEncoder().encode(Array(repeating: Array(repeating: false, count: 8), count: 8)),
            colStripData: nil, rowStripData: nil, cornerData: nil, tilingData: nil)
        context.insert(legacy)

        let loaded = docWithStitch()          // previous Pattern's stitches must not leak in
        store.loadPattern(legacy, into: loaded)
        #expect(loaded.stitches.count == 8)
        #expect(loaded.stitches.allSatisfy { $0.count == 8 && $0.allSatisfy { $0 == .knit } })
    }
}
