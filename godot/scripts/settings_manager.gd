extends Node
## Autoload. Owns video + audio settings, persists them to user://settings.cfg,
## and applies them to the running game. Registered as "SettingsManager".

const CONFIG_PATH := "user://settings.cfg"
const AUDIO_BUSES := ["Master", "Music", "SFX"]

var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var resolution: Vector2i = Vector2i(1280, 720)
var vsync_enabled: bool = true
var volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply_all()


func _ensure_buses() -> void:
	# Master always exists at bus 0; create Music/SFX at runtime so no
	# default_bus_layout.tres is needed. Both route to Master.
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func apply_all() -> void:
	apply_video()
	for bus in volumes:
		apply_volume(bus, volumes[bus])


func apply_video() -> void:
	DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		var screen_pos := DisplayServer.screen_get_position(screen)
		# Integer division is intentional — window positions are whole pixels.
		@warning_ignore("integer_division")
		var centered := screen_pos + (screen_size - resolution) / 2
		DisplayServer.window_set_position(centered)
	var mode := DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func apply_volume(bus_name: String, linear: float) -> void:
	volumes[bus_name] = linear
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution_x", resolution.x)
	cfg.set_value("video", "resolution_y", resolution.y)
	cfg.set_value("video", "vsync", vsync_enabled)
	for bus in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	window_mode = cfg.get_value("video", "window_mode", window_mode)
	resolution = Vector2i(
		cfg.get_value("video", "resolution_x", resolution.x),
		cfg.get_value("video", "resolution_y", resolution.y))
	vsync_enabled = cfg.get_value("video", "vsync", vsync_enabled)
	for bus in volumes:
		volumes[bus] = cfg.get_value("audio", bus, volumes[bus])
