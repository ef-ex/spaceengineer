# Ship Designer — Spec

**Status:** Active design (2026-06-22).
**Working title:** "Space Engineer" is a placeholder — no final name chosen yet.
**Related:** `game_vision.md`, `ships_and_stations_design.md`, `prototype_scope.md`.
**Overrides:** Galaxia's `module_set_spec.md` class/grid model (see "Class" below).

---

## Grid & decks

- The designer is **grid-based**. Ships are defined on an X/Y grid, in 3D space.
- **Decks = Z-layers.** Multi-deck ships add a layer in Z+ or Z− as the player chooses.
- **One deck = one Z-layer** (a floor). Do NOT use a tile-threshold to define a deck — a deck is
  literally a floor; keep it intuitive. Size is measured by total volume, never by deck count.
- **Deck editing UX:** edit **one deck at a time**; **up/down arrow buttons** hide/reveal decks so
  the player focuses on the active floor; plus a **full-ship view** to see the whole assembly.

## Shape definition (the hull / exterior, Layer 1)

The player defines which grid tiles make up the ship — maximum artistic freedom, minimum friction.

- **Prototype tool: rectangle / cell selection.** Select tiles to fill. Trivial, already varied.
- **Vision tool: spline outline.** Draw a spline; per grid cell, measure the enclosed polygon area;
  area ≥ threshold → filled cell, else border/empty. (The proven LEGO-stud technique — a bounded,
  feasible tool, not freehand painting.)
- **Shared primitive: the "valid cell" test** — *does the shape cover ≥ threshold of this cell?*
  Built once; every shape tool (rectangle, spline, future freeform) feeds the same validator.
- **Vision endpoint: procedural hull pieces** (grid-defining, deformable) — see the build model in
  `ships_and_stations_design.md`. They simply *emit* valid cells.

Spline is a fast-follow, not day-one — the prototype proves the loop with rectangle selection first.

> **Forward-compat invariant:** the canonical input to interior + function is always **"hull = a set
> of occupied grid cells"** (`ShipDesign.hull`), regardless of which tool authored them. Keep this and
> nothing built now blocks the spline/procedural-pieces vision — each tool is just a different way to
> produce cells.

## Class = size, NOT grid scale

**Decision (overrides Galaxia `module_set_spec.md`):** classes do **not** change grid unit size.
All classes share **one grid unit and one module mesh set**.

- **Why:** per-class grid scaling forces re-creating every module at each scale — Galaxia's count
  reached ~3000 unique ship meshes, untenable for a solo dev. One shared mesh set serves all classes.
- **Classes differ by size / crew capacity, not mesh scale.** A Titan is a much larger assembly of
  the same modules, not bigger-meshed modules.

| Class | Crew (vision — unproven) | Intent |
|---|---|---|
| Drake | 1–3 | Small ships (prototype focuses here) |
| Goliath | 4–20 | Bigger working ships |
| Titan | 100–1000 | Capital-scale |

- **Generation ship** (the Galaxia bridge / end goal) is a **special one-off capstone commission**,
  NOT a general class. (Leviathan as a class is dropped — a Galaxia concept.)
- **Size = tile / volume count** (reuse the existing tile count). Bigger class = more volume.
- **Note for later (does NOT affect the Drake prototype):** a constant small grid makes Titan-scale
  tile counts large. Crew-per-module must scale nonlinearly (a Titan crew module holds far more than
  a Drake's), and the blueprint system makes big ships editable — stamp saved sub-assemblies, not
  individual tiles.

## Blueprint system

Factorio-style: **save and reuse designs / sub-assemblies.** Two jobs:
1. Player convenience — reuse a good design across contracts.
2. **The editing solution for large classes** — stamp "deck blocks" instead of placing thousands of
   tiles by hand.

> ⚠️ **Open risk:** blueprints can trivialize the core design loop (save one good ship, re-stamp
> forever, stop designing). Unsolved. See `open_questions.md`.

## Functional networks (the interior puzzle, Layer 2) — manual routing, precalc validation

The interior is made *functional* by routing networks through it:
- **Power** (cables), **Heat** (pipes → hull-surface radiators), **Oxygen**, **Water**.

**Routing is manual:** the player drags cables and pipes, which **run inside the walls and floors**
of the ship. Laying out a clean, working network is the puzzle.

**Validation is a design-time graph solve, run once per change — never simulated per frame.**

> For each network: is every consumer reachable from a producer through the right network, within
> capacity? Returns **pass/fail + diagnostics** (e.g. "crew quarters on deck 3 has no O2 line",
> "reactor heat exceeds radiator capacity").

- **Why precalc:** Galaxia simulates ~1000 systems; per-frame fluid sim per ship does not scale. A
  one-shot solve does, and it makes the interior a clean static constraint-satisfaction puzzle.
- **Shared engine:** the contract generator (`mission_generator.md`) calls this same solver to
  confirm a contract is solvable.
- **Consequence model:** connectivity + logical proximity, NOT adjacency bonus tables. See
  `ships_and_stations_design.md`.

## Visuals — shading, colour, preview meshes (prototype)

Nothing exists yet shading-wise; build it **cheap (no authored art)**. This serves the demand test
("a ship I'm proud of"), so plain boxes are a real problem to fix.

- **Shading pipeline:** one cached `StandardMaterial3D` factory shared by the designer and
  `ship_renderer.gd` (albedo / metallic / roughness / emission per surface, driven by data); bring the
  delivery view's filmic lighting into the designer too.
- **Colour (in scope — built-in `ColorPickerButton`):** a **hull base colour** + **accent**, stored on
  `ShipDesign` (serialised, so it survives undo/save and rides into delivery). Modules keep functional
  colours so the interior stays readable.
- **Preview meshes (in scope, cheap):** replace identical boxes with **data-driven per-module shape
  recipes** (reactor = housing + glowing core, engine = body + nozzle, radiator = finned panel, …)
  composed from primitives; plus hull bevel/paneling. The recipe field later swaps to real meshes.
- **Build order:** shading+lighting → colour → shape recipes → hull paneling (each independently
  shippable).

Advanced colour tools, textures/materials, and authored/freeform meshes are vision (build model in
`ships_and_stations_design.md`; deferred per `prototype_scope.md`).

## Prototype subset

Drake only; rectangle/cell shaping; place a handful of interior modules; **manually route power +
heat** (add O2/water only if cheap); precalc pass/fail + diagnostics; gate-fit check; flat-colour
customization. Splines, procedural hull pieces, blueprints, multiple classes, textures, and the full
network set are vision, not prototype.
