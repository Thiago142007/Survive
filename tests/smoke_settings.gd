extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings := root.get_node_or_null("SettingsManager")
	if not _expect(settings != null, "SettingsManager must be registered as an autoload"):
		return
	for method_name in ["load_settings", "save_settings", "apply_settings"]:
		if not _expect(settings.has_method(method_name), "SettingsManager must expose %s" % method_name):
			return
	var original_path: String = settings.settings_path
	settings.settings_path = "user://smoke_settings.cfg"
	var defaults: Dictionary = settings.load_settings()
	if not _expect(defaults.get("master_volume") == 1.0 and defaults.get("window_mode") == "windowed" and defaults.get("resolution") == "1280x720", "Settings must have safe defaults"):
		return
	var changed := {"master_volume": 0.42, "window_mode": "borderless", "resolution": "1600x900"}
	if not _expect(settings.save_settings(changed), "Settings must be saved independently"):
		return
	var loaded: Dictionary = settings.load_settings()
	if not _expect(is_equal_approx(float(loaded["master_volume"]), 0.42) and loaded["window_mode"] == "borderless" and loaded["resolution"] == "1600x900", "Settings must reload the persisted volume and display configuration"):
		return
	var config := ConfigFile.new()
	config.set_value("display", "master_volume", 9.0)
	config.set_value("display", "window_mode", "unsafe_mode")
	config.set_value("display", "resolution", "1x1")
	config.save(settings.settings_path)
	var invalid: Dictionary = settings.load_settings()
	if not _expect(invalid.get("master_volume") == 1.0 and invalid.get("window_mode") == "windowed" and invalid.get("resolution") == "1280x720", "Invalid settings must fall back to safe defaults"):
		return
	settings.settings_path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_settings.cfg"))
	print("Settings smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
