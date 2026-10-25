// SymmetryVisualEquivalentTests.swift
// Symmetry Groups with stitches (ADR 0001): linked cells carry their Transformation,
// stitches copy as Visual Equivalents, and stitches limit which groups are allowed.

import Foundation
import Testing
@testable import Colorwork

struct SymmetryVisualEquivalentTests {

    // MARK: Linked cells

    /// Where cell (1, 2) of a 6×6 grid lands under each Transformation.
    static let expected: [Transformation: CellIndex] = [
        .identity:                   CellIndex(row: 1, col: 2),
        .verticalAxisReflection:     CellIndex(row: 1, col: 3),
        .horizontalAxisReflection:   CellIndex(row: 4, col: 2),
        .halfTurn:                   CellIndex(row: 4, col: 3),
        .quarterTurn:                CellIndex(row: 2, col: 4),
        .threeQuarterTurn:           CellIndex(row: 3, col: 1),
        .diagonalAxisReflection:     CellIndex(row: 2, col: 1),
        .antiDiagonalAxisReflection: CellIndex(row: 3, col: 4),
    ]

    @Test(arguments: [
        (SymmetryGroup.c1, [Transformation.identity]),
        (.d1,  [.identity, .verticalAxisReflection]),
        (.d1h, [.identity, .horizontalAxisReflection]),
        (.c2,  [.identity, .halfTurn]),
        (.d2,  [.identity, .verticalAxisReflection, .horizontalAxisReflection, .halfTurn]),
        (.c4,  [.identity, .quarterTurn, .halfTurn, .threeQuarterTurn]),
        (.d4,  Transformation.allCases),
    ])
    func linkedCellsPairEachCellWithItsTransformation(group: SymmetryGroup, transformations: [Transformation]) {
        let linked = group.linkedCells(1, 2, H: 6, W: 6)
        #expect(Set(linked.map(\.transformation)) == Set(transformations))
        for (cell, t) in linked {
            #expect(cell == Self.expected[t], "\(group) \(t)")
        }
        #expect(group.orbit(1, 2, H: 6, W: 6) == Set(linked.map(\.cell)))
    }

    @Test func storedSymmetryStringsStillLoad() {
        #expect(SymmetryGroup(rawValue: "d1") == .d1)
        #expect(SymmetryGroup(rawValue: "d1h") == .d1h)
    }

    // MARK: Visual Equivalents

    @Test(arguments: [
        (Stitch.k2tog, Stitch.ssk), (.k3tog, .sssk), (.m1r, .m1l),
        (.knit, .knit), (.purl, .purl), (.yarnOver, .yarnOver),
        (.centeredDoubleDecrease, .centeredDoubleDecrease),
    ])
    func verticalAxisReflectionSwapsLean(stitch: Stitch, mirror: Stitch) {
        #expect(stitch.visualEquivalent(under: .verticalAxisReflection) == mirror)
        #expect(mirror.visualEquivalent(under: .verticalAxisReflection) == stitch)
    }

    @Test(arguments: Stitch.allCases)
    func applyingAVisualEquivalentTwiceGivesBackTheStitch(stitch: Stitch) {
        for t in [Transformation.identity, .verticalAxisReflection, .horizontalAxisReflection,
                  .halfTurn, .diagonalAxisReflection, .antiDiagonalAxisReflection] {
            if let once = stitch.visualEquivalent(under: t) {
                #expect(once.visualEquivalent(under: t) == stitch, "\(stitch) \(t)")
            }
        }
    }

    // MARK: Allowed groups and the downgrade

    @Test func allKnitAllowsEveryGroup() {
        #expect(SymmetryGroup.allCases.allSatisfy { $0.allows([.knit]) })
    }

    @Test(arguments: [Stitch.purl, .yarnOver])
    func directionlessStitchesAllowEveryGroup(stitch: Stitch) {
        #expect(SymmetryGroup.allCases.allSatisfy { $0.allows([.knit, stitch]) })
    }

    @Test(arguments: [Stitch.k2tog, .ssk, .k3tog, .sssk, .centeredDoubleDecrease, .m1r, .m1l])
    func decreasesAndLeaningIncreasesAllowOnlyC1AndD1V(stitch: Stitch) {
        let allowed = Set(SymmetryGroup.allCases.filter { $0.allows([stitch]) })
        #expect(allowed == [.c1, .d1])
    }

    @Test(arguments: [
        (SymmetryGroup.d4, SymmetryGroup.d1), (.d2, .d1),
        (.c4, .c1), (.c2, .c1), (.d1h, .c1),
        (.d1, .d1), (.c1, .c1),
    ])
    func downgradeGoesToTheLargestAllowedGroupWithinTheCurrentOne(from: SymmetryGroup, to: SymmetryGroup) {
        #expect(from.largestGroupAllowing([.k2tog]) == to)
    }

    // MARK: Painting

    @Test func paintingUnderD1VPlacesTheMirrorStitch() {
        let doc = PatternDocument()
        doc.symmetryGroup = .d1
        doc.paintStitch(.k2tog, at: CellIndex(row: 2, col: 1))
        #expect(doc.stitches[2][1] == .k2tog)
        #expect(doc.stitches[2][doc.W - 2] == .ssk)
    }

    @Test func paintingADisallowedStitchDowngradesWithANoticeAndOneUndoRestoresBoth() {
        let doc = PatternDocument()
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.undoManager = undo
        #expect(doc.symmetryGroup == .d4)

        undo.beginUndoGrouping()
        doc.pushUndo("Paint")            // the canvas does this at the start of a drag
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 1))
        undo.endUndoGrouping()

        #expect(doc.symmetryGroup == .d1)
        #expect(doc.symmetryNotice != nil)
        #expect(doc.stitches[0][doc.W - 2] == .ssk)

        undo.undo()
        #expect(doc.symmetryGroup == .d4)
        #expect(doc.stitches.joined().allSatisfy { $0 == .knit })
    }

    @Test func erasingTheLastLimitingStitchReenablesGroupsWithoutSwitching() {
        let doc = PatternDocument()
        doc.paintStitch(.k2tog, at: CellIndex(row: 0, col: 1))
        #expect(doc.allowedSymmetryGroups == [.c1, .d1])

        doc.paintStitch(.knit, at: CellIndex(row: 0, col: 1))
        #expect(doc.symmetryGroup == .d1)
        #expect(doc.allowedSymmetryGroups == Set(SymmetryGroup.allCases))
    }
}
