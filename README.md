# Space Engineer (working title)

A 3D ship-design game: clients commission ships, you design them (free-form hull + a functional,
network-routed interior), deliver, get paid and rated, and rise from an unknown shop to a legendary
shipwright. The career capstone — designing humanity's generation ship — bridges into the sister
project **Galaxia**.

> **"Space Engineer" is a placeholder name.** See `documentation/` for the full design.

## Repository layout

- **`documentation/`** — design docs (vision, prototype scope, designer + mission specs).
- **`godot/`** — the Godot project (the shippable game). Has its own project-level `.gitignore`.
- **`source/`** — authoring source files (Houdini `.hip`, Blender, source textures/audio) that the
  Godot project imports baked versions of.

Editor plugins bundled in `godot/addons/`: **gdUnit4** (unit tests) and **Godot MCP** (AI bridge).

## Design docs

All design lives in [`documentation/`](documentation/):

- `game_vision.md` — read-first big picture.
- `prototype_scope.md` — what's in the first shippable build.
- `ship_designer_spec.md` — the grid/hull/interior designer.
- `designer_ux_research.md` — UX/UI/building-feature survey of shipped games, with recommendations.
- `mission_generator.md` — the procedural contract generator.
- `ships_and_stations_design.md` — the ship design model.
- `open_questions.md` — living checklist of unresolved design questions.

## Branches (Steam release model)

- **`main`** — stable. Maps to the Steam **default** branch (the public/released build).
- **`experimental`** — active development. Maps to a Steam **experimental/beta** branch for testing
  builds before they're promoted to `main`.

Day-to-day work happens on `experimental`; promote to `main` when a build is release-ready.
