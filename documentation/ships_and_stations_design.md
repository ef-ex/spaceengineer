# Ships & Stations — Design Synthesis

**Status:** Active design (2026-06-22). Captures decisions from design discussion.
**Origin note:** Originally drafted in Galaxia's docs; copied here because ship design is now Rigger's
Hullworks' domain. ⚠️ A copy also exists in `galaxia/documentation/` — pick ONE canonical home to
avoid divergence. Recommendation: keep this (Rigger's Hullworks) copy canonical; leave a pointer in Galaxia.
**Builds on (Galaxia docs):** `module_patterns.md`, `module_set_spec.md`, `class_hierarchy.md`.

> **Scope note:** This documents the *full* ship design intent. Stations are deliberately left as an
> open stub (not yet thought through). The shippable prototype tests only a thin slice — see
> `prototype_scope.md`.

---

## Ship identity — three orthogonal axes

Ship identity runs on three independent axes. Most ship-builders have one or two; this design has all three.

1. **Class = size / crew capacity, NOT grid scale.** Drake (crew 1–3) / Goliath (4–20) /
   Titan (100–1000) / Leviathan (colony-scale). All classes share **one grid unit and one module mesh set** — bigger class =
   larger assembly of the same modules, not bigger meshes. This overrides Galaxia's
   `module_set_spec.md` (per-class grid scaling) to avoid the ~3000-mesh art cost. Size is measured
   by tile/volume count. **Leviathan** is the largest class — the generation/colony-ship class; its
   capstone build (Galaxia's start / the win condition) is the finale. See `game_vision.md`.
2. **Pattern = design school.** Scientific / Industrial / Logistic / Living. Aesthetic + stat
   specialty + unlock gate. See Galaxia's `module_patterns.md`.
3. **Role = what you install.** Miner / hauler / scout / colonizer emerges from the modules
   chosen. The game enforces only the mandatory modules, never a role.

**Mandatory modules (every ship):** chassis, reactor, thruster, life support, crew quarters,
command, dock. Everything else is optional; role is a player label.

---

## Two-layer ship design

Ship design is split into two layers. This split is the core resolution of the "adjacency forces
ugly ships" problem: the aesthetic layer and the puzzle layer are separated, so they no longer fight.

### Layer 1 — Hull (exterior): artistic freedom
- The player shapes the outside of the ship however they want.
- The hull's shape and size define how much **internal volume** is available.
- Aesthetic expression lives entirely here. Nothing in the puzzle layer dictates exterior form.

### Layer 2 — Interior: the functional puzzle
- Inside the hull volume, the player places the technologies: reactor, crew quarters, life
  support, cargo, processing plants (on a miner), etc.
- This is the **actual puzzle game**: not *whether* you have the modules, but *where* they go.
- Because it's internal, it never needs to look pretty — so a rich placement puzzle here does
  NOT compromise the exterior aesthetic.

### The build model — four systems that realise the two layers (vision)
The two layers above are the *principle* (separate aesthetic from function). The full game realises
them with **four systems**, foundation first:

1. **Procedural hull pieces (the foundation).** A library of grid-defining, controllably-deformable
   hull pieces. Placing/shaping them authors the **grid**, the **outer hull**, and the **interior room
   volumes** in one act — so there is no separate exterior↔interior reconciliation step. Each piece has
   a **logical grid footprint** (integer cells → drives interior + function, stays simple) and a
   **procedural visual skin** (taper/curve/bevel → the exterior, what stops ships reading as blocks).
   This beats Space Engineers/Avorion because you deform *well-authored hull segments* over the grid,
   not cubes. **Deformation must stay grid-preserving.** **Prototype slice:** a cheap version of this
   *is* in the prototype — **authored** meshes with morph/variant handles instead of runtime geometry
   generation (see `ship_designer_spec.md` → "Prototype hull pieces").
2. **Decorative objects.** Freely placed props (some procedurally adjustable). Includes **posed
   puppets** — *static* crew figures for scale/life (no animation/pathing; animated NPCs are far later).
3. **Custom modeling tools + surface detailing.** Freeform shapes for bespoke bits the piece library
   doesn't cover, plus **player-drawn surface detail**. Flagship example — a **panel-line tool**: the
   player draws a spline on the hull surface and it generates a ribbon along the surface with a chosen
   panel-line texture (a Houdini SOP reimagined as a *runtime* tool — this is the Tiny Glade "port the
   procedural generation into the game" move, see Quality north-star below). **Cheapest runtime path:
   projected decals along the spline** (Godot `Decal` nodes), NOT runtime mesh export or texture baking.
   **Pragmatic sequencing:** author the look in Houdini first (ship as baked/decal assets) and only port
   to a live in-game tool if it earns its place. A lot of the intended detailers (panel lines, greebles,
   vents, plating) already exist as Houdini intents — each is a candidate for this author-first → port-later
   path. **Vision-tier; explicitly OUT of the prototype** (advanced art tools — `prototype_scope.md`).
4. **Functional parts.** The modules that make the ship work (the prototype's module/network puzzle).

**Interior architecture (vision):** walls / doors / windows to form rooms, and stairs/elevators
between decks. (Risers already serve as the logical elevator for the networks.)

**Hard principle — no first-person editing, ever.** All building is in free orbit camera; forcing
artistry through an FP camera (the Dual Universe gripe) is banned. The piece library's authoring is the
make-or-break, not the tech (cf. Juno/Spore's reshapeable parts).

> Vision, not prototype. The prototype stays cell-painting + box/recipe modules (`prototype_scope.md`).
> `ship_designer_spec.md` holds the shape-tool ladder and the forward-compat rule that keeps this
> reachable.

### Quality north-star — Tiny Glade (build feel + mesh quality)
The long-term quality bar for the *building experience* is **Tiny Glade** (Pounce Light). What that
actually means, from the developers' own talks (confirmed vs. flagged):

- **Author rules, not geometry.** The player expresses *intent*; the system resolves the detail.
  (Opara: *"complexity emerges from the interaction of simple rules"*, *"I create every single rule
  that goes into the system."*) This is exactly our forward-compat invariant — hull pieces *emit*
  cells; the mesh is downstream.
- **Many small per-element generators, built incrementally** — not one monolith. (Opara: *"a lot of
  algorithms and generators, each tailored to a specific element."*) Tiny Glade itself began as just a
  procedural **wall** generator. → Build our detailers one at a time (hull piece → panel lines →
  greebles), each a self-contained tool.
- **Curate constraints for *feel*** — it took the devs *"five or six iterations"* to make rules feel
  intuitive, not restrictive. The feel is the work, not the rules existing.
- **Lighting is ~half the perceived quality.** Tiny Glade's look is a **bespoke ray-marched real-time
  GI** renderer (Stachowiak: *"Rendering tiny glades with entirely too much ray marching"* — real-time
  GI, tilt-shift DoF, stable soft shadows). It is **NOT Gaussian splatting** (a common misattribution;
  no evidence found). Validates investing early in designer lighting/materials.
- **DECIDED (2026-06-26): no custom / from-scratch renderer, ever.** Tiny Glade's renderer is a
  multi-year specialist effort (custom engine on modified Bevy/Rust + compute shaders + ray-marched GI;
  Stachowiak also authored the "kajiya" GI renderer) — explicitly **out of scope**. We **push Godot's
  built-in rendering** to squeeze out fidelity: **SDFGI / lightmaps, good PBR materials, post (DoF /
  bloom / tonemap), soft shadows, and art direction.** Visual quality comes from lighting + material +
  art-direction tuning, not engine R&D — ~80% of the feel at a fraction of the cost.
- **Their runtime-GPU geometry generation is the expensive path.** Our authored-mesh + morph-handle
  plan (emit cells, author the skin) is a deliberate cheaper shortcut to a similar feel; full
  runtime-generative pieces stay the long-term vision tier.

Sources: [80.lv dev interview](https://80.lv/articles/exclusive-tiny-glade-developers-discuss-bevy-proceduralism-publishers-cozy-games),
[Graphics Programming Conference 2024 — Stachowiak talk](https://graphicsprogrammingconference.com/archive/2024/),
[80.lv: believability in procedural modelling](https://80.lv/articles/siggraph-believability-in-procedural-modelling).
(Researched 2026-06-26; flagged claims are where sources were thin or contradicted.)

---

## The interior puzzle = connectivity & proximity, NOT bonus tables

"Where do I place the reactor vs. crew quarters" is only a puzzle if placement has **consequences**.
The consequence system must be the *diegetic* kind, not the arbitrary kind:

- ❌ **Rejected: adjacency bonus tables** (e.g. "+15 energy if next to a reactor"). Arbitrary,
  gamey, and the source of the forced-ugly-layout problem.
- ✅ **Adopted: connectivity, flow, and logical proximity.** Power must physically reach modules
  through conduits; heat must travel to a hull-surface radiator; crew must walk from quarters to
  their stations; volatile/hot modules shouldn't sit next to the bridge or crew. These read as
  *engineering logic*, not min-maxing — the player understands *why* instantly.

This is the Cosmoteer model (crew physically ferry power/ammo; the floor plan determines
performance) — proven fun and shippable in that game. It reuses the connection-type system:

- **INTERNAL** modules need internal volume + valid internal connections.
- **EXTERNAL** modules (sensors, docks, mining drills, radiators) need hull-surface placement
  with correct outward facing.
- **STRUCTURAL** connects chassis to chassis.

### Adjacency decision
Adjacency bonuses are **demoted** from "the core puzzle" (as written in Galaxia's
`module_tier_materialFamily_system.md`) to, at most, a **handful of intentional, signposted
synergies** (e.g. reactor ↔ radiator). The real "good design is rewarded" pressure comes from:
**interior connectivity/flow + proximity logic**, **exterior gate-fit**, **budgets**
(power / heat / mass / crew), **pattern purity** (soft), and **role-fitness** (does it do the job).

---

## The central tension: exterior-fit ⟷ interior-packing

The two layers trade against each other, and this coupling is the **heart of the design** (not a
minor side-effect):

> A sleek, narrow hull threads tight jump gates and asteroid fields — but gives a cramped,
> hard-to-pack interior. A fat, roomy hull is easy to lay out inside — but can't fit small gates
> or tight fields.

Every ship becomes a negotiation between *where can this ship go* and *what can I fit inside it*.
Lean into this — it makes both layers matter simultaneously and produces varied, characterful ships.

---

## Size matters — contextually, as a trade

Ship size/shape is **never globally good or bad.** It is a **contextual trade**: big buys capacity
/ power / range; small buys access. This is exactly what a fleet-logistics game wants — a fleet
of **differently-sized specialists**, not one optimal size.

**Design rule:** every size constraint must be a *tradeoff*, not a pure gate. If "big" is just
"harder to use with no upside," players always go small and the system dies. Big must *buy*
something small can't (haul more, mount the larger reactor, carry the processing plant).

**Diegetic size-constraint scenarios (every one makes physical sense):**
| Scenario | What constrains size |
|---|---|
| Shipyard construction | Ship is built inside the yard and must fit through the yard's gate |
| Station docking | Available space at the docking port caps ship footprint |
| Asteroid-field mining | Minimum spacing between asteroids limits how big a miner can maneuver |
| Jump gates / fast-travel routes | Gate aperture caps what can pass through |

More to come (candidates: planetary atmosphere entry for colonizers, narrow canyon/cave
harvesting, convoy/formation limits). The pattern is the point: size matters *per activity*, so
different jobs want different-sized ships.

---

## Pattern bonus — soft, and a fleet incentive (not a ship-design puzzle)

- The pure-pattern bonus is **not** a ship-designer min-max lever. Its real jobs are:
  1. **Fleet-specialization incentive** — rewards building dedicated single-purpose ships over
     one do-everything ship.
  2. **Aesthetic identity** — four visually distinct schools make a fleet readable and make
     "design a ship I'm proud of" satisfying. This justifies patterns even if the bonus were zero.
- Keep the bonus **soft and gradient** (never mandatory). Consistent with "expressive but meaningful."
- **Skip it entirely in the prototype** — a pure ship-design game doesn't need it.

---

## Stations — DEFERRED (not yet designed)

Stations are assumed to be **broadly similar to ships** (same module / pattern / class / connection
systems) **with differences yet to be worked out.** Not designing them here per current intent.

**One open question to resolve when station design begins:** a station does not move, so it has
**no gate-fit constraint** — the very thing that makes *ship* design meaningful. Stations will
therefore need a *different* primary constraint axis (candidates floated but not decided:
docking/throughput capacity, power-at-scale, orbital footprint, placement in the system). Plus:
designed-then-built vs. grown-incrementally. To be designed later.

---

## Prototype relationship

The shippable prototype tests a thin slice of the above: exterior **gate-fit** + a simple
**interior pack** ("does it fit / does it work") against a contract. It deliberately omits patterns,
exotics, multiple classes, fleets, combat, art tooling, and stations. See `prototype_scope.md`.
