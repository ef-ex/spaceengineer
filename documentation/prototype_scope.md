# Space Engineer — Prototype Scope

> **Working title:** "Space Engineer" is a placeholder — no final name chosen yet.

**Status:** Proposed scope (2026-06-22). The authoritative "what's in the first shippable build" doc.
**Relationship:** This is the prototype slice of the full vision in `game_vision.md`. Design detail:
`ship_designer_spec.md`, `mission_generator.md`, `ships_and_stations_design.md`.

> **The prototype's one job:** answer *"is the two-layer ship-design + gate-fit loop fun, and do
> people want it?"* — cheaply, shipped to itch. Everything below is judged against that, not the full
> vision. Vision features are welcome in the vision; the prototype stays tiny.

---

## The whole prototype (one sentence)

A client commissions a ship for a stated purpose that must fit through a given gate within a budget;
you shape its hull, lay out and route its interior so it works, deliver it (it flies through the
gate), get paid + rated, and the next contract is harder.

3D, Godot. Drake class only. No combat. No art suite.

## Core loop

Read contract → shape hull → place interior modules + manually route power/heat → validate (works +
fits) → ship auto-flies through the gate (pass/fail) → paid + rated → small unlock → harder contract.

---

## Feature triage

### IN — the core hook + must-haves
- **Hull shaping via authored hull pieces** — placeable parametric pieces that occupy grid cells and
  carry an **authored mesh** with simple morph/variant handles (rectangle/cell as the quick fallback).
  Flexible hull shaping is the **core creative act**, so a cheap version must be in the prototype to
  test the real hook — *not* splines, freeform sculpting, or runtime-generated geometry (those are
  vision). One bounded authored-art exception, justified by the Houdini pipeline. See
  `ship_designer_spec.md`.
- **Interior module placement + manual conduit routing** (power + heat to start; pipes/cables run in
  walls/floors). Connectivity puzzle, validated by precalc. See `ship_designer_spec.md`.
- **Gate-fit constraint** — exterior silhouette must pass the contract's gate.
- **Contract** — purpose (→ required modules/stats) + gate class + budget.
- **Validation + scripted gate fly-through** — pass/fail payoff. Scripted, NOT player flight.
- **Screenshot button** — produces marketing clips + the "share my ship" appeal.
- **Present the build** — an orbit/free camera to view the finished ship + decent default lighting and
  a clean backdrop, so even blockout ships look "cool" and screenshot well. This is half of what the
  demand test measures (people share builds they're proud of), so it's in — but **sequence it after**
  the core mechanic (build the puzzle first, then add this layer). NOT a photo mode or turntable.
- **Main menu + settings (video/audio).** Non-negotiable baseline polish; trivial to implement.

### LIGHT — minimal version only
- **Money + rating + tiny shop unlock.** Enough to make the "satisfying job" loop feel rewarding.
  Reputation/awards/penalties can be stubbed. NOT the full progression.

### OUT — deferred to the full game (good features, wrong time)
- ❌ **Combat as gameplay** (firing/battles). Weapon *modules* (turrets/cannons as cosmetic + stat
  parts) are a final-vision feature — see `game_vision.md` — but out of the prototype.
- ❌ **Ship tester / player flight** — it's a flight-control system; the scripted gate fly-through
  covers the prototype payoff. Vision feature (pairs with hall of fame).
- ❌ **Advanced art tools** — splines, painting, texture projection, complementary-color pickers.
  Use Godot's built-in ColorPicker + primitives.
- ❌ **Goliath / Titan classes** — Drake only. (Leviathan is cut from the game entirely.)
- ❌ **Full progression** — reputation-gated clients, shipyard unlocks, pattern unlocks, awards, the
  generation-ship finale. All vision.
- ❌ **Blueprints, O2/water networks (unless cheap), turntable/video, photo mode, showroom/gallery, stations.**

---

## Definition of done (ship gate)

- [ ] A first-time player can read a contract, shape a hull, route a working interior, and deliver a
      fitting ship — unaided (tutorial via the wiki system; see `open_questions.md`).
- [ ] A playtest shows a *spread* of viable designs for the same contract (freedom is real).
- [ ] One clean 15-sec hook clip exists (custom ship threading a tight gate) and reads instantly.
- [ ] The finished ship is viewable from any angle (orbit camera) and reads as "cool" under default lighting.
- [ ] ~3–5 escalating contracts + the pay/rating/small-shop loop.
- [ ] Main menu + working video/audio settings.
- [ ] No item from the OUT list snuck in.

---

## Full-game vision parking lot (NOT prototype)

Recorded so they aren't lost — see `game_vision.md` and `ships_and_stations_design.md` for the
coherent picture: ship tester + hall of fame, the **four-system build model** (procedural hull pieces,
decorative objects incl. **posed puppets**, custom modeling tools) and art tools (spline hull, copy
tools, advanced/complementary color pickers, texture projection), turntable/video capture, the
Goliath/Titan class system, the money→shipyard / reputation→clients+patterns progression,
**speculative building + resale**, reviews & awards → reputation → clients + tech, the
**generation-ship finale** (bridging into Galaxia's panspermia), the wiki-based tutorial, interior
architecture (walls/doors/rooms, stairs/elevators), and **weapon modules** (cosmetic/structural
turrets/cannons + a contract dimension). Combat-as-gameplay stays cut.
