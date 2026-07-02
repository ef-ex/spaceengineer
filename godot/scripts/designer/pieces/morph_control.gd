@tool
class_name MorphControl
extends Resource
## One authored morph control = an ARROW the designer shows in-game to drive one blend shape. The
## Piece Rigger authors its position + direction (where the arrow sits and the axis it points/drags
## along); the runtime spawns the arrow there and dragging it sets that blend shape's weight.

## The blend shape this arrow drives (e.g. "wall.thin"). Set by WallPiece's scan.
@export var blend_shape := ""
## Player-facing label / tooltip.
@export var label := ""
## Arrow base position, in the mesh's local space.
@export var position := Vector3.ZERO
## Arrow direction = drag axis (normalized), in the mesh's local space. Points from weight 0 → 1.
@export var direction := Vector3.UP
## Flip so dragging along +direction lowers the weight instead of raising it.
@export var invert := false
## Weight the wall starts at (0 = base mesh, unmorphed).
@export_range(0.0, 1.0, 0.01) var default_weight := 0.0
