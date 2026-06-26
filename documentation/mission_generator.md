# Mission / Contract Generator — Spec

**Status:** Active design (2026-06-22).
**Working title:** **Rigger's Hullworks** (chosen 2026-06-26). See `game_vision.md`.
**Related:** `game_vision.md`, `ship_designer_spec.md` (shares the precalc solver), `prototype_scope.md`.

---

## Goal

Clients commission ships. The generator must be **procedural** (endless varied contracts) AND
**predictable** (deterministic, always solvable, legible, controllable difficulty).

## Core principle: generate from the solution space, not the requirement space

Do **not** roll random requirements and hope they're buildable. Instead:

1. Read the player's current **tech / class / unlocked modules** → compute the **feasible envelope**.
2. Set the contract's hard requirements **inside that envelope** → solvable by construction.
3. **Difficulty = how tight** the constraints are vs. the envelope. Never emit a zero-solution contract.

The same precalc graph-solver used for ship validation is used here to confirm solvability.

## The three-bucket requirement model

| Bucket | Behaviour | Generation rule | Examples |
|---|---|---|---|
| **1. Hard requirement** | Deliver-or-fail | Generate **from the feasible envelope** | mining type (solid/gas), cargo type, "fits gate class Y", a minimum capability |
| **2. Bounded-random** | Must be met; value rolled | Roll **within the solvable range** | crew count, minimum speed, budget |
| **3. Soft preference** | Never blocks delivery; modifies rating | **Free to randomize** (always satisfiable) | use this colour, name it X, under budget, exceed speed, single-pattern build |

Bucket 1 needs the envelope check; buckets 2 and 3 are inherently safe to randomize. (Colour is the
canonical bucket-3 case — it can never make a contract unsolvable.)

## Rating, reputation & who approaches you

- **Hard + bounded-random** = the pass/fail gate (can you deliver at all).
- **Soft preferences** = the **rating spread** — how *good* the delivery is.
- **Reputation accumulates from ratings** and gates the game:
  - Which **clients approach you** (bad rep → only small/low-tier clients, even if cash-rich).
  - Which **shipyards become purchasable** in the shop (→ bigger classes).
  - **Pattern unlocks** (a corporation approaches offering their design school).

> **Recovery floor (must design):** always keep low-tier "bread and butter" contracts available so a
> bad-rep player can grind back up. Without it the reputation gate becomes a death-spiral. Open item —
> see `open_questions.md`.

## Awards

Prestige milestones (e.g. **max rating 3× in a row**) grant **awards** that **attract luxury / high-
tier clients**. They are the prestige ladder toward the generation-ship finale (`game_vision.md`).

## Delivery quality & penalties

- **Minimum-to-ship gate:** a ship must be functional enough to deliver (e.g. it can actually fly —
  no engines = cannot ship). Below that, delivery is blocked.
- **Bad-but-shippable:** **reduced pay + a reputation hit** — NOT an out-of-pocket fine. The rep hit
  is the self-correcting consequence; fines sour a creative/relaxed game.
- **Fines only for opt-in high-stakes contracts** ("double pay, but a penalty if you miss spec") —
  the player chose the risk, so it's fun rather than punishing.

## Predictability mechanisms (summary)

- **Seeded RNG** → reproducible missions (testing, fairness).
- **Envelope-derived hard reqs** → always solvable.
- **Legible terms** → cargo ≥ X, fits gate class Y, budget Z.
- **Difficulty = tightness** → early contracts aim at the *middle* of the envelope (many solutions);
  later ones tighten toward the edges (small gate + high capacity + low budget squeeze).

## Drake contract archetypes (prototype set)

| Contract | Hard requirement | What it exercises |
|---|---|---|
| Mining vessel (solid/gas) | mining drill of the right type | module choice + power/heat routing |
| Cargo (solid/gas/liquid, one type) | matching cargo bay, capacity ≥ X | volume vs. gate-fit squeeze |
| Transport (A→B) | crew/passenger + speed | the "just make it work" baseline |
| Scanning vessel | sensors + data capacity | external-module placement (facing) |
| Racing ship | top speed ≥ X, minimal else | extreme thrust-vs-mass tradeoff |

**Scope guard (racing):** validate "fast enough" from the *computed top-speed stat* (precalc) — do
NOT add an actual flight/race mode to the prototype.

## Prototype subset

3–5 archetypes; small parameter space; difficulty = gate size + budget tightening over ~3–5
contracts; seeded. Reputation/awards/penalty systems are light or stubbed in the prototype; the full
weighted, multi-pattern generator is vision.
