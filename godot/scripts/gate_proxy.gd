class_name GateProxy
extends RefCounted
## A gate aperture frame sized to a contract gate (width in cells × height in
## decks), built in the Y-Z plane with its opening centred on local origin and
## facing +X. Shared by the delivery fly-through and the designer's toggleable
## "what must I fit through" reference. with_pane adds a faint translucent sheet
## across the opening so the size reads at a glance (designer); delivery omits it
## so the ship doesn't fly through a visible sheet.

static func build(gate_width: int, gate_height: int, config: DesignerConfig, with_pane := false) -> Node3D:
	var gate := Node3D.new()
	var inner_w: float = gate_width * config.cell_size      # along Z
	var inner_h: float = gate_height * config.deck_height    # along Y
	var t: float = config.cell_size * 0.35
	var pad: float = config.cell_size * 0.25
	var w := inner_w + pad * 2.0
	var h := inner_h + pad * 2.0
	var col := Color(0.55, 0.62, 0.75)
	_bar(gate, Vector3(0, h * 0.5 + t * 0.5, 0), Vector3(t, t, w + t * 2.0), col, false)
	_bar(gate, Vector3(0, -h * 0.5 - t * 0.5, 0), Vector3(t, t, w + t * 2.0), col, false)
	_bar(gate, Vector3(0, 0, w * 0.5 + t * 0.5), Vector3(t, h, t), col, false)
	_bar(gate, Vector3(0, 0, -w * 0.5 - t * 0.5), Vector3(t, h, t), col, false)
	if with_pane:
		_bar(gate, Vector3.ZERO, Vector3(0.02, inner_h, inner_w), Color(0.35, 0.7, 0.9, 0.12), true)
	return gate


static func _bar(parent: Node3D, pos: Vector3, size: Vector3, col: Color, transparent: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.metallic = 0.7
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = Color(0.15, 0.35, 0.6)
		m.emission_energy_multiplier = 0.4
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
