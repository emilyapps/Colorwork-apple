# Notes for next session

_Last updated 2026-10-24._

## Where things stand

- The stitches-and-wedges feature is finished. All its issues are closed: the PRD #1 and the slices #2–#10.
- The work is on branch `docs/stitches-and-wedges` (22 commits ahead of `main`). It's pushed, but not merged and has no pull request yet.
- `CONTEXT.md` is the glossary and holds the rules for where gaps go. `docs/adr/` holds the two design decisions.

## Parked from the start of the session

1. **List reordering on macOS.** Reordering Patterns and Projects works and persists on iOS, but not on the Mac.
2. **iPhone editor toolbar.** The tools moved to a row below the canvas (commit 30096c9). The redesign you'd mentioned is still parked.

## Things to look into (noticed along the way)

- **Gap placement felt "weird"** in some of your charts. The rules are in `CONTEXT.md` under "Relationships" and "Flagged ambiguities". The likeliest suspects:
  - A decrease ends the *nearest live* column on its side.
  - Columns wrap around at the chart's edges.
  - Increases and decreases in a row cancel nearest first.
  - Paint a case that looks wrong and compare it with what you expected.
- **Known limitations** (in `CONTEXT.md`):
  - Two increases stacked in the same column contradict each other.
  - Nearest-first cancellation can choose the wrong stitch among lace pairs.
  - A stitch on the D1V mirror line keeps the stitch you painted. You want k2tog in the center column to stay possible.
- **Wedge ideas you might want:**
  - a "New Wedge" command (today it's choose Wedge, then Clear)
  - stitch symbols in the Circular View
  - a more realistic ring spacing option (rows are evenly spaced today)
  - the Circular View's outlines are all-or-nothing. With the yoke there are none.
- **Limits still at 25:** width, the square-grid size N (4× symmetry), and the brick offset "Col ↓". Height goes to 50.
- **Not checked:** stitch totals on the iPhone canvas for a Wedge. They work on the Mac and in exports.
- **The yoke's "V" stitch** (beside each increase) is charted as plain knit. There's no "V" stitch in the catalog.
- **Out of scope, as planned:**
  - written row-by-row instructions
  - multiple sizes
  - border strips on Wedges
  - lace in border strips

## How the project works (gotchas)

- **New Swift files outside `Colorwork/`, `ColorworkTests/` and `ColorworkUITests/` must be registered in the Xcode project.** Use the script:
  ```bash
  python3 -I scripts/add_to_pbxproj.py Colorwork.xcodeproj/project.pbxproj <Group> NewFile.swift ExistingFileInSameGroup.swift
  ```
- **Tests:** Swift Testing, run with
  ```bash
  xcodebuild test -scheme Colorwork -destination 'platform=macOS' -skip-testing:ColorworkUITests
  ```
  If the test target says a new type "can't be found", the incremental build is stale. Run `xcodebuild clean` first.
- **Scaffolding tests** live in `ColorworkTests/Scratch/`, which is gitignored. That folder holds:
  - the yoke chart read from your photo (`YokeSeedScratch.swift`)
  - the check that its gaps match the print (`YokeScratch.swift`)
  - one-off export and render writers
  - a guarded writer that saved the yoke patterns into the Mac Library
- **The two yoke patterns** ("Yoke – published (increases)" and "Yoke – bottom-up (decreases)") are saved in the Simulator's Library and in the Mac app's Library.
- **iOS Simulator tool quirks:**
  - Screenshots lag taps by a second or two.
  - Switches ignore taps, so slide them instead.
  - Hardware-key presses (select-all, return) hide the on-screen keyboard.
  - Number boxes are narrow, so tap their center.
