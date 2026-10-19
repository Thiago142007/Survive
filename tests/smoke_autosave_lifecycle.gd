extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node("Main")
	var saves := root.get_node("SaveManager")
	var mock_world := Node3D.new()
	mock_world.name = "AutosaveTestWorld"
	root.add_child(mock_world)
	current_scene = mock_world
	var menu := CanvasLayer.new()
	menu.name = "MainMenu"
	menu.visible = false
	mock_world.add_child(menu)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	mock_world.add_child(hud)
	if not _expect(saves.has_method("set_active_world") and saves.has_method("save_active_world"), "SaveManager must expose active-world lifecycle"):
		return
	if not _expect(saves.has_method("handle_world_generator_version"), "Generator compatibility must be explicit"):
		return
	var original_dir: String = saves.save_directory
	saves.save_directory = "user://smoke_autosave_lifecycle"
	for prior_save in saves.list_saves():
		saves.delete_save(String(prior_save.get("world_id", "")))
	main.game_started = false
	saves.set_active_world("")
	var title_save_result: bool = saves.save_active_world()
	var title_save_list: Array = saves.list_saves()
	if not _expect(not title_save_result and title_save_list.is_empty(), "Title screen must never autosave a stale world (saved=%s count=%d)" % [str(title_save_result), title_save_list.size()]):
		return
	if not _expect(saves.handle_world_generator_version(saves.WORLD_GENERATION_VERSION).get("status") == "supported", "Current generator version must load"):
		return
	if not _expect(saves.handle_world_generator_version(saves.WORLD_GENERATION_VERSION + 1).get("status") == "incompatible", "Newer generator version must be preserved as incompatible"):
		return
	main.game_started = true
	main.world_name = "Lifecycle island"
	main.world_seed = 9281
	main.autosave_interval_seconds = 1.0
	main._autosave_elapsed = 0.95
	if not _expect(saves.save_active_world(), "Manual save must create the initial active world"):
		return
	var active_id: String = saves.active_world_id
	if not _expect(not active_id.is_empty(), "Created save must become the active world"):
		return
	main.world_name = "Autosaved island"
	main._process(1.0)
	var saved: Dictionary = saves.read_save(active_id)
	if not _expect(saved.get("ok", false) and saved["data"].get("name") == "Autosaved island", "Active world must autosave after the interval"):
		return
	if not _expect(saves.load_world_thumbnail(active_id) == null, "Manual and automatic saves must not create exit thumbnails"):
		return
	if not _expect(await main._save_world_and_thumbnail(), "Shared exit helper must save the world and its thumbnail"):
		return
	var thumbnail_path: String = ProjectSettings.globalize_path(saves.get_thumbnail_path(active_id))
	var thumbnail_before_normal_save := FileAccess.get_file_as_bytes(thumbnail_path)
	var stored_thumbnail := saves.load_world_thumbnail(active_id) as Texture2D
	if not _expect(stored_thumbnail != null and stored_thumbnail.get_width() == 480 and stored_thumbnail.get_height() == 270, "Shared exit helper must create a decodable thumbnail"):
		return
	main.world_name = "Manual save after preview"
	if not _expect(saves.save_active_world(), "Manual save must remain available after thumbnail capture"):
		return
	main.world_name = "Autosave after preview"
	main._process(1.0)
	if not _expect(FileAccess.get_file_as_bytes(thumbnail_path) == thumbnail_before_normal_save, "Manual and automatic saves must not refresh an existing exit thumbnail"):
		return
	await main.return_to_title()
	saved = saves.read_save(active_id)
	if not _expect(saved.get("ok", false) and not main.game_started and paused, "Returning to title must save before deactivating gameplay"):
		return
	if not _expect(saves.delete_save(active_id), "Lifecycle test save and thumbnail must be removable"):
		return
	saves.set_active_world("")
	saves.save_directory = original_dir
	main.autosave_interval_seconds = 120.0
	main._autosave_elapsed = 0.0
	main.world_id = ""
	paused = false
	mock_world.free()
	print("Autosave lifecycle smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
