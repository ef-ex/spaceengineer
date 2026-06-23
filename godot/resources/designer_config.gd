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
@export var orbit_min_pitch: float = 0.2
@export var orbit_max_pitch: float = 1.45
@export var orbit_min_distance: float = 6.0
@export var orbit_max_distance: float = 60.0
## Orbit sensitivity, radians per pixel of right-drag.
@export var orbit_speed: float = 0.01
## Distance change per mouse-wheel notch.
@export var zoom_step: float = 2.0

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
## Translucent preview tile shown under the cursor.
@export var ghost_color: Color = Color(1.0, 1.0, 1.0, 0.22)
