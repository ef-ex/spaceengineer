# spaceengineer — project instructions

This project follows **Vela's coding-agent operating standard** (source of truth: the velaHub
orchestration roles + skills). The rules that matter for building this game are distilled below,
plus project-specific conventions. Per Vela's meta-rule, skills/roles stay project-agnostic and
project specifics live here.

> "Space Engineer" is a placeholder name. Design is the source of truth in `documentation/`.

## How to work (Vela coding-agent rules)

The global working rules apply: lead with the outcome, act when the path is clear, pause only for
real stakes, audit claims against evidence, a question's deliverable is your assessment, match
effort to the task.

**Ponytail always on.** Climb the ladder: does it need to exist (YAGNI) → engine/stdlib feature →
existing dependency → one line → only then minimal code. Shortest working diff; no unrequested
abstractions or dependencies. Never simplify away validation, error handling, security, determinism,
or feel-tunables-in-data.

**Reuse before building; tight scope.** Search the project first and extend existing systems instead
of reimplementing. Solve the requested problem only — no unrelated drive-by changes. Design small,
deep modules with clear interfaces.

## Game-dev disciplines (game-programmer / game-designer)

- **Two kinds of code, two kinds of proof.**
  - *System logic* (state machines, save/load, spawning, validation, the ship-network precalc, the
    mission generator): write **gdUnit4** tests and run them. No "it works" without execution evidence.
  - *Feel* (movement, feedback, juice): **not unit-testable — verified by playing.** Run the game and
    exercise the change. Never auto-approve feel; when the question is "does this feel right?", surface
    it to the user — their play is the oracle.
- **Feel lives in DATA, not code.** Every value worth tuning (speeds, cooldowns, spawn rates, easing,
  shake, gate tolerances, budgets, ratings weights) lives in a config/constants resource, never
  hard-coded in logic. Hard-coding a tunable is a bug.
- **Performance is a feature.** Keep per-frame hot paths allocation-free where the engine cares; flag
  anything risking frame budget; don't micro-optimize cold code.
- **Determinism where it matters.** Keep simulation off the render clock when reproducibility matters
  (e.g. the seeded mission generator, the precalc network solve).

## Testing (required)

- Use **gdUnit4** (`godot/addons/gdUnit4`) for system-logic tests. Test behavior through public
  interfaces, not internals. Run the smallest slice covering the change first, then broaden.
- **Reproduce first**, then fix; add a regression test for every bug (fails on old behavior, passes
  after).
- Run the actual game to verify gameplay/feel changes and report what you observed.
- Never claim success from reading code — run it and cite the result.

## Git

Never commit, amend, or push unless explicitly asked; never run destructive git or skip hooks without
explicit request. Day-to-day work on **`experimental`**; promote to **`main`** for Steam releases.

## Project layout

- **`documentation/`** — design docs, the source of truth. Read before building: `game_vision.md`,
  `prototype_scope.md`, `ship_designer_spec.md`, `mission_generator.md`, `ships_and_stations_design.md`,
  `open_questions.md`. Match documented scope; don't present deferred features as done.
- **`godot/`** — the Godot 4.7 project (GDScript). Engine-ready code, scenes, assets.
- **`source/`** — authoring source files (Houdini `.hip`, Blender, source textures/audio); not
  imported directly by the engine.
- **`godot/addons/`** — gdUnit4 (tests), godot_mcp (AI bridge).

## Graphify (graph-first)

A GDScript knowledge graph lives in `godot/graphify-out/`. Before reading or grepping to understand
or change game code, query the graph first:

- Query (global CLI), run from `godot/`: `graphify query "<question>"`
- Rebuild after code changes, run from `godot/`:
  `PYTHONPATH=F:\projects\graphify\src F:\projects\graphify\.venv\Scripts\python.exe -m godot_graphify . --build --label "Space Engineer"`

Cold Read/Grep is the fallback when the graph doesn't surface enough.
