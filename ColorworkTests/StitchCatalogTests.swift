// StitchCatalogTests.swift
// Lean and stitch-count change drive the Shaping Resolver (ADR 0002),
// so these values are a contract, not just data.

import Testing
@testable import Colorwork

struct StitchCatalogTests {

    @Test(arguments: [
        (Stitch.knit,                   Lean.none,   0),
        (.purl,                         .none,       0),
        (.k2tog,                        .right,     -1),
        (.ssk,                          .left,      -1),
        (.centeredDoubleDecrease,       .center,    -2),
        (.k3tog,                        .right,     -2),
        (.sssk,                         .left,      -2),
        (.yarnOver,                     .none,       1),
        (.m1r,                          .right,      1),
        (.m1l,                          .left,       1),
    ])
    func leanAndStitchCountChange(stitch: Stitch, lean: Lean, change: Int) {
        #expect(stitch.lean == lean)
        #expect(stitch.stitchCountChange == change)
    }
}
