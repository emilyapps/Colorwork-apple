# No Stitch is derived from Shaping, never stored or painted

No Stitch cells are computed from the Shaping stitches in a Pattern, not painted with a brush or saved in the Pattern's data. A decrease ends a column (the side follows its Lean) from its own row to the top of the chart. An increase starts its own column, which is No Stitch from row 1 up to the row below it. Increases and decreases in the same row of the repeat cancel nearest-first, and only the leftovers count as Shaping. We chose this because the knitter places shaping by its decreases and increases; where the gaps go follows from them. Deriving them keeps stitch counts correct by construction: moving a decrease moves its gap, and no row can disagree with its neighbours.

## Consequences

- There is no No Stitch tool. Colors painted under a derived No Stitch are kept and reappear if the Shaping stitch is removed.
- Saved data holds only colors and stitches, so changing the derivation rules (e.g. adding a per-stitch override) needs no conversion of saved data.
- Two rules are known to be approximate, both recorded in `CONTEXT.md`: the side of an Ended Column follows the decrease's Lean, and cancellation is nearest-first. If real charts break them, the fix is a per-stitch override, not stored No Stitch cells.

## Considered options

- **Paint No Stitch by hand**: rejected, because it's tedious and makes it easy to produce charts that can't be knit (row counts that don't add up).
- **Generate a Wedge outline from parameters** (base width, rate, decrease positions): rejected, because real charts such as yokes put No Stitch columns inside the motif, not only along the edges.
