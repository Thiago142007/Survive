extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if not _expect(main_scene != null, "Main scene must load"):
		return
	var world := main_scene.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var pause_menu := world.get_node_or_null("PauseMenu")
	if not _expect(pause_menu != null and pause_menu.has_method("open_pause"), "Gameplay must include an interactive pause overlay"):
		return
	if not _expect(pause_menu.has_method("open_settings"), "Pause menu must expose in-game settings"):
		return
	var main := root.get_node("Main")
	assert(not auto_accept_quit, "Main must intercept native close requests until its asynchronous save finishes")
	var saves := root.get_node("SaveManager")
	var prior_dir: String = saves.save_directory
	saves.save_directory = "user://smoke_pause_flow"
	for stale in saves.list_saves():
		saves.delete_save(String(stale.get("world_id", "")))
	saves.set_active_world("")
	main.game_started = true
	main.world_name = "Before pause"
	var player: Node = main.player
	var inventory_ui := world.get_node("InventoryUI")
	paused = false
	pause_menu.open_pause()
	var settings_manager := root.get_node("SettingsManager")
	var original_settings_path: String = settings_manager.settings_path
	settings_manager.settings_path = "user://smoke_pause_settings.cfg"
	pause_menu.settings_button.pressed.emit()
	if not _expect(pause_menu.settings_panel.visible and not pause_menu.actions.visible and paused, "Pause settings must replace pause actions without resuming the world"):
		return
	pause_menu.settings_volume.value = 0.42
	pause_menu.settings_mode.select(1)
	pause_menu.settings_resolution.select(1)
	pause_menu.get_node("Panel/Margin/Content/SettingsPanel/SettingsActions/ApplyButton").pressed.emit()
	var persisted_settings: Dictionary = settings_manager.load_settings()
	if not _expect(is_equal_approx(float(persisted_settings["master_volume"]), 0.42) and persisted_settings["window_mode"] == "borderless" and persisted_settings["resolution"] == "1280x800", "Pause settings must apply and persist audio and display changes"):
		return
	if not _expect(pause_menu.actions.visible and not pause_menu.settings_panel.visible and paused, "Applying settings must return to pause actions without resuming"):
		return
	pause_menu.open_settings()
	var settings_cancel := InputEventAction.new()
	settings_cancel.action = "ui_cancel"
	settings_cancel.pressed = true
	pause_menu._unhandled_input(settings_cancel)
	if not _expect(pause_menu.actions.visible and not pause_menu.settings_panel.visible and paused, "Back from settings must return to the still-paused game"):
		return
	settings_manager.settings_path = original_settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_pause_settings.cfg"))
	pause_menu.continue_game()
	var pause_event := InputEventAction.new()
	pause_event.action = "ui_cancel"
	pause_event.pressed = true
	player._input(pause_event)
	if not _expect(paused and pause_menu.visible and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE), "Esc pause state must show the overlay and release the pointer"):
		return
	if not _expect(not player.gameplay_input_enabled, "Pause must disable gameplay input"):
		return
	pause_menu.continue_game()
	if not _expect(not paused and not pause_menu.visible and player.gameplay_input_enabled and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "Continue must resume gameplay and recapture the pointer"):
		return
	inventory_ui.open()
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	player._input(cancel_event)
	if not _expect(not pause_menu.visible and inventory_ui.is_open(), "Esc while inventory is open must stay with inventory instead of opening pause"):
		return
	inventory_ui.close()
	paused = false
	pause_menu.open_pause()
	if not _expect(pause_menu.save_now(), "Manual save action must save the active world"):
		return
	var active_id: String = saves.active_world_id
	if not _expect(not active_id.is_empty(), "Manual save must assign an active world ID"):
		return
	if not _expect(saves.load_world_thumbnail(active_id) == null, "Manual saves must not refresh the world thumbnail"):
		return
	main.game_started = false
	if not _expect(not pause_menu.save_now() and pause_menu.status_label.text.contains("Falha") and pause_menu.visible, "Save failure must show feedback and keep the pause overlay open"):
		return
	main.game_started = true
	main.world_name = "Saved before title"
	await pause_menu.return_to_title()
	var saved: Dictionary = saves.read_save(active_id)
	if not _expect(saved.get("ok", false) and saved["data"].get("name") == "Saved before title", "Return to menu must save state before transition"):
		return
	var exit_thumbnail := saves.load_world_thumbnail(active_id) as Texture2D
	if not _expect(exit_thumbnail != null and exit_thumbnail.get_width() == 480 and exit_thumbnail.get_height() == 270, "Returning to title must store a decodable 480x270 gameplay view"):
		return
	if not _expect(not main.game_started and paused and world.get_node("MainMenu").visible and not world.get_node("HUD").visible and not pause_menu.visible, "Title menu must become interactive after return"):
		return
	var thumbnail_path: String = ProjectSettings.globalize_path(saves.get_thumbnail_path(active_id))
	var prior_thumbnail_bytes := FileAccess.get_file_as_bytes(thumbnail_path)
	if not _expect(main.start_world_from_save(saved["data"]), "Saved world must be reloadable before testing a failed return"):
		return
	pause_menu.open_pause()
	var primary_save_path := ProjectSettings.globalize_path("%s/%s.json" % [saves.save_directory, active_id])
	var broken_save := FileAccess.open(primary_save_path, FileAccess.WRITE)
	if not _expect(broken_save != null, "Test must be able to corrupt its isolated primary save"):
		return
	broken_save.store_string("{broken}")
	broken_save.close()
	await pause_menu.return_to_title()
	if not _expect(main.game_started and pause_menu.visible and pause_menu.status_label.text.contains("Falha"), "Failed world save must keep the current world and pause screen active"):
		return
	if not _expect(FileAccess.get_file_as_bytes(thumbnail_path) == prior_thumbnail_bytes, "Failed world save must preserve the previous valid thumbnail"):
		return
	if not _expect(main.start_new_world({"name": "After pause", "seed": 9876}) and player.gameplay_input_enabled, "Starting a new world after the pause menu must restore gameplay input"):
		return
	await main.return_to_title()
	var next_world_save: Dictionary = saves.read_save(saves.active_world_id)
	if not _expect(next_world_save.get("ok", false) and main.start_world_from_save(next_world_save["data"]) and player.gameplay_input_enabled, "Loading a world after the pause menu must restore gameplay input"):
		return
	await main.return_to_title()
	if not _expect(saves.delete_save(active_id), "Pause flow test save must be removable"):
		return
	if not _expect(saves.delete_save(saves.active_world_id), "Follow-up world save must be removable"):
		return
	saves.set_active_world("")
	saves.save_directory = prior_dir
	main.game_started = false
	paused = false
	world.free()
	print("Pause save flow smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
