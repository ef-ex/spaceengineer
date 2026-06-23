# Graph Report - D:\godotGames\spaceengineer\godot  (2026-06-23)

## Corpus Check
- 4 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 8 nodes · 8 edges · 1 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]

## God Nodes (most connected - your core abstractions)
1. `spaceengineer` - 9 edges
2. `res://icon.svg` - 1 edges
3. `window/stretch/mode=canvas_items` - 1 edges
4. `window/stretch/aspect=expand` - 1 edges
5. `3d/physics_engine=Jolt Physics` - 1 edges
6. `rendering_device/driver.windows=d3d12` - 1 edges
7. `res://addons/gdUnit4/plugin.cfg` - 1 edges
8. `res://addons/godot_mcp/plugin.cfg` - 1 edges

## Surprising Connections (you probably didn't know these)
- `spaceengineer` --uses_project_icon--> `res://icon.svg`  [EXTRACTED]
  project.godot → res://icon.svg
- `spaceengineer` --enables_editor_plugin--> `res://addons/gdUnit4/plugin.cfg`  [EXTRACTED]
  project.godot → res://addons/gdUnit4/plugin.cfg
- `spaceengineer` --enables_editor_plugin--> `res://addons/godot_mcp/plugin.cfg`  [EXTRACTED]
  project.godot → res://addons/godot_mcp/plugin.cfg

## Communities

### Community 0 - "Community 0"
Cohesion: 0.29
Nodes (8): window/stretch/aspect=expand, window/stretch/mode=canvas_items, 3d/physics_engine=Jolt Physics, spaceengineer, rendering_device/driver.windows=d3d12, res://addons/gdUnit4/plugin.cfg, res://addons/godot_mcp/plugin.cfg, res://icon.svg

## Knowledge Gaps
- **7 isolated node(s):** `res://icon.svg`, `window/stretch/mode=canvas_items`, `window/stretch/aspect=expand`, `3d/physics_engine=Jolt Physics`, `rendering_device/driver.windows=d3d12` (+2 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `res://icon.svg`, `window/stretch/mode=canvas_items`, `window/stretch/aspect=expand` to the rest of the system?**
  _7 weakly-connected nodes found - possible documentation gaps or missing edges._