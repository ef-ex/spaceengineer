# Game Vision — (working title "Rigger's Hullworks")

**Status:** Active vision (2026-06-22).
**Working title:** **Rigger's Hullworks** (chosen 2026-06-26) — a diegetic title: the game is named
after the player's in-game ship workshop. Steam/USPTO/EU-trademark-clear as of that date; not yet registered.
**Read-first doc.** Detail lives in `ship_designer_spec.md` (designer mechanics + visuals),
`mission_generator.md`, `ships_and_stations_design.md` (build model + interior),
`prototype_scope.md` (scope + vision parking lot), `open_questions.md`.

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

## Shipyards — the money sink (design vs. build vs. sell-the-design)

How shipyards gate the economy **without gating creativity**:

- **Design is free.** The player can design **any** ship at any time, regardless of which shipyard
  they own. Creativity is never money-gated.
- **Building for full price needs a big-enough yard.** You get the **full sale price** only if you own
  a shipyard that can build the finished ship. If not, you **sell the design only** — the client has it
  built elsewhere — for **much less**.
- **Surface it as a simple binary; hide the mechanics.** The player just sees the outcome for *their*
  yards: "build & sell for ¤X" vs "sell design only for ¤Y (≪ X)". No need to expose the rules.
- **A shipyard is a gate + a size cap, not a class label.** Each yard is specified by its **gate
  aperture (beam × height)** and a **max size/volume**. So owning a "Titan-capable" yard does **not**
  mean you can build *every* Titan — a larger Titan needs a larger yard. Variety comes from differing
  gate shapes/sizes (a wide-but-short yard vs a tall one favour different silhouettes).
- **Two gate checks, different jobs** (the yard reuses the existing gate-fit constraint — see
  `ships_and_stations_design.md` size-constraint scenarios):
  - **Contract / delivery gate** — a *hard validity* constraint (the ship must reach the client; jump
    gate, dock). Fail it and the design isn't a valid submission at all.
  - **Shipyard / build gate** — a *soft economic* constraint (full build price vs design-only).
- **Balance intent (the whole point of the sink):** building must beat selling-the-design by enough
  that upgrading yards pays off, and **contract sizes must escalate** (via reputation-gated clients) so
  the player keeps hitting the "too big for my yard" wall. **This is where the two axes meet:**
  reputation brings the big commission; money (a bigger yard) is what lets you cash it at full price.

Vision, not prototype — the prototype keeps the LIGHT money/shop stub (`prototype_scope.md`). Open
tuning lives in `open_questions.md`.

## Awards

Prestige milestones (e.g. **max rating 3× in a row**) grant **awards**. Awards **attract luxury /
high-tier clients** and are the visible rungs of the prestige ladder toward the finale.

## Speculative building & reviews (vision)

Beyond commissions, you can **build ships on spec** (no client) — paying the build cost **up front**,
gated by your cash — and **put them up for sale**. Both delivered and sold ships earn **client reviews**
and **award nominations** that feed reputation; higher reputation brings **better clients and more tech
to buy**. (New economy loop — pricing / who-buys / unsold-upkeep TBD; see `open_questions.md`.)

## End goal — the Leviathan generation ship (win condition · bridge to Galaxia)

The **win condition**: once **reputation** is high enough, the player is offered a once-in-a-
generation commission — the **Leviathan**, humanity's generation ship. Completing it and launching it
**into deep space to colonize a new galaxy** wins the game. That vessel is **the very ship Galaxia
begins with**, kicking off Galaxia's **panspermia** mechanic — Rigger's Hullworks ends exactly where
Galaxia starts. **Leviathan is the largest ship class** — the generation/colony-ship class — and this
finale is its **capstone commission**. Vision/finale, not prototype (see `prototype_scope.md`).

## Classes

**Drake / Goliath / Titan / Leviathan.** (Leviathan = the largest, the generation/colony-ship class;
its capstone build is the win condition — see "End goal" above.)

## Weapons (cosmetic/structural modules — NOT combat)

The fantasy is building cool, iconic ships, and iconic ships (X-wing, Star Destroyer, Enterprise) are
*armed*. So weapons belong in the final vision — but as **ship modules**, not a combat system:

- **IN (final vision):** weapons as a **module category** — turrets, cannons, torpedo bays — with a
  look + stats (mass, power, footprint, gate-fit cost), and a **contract dimension** ("military client
  wants a patrol ship with ≥4 turret hardpoints"). Players build their armed ships; the contract
  checks the spec. **Nothing fires** — zero combat code required.
- **OUT (stays cut):** combat *as gameplay* — flying, firing, enemies, damage, AI, balancing, a battle
  arena. That's a whole second game and is not part of Rigger's Hullworks.

The line: weapons are part of the *build*, not a *fight*. Any future "see it fire" behavior pairs with
the (deferred) ship tester and is a separate, opt-in decision. Weapon modules are Rigger's-Hullworks-only —
they do not transfer to Galaxia (which is non-combat).

## What this game is NOT (the Galaxia/Rigger's-Hullworks split)

Out of scope here, belongs to Galaxia: stations, the resource/production chain, blueprint *sharing*,
galaxy map / fleet logistics. **Rigger's Hullworks = the ship designer + the job-sim wrapper.**
(Combat-as-gameplay is out of *both* games — see Weapons above.)

## What transfers to Galaxia

The ship designer, the two-layer model, the functional networks (precalc), and the class/pattern
model — proven cheaply here, then adopted in Galaxia. The wrapper (contracts, economy, ratings,
awards) is Rigger's-Hullworks-only and does not transfer.
