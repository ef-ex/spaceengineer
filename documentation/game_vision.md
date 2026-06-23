# Game Vision — (working title "Space Engineer")

**Status:** Active vision (2026-06-22).
**Working title:** "Space Engineer" is a placeholder — no final name chosen yet.
**Read-first doc.** Detail lives in `ship_designer_spec.md`, `mission_generator.md`,
`ships_and_stations_design.md`, `prototype_scope.md`, `open_questions.md`.

---

## What it is

A 3D **ship-design game** wrapped in a **job sim**: clients commission ships; you design them
(free-form hull exterior + a functional, network-routed interior); you deliver, get paid, and get
rated. You rise from an unknown shop to a legendary shipwright.

## The fantasy

Unknown shop → renowned shipwright → living legend. Real-world inspiration for the recognition
ladder: **Pritzker Prize** (architecture), **Collier Trophy** (aerospace), **Concours d'Elegance**
(prestige beauty competitions), **Red Dot / iF** (product design).

## Core loop

Read contract → shape hull → lay out + manually route the interior so it works → deliver (fits the
gate, is functional) → get paid + rated → spend money / earn reputation → harder, better contracts.

## Two-axis progression

- **Money → bigger shipyards → bigger classes** (Drake → Goliath → Titan). Shipyards are the money sink.
- **Reputation (ratings) → who approaches you + what you can unlock.** Bad rep = small clients only,
  even if you're cash-rich. Good rep gates higher-tier clients, makes new shipyards purchasable, and
  triggers **pattern** unlocks (a corporation approaches offering their design school).
- **Tech** (modules/capabilities) is bought in the **shop with money**. **Patterns** come from
  **reputation events**. Two separate axes.

> **Recovery floor (must design):** always keep low-tier "bread and butter" contracts available so a
> player with bad ratings can grind back up. Prevents a reputation death-spiral. See `open_questions.md`.

## Awards

Prestige milestones (e.g. **max rating 3× in a row**) grant **awards**. Awards **attract luxury /
high-tier clients** and are the visible rungs of the prestige ladder toward the finale.

## End goal — the generation ship (bridge to Galaxia)

The career capstone is a once-in-a-generation commission: **design humanity's generation ship** —
the very vessel **Galaxia begins with**, which kicks off Galaxia's **panspermia** mechanic. Space
Engineer ends exactly where Galaxia starts. The generation ship is a **special one-off capstone
commission**, not a general buildable class.

## Classes

**Drake / Goliath / Titan.** (Leviathan dropped — a Galaxia concept; the generation-ship finale is a
special build, not a class.)

## Weapons (cosmetic/structural modules — NOT combat)

The fantasy is building cool, iconic ships, and iconic ships (X-wing, Star Destroyer, Enterprise) are
*armed*. So weapons belong in the final vision — but as **ship modules**, not a combat system:

- **IN (final vision):** weapons as a **module category** — turrets, cannons, torpedo bays — with a
  look + stats (mass, power, footprint, gate-fit cost), and a **contract dimension** ("military client
  wants a patrol ship with ≥4 turret hardpoints"). Players build their armed ships; the contract
  checks the spec. **Nothing fires** — zero combat code required.
- **OUT (stays cut):** combat *as gameplay* — flying, firing, enemies, damage, AI, balancing, a battle
  arena. That's a whole second game and is not part of Space Engineer.

The line: weapons are part of the *build*, not a *fight*. Any future "see it fire" behavior pairs with
the (deferred) ship tester and is a separate, opt-in decision. Weapon modules are Space-Engineer-only —
they do not transfer to Galaxia (which is non-combat).

## What this game is NOT (the Galaxia/Space-Engineer split)

Out of scope here, belongs to Galaxia: stations, the resource/production chain, blueprint *sharing*,
galaxy map / fleet logistics. **Space Engineer = the ship designer + the job-sim wrapper.**
(Combat-as-gameplay is out of *both* games — see Weapons above.)

## What transfers to Galaxia

The ship designer, the two-layer model, the functional networks (precalc), and the class/pattern
model — proven cheaply here, then adopted in Galaxia. The wrapper (contracts, economy, ratings,
awards) is Space-Engineer-only and does not transfer.
