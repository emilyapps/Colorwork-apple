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
   - Top bar: Undo, Redo (left) · title menu · Share (right, kept because Export is used often).
   - Stitch bar above the toolbar: brush, 4 most recently used stitches, More (labelled grid of all stitches). 44pt targets.
   - Bottom toolbar, icons with labels: Generate · Settings · Colors · Tiling · ⋯ (Fit to Screen, Clear in red).
   - Fit happens automatically when chart size changes or on rotation. No double-tap (it conflicts with paint-on-touch).
   - Canvas uses the empty space above it.
4. **Dynamic Type.** All interface text scales with the system text size. Canvas row/column numbers scale with cell size instead.

Build order: 1 → 2 → 3 → 4, each checked in the Simulator.

## Later

5. Settings sheet: title and Done; plain words for "D4", "N", "ρ"; tidy slider rows and fonts.
6. "Copies" enabled when no repeat is on.
7. Tiling preview pushes settings below the fold.
8. Colors sheet: hex shown twice, no selected-swatch mark; palette not grouped by hue.
9. Parked: Wedge stitch totals on the iPhone canvas; macOS list reordering. The Mac app has not been audited.
