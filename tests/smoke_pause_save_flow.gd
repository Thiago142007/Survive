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
	var main := root.get_node("Main")
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
	main.game_started = false
	if not _expect(not pause_menu.save_now() and pause_menu.status_label.text.contains("Falha") and pause_menu.visible, "Save failure must show feedback and keep the pause overlay open"):
		return
	main.game_started = true
	main.world_name = "Saved before title"
	pause_menu.return_to_title()
	var saved: Dictionary = saves.read_save(active_id)
	if not _expect(saved.get("ok", false) and saved["data"].get("name") == "Saved before title", "Return to menu must save state before transition"):
		return
	if not _expect(not main.game_started and paused and world.get_node("MainMenu").visible and not world.get_node("HUD").visible and not pause_menu.visible, "Title menu must become interactive after return"):
		return
	if not _expect(main.start_new_world({"name": "After pause", "seed": 9876}) and player.gameplay_input_enabled, "Starting a new world after the pause menu must restore gameplay input"):
		return
	main.return_to_title()
	var next_world_save: Dictionary = saves.read_save(saves.active_world_id)
	if not _expect(next_world_save.get("ok", false) and main.start_world_from_save(next_world_save["data"]) and player.gameplay_input_enabled, "Loading a world after the pause menu must restore gameplay input"):
		return
	main.return_to_title()
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
