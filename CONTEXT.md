# Colorwork

A charting tool for knitting patterns: colorwork and lace motifs drawn on a grid, with symmetry and repeats.

## Language

### Patterns

**Pattern**:
The chart itself — Cells, Stitches, colors, Symmetry Group; for a Tile, one tile; for a Wedge, one wedge.
_Avoid_: Chart (as a separate concept), design

**Project**:
A Pattern plus how it is repeated and shown: border strips, Planar or Radial Repeat settings (including a Wedge's N), and view settings.
_Avoid_: Tiled pattern

**Pattern Kind**:
The shape-and-repeat rule a Pattern follows: **Tile** or **Wedge**.
_Avoid_: Mode

**Tile**:
A rectangular Pattern with a **Planar Repeat**, optionally with border strips.

**Wedge**:
A Pattern, drawn in a rectangle, with a **Radial Repeat** and usually Shaping (e.g. hat crown, sweater yoke); the knitter's term, whatever its actual outline.
_Avoid_: Triangle, sector, yoke chart (a yoke is one use of a Wedge)

**Chart View**:
A Wedge shown as charted — N copies side by side, No Stitch cells included, with per-row stitch totals.

**Circular View**:
A Wedge shown as rings of stitches around a center, one ring per row, No Stitch cells removed — the finished object seen from above.

**Planar Repeat**:
A Tile repeated by horizontal and/or vertical **Translation**, as an allover fabric; alternate copies may also be reflected or half-turned.

**Radial Repeat**:
A Wedge repeated N times around the circumference, and never by vertical Translation.
_Avoid_: Circular repeat, round

### Cells and stitches

**Cell**:
One square of a Pattern's grid, carrying a color and a **Stitch**.

**Stitch**:
The knitting instruction for a Cell: knit, an increase, a decrease, or **No Stitch**.
_Avoid_: Symbol (the symbol is how a Stitch is drawn, not the Stitch itself)

**No Stitch**:
A Cell that does not exist in the fabric (in that row); it holds a place on the grid so the motif's columns stay aligned. It can appear anywhere, not only at the edges. Never painted directly; always derived from **Shaping** stitches.
_Avoid_: Blank, empty

**Shaping**:
An increase or decrease left over after the increases and decreases in its row cancel each other; only Shaping stitches start or end columns.

**Balanced**:
An increase or decrease cancelled by an opposite one in the same row (e.g. a lace yo paired with a k2tog); it creates no No Stitch.

**Ended Column**:
A grid column that a decrease ends; it is No Stitch from the decrease's own row to the top of the chart.

**Started Column**:
The grid column of an increase; it is No Stitch from row 1 up to the row below the increase.

**Lean**:
The visual direction a decrease or increase slants in the fabric: left, right, or centered.

### Symmetry

**Symmetry Group**:
The set of **Transformations** that keep a Pattern looking unchanged (C1, D1V, D1H, C2, D2, C4, D4).

**Transformation**:
One reflection or rotation within a Symmetry Group, or applied to alternate copies by a Planar Repeat.

**Reflection across a vertical axis**:
A Transformation that swaps left and right; the mirror line is vertical. Short form: vertical-axis reflection. D1V is the Symmetry Group containing it.
_Avoid_: Horizontal reflection, vertical reflection, vertical mirror, mirror plane, "H"/"V"

**Reflection across a horizontal axis**:
A Transformation that swaps top and bottom; the mirror line is horizontal. Short form: horizontal-axis reflection. D1H is the Symmetry Group containing it.
_Avoid_: Horizontal reflection, vertical reflection, horizontal mirror, mirror plane, "H"/"V"

**Half-turn**:
A 180° rotation. C2 is the Symmetry Group containing it.

**Quarter-turn**:
A 90° clockwise rotation. C4 is the Symmetry Group containing it, along with the half-turn and the **three-quarter-turn** (270°).

**Reflection across a diagonal axis**:
A Transformation whose mirror line runs corner to corner: the diagonal (top-left to bottom-right) or the anti-diagonal (top-right to bottom-left). Only D4 contains them; like turns, they need a square Pattern.

**Translation**:
Shifting a copy of a Pattern horizontally or vertically without turning or reflecting it; it has a direction, not an axis.

**Visual Equivalent**:
The Stitch that looks like a given Stitch after a Transformation, as judged by a knitter; may be undefined.
_Avoid_: Flipped stitch, rotated stitch

## Relationships

- A **Pattern** has exactly one **Pattern Kind**, which can be switched either way in one undoable step; Tile → Wedge applies the symmetry downgrade rule and hides (does not delete) border strips
- Random generation sets colors only, under the current Symmetry Group; it never places or removes Stitches
- A **Pattern** has a grid of **Cells**; each **Cell** has one color and one **Stitch** (knit by default)
- A **Stitch** has zero or one **Visual Equivalent** per **Transformation**
- A **Symmetry Group** is allowed for a **Pattern** only if every **Stitch** in it has a **Visual Equivalent** under every **Transformation** in the group
- Painting a Stitch that the current **Symmetry Group** doesn't allow downgrades it to the largest allowed group within the current one (first pass: D4, D2 → D1V; C4, C2, D1H → C1), with a notice; one undo restores both the Stitch and the group
- Removing the last such Stitch does not restore the earlier group; it only becomes available again
- A **Wedge**'s stitches per row = its live (non-No-Stitch) cells in that row × its **Radial Repeat** count
- A **Wedge** allows only C1 or D1V symmetry, even when it has no Shaping
- Saving a **Pattern** saves the chart only; saving a **Project** saves the chart plus repeat and view settings. Loading a Pattern keeps the current repeat settings. Tile and Wedge behave the same way
- A **Wedge**'s Radial Repeat count N belongs to the **Project**, not the Pattern — the same Wedge is used at different N for different garment sizes
- Export: PDF page 1 is the Pattern (a Tile with its border strips; a Wedge as one charted repeat with legend and stitch totals on rows where the count changes), page 2 is the repeated preview (a Tile's tiling; a Wedge's **Circular View**); PNG and SVG export the Pattern only
- Written row-by-row instructions are deferred
- A **Wedge** has one **Radial Repeat** count N (for now); multiple garment sizes, each the same Wedge with a different N, are deferred
- A **Wedge** has no border strips (for now)
- In the **Circular View**, row 1 is at the center if stitch counts mostly grow, and on the outside if they mostly shrink; a flip control overrides this (this view setting is not a construction direction)
- **Reflection across a vertical axis** swaps **Lean** left ↔ right; what other Transformations do to a Stitch is left to its **Visual Equivalents**
- A decrease leans away from its **Ended Column(s)**: k2tog ends the column to its left, ssk the column to its right, a centered double decrease one on each side
- An increase's **Started Column** is its own column; **Lean** affects only its symbol
- A Cell's color and **Stitch** are painted independently: painting a Stitch never changes the color, painting a color never changes the Stitch
- Stitches are drawn with Craft Yarn Council (CYC) standard symbols, in black or white, whichever contrasts with the Cell's color; every chart shows a legend of the Stitches it uses
- Painting knit returns a Cell to plain; there is no separate eraser
- Colors painted under **No Stitch** are kept but hidden, and reappear if the shaping stitch is removed
- Row 1 is always the first row knit, at the bottom of the chart, whether the garment is knit top-down (mostly increases) or bottom-up (mostly decreases); a Pattern has no construction-direction setting

## Example dialogue

> **Dev:** "If I reflect a lace **Tile** across a vertical axis, does a k2tog stay a k2tog?"
> **Domain expert:** "No — its **Visual Equivalent** under a **reflection across a vertical axis** is ssk. The fabric looks symmetric; the stitches aren't literally flipped."
> **Dev:** "And under a **half-turn**?"
> **Domain expert:** "Undefined for now, so that **Symmetry Group** isn't offered once the Pattern has decreases."

## Flagged ambiguities

- **Known limitation:** within each row of the repeat, increases and decreases cancel one for one, *nearest first*; the leftovers are **Shaping**. This will choose the wrong stitch in charts where Shaping decreases sit among lace pairs (e.g. 2 yo + 3 decreases, with the intended Shaping one not the farthest). Revisit with a per-stitch override when real charts need it.
- **Unconfirmed assumption:** which side a decrease's **Ended Column** falls on follows from its **Lean**. The knitter isn't certain this holds for all designs; it may need a per-stitch override.
- "Horizontal/vertical reflection" was used three incompatible ways (named by axis in `SymmetryGroup`, by translation direction in `TilingSettings.hType`/`vType`, by motion in `stripHReflect`/`stripVReflect`), so the same left↔right flip was called "V" in one place and "H" in another — resolved: reflections are always named by their **axis**. Code mapping: `.d1`/D1V, `horizontalRepeatType = .reflection` and `stripReflectsAcrossVerticalAxis` are all a **reflection across a vertical axis**; `.d1h`/D1H, `verticalRepeatType = .reflection` and `stripReflectsAcrossHorizontalAxis` are all a **reflection across a horizontal axis**; `RepeatType.rotation` is a **half-turn**. The stored strings `"d1"`/`"d1h"` and the stored keys `hType`/`vType`/`stripHReflect`/`stripVReflect` must keep loading.
- Lace "symmetry" means visual symmetry of the fabric, not geometric symmetry of the chart symbols — resolved: modeled via **Visual Equivalents**.
- A yarn over looks the same however it's turned, but on its own it's **Shaping**, so it makes a **Wedge** (at most D1V); only paired with decreases does it make turn-symmetric lace — resolved: like other shaping stitches, it has Visual Equivalents only under identity and **reflection across a vertical axis**.
- **For now:** a lean-dependent stitch painted on the mirror line of a D1V Pattern keeps the stitch as painted (it would otherwise have to be its own mirror image). Revisit with **No Stitch** (issue #6): a k2tog in the center column should stay an option there.
