# Concept-art direction

Art-direction decisions for generating ship/vehicle concepts. The concept-art *workspace*
(`concept-art/`) is **local-only and gitignored** — image outputs are large binaries and the WIP
style profiles live there. Only these decisions are versioned (here).

Concepts are generated with the external, project-agnostic **media-mcp** toolkit (`image-director`
+ `vehicle-director` skills + the `media-gen` MCP). That toolkit never references this project; this
doc is the project side.

## Sources of truth (link, don't restate)
- **Ship roster** → the 5 contracts in `godot/resources/contract_set.tres` (each = one buildable
  ship). Roles + gate apertures are defined there; there are **no per-ship dimension figures**.
- **Design patterns** → canonical in galaxia `documentation/module_patterns.md`, referenced by
  [`ships_and_stations_design.md`](ships_and_stations_design.md). Four patterns: **Scientific**
  (curved/cylindrical), **Industrial** & **Logistic** (blocky), **Living** (organic, endgame).
- **Base art lock** → `concept-art/style.json` (local): finish/material/render, deliberately
  shape-agnostic (silhouette chosen per generation).

## Two axes: pattern × role
A ship's look is driven by two SEPARATE axes (every major sci-fi franchise does this):
- **Pattern / manufacturer** — shared aesthetic DNA (surface, palette, panel habits) that makes a
  fleet look related. (The game's Logistic / Industrial / Scientific patterns.)
- **Role / function** — the *massing and silhouette* driven by the job. Advertise the function: find
  the one defining feature and **scale it up** until the silhouette reads the role.

When the pattern is held constant (as in the prototype), **role shape language carries ALL the
differentiation** — or every ship reads the same.

### Role shape language
| Role | Dominant feature (scale up) | Core massing / silhouette | Emotion |
|---|---|---|---|
| Courier | tiny cockpit pod + small cargo box | compact, short, smallest, slightly streamlined | nimble |
| Cargo hauler | the cargo container IS the ship | huge boxy hold spine + small tug-head cockpit + big engines | heavy workhorse |
| Mining tug | the drill / cutter head + manipulator arms | short, stubby, armoured front, oversized engines | rugged tool |
| Survey scout | forward sensor dish + booms + fuel tanks | an ELONGATED long-range hull, sensors integrated — NOT a tower | precise, far-reaching |
| Crew runabout | windowed passenger cabin + doorway | rounded, bus / shuttle-like, comfortable | safe, civilian |

**Silhouette test (QA):** fill each concept solid black — does it read as the role AND stand apart
from its siblings? If not, push the dominant mass.

## Prototype decisions
- **Concept art starts with the Logistic pattern only** (blocky freight / oil-platform look);
  Industrial and Scientific (curved, harder) deferred. NB: the pattern *system* is cut from the
  prototype **game** scope — this concept work is art R&D running ahead of the code.
- **Pattern profiles** extend the base: `concept-art/style_logistic.json` (local) = base finish +
  Logistic shape language + scale devices. Add `style_industrial.json` / `style_scientific.json`
  when those patterns come up.
- **Scale devices (always):** a **human figure** + a **countable floor grid** under the craft. Image
  models have no absolute scale, so size is set by these relative anchors — NOT by metre figures.
  Get one correctly-scaled render, then reuse it as the scale reference.
- **Courier baseline:** ~**8×3 tiles, 1 person** (chosen by feel; supersedes the earlier 6×2 guess).

## Workflow (detail in the vehicle-director skill)
Silhouette thumbnails → pick → develop via reference. Closed + cutaway as a **matched pair**
(generate one, reference it for the other, `compose_sheet` them). Re-pose / restyle / localized-edit
via reference images. Across a set, keep the pattern profile locked and vary only the subject.
