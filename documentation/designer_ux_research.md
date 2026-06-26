# Ship Designer — UX Research & Recommendations

**Status:** Research synthesis (2026-06-23).
**Working title:** **Rigger's Hullworks** (chosen 2026-06-26). See `game_vision.md`.
**Related:** `ship_designer_spec.md` (the spec this informs), `prototype_scope.md` (the
scope fence), `game_vision.md`.
**Scope note:** Every recommendation below is tagged **[PROTOTYPE]** (in the documented
prototype slice) or **[VISION]** (good idea, wrong time — parked, not built). The
prototype stays tight to `prototype_scope.md`; this doc must not become a backdoor for
scope creep.

> **Why this exists:** Before building more designer, we surveyed how shipped games solve
> grid building + network routing, to land on a UX that fits our two-layer model
> (free-form hull + functional, manually-routed interior validated by a one-shot solve).

---

## The one big idea: an overlay-per-network designer

The most consistent, highest-value lesson across the survey — and the closest fit to our
two-layer model — is **Oxygen Not Included's overlay system**: pick a network (Power /
Heat / O2 / Water), the world dims to greyscale, and *only that network* is drawn in
colour, with each segment coloured by status (green OK · amber near-capacity · red
over-capacity / disconnected · grey inactive). Starbase (per-tool Cable/Pipe + durability
overlays), RimWorld (power overlay draws a line to each appliance), and Prison Architect
(separate Electricity / Water views) all reinforce variants.

This should be the **architectural spine of our interior layer**, designed in from the
start even if built incrementally. Our one-shot graph solve maps onto it directly: the
solver's per-segment result *is* the overlay's colour. It is what keeps multi-deck,
multi-network routing legible instead of becoming spaghetti. **[PROTOTYPE]** for power +
heat; **[VISION]** to extend the same shell to O2/water.

---

## Reference games (what each taught us)

| Game | Most transferable idea | Source |
|---|---|---|
| Oxygen Not Included | Per-network overlay; world greyscales, network colour-coded by health; bridges to cross without connecting; hidden-in-floor conduit | [Power Circuits](https://oxygennotincluded.wiki.gg/wiki/Guide/Power_Circuits) |
| Cosmoteer | "Blueprint mode" (rough out illegal, validate on commit); persistent stat strip with target-vs-current + per-part hover; player-authored proximity (adjacency %) | [Ship Editor](https://cosmoteer.wiki.gg/wiki/Ship_Editor), [copy/paste devblog](https://blog.cosmoteer.net/2016/07/cosmoteer-094-copy-paste.html) |
| Highfleet | Select a module → traces its power path back to the supplying source; MW required vs available readout | [Shipworks guide](https://www.magicgameworld.com/highfleet-shipworks-editor-guide/) |
| Starbase | Separate Cable/Pipe tools validated by continuous path between matching sockets; durability overlay (green/red, magenta stress); "save selection as" sub-assembly | [Designer Guide](https://wiki.starbasegame.com/index.php/Spaceship_Designer_Guide) |
| Space Engineers | CTRL+drag line/area fill; mirror planes (regular vs offset) placing 2/4/8 blocks at once; Info Screen + Build Planner stats | [Creative Mode](https://spaceengineers.fandom.com/wiki/Creative_Mode), [Symmetry](https://spaceengineers.fandom.com/wiki/Symmetry) |
| Avorion | Mirror origin = a selected block (not just ship centre); Match Shape smart placement; F focuses camera on selection | [Build](https://avorion.fandom.com/wiki/Build) |
| RimWorld | Power overlay draws a line to the offending building; conduit hidden under floor; coverage-radius auto-connect | [Power](https://rimworldwiki.com/wiki/Power), [conduit](https://rimworldwiki.com/wiki/Power_conduit) |
| Prison Architect | Trunk/branch pipe tiers (Large → Small); split Electricity/Water overlay views | [Utilities](https://prisonarchitect.paradoxwikis.com/Utilities) |
| Factorio / Satisfactory | Box-select → blueprint → ghost-preview paste; auto-connect on paste within a small radius | [Blueprint](https://wiki.factorio.com/Blueprint) |
| Dwarf Fortress | One Z-level edited at a time, up/down to change, lower level ghosted for context; drag-rectangle designations spanning Z | [Z-level](https://dwarffortresswiki.org/index.php/DF2014:Z-level), [Designations](https://dwarffortresswiki.org/index.php/Designations_menu) |
| Townscaper | LMB add / RMB remove (no eraser mode); marching-squares on a **dual grid** (values on cell corners); hide complexity behind the algorithm | [How Townscaper Works](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making), [dual grid](https://boristhebrave.com/docs/sylves/1/articles/tutorials/townscaper.html) |
| KSP (VAB/SPH) | Mirror/radial symmetry as a first-class toggle (R/X), placed live; numbered hotkeys per tool | [keybinds](https://defkey.com/kerbal-space-program-ksp-shortcuts) |
| The Sims 4 / Cities: Skylines | Grid-snap default + Alt to escape; three-click bounded creation; per-tool tooltips for approachability | [Sims build](https://sims.fandom.com/wiki/Build_mode_(The_Sims_4)), [CS road tools](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/road-tools) |

---

## Recommendations by facet

### Hull shaping (Layer 1)
- **[PROTOTYPE]** `LMB add / RMB remove`, no eraser mode (Townscaper). Replaces today's
  click-*toggle*. Cheapest, biggest feel win.
- **[PROTOTYPE]** Drag-rectangle fill / erase (Dwarf Fortress, Space Engineers CTRL+drag)
  — this *is* the spec's "rectangle/cell selection."
- **[PROTOTYPE]** Mirror / symmetry toggle (KSP, SE). Design half, mirror the rest. Keep
  *enable* and *set-axis* as separate actions so symmetry never surprises the player.
- **[VISION]** Spline-outline tool = **marching squares on a dual grid**: store solid/empty
  on cell **corners** as the source of truth and derive the mesh. The "≥ X% enclosed"
  threshold is a **separate rasterise stage** (outline → corner occupancy) that feeds a
  clean boolean grid to the fill step — keep the two passes apart. Corner-bits-as-truth
  also makes undo/redo trivial.

### Interior + network routing (Layer 2)
- **[PROTOTYPE]** Drag-to-lay conduit; **touching = same network** (auto-merge);
  **bridges** to cross without connecting (ONI).
- **[PROTOTYPE]** Conduits run *inside walls/floors* — invisible in the normal view, shown
  only in the overlay (RimWorld hidden conduit). Matches our fiction exactly.
- **[PROTOTYPE]** Highlight a module → trace its power/heat path back to source (Highfleet);
  on failure, colour the broken path red.
- **[PROTOTYPE]** Reward short routes via cable/pipe cost (Cosmoteer's visible proximity) —
  but we validate **once** via the graph solve, never a per-frame crew/fluid sim.
- **[VISION]** Trunk/branch conduit tiers (Prison Architect), O2/water networks, risers as
  explicit cross-deck endpoints appearing on both decks' overlays.

### Validation & diagnostics (a differentiator)
- **[PROTOTYPE]** Every text diagnostic is **click-to-focus + spatial pulse** on the
  offending room (RimWorld line + ONI colouring). Pair every message with a highlight.
- **[PROTOTYPE]** Per-network budget bar ("Heat 1400 / 1000 kW") — literally our "reactor
  heat exceeds radiator capacity" diagnostic.
- **[PROTOTYPE]** Cosmoteer "blueprint mode": let the player rough out an illegal layout,
  mark violations red, and validate on demand — fits a one-shot solver better than blocking
  every illegal placement mid-build.
- **[PROTOTYPE]** Persistent stat strip: budget, power/heat balance, gate-fit pass/fail,
  required-modules count (Cosmoteer / SE Info Screen).

### Multi-deck Z-layers
- **[PROTOTYPE]** One active deck, up/down to change, decks above hidden / deck below
  ghosted, plus a full-ship view (Dwarf Fortress + Sims cutaway) — exactly the spec.

### Editor fundamentals & onboarding
- **[PROTOTYPE]** `Ctrl+Z / Ctrl+Y` undo-redo, copy/paste, focus-on-selection camera (F),
  grid-snap default with Alt to escape, numbered hotkeys per tool, mouse-button overloading.
- **[PROTOTYPE]** Non-dev onboarding: start with hull-fill only, reveal routing then
  spline/blueprints progressively; tooltips on everything (already required by our
  `ui-design` rules). Three-click bounded creation for the rectangle tool.
- **[VISION]** Blueprints / sub-assembly reuse (Factorio box-select → paste, Starbase "save
  selection as"). **Open risk:** blueprints can trivialise the design loop — see
  `open_questions.md` #1. Do not build until that's resolved.

---

## Showing off the build & keeping players engaged

Building UX (above) is half the game; the other half is **enjoying the result and wanting to share
it** — for a creative game the shareable build *is* the growth loop. Survey of how comparable
creative/builder games handle presentation and engagement:

| Game | Mechanic | Takeaway |
|---|---|---|
| Cities: Skylines II | Rich **photo mode** (free camera, lighting, filters, sliders) | Added *because* shared screenshots drove visibility — "a toy for generating desktop backgrounds." Presentation is a marketing engine. [Photo Mode](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/cinematic-camera-photo-mode) |
| Townscaper | Tactile **placement juice** (plop/splash/pops); social-shared screenshots | The *feel* of placing is the appeal; the micro-genre grew off shared images. [Into The Spine](https://intothespine.com/2020/09/21/creativity-and-relaxation-townscaper/) |
| Enshrouded | In-game **sharing dashboard** (new/trending/popular, tags, creator notes) | A browseable build gallery inside the game. [Adventure Sharing](https://hacktheminotaur.com/enshrouded/enshrouded-adventure-sharing-complete-guide/) |
| Cosmoteer / Trailmakers | **Steam Workshop** share/download builds; Discord community | Workshop = longevity + community engine. [Cosmoteer](https://store.steampowered.com/app/799600/Cosmoteer_Starship_Architect__Commander/) |
| The Sandbox | **Builder's challenges** (themed contests) | Periodic prestige events drive engagement. [Builder's Challenge](https://sandboxgame.medium.com/driving-community-engagement-through-the-sandboxs-builder-s-challenge-cb2e496ef9b7) |
| (sandbox design, general) | **Constraints generate problems**; guided creativity; tycoon loop | Validates our contract/gate-fit + money/rep design as the engagement engine. [GameDesigning](https://gamedesigning.org/beyond/designing-for-creativity-at-scale-how-sandbox-games-balance-freedom-and-structure/) |

### Show-off mechanics
- **[PROTOTYPE]** Orbit/free camera to view the finished ship + decent default lighting + clean
  backdrop, so even blockout shapes read as "cool" and screenshot well. (Already in
  `prototype_scope.md`; sequence *after* the core mechanic.)
- **[PROTOTYPE]** Screenshot button (already in scope).
- **[VISION]** Full **photo mode** (camera / lighting / filter sliders) — confirmed high-ROI; it's
  literally a marketing-content generator ([photo modes survey](https://www.thegamer.com/games-with-most-creative-photo-modes/)).
- **[VISION]** In-game **build gallery** ("hall of fame") + one-click share to Discord/social.
- **[VISION]** **Steam Workshop** ship sharing/downloading. (Blueprint *sharing* sits next to the
  blueprint-trivialisation risk — `open_questions.md` #1.)

### Engagement mechanics
- **Validated, already in the design:** constraints-generate-problems (contracts + gate-fit +
  interior puzzle), guided creativity (contracts as guidance), tycoon progression (money →
  shipyards, reputation → clients), prestige challenges (awards / Concours, `game_vision.md`).
  The survey confirms these are textbook engagement drivers — no change needed.
- **[PROTOTYPE]** ⭐ **Placement juice** — a satisfying snap + sound + small visual pop when a hull
  cell / module is placed (Townscaper). It's *feel*, so a data-driven tunable (game-programmer
  rule), and it's part of "does building feel good" — the hook. Fold into **build-order step 1**
  (hull-tool polish), not a separate pass.
- **[PROTOTYPE]** Keep failure **low-stress** (reduced pay + reputation hit, not fines) — no-fail
  creativity is a major draw (Townscaper). Matches `mission_generator.md`'s penalty model.
- **[VISION]** Recurring **builder's-challenge / Concours** prestige events as an engagement loop.

**Net:** mostly *validation* of the existing design. The two actionable items are **placement juice**
(cheap, on-hook → build-order step 1) and confirming **photo mode + gallery/workshop** as high-ROI
VISION features. Nothing new enters the prototype beyond juice + the already-scoped present-the-build
camera/lighting.

---

## What we deliberately will NOT copy
- **Per-frame structural / fluid simulation** (SE, From the Depths, ONI gas packets) — we
  chose a one-shot graph solve. Adopt the *overlay presentation* of results, not the sim.
- **Free per-axis block scaling** (Avorion) — breaks the fixed grid and gate-silhouette fit.
  Use fixed-footprint modules and 90° rotation only.
- **Auto-routing whole runs** (Factorio power-pole auto-place) — manual routing *is* the
  core verb. Keep auto-connect to a tiny snap radius only.
- **Random failure events** (RimWorld short-circuits, PA flooding) — runtime drama,
  irrelevant to a design-time validation pass.
- **Mirror-as-one-shot-action** (Reassembly) — prefer a persistent symmetry axis (KSP /
  Cosmoteer); a one-shot flip is a worse UX.

---

## Recommended build order (prototype-scoped)

1. **Hull-tool polish** (small, immediate): `LMB add / RMB remove`, drag-rectangle
   fill/erase, undo/redo, mirror toggle. Builds directly on `designer.gd` + `DesignerConfig`.
   Makes hull shaping *feel* good — the foundation everything else sits on.
2. **Module placement + the overlay shell**: place a few fixed-footprint modules; introduce
   the overlay framework (Power first) with the greyscale-dim + segment-colour pattern.
3. **Manual power routing + graph solve**: drag cables, one-shot validate, click-to-focus
   diagnostics + stat strip. Then **heat** on the same shell.
4. **Multi-deck**: active-deck focus, hide/reveal, full-ship view, risers.
5. **Gate-fit + contract wiring**: silhouette check and required-modules/budget against a
   contract (see `mission_generator.md`).

Everything past step 5 (spline hull, blueprints, O2/water, multi-class) is **[VISION]** and
stays parked until the core loop is proven fun (`prototype_scope.md` definition of done).
