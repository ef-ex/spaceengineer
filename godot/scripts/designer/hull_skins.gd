class_name HullSkins
extends RefCounted
## Placeholder hull-wall skins for the prototype. A skin is swapped onto an exposed
## wall edge (ShipDesign.wall_skins) to restyle it. These are stand-ins for the
## authored Houdini blend-shape hull pieces (ship_designer_spec.md → "Prototype hull
## pieces"); for now a skin only changes the wall's colour + thickness. Swap this
## lookup for a real mesh/blend-shape load once the Houdini pieces exist.
##
## "" (empty id) = the default auto-generated wall — no skin.

const SKINS := [
	{"id": "armor", "name": "Armor", "color": Color(0.38, 0.42, 0.50), "thickness_mul": 2.2},
	{"id": "window", "name": "Viewport", "color": Color(0.45, 0.74, 0.96), "thickness_mul": 0.6},
	{"id": "vent", "name": "Vent", "color": Color(0.58, 0.50, 0.36), "thickness_mul": 1.6},
]


static func by_id(skin_id: String) -> Dictionary:
	if skin_id == "":
		return {}
	for s in SKINS:
		if s.id == skin_id:
			return s
	return {}
