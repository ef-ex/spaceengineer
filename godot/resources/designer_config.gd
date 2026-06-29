class_name DesignerConfig
extends Resource
## Tunable data for the ship designer. Edit `designer_config.tres` in the Godot
## inspector — never hard-code these values in designer.gd. ("Feel lives in
## DATA", see CLAUDE.md.) The defaults here are the safety fallback used when no
## .tres is assigned; the .tres is the authoritative source of truth.

@export_group("Grid")
## Cells per side of one deck (the X/Z build plane).
@export var grid_size: int = 16
## World units per grid cell. Tiles and grid lines scale with this.
@export var cell_size: float = 1.0

@export_group("Camera")
## Starting orbit yaw (radians, around Y).
@export var orbit_initial_yaw: float = -0.7
## Starting orbit pitch (radians above the plane).
@export var orbit_initial_pitch: float = 0.9
## Starting distance from the grid centre.
@export var orbit_initial_distance: float = 24.0
# Near-full vertical range so the ship can be admired from any angle (just shy of
# the poles, where look_at(UP) would flip). Negative = looking up from below.
@export var orbit_min_pitch: float = -1.5
@export var orbit_max_pitch: float = 1.5
@export var orbit_min_distance: float = 6.0
@export var orbit_max_distance: float = 60.0
## Orbit sensitivity, radians per pixel of right-drag.
@export var orbit_speed: float = 0.01
## Distance change per mouse-wheel notch.
@export var zoom_step: float = 2.0
## WASD/QE free-move speed, in "screen-distances" per second — scaled by zoom so
## panning feels the same close-in and far-out. Feel knob.
@export var pan_speed: float = 1.2

@export_group("World")
@export var background_color: Color = Color(0.05, 0.06, 0.09)
@export var ambient_color: Color = Color(0.40, 0.45, 0.55)
@export var ambient_energy: float = 0.7
@export var sun_rotation_degrees: Vector3 = Vector3(-55, -40, 0)
@export var sun_energy: float = 1.1

@export_group("Tiles")
@export var grid_line_color: Color = Color(0.30, 0.40, 0.55, 0.6)
@export var hull_tile_color: Color = Color(0.55, 0.70, 0.95)
@export var hull_tile_metallic: float = 0.2
@export var hull_tile_roughness: float = 0.6
## Perimeter walls drawn on hull edges that face open space (full-ship + delivery
## views), so the ship reads as a volume rather than bare floors.
@export var wall_color: Color = Color(0.42, 0.52, 0.70)
@export var wall_thickness: float = 0.08
## Opacity of the perimeter shell drawn around the active deck while editing, so
## the floor reads as an enclosed room without hiding the top-down build view.
## 0 = off (bare floor plan); ~0.35 = a clear see-through hull. Feel knob.
@export_range(0.0, 1.0) var edit_shell_alpha: float = 0.35
## Translucent valid-placement preview under the cursor.
@export var ghost_color: Color = Color(1.0, 1.0, 1.0, 0.22)
## Translucent preview when the cursor placement is invalid.
@export var ghost_invalid_color: Color = Color(0.85, 0.23, 0.23, 0.30)

@export_group("Decks")
## Vertical world spacing between decks (floor-to-floor), in metres. NOT gridded — the
## only grid is horizontal (cell_size); decks sit at deck*deck_height on a free Y axis,
## so any value is safe. Tuned to a human-standable ~2.5 m (a 1 m ceiling is a coffin;
## real stand-up vehicle cabins are 1.9–2.2 m). Live value lives in designer_config.tres.
@export var deck_height: float = 2.5

@export_group("Overlay & feedback")
## Flat colour hull/modules fade to when a network overlay is active, so the
## live network reads clearly (the ONE-overlay-at-a-time pattern).
@export var overlay_dim_color: Color = Color(0.16, 0.18, 0.22)
@export var status_ok_color: Color = Color(0.18, 0.62, 0.46)
@export var status_warn_color: Color = Color(0.73, 0.46, 0.09)
@export var status_error_color: Color = Color(0.85, 0.23, 0.23)
@export var status_inactive_color: Color = Color(0.42, 0.45, 0.50)

@export_group("Networks")
@export var power_color: Color = Color(0.93, 0.62, 0.15)
@export var heat_color: Color = Color(0.85, 0.35, 0.25)
## Conduit segment visual: height above the floor and box thickness.
@export var conduit_height: float = 0.14
@export var conduit_thickness: float = 0.24

@export_group("Wall handle")
## On-object morph handle (Select mode): drag it to scrub a wall selection's
## flat<->thick morph live — replaces the old 3-level Edit radial. All feel knobs.
## Screen-pixel radius within which a click grabs the handle.
@export var handle_pick_px: float = 24.0
## Cursor pixels of drag for a full 0..1 morph sweep. Lower = more sensitive.
@export var handle_drag_px: float = 180.0
## How far (m) the handle floats off the wall face along its outward normal.
@export var handle_offset_m: float = 0.5
## Distance->scale factor so the handle holds a near-constant on-screen size.
@export var handle_screen_scale: float = 0.02
## Handle colour.
@export var handle_color: Color = Color(1.0, 0.78, 0.25)
