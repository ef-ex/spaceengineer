extends Node
## Autoload "Keybinds": registers the designer's rebindable actions in the
## InputMap, persists per-action overrides to user://keybinds.cfg, and exposes
## helpers for the Settings rebinding UI. Mouse actions stay fixed (shown as a
## read-only reference in Settings).

const CONFIG_PATH := "user://keybinds.cfg"

# [action, label, default keycode, default ctrl]
const DEFAULTS := [
	["des_select", "Select mode", KEY_1, false],
	["des_hull", "Hull tool", KEY_2, false],
	["des_rooms", "Rooms tool", KEY_3, false],
	["des_door", "Doors tool", KEY_4, false],
	["des_modules", "Equipment tool", KEY_5, false],
	["des_route", "Route tool", KEY_6, false],
	["des_riser", "Riser tool", KEY_7, false],
	["des_rotate", "Rotate module", KEY_R, false],
	["des_copy", "Copy selected", KEY_C, false],
	["des_mirror", "Toggle mirror", KEY_M, false],
	["des_delete", "Delete selected", KEY_DELETE, false],
	["des_undo", "Undo", KEY_Z, true],
	["des_redo", "Redo", KEY_Y, true],
	["des_menu", "Open menu", KEY_ESCAPE, false],
]


func _ready() -> void:
	for d in DEFAULTS:
		if not InputMap.has_action(d[0]):
			InputMap.add_action(d[0])
		_set_event(d[0], d[2], d[3])
	_load()


func actions() -> Array:
	return DEFAULTS


func current_event(action: String) -> InputEventKey:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


func display(action: String) -> String:
	var ev := current_event(action)
	if ev == null:
		return "—"
	var s := OS.get_keycode_string(ev.keycode)
	return "Ctrl+" + s if ev.ctrl_pressed else s


func rebind(action: String, keycode: int, ctrl: bool) -> void:
	_set_event(action, keycode, ctrl)
	_save()


func reset() -> void:
	for d in DEFAULTS:
		_set_event(d[0], d[2], d[3])
	_save()


func _set_event(action: String, keycode: int, ctrl: bool) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.ctrl_pressed = ctrl
	InputMap.action_add_event(action, ev)


func _save() -> void:
	var cfg := ConfigFile.new()
	for d in DEFAULTS:
		var ev := current_event(d[0])
		if ev:
			cfg.set_value(d[0], "keycode", ev.keycode)
			cfg.set_value(d[0], "ctrl", ev.ctrl_pressed)
	cfg.save(CONFIG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for d in DEFAULTS:
		if cfg.has_section(d[0]):
			_set_event(d[0], cfg.get_value(d[0], "keycode", d[2]), cfg.get_value(d[0], "ctrl", d[3]))
