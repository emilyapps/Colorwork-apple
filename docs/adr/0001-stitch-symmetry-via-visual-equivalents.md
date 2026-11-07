# Stitch symmetry uses a table of Visual Equivalents, not geometric flips

When a Symmetry Group copies a Cell to its linked cells, the Stitch is replaced by its **Visual Equivalent** under that Transformation, which is looked up in a hand-written per-stitch table (e.g. k2tog under a reflection across a vertical axis → ssk). It is not computed by reflecting or rotating the symbol. Knitting has a direction (a decrease merges stitches going *up* the fabric), so lace that "has" half-turn symmetry or symmetry under a reflection across a horizontal axis is visually symmetric, not literally flipped; only a knitter can say which stitch looks equivalent, and sometimes nothing does.

A Symmetry Group is offered for a Pattern only if every Stitch in it has a defined Visual Equivalent under every Transformation in that group. For colorwork-only Patterns (all knit) this allows every group, as before. For Patterns with other stitches the allowed groups are restricted, without any hard-coded rule.

## Consequences

- The same rule and table govern Planar Repeat types (`RepeatType.reflection` / `.rotation`) and border-strip reflections: a repeat or strip reflection is offered only if every Stitch has a Visual Equivalent under the Transformation it applies, and alternate copies show those equivalents.
- To do so, `orbit` must return each linked cell *with* the Transformation that produced it, not a bare set of cells.
- The first pass defines only identity and vertical-axis-reflection equivalents, so Patterns with stitches allow C1 or D1V. Supporting C2, D1H, etc. for lace later means adding table entries, with no engine changes.

## Considered options

- **Geometric reflection/rotation of the symbol**: rejected, because it produces stitches that look wrong or can't be knit (an upside-down decrease).
- **Hard-code "stitches ⇒ vertical-axis reflection only"**: rejected, because it blocks the lace rotational symmetry the knitter wants later.
