# GUI audit — iPhone, November 2026

Audit of the iPhone app against Apple's Human Interface Guidelines, decided with Emily on 2026-11-07.

## This round (items 1–4)

1. **Accessibility labels.** Every icon-only button gets a spoken name.
2. **Saving and file access** (Pages/Freeform-style documents):
   - The open **Project autosaves**. No Save button.
   - At launch the app opens a **fresh random chart** ("Untitled"). A new Project is **saved only once it is changed** (painting, settings, Generate, rename), so unedited starts leave no clutter. New Projects are named "Untitled", "Untitled 2", … (revised 2026-11-07; first version reopened the last Project).
   - Tapping a **Pattern** in the Library starts a **new Untitled Project** from it (template behaviour). The Pattern is never changed.
   - Projects are listed by **last edited**. Library **Edit** mode selects several Projects (Select All) and deletes them after one confirmation.
   - Tapping a **Project** in the Library opens it; edits go into it.
   - **Title menu** (tap the title): New Project, Rename, Duplicate, Save as Pattern…, Export…. Save as Pattern with an existing name asks "Replace existing pattern?".
   - Library: "+" in Projects for New Project; long-press → Duplicate; Patterns footer "Opening a pattern starts a new project."; the Name field and Save Pattern button are removed; rows use normal text color.
   - The folder ("Library") menu in the editor goes away. "Pattern" keeps its name (not renamed to Template).
3. **Editor layout:**
   - Top bar: Undo, Redo (left) · title menu · Share (right, kept because Export is used often). _Superseded 2026-11-08: back to Library (left) · title menu · Undo, Redo (right); Export only in the title menu._
   - Stitch bar above the toolbar: brush, 4 most recently used stitches, More (labelled grid of all stitches). 44pt targets.
   - Bottom toolbar, icons with labels: Generate · Settings · Colors · Tiling · ⋯ (Fit to Screen, Clear in red).
   - Fit happens automatically when chart size changes or on rotation. No double-tap (it conflicts with paint-on-touch).
   - Canvas uses the empty space above it.
4. **Dynamic Type.** All interface text scales with the system text size. Canvas row/column numbers scale with cell size instead. At accessibility sizes the bottom toolbar shows icons only (long-press shows the name, Large Content Viewer); toolbar and stitch-bar icons stop growing at xxxLarge.

Build order: 1 → 2 → 3 → 4, each checked in the Simulator.

## Later

5. Settings sheet (done 2026-11-07): title and Done; shorthand "D4", "N", "ρ" kept by choice; slider rows even (body text, full-width slider, aligned tracks, boxed value). Still open: at accessibility text sizes put labels above their controls (e.g. "Rota-tion" wraps beside its picker).
6–7. Tiling sheet (done 2026-11-07): preview fixed at ~40% of the sheet and centred, settings get the rest; Copies, Border Strip and Brick Offset dimmed (faded) with no repeat, strip reflect toggles also dimmed at width 0; brick offset capped at chart width/height − 1. Preview with no repeat left as is (Emily's choice).
8. Colors sheet (done 2026-11-07, iPhone): Fill and Background shown as two swatches side by side with editable hex; matplotlib palette kept (Emily likes it), in its original order with the current colour ringed and named (hue grouping tried and reverted); CMYK tab replaced by Apple's colour picker ("Custom"); Compare labelled ("Blend from fill to background", "Suggested backgrounds"); preview centred. The Mac sidebar still has CMYK.
9. Wedge stitch totals on the iPhone canvas: checked, they work (2026-11-08). Still parked: macOS list reordering. The Mac app has not been audited.

## Follow-up round (2026-11-08, after Emily played with the app)

- **Cancel on every sheet.** Settings and Tiling got Cancel like Colors. While a sheet is open its edits stay out of Undo; Done adds one undo step, Cancel leaves none.
- **Settings sheet** matches the others: look-only chart preview on top (a third of the sheet), controls scroll underneath; all sheets open full height only. Cell Size slider removed (the Mac gets View › Zoom In/Out/To Fit, ⌘+ ⌘− ⌘0). Section "Fill Density - used when you tap Generate" with a Generate button.
- **Resizing keeps the drawing centred.** Going odd↔even adds or removes a blank centre strip. Nothing is lost until the next real edit (grow, shrink, grow restores it).
- **Symmetry changes leave the drawing alone**; the group only governs new taps. A tap uses the tapped cell's colour; a drag stroke fills or erases throughout. Grey caption under the chart: "Drawing with D4 symmetry (snowflake)" (tap opens Settings; beside the Pattern heading on the Mac).
- **Colors › Custom** shows Apple's picker inline (no extra button, no X). It fills the space left with no scrolling, so its saved-colours row doesn't fit. Emily is going without saved colours for now; if missed, the option is a smaller preview on the Custom tab only.
- **Navigation:** the Editor/Library tab bar is gone. Library is home and the editor opens on top with a back chevron (Pages/Freeform style); the app still launches into a fresh chart. Undo/Redo top-right; Export only in the title menu.

Not checked by hand: the Mac zoom menu and Mac caption (build only).

