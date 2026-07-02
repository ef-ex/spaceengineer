# Asset pipeline & folder structure

**Status:** Active (2026-07-02). How authored meshes get from Houdini into the game, where files
live, and how morph controls are configured. Owned here; `ship_designer_spec.md` cross-links.

## Folder structure

```
godot/
  addons/riggers/                 # the Rigger's editor plugin (procedural mesh tool)
  models/pieces/                  # authored building-piece meshes (.glb) — Houdini exports here
  textures/                       # texture images (.png/.ktx…): glTF-extracted or hand-painted
  materials/                      # material resources (.tres/.material): glTF-extracted or authored
  resources/pieces/               # piece configs (.tres): WallPiece = mesh ref + morph controls
  resources/                      # other config resources (designer_config.tres, …)
  scripts/designer/pieces/        # piece resource classes (morph_control.gd, wall_piece.gd)
  scripts/designer/               # designer runtime code
source/                           # .hip authoring files only (NOT imported by the engine)
```

## Textures & materials

Meshes export **geometry-only** (no baked material) so the game assigns materials — either in code
(procedural pieces like walls) or from editable resources:

- **`textures/`** — image files. If a glTF ships embedded textures, use the Import dock's
  **Extract Textures** to write them here as editable images.
- **`materials/`** — `StandardMaterial3D`/`ShaderMaterial` `.tres`. Get them via **Extract
  Materials** (Advanced Import Settings → `Actions… → Extract Materials`) so edits survive reimport,
  or author them by hand and assign per surface. Never edit the imported-scene materials directly —
  they're locked and regenerated on reimport.

Existing `wall_1.glb` still sits in `models/` for now; move it to `models/pieces/` **via the editor
FileSystem dock** (not the OS — the editor preserves the `uid` + its `root_scale` import setting).

## Houdini → Godot: glTF, not FBX

- **Format: glTF `.glb`** via the **plain `rop_gltf`** ROP (not the character output — that drags a
  useless skeleton). glTF carries blend shapes as native morph targets; FBX drops them in Godot.
- **Export straight into `godot/models/pieces/`** — no `source/export/` staging + manual copy.
- **Blend-shape targets must be *named packed primitives*** into `characterblendshapesadd` (Pack +
  Name per target). Loose named polygons silently produce zero morphs. See `blendshape-morph-workflow`
  memory + `ship_designer_spec.md`.
- **⚠ Every glTF's import `root_scale` must be `1.0`.** The project's scene-import default is `100`
  (a leftover from the FBX pipeline, which came in at cm). glTF is meters-native, so `100` bakes the
  mesh ×100 → giant walls. Fix per-file in the Import dock (or the `.glb.import`: `nodes/root_scale=1.0`)
  until/unless the project default is changed to 1.

## Piece configs (data-driven morph controls)

A **`WallPiece`** (`resources/pieces/*.tres`) pairs an imported `.glb` with a list of **`MorphControl`**
entries — one per blend shape — describing how each morph maps to an on-object handle (anchor, drag
direction/invert, arrows, default weight). Press **"Scan blend shapes"** on the WallPiece to auto-add a
control per morph, then tune each in the inspector. The designer renders the mesh and spawns handles
from this config, so **no morph is hardcoded** — author a new morph in Houdini, re-export, re-scan, and
its handle appears. (Classes: `scripts/designer/pieces/wall_piece.gd`, `morph_control.gd`.)
