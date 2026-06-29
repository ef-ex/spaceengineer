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

---

## Build/edit interaction — the Tiny Glade lesson (research 2026-06-29)

> The interaction model these findings drove — four phases (Shape/Structure/Systems/Decorate) as
> selection filters, six shared grammars, one universal modifier language, on-object handles + a flat
> variant palette (no radial) — is specced in `ship_designer_spec.md` → "Interaction model — the
> unified grammar". This section is the *why*; that section is the *what to build*.

The sections above optimised *network routing* and *show-off*. This one targets the
**moment-to-moment build/edit feel** — the real complaint in play: *"building/editing requires
too many clicks and isn't obvious."* Researched **Tiny Glade** (north-star), **ShipShaper**
(closest direct comparable, by Tomas Sala / The Falconeer), **The Sims 4** (click-economy gold
standard), and the HCI literature on modeless editing + radial menus.

### The reframe: Tiny Glade is NOT tool-less — it's *modeless*
The key correction to our assumption. Tiny Glade still has a tool palette (wall, building, tower,
path, window, ground) — like our toolbar. Its magic is **how the tools behave**, not their absence:
- **Direct manipulation with on-object handles.** Drag to extend a wall, then **grab its top edge
  and pull up** to raise height; drag a box for a building; push/pull a tower's height & diameter.
  **Handles appear ON the object on hover** — never a separate "Edit" mode or nested menu. *(The
  single most transferable mechanic.)*
- **Procedural auto-completion.** Paths meeting walls auto-spawn archways/doors; props/ivy fill in.
  The player shapes big forms; **detail places itself** — deleting whole categories of fiddly clicks.
- **Instant feedback + no-fail freedom.** Every action has a visual/sound response; non-prescriptive
  ("like giving a child LEGO bricks"). Feel comes as much from this as from layout.

### Per-game breakdown
| Game | Interaction model | The transferable bit |
|---|---|---|
| **Tiny Glade** | Tool palette, but **modeless** — drag-direct, hover reveals handles **on the object**, no interrupting menus | **On-object hover handles** + procedural auto-completion of detail |
| **ShipShaper** (Sala) | **Gridless** push/pull/drag sculpt of one continuous, symmetrically-mirrored welded hull + discrete prop attach. Deliberately **rejects CAD "lists and precision-placement"** for "minimalist, exploratory" | Philosophy: reject menu-heavy precision; **symmetry/mirror as a first-class affordance**. (Caveat: gridless, and a Feb-2026 demo that may evolve — no hands-on feel confirmation) |
| **The Sims 4** | Modal tools, but the click-economy playbook on top | **1-key tool swaps** (B/H/E/R/K); **eyedropper (E) clones** without catalog trips; **Shift** = place-multiples / flood-fill; **Alt** = *held* override of grid snap — **modifiers change the active tool's behaviour instead of forcing a mode switch** |
| **HCI** | Modal dialogs/modes interrupt flow + add read-comprehend-decide cost (NN/g). Pie menus are fast **only at ≤~8 items, 1 level** (Callahan et al. CHI'88) | **Depth is the enemy.** Our 3-deep Edit radial is the textbook anti-pattern |

### Diagnosis of our current designer
- **Too many modal tools** (Select/Delete/Edit/Hull/Rooms/Doors/Equipment/Route/Riser) → constant
  toolbar round-trips, each a mode-switch with read-comprehend-decide cost.
- **The Edit radial is 3 levels deep** (select walls → Edit → ⬢ Walls → Wall 1 → slider). Research
  verdict: the *depth*, not the radial form, is the problem — and the right fix isn't a shallower
  radial, it's **on-object handles** that drop the radial for editing entirely.
- We removed the control-hint bar (it didn't scale) → **discoverability dropped**; shortcuts exist
  (`des_*` InputMap) but aren't surfaced.

### Recommendations (prioritised)
**Quick wins — cheap, high-impact, [PROTOTYPE]:**
1. **Modifier overrides instead of mode-switches** (Sims 4): hold **Shift** to keep placing Equipment
   (don't drop to Select after one); Shift/Ctrl for line/rect fill inside the active tool; make the
   **eyedropper/clone** (`des_copy` / `_copy_selected`) prominent — research confirms it as a top
   click-saver.
2. **Surface the 1-key tool shortcuts** we already have — a compact, always-visible legend or
   per-tool tooltip (replace the cut hint-bar with something that scales). One keypress beats a
   toolbar trip.
3. **Instant placement juice** (already build-order step 1) — snap + sound + pop per action.

**The headline redesign — bigger, [PROTOTYPE] for walls first:**
4. **Replace the Edit mode + 3-deep radial with on-object hover handles.** In the default Select
   mode, hovering a wall reveals a **drag-handle on the wall** to morph flat↔thick directly (exactly
   Tiny Glade's "grab the wall top and pull"). No Edit button, no Walls→Wall 1→slider. Biggest single
   fix for "too many clicks + not obvious," and we already have the wall mesh + morph to hang it on.
5. **Auto-completion of detail** [mostly VISION]: auto-place doors where a corridor meets a room wall;
   auto-trim. Shapes get placed; fiddly detail fills itself in.

**Where we genuinely CAN'T be as simple as Tiny Glade (don't pretend to):**
- **Selection disambiguation** is harder for us: multi-deck + overlapping walls/equipment means
  "hover reveals the right handles" needs a disambiguation rule (our active-deck focus helps — one
  deck at a time). **Solve this before on-object handles can fully replace the Edit mode.**
- **Networks + contract validation** need inline feedback — but the answer is the
  **overlay-per-network system specced above**, not modal dialogs or a separate inspect mode.
- Transfer the **principles** (on-object handles, modeless modifiers, shallow/no menus,
  auto-completion, instant feedback) — **not** ShipShaper's gridless sculpt or Tiny Glade's
  single-deck simplicity.

### Open questions before building #4 (on-object handles)
- Selection disambiguation among overlapping walls/decks/equipment without a dedicated Select mode.
- The discrete-placement click-path (Equipment/Doors/Route) — how to keep it modeless (ShipShaper's
  prop-attach is the analog; under-documented).
- Inline validation feedback (networks/contract) without reintroducing modal dialogs.

Sources: [Tiny Glade dev interview (80.lv)](https://80.lv/articles/exclusive-tiny-glade-developers-discuss-bevy-proceduralism-publishers-cozy-games),
[Tiny Glade teardown](https://medium.com/@adventuresinindiegaming/doodle-designer-tiny-glade-5fac5a60ebb4),
[ShipShaper (Steam)](https://store.steampowered.com/app/4339280/ShipShaper/) + [Sala interview](https://www.fixgamingchannel.com/shipshaper-demo-launch-tomas-sala-on-flow-minimalism/),
[Sims 4 hotkeys](https://simscommunity.info/2022/01/24/the-sims-4-build-buy-hotkey-guide/),
[NN/g modal vs modeless](https://www.nngroup.com/articles/modal-nonmodal-dialog/),
[Pie menus / Callahan CHI'88](https://en.wikipedia.org/wiki/Pie_menu).
