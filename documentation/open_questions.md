# Open Questions — living checklist

**Status:** Living doc (2026-06-22). Knock these down before/while building. Grouped by urgency.

---

## Critical — affect the core / longevity

### 1. Blueprint trivialization — RESOLVED (approach); tuning TBD
Blueprints are wanted (convenience + large-ship editing) but can kill the design loop if players just
re-stamp one good ship forever — and designing *is* the game. **Resolved approach: a uniqueness/novelty
score feeding the rating as a client-tier-weighted soft modifier.** Don't ban blueprints — make them
unable to carry you up the ladder.

- **Detection (cheap, deterministic, runs in the precalc step):** canonicalize the ship (translate to
  origin + canonical rotation/mirror), then fingerprint it two ways — an exact **voxel-occupancy hash**
  (catches literal copies) and a **feature vector** (module-type counts, bbox dims, mass, hardpoints,
  network length, symmetry). Score similarity vs the player's *recent deliveries* (voxel **IoU** +
  feature distance), take the max; **novelty = 1 − maxSimilarity**. A one-cell tweak barely moves IoU or
  the features, so it can't dodge the check.
- **Rating tie-in:** novelty is a **bucket-3 soft modifier** (`mission_generator.md`), **weighted by
  client tier**. Bread-and-butter clients don't care → blueprints stay genuinely useful for grunt work.
  **Luxury/prestige clients + awards demand bespoke** → deliver a clone and the rating tanks, so reuse
  can't climb the prestige ladder. The design loop stays alive exactly where it gates progression,
  without banning the feature.
- **Still open (playtest-only tuning):** similarity threshold, shape-vs-modules weighting, per-tier
  sensitivity. Keep it **gradient** (reward freshness more than punish reuse) and target
  **wholesale-identical ships, not reused components** (a reused reactor layout is not plagiarism).
  Err toward not nagging.

### 2. End-goal narrative depth — DECIDED direction, depth TBD
End goal = design the **generation ship** (bridges to Galaxia's panspermia). Open: how much story/
framing wraps the climb (cutscenes? just escalating contracts + awards?), and how the capstone
commission is structured (a special large build vs. a scripted finale).

### 6. Interior network puzzle is too shallow — OPEN (defer until prototype is feature-complete)
Observed in play (2026-06-26): routing power/heat is "place some stuff, connect the dots, done" — not
much of a puzzle. **Root cause: interior space is free and abundant**, so the only real constraint is
capacity (supply ≥ demand), trivially solved by adding another reactor. A constraint-satisfaction
puzzle needs **scarcity + competing pressures on the same resource (space)**. Note the asymmetry: the
gate-fit constraint already makes the *exterior* a real puzzle; the *interior* has no equivalent
pressure. Candidate levers (none chosen):
- Conduits cost money / take space / have a length budget → routing becomes an optimization, not a free line.
- Per-segment throughput (thin lines carry little → trunk-and-branch topology).
- Heat radiators must sit on the hull surface AND reactor heat must route there, so heat and power
  networks **compete** for the same interior space.
- Proximity / adjacency rules (crew away from reactors, etc.).

The building/aesthetic act is already fun; the puzzle isn't carrying its weight yet — a real finding
for the demand test (the fun may live more in *building* than in *wiring*). **Deferred on purpose:**
finish the missing prototype pieces first (gate-as-build-bound, auto-furnishing) before adding depth,
so we don't over-build an unproven layer. Where the fun actually is = a playtest question.

### 7. Drake sub-types: single-seater vs small-craft — OPEN (likely resolves with hull pieces)
Within Drake there are really two silhouettes: **single-seaters** (X-/A-wing — cockpit-only, the ship
IS its shape) and **small crafts** (Trek shuttle — a small walkable cabin). Both must be buildable.
Provisional read: this is a **spectrum the two-layer model already spans**, not two systems — a
single-seater is exterior-dominant (structure + cockpit + engines, near-zero interior); a shuttle adds
a small interior cluster. What makes them feel distinct is the **procedural hull pieces** (a sleek
swept fighter hull vs a boxy shuttle), so the hunch that "the answer comes once the hull elements +
the rest are in" is probably right. Sub-questions to settle then:
- Is a cockpit a 1-cell **room** or an **equipment** piece? (Single-seaters want the latter.)
- **Structural/external hull vs habitable interior** — the meaty one. Today the shell walls + ceilings
  every hull cell, which would wrongly enclose an X-wing's wings/nose. The model likely needs to mark
  cells (or hull pieces) as structural (frame, not pressurized, no walls) vs habitable (walkable, walled).
  This is also what lets the interior/network puzzle degrade gracefully to near-nothing for a single-seater
  without feeling broken (see [[#6]]).
Deferred — don't design now; revisit alongside the hull-piece system. Build model in
`ships_and_stations_design.md`.

---

## Important — full-game coherence

### 3. Reputation death-spiral / recovery floor
The reputation gate ("bad ratings → only small clients") risks trapping a struggling player. Needs a
deliberate **floor**: always-available low-tier "bread and butter" contracts so a player can grind
back up. Decided in principle; needs tuning so the floor is a lifeline, not a grind.

### 4. Tutorial design
Approach decided: **reuse Galaxia's wiki system** (clickable in-game word → opens the wiki at that
page). Open: the actual onboarding sequence — how a new player learns the two-layer design + manual
network routing without overwhelm. Content undesigned.

### 5. Aesthetic reward outlet
"Design a ship I'm proud of" needs an outlet. Decided: screenshots + video capture, and a **hall of
fame** of your designs (pairs with the ship tester). Open: details (in-game gallery? client praise
for beauty beyond function?). No blueprint *sharing* (that's a Galaxia thing).

---

## Resolved (moved here for the record)

- **Network routing:** manual — drag cables/pipes that run in walls/floors. (`ship_designer_spec.md`)
- **Multi-deck UX:** edit one deck at a time, up/down arrows to hide/reveal, plus full-ship view.
- **Class model:** size not grid scale; one mesh set; Drake/Goliath/Titan; Leviathan cut; gen ship is
  a capstone, not a class.
- **Economy:** money → shipyards (sink); reputation → clients + shipyard/pattern unlocks; tech in
  shop. Penalties = reduced pay + rep hit (fines only on opt-in high-stakes), minimum-to-ship gate.
- **Combat:** on hold / cut from this game.
- **Stations:** not in this game (Galaxia only).
- **Settings/menu:** in the prototype.
- **End goal:** the generation ship (see #2 for remaining depth questions).
- **Blueprint trivialization:** novelty score (canonicalize → fingerprint → similarity vs recent
  deliveries) feeding a client-tier-weighted soft rating modifier — blueprints stay valid for low-tier
  contracts but can't climb the prestige ladder. Tuning is playtest-only. (Full detail in #1.)
