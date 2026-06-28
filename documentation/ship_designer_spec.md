# Ship Designer — Spec

**Status:** Active design (2026-06-22).
**Working title:** **Rigger's Hullworks** (chosen 2026-06-26). See `game_vision.md`.
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
Because flexible hull shaping is the **core** of ship creation, the prototype must test it (not just
block-painting). The decision: bring a **cheap, authored-mesh** version of the hull-piece system into
the prototype, and keep the runtime-*generative* version as vision.

- **Prototype tool: placeable authored hull pieces.** Place parametric pieces that **occupy grid
  cells** and carry an **authored mesh** with simple, art-cheap controls (see "Prototype hull pieces"
  below). Rectangle/cell selection remains as the trivial degenerate piece / quick block-fill.
- **Vision: spline outline** (fast-follow) and **runtime-generative deformable pieces** — the full
  build-model foundation in `ships_and_stations_design.md`. Same role as the prototype pieces, just
  generated in code instead of authored.
- **Shared primitive: the "valid cell" test** — *does the shape cover ≥ threshold of this cell?* Built
  once; every shape tool (rectangle, piece, spline, future freeform) feeds the same validator.

> **Forward-compat invariant:** the canonical input to interior + function is always **"hull = a set
> of occupied grid cells"** (`ShipDesign.hull`), regardless of which tool authored them. The hull pieces
> *emit* cells; their mesh/shape is visual only. Keep this and nothing built now blocks the
> spline/generative-pieces vision — each tool is just a different way to produce cells.

### Prototype hull pieces (authored-mesh approach)

Avoid runtime geometry generation in the prototype (the expensive part); use **authored meshes** (we
have the Houdini pipeline) with two art-cheap handle types:

- **Morph weight (continuous).** Author the piece with **blend shapes / morph targets** (e.g. "curve
  amount", "flare top", "fillet"); a Select-panel slider sets each 0–1 weight at runtime. This is
  "drag existing points further out", baked at author time — no runtime mesh math.
- **Variant swap (discrete).** A handle switches between a few authored base meshes for bigger profile
  changes.

Per-piece structure (the floor/wall split):
- **Floor side — nothing new.** Floor depth = occupy *N* more grid cells; the floor visual is the cell
  tiles already rendered. No geometry work.
- **Wall side.** An authored wall-segment mesh that **aligns to the cell at its base** and **tiles per
  cell** along the length (so "longer" = more segments, profile stays consistent — no stretch). It
  carries the morph targets. Seams between adjacent pieces are designed to tile cleanly in Houdini.

Controls live in **Select mode** (select a placed piece → its sliders appear). Piece set: **start with
two — `hullSide` (handles: wall length in cells, floor depth in cells, outer curvature morph) and
`corner` (+ fillet morph).** Two cover any rectangle/octagon-ish hull. Add a **concave/inner corner**
when non-rectangular hulls are wanted, and an **interior floor tile** only if ships get deep enough
that opposite side-floors don't meet. **Keep the set tiny — resist variant sprawl.** This is the one
deliberate, bounded "authored art" exception in the prototype (justified by the Houdini pipeline).

## Class = size, NOT grid scale

**Decision (overrides Galaxia `module_set_spec.md`):** classes do **not** change grid unit size.
All classes share **one grid unit and one module mesh set**.

**The grid unit (confirmed by play 2026-06-27):** 1 build tile = **1 m** (`cell_size = 1.0`;
1 Godot unit = 1 Houdini m = 1 m — see the FBX pipeline). Deck/room height = **2.5 m**
(`deck_height = 2.5`). **One grid only** — no nested 0.5/0.25 m sub-grids; cables/heat pipes route
on the 1 m grid (a finer grid is *deferred* until edge-routing proves too coarse — the Satisfactory
precedent treats small connectors as soft-clearance, not a second grid). Scale is tuned to the
**Drake** (small craft): a 1-tile space is a coffin, a 2-tile-wide room feels right — **slightly
cramped interiors are intentional** for small spacecraft (real stand-up vehicle cabins are only
1.9–2.2 m; 2.5 m is deliberately a touch roomier for camera readability). Bigger classes get bigger
by **tile count, not a bigger grid** (consistent with "Size = tile / volume count" below).

- **Why:** per-class grid scaling forces re-creating every module at each scale — Galaxia's count
  reached ~3000 unique ship meshes, untenable for a solo dev. One shared mesh set serves all classes.
- **Classes differ by size / crew capacity, not mesh scale.** A Titan is a much larger assembly of
  the same modules, not bigger-meshed modules.

| Class | Crew (vision — unproven) | Intent |
|---|---|---|
| Drake | 1–3 | Small ships (prototype focuses here) |
| Goliath | 4–20 | Bigger working ships |
| Titan | 100–1000 | Capital-scale |
| Leviathan | colony-scale (thousands) | Generation/colony-ship class; its capstone build is the **win condition** (`game_vision.md`) |

- **Leviathan is the largest class** — the generation/colony-ship class (the name describes the
  ship's function). Its **capstone commission** — humanity's generation ship — is the **win
  condition** / Galaxia bridge (see `game_vision.md`). Adding it costs no extra meshes under the
  shared-grid, size-by-tile-count model (a bigger assembly, like Titan), so the ~3000-mesh reason
  Galaxia dropped it doesn't apply here.
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

## Interior contents — rooms vs equipment (Layer 2 objects)

The interior is built from **two kinds of object**, not one. The single "module"
model is a **Galaxia holdover** — there, ships were assemblies of adjacency-scored
modules, so a "crew-quarters module" made sense as a unit. On this freeform grid a
crew quarters or cargo hold is a **space**, not a unit, so the model splits:

- **Rooms** — functional **volumes** (crew quarters, cargo hold, medbay, bridge…).
  Authored with the **same resize-a-box mechanic as the hull**: the player drags out
  the room's extent on a deck. The game **auto-furnishes** the interior (walls,
  fixtures, equipment props — cheap primitives) and the **player places the doors**.
  A room is the canonical **network consumer**: its demand (power/heat/O2/water)
  scales with its **type and size**.
- **Equipment** — discrete **technical pieces** the player drops down (reactor,
  radiator, engine, thruster…). Keeps the current place-a-footprint mechanic. These
  are the network **producers / sinks** (reactor → power, radiator → heat).

**Data:** `ModuleDef` gains `kind: room | equipment`. Equipment keeps a fixed
footprint; rooms carry a **resizable rect** (origin + size) + type. The precalc
solver is unchanged *in spirit* — it still resolves producers → consumers within
capacity; rooms are sized consumers, equipment are producers/sinks, so the existing
solver and its tests carry over. This is an **evolution of the module model, not a
teardown.**

**Prototype scope for this:** a room reads as an enclosed space with a player-placed
door; auto-props are cheap primitives; room demand is a simple function of type × size.
Richer interior architecture (corridors, stairs/elevators, room-to-room flow rules)
stays vision — see `ships_and_stations_design.md`.

> **Routing UX:** cables and heat-pipes are picked from a **Route palette** (like the
> module palette) — NOT inferred from the active overlay. **Overlay = what you *see*;
> palette = what you *place*.** Two independent controls.

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

Nothing exists yet shading-wise; build it **cheap** — shading and the module **preview meshes** use
composed primitives (no authored art); the **hull pieces** are the one authored-mesh exception (see
"Shape definition"). This serves the demand test ("a ship I'm proud of"), so plain boxes are a real
problem to fix.

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

Advanced colour tools, textures/materials, and *freeform/sculpted* meshes are vision; the prototype's
one bounded **authored-mesh** exception is the hull pieces (see "Shape definition"). (Build model in
`ships_and_stations_design.md`; deferred items per `prototype_scope.md`.)

## Prototype subset

Drake only; **authored hull pieces** (cells + morph handles), with rectangle/cell as the quick
fallback; place **rooms** (resizable, typed) + **equipment** (discrete technical pieces);
**manually route power + heat** (add O2/water only if
cheap); precalc pass/fail + diagnostics; gate-fit check; flat-colour customization. Splines,
**runtime-generative** hull pieces, blueprints, multiple classes, textures, and the full network set
are vision, not prototype.
