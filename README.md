# Space Engineer (working title)

A 3D ship-design game: clients commission ships, you design them (free-form hull + a functional,
network-routed interior), deliver, get paid and rated, and rise from an unknown shop to a legendary
shipwright. The career capstone — designing humanity's generation ship — bridges into the sister
project **Galaxia**.

> **"Space Engineer" is a placeholder name.** See `documentation/` for the full design.

## Design docs

All design lives in [`documentation/`](documentation/):

- `game_vision.md` — read-first big picture.
- `prototype_scope.md` — what's in the first shippable build.
- `ship_designer_spec.md` — the grid/hull/interior designer.
- `mission_generator.md` — the procedural contract generator.
- `ships_and_stations_design.md` — the ship design model.
- `open_questions.md` — living checklist of unresolved design questions.

## Branches (Steam release model)

- **`main`** — stable. Maps to the Steam **default** branch (the public/released build).
- **`experimental`** — active development. Maps to a Steam **experimental/beta** branch for testing
  builds before they're promoted to `main`.

Day-to-day work happens on `experimental`; promote to `main` when a build is release-ready.
