// ShapingResolverTests.swift
// No Stitch is derived from decreases (ADR 0002): each decrease ends a column on the side
// opposite its Lean, from its own row to the top of the chart.

import Testing
@testable import Colorwork

struct ShapingResolverTests {

    /// Builds a stitch grid from rows written top row first; "." is knit.
    private func grid(_ rows: [[Stitch?]]) -> [[Stitch]] {
        rows.map { $0.map { $0 ?? .knit } }
    }

    /// The No Stitch mask as strings, top row first: "x" No Stitch, "." live.
    private func mask(_ stitches: [[Stitch]]) -> [String] {
        ShapingResolver.resolve(stitches).noStitch.map { String($0.map { $0 ? "x" : "." }) }
    }

    @Test func allKnitHasNoNoStitch() {
        let r = ShapingResolver.resolve(Stitch.allKnit(rows: 3, cols: 4))
        #expect(r.noStitch.joined().allSatisfy { !$0 })
        #expect(r.liveStitchesPerRow == [4, 4, 4])
    }

    @Test func k2togEndsTheColumnToItsLeftFromItsOwnRowUp() {
        let s = grid([[nil, nil, nil, nil],
                      [nil, nil, .k2tog, nil],
                      [nil, nil, nil, nil]])
        #expect(mask(s) == [".x..",
                            ".x..",
                            "...."])
        #expect(ShapingResolver.resolve(s).liveStitchesPerRow == [3, 3, 4])
    }

    @Test func sskEndsTheColumnToItsRight() {
        let s = grid([[nil, .ssk, nil, nil]])
        #expect(mask(s) == ["..x."])
    }

    @Test func centeredDoubleDecreaseEndsOneColumnOnEachSide() {
        let s = grid([[nil, nil, .centeredDoubleDecrease, nil, nil]])
        #expect(mask(s) == [".x.x."])
    }

    @Test func k3togAndSsskEndTwoColumnsOnTheirSide() {
        #expect(mask(grid([[nil, nil, nil, .k3tog, nil]])) == [".xx.."])
        #expect(mask(grid([[nil, .sssk, nil, nil, nil]])) == ["..xx."])
    }

    @Test func stackedDecreasesEndTheNextLiveColumn() {
        // A crown-style decrease line: k2tog in the same column every row.
        let s = grid([[nil, nil, nil, .k2tog],
                      [nil, nil, nil, .k2tog],
                      [nil, nil, nil, .k2tog]])
        #expect(mask(s) == ["xxx.",
                            ".xx.",
                            "..x."])
        #expect(ShapingResolver.resolve(s).liveStitchesPerRow == [1, 2, 3])
    }

    @Test func adjacentDecreasesDoNotEndEachOther() {
        let s = grid([[nil, nil, .k2tog, .k2tog, nil]])
        #expect(mask(s) == ["xx..."])
    }

    @Test func decreasesAtTheEdgeWrapIntoTheNextRepeat() {
        #expect(mask(grid([[.k2tog, nil, nil, nil]])) == ["...x"])
        #expect(mask(grid([[nil, nil, nil, .ssk]])) == ["x..."])
    }

    @Test func gapsReflectWithTheirDecreasesUnderD1V() {
        let doc = PatternDocument()
        doc.symmetryGroup = .d1
        doc.paintStitch(.k2tog, at: CellIndex(row: doc.H - 1, col: 2))   // ssk appears at W-3
        let row = doc.noStitch[doc.H - 1]
        #expect(row[1] && row[doc.W - 2])
        #expect(row.filter { $0 }.count == 2)
    }

    @Test func colorsUnderNoStitchAreKeptAndReappear() {
        let doc = PatternDocument()
        doc.symmetryGroup = .c1
        let hidden = CellIndex(row: 0, col: 1)
        doc.grid[0][1] = true
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 2))
        #expect(doc.noStitch[0][1])
        #expect(doc.grid[0][1])                          // still stored

        doc.paintStitch(.knit, at: CellIndex(row: 0, col: 2))
        #expect(!doc.noStitch[hidden.row][hidden.col])
        #expect(doc.grid[0][1])
    }
}
