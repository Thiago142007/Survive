extends Node

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"window_mode": "windowed",
	"resolution": "1280x720"
}
const SUPPORTED_RESOLUTIONS := ["1280x720", "1280x800", "1600x900", "1600x1000", "1920x1080"]
const SUPPORTED_WINDOW_MODES := ["windowed", "borderless", "fullscreen"]

var settings_path: String = "user://settings.cfg"
var current_settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

func _ready() -> void:
	current_settings = load_settings()
	apply_settings(current_settings)

func load_settings() -> Dictionary:
	var settings := DEFAULT_SETTINGS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return settings
	var volume: Variant = config.get_value("audio", "master_volume", settings["master_volume"])
	var mode: Variant = config.get_value("display", "window_mode", settings["window_mode"])
	var resolution: Variant = config.get_value("display", "resolution", settings["resolution"])
	if (volume is float or volume is int) and float(volume) >= 0.0 and float(volume) <= 1.0:
		settings["master_volume"] = float(volume)
	if mode is String and mode in SUPPORTED_WINDOW_MODES:
		settings["window_mode"] = mode
	if resolution is String and resolution in SUPPORTED_RESOLUTIONS:
		settings["resolution"] = resolution
	current_settings = settings.duplicate(true)
	return settings

func save_settings(settings: Dictionary) -> bool:
	var safe_settings := _sanitize(settings)
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", safe_settings["master_volume"])
	config.set_value("display", "window_mode", safe_settings["window_mode"])
	config.set_value("display", "resolution", safe_settings["resolution"])
	if config.save(settings_path) != OK:
		return false
	current_settings = safe_settings
	return true

func apply_settings(settings: Dictionary) -> void:
	var safe_settings := _sanitize(settings)
	current_settings = safe_settings
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var volume := float(safe_settings["master_volume"])
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(volume) if volume > 0.0 else -80.0)
	if DisplayServer.get_name() == "headless":
		return
	var mode := String(safe_settings["window_mode"])
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == "borderless")
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var resolution_parts := String(safe_settings["resolution"]).split("x")
		DisplayServer.window_set_size(Vector2i(int(resolution_parts[0]), int(resolution_parts[1])))

func _sanitize(settings: Dictionary) -> Dictionary:
	var safe_settings := DEFAULT_SETTINGS.duplicate(true)
	var volume: Variant = settings.get("master_volume", 1.0)
	if (volume is float or volume is int) and float(volume) >= 0.0 and float(volume) <= 1.0:
		safe_settings["master_volume"] = float(volume)
	var mode: Variant = settings.get("window_mode", "windowed")
	if mode is String and mode in SUPPORTED_WINDOW_MODES:
		safe_settings["window_mode"] = mode
	var resolution: Variant = settings.get("resolution", "1280x720")
	if resolution is String and resolution in SUPPORTED_RESOLUTIONS:
		safe_settings["resolution"] = resolution
	return safe_settings
