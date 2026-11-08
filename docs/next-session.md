# Notes for next session

_Last updated 2026-11-08._

## Where things stand

- **Next: audit the Mac app** against Apple's HIG, the way the iPhone was audited in `docs/gui-audit-2026-11.md`. Known Mac items: the sidebar still has CMYK (iPhone's Colors now uses Palette / Custom / Compare); list reordering of Patterns and Projects doesn't work on the Mac; the new View › Zoom menu and "Drawing with…" caption were built but never looked at.
- The iPhone audit and the 2026-11-08 follow-up round are done and on `main` (pushed). Details in `docs/gui-audit-2026-11.md`.
- The stitches-and-wedges feature is finished (PRD #1, slices #2–#10 closed). `CONTEXT.md` is the glossary and holds the rules for where gaps go; `docs/adr/` holds the design decisions.
- Other branches: `docs/stitches-and-wedges` and local `gui-audit` are merged into `main`; `agentic-colorwork` (on GitHub) is not.

## Your ideas for next time

1. **Make the app agentic: build a chart from a photo.** Reading the yoke from your photo worked well, so do it in the app. This session's steps were:
   - find the corners of one repeat
   - correct for tilt and perspective
   - read each cell's color
   - spot the increase and decrease symbols
   - choose the orientation (as printed, or recharted bottom-up)
   - check the derived gaps against the printed gray cells

   Things to decide:
   - Use the Claude API with image input (best at reading symbols and layout, needs a network connection and an API key), or do it on-device with Apple's Vision framework for the grid plus color sampling, or combine the two.
   - How the user confirms or fixes the result before it becomes a Pattern.
   - Whether the app can go further, e.g. "rechart this bottom-up with decreases".
2. **Play with the stitch picker** to find UI and functionality improvements, then bring back the list.

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
- **Low fill density can generate a blank chart** (seen at ρ = 0.05, 8×8 D4).
- **Limits still at 25:** width, the square-grid size N (4× symmetry), and the brick offset "Col ↓". Height goes to 50.
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
  - Screenshots lag taps by a second or two; segmented controls ignore taps.
  - The tool's `launch` sometimes kills the app on the first tap; `xcrun simctl install` + `xcrun simctl launch --terminate-running-process <udid> emilyapps.Colorwork` is reliable.
  - Switches ignore taps, so slide them instead.
  - Hardware-key presses (select-all, return) hide the on-screen keyboard.
  - Number boxes are narrow, so tap their center.
