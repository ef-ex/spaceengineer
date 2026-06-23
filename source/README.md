# source/

Authoring **source files** — the originals you edit, not the engine-ready versions.

Examples: Houdini `.hip` files (ship modules via the polyfactory bridge), Blender `.blend`,
source textures (`.psd`/`.kra`/high-res), raw audio, reference material.

The shipped Godot project lives in [`../godot/`](../godot/) and imports the baked/exported
versions of these sources. Keep originals here so they're versioned but separate from the
engine project.
