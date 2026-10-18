extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node("Main")
	var saves := root.get_node("SaveManager")
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	if not _expect(menu_scene != null, "Main menu scene must load"):
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	if not _expect(menu.get_node_or_null("Background") is TextureRect, "Title artwork must be a TextureRect"):
		return
	var background: TextureRect = menu.get_node("Background")
	if not _expect(background.texture != null and background.texture.resource_path == "res://assets/ui/main_menu_sunset_background.png", "Title background must not contain baked menu buttons"):
		return
	for button_id in ["singleplayer", "multiplayer", "settings", "quit"]:
		if not _expect(menu.has_method("get_title_button_rect") and menu.get_title_button_rect(button_id, Vector2(1280, 720)).has_area(), "Title hotspot %s must have a screen rectangle" % button_id):
			return
		var rect_16_10: Rect2 = menu.get_title_button_rect(button_id, Vector2(1280, 800))
		if not _expect(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(rect_16_10), "Title hotspot %s must remain inside a 16:10 viewport" % button_id):
			return
		var button_name: String = {"singleplayer": "Singleplayer", "multiplayer": "Multiplayer", "settings": "Configs", "quit": "Quit"}[button_id]
		var title_button := menu.get_node_or_null("TitleHotspots/%s" % button_name) as TextureButton
		if not _expect(title_button != null and title_button.texture_normal != null and title_button.texture_normal.resource_path.ends_with("main_menu_button_%s.png" % button_id), "Title hotspot %s must render its own button sprite" % button_id):
			return
	var animated_button: TextureButton = menu.get_node("TitleHotspots/Singleplayer")
	var rest_position: Vector2 = animated_button.position
	menu._animate_title_button(animated_button, true)
	await create_timer(0.22).timeout
	if not _expect(animated_button.position.x > rest_position.x, "Hovering a title button must animate the button and its hitbox to the right"):
		return
	menu._animate_title_button(animated_button, false)
	await create_timer(0.22).timeout
	if not _expect(animated_button.position.is_equal_approx(rest_position), "The title button must return to its original hitbox position after hover"):
		return
	if not _expect(menu.get_node("TitleHotspots/Multiplayer").disabled, "Multiplayer must remain disabled"):
		return
	if not _expect(menu.get_node("TitleHotspots/Multiplayer").get_meta("hotspot_id", "") == "multiplayer" and menu.get_node("TitleHotspots/Multiplayer/ComingSoon").text == "EM BREVE", "Disabled multiplayer must still align over its image button and show the coming-soon label"):
		return
	if not _expect(menu.has_method("refresh_save_list") and menu.has_method("_on_new_world_pressed"), "Save selection and new world actions must be wired"):
		return
	menu._on_settings_pressed()
	if not _expect(menu._settings_panel.visible, "Configs hotspot must open independent settings controls"):
		return
	menu._on_settings_back_pressed()
	var previous_save_dir: String = saves.save_directory
	saves.save_directory = "user://smoke_main_menu_flows"
	for stale in saves.list_saves():
		saves.delete_save(String(stale.get("world_id", "")))
	saves.set_active_world("")
	main.game_started = false
	var fixture := _valid_save("Shared name", 12)
	var first_id: String = saves.create_save(fixture)
	var second_id: String = saves.create_save(_valid_save("Shared name", 34))
	if not _expect(not first_id.is_empty() and not second_id.is_empty() and first_id != second_id, "Same-name worlds must keep independent save IDs"):
		return
	menu._on_singleplayer_pressed()
	if not _expect(menu.save_items.item_count == 2, "World selection must list saved worlds"):
		return
	menu.save_items.select(0)
	menu._on_save_selected(0)
	menu._on_delete_selected_pressed()
	if not _expect(menu.delete_confirmation.visible and saves.list_saves().size() == 2, "Delete must require confirmation and preserve saves before confirmation"):
		return
	menu.delete_confirmation.hide() # Cancel leaves the selected save intact.
	if not _expect(saves.read_save(menu._save_ids[0]).get("ok", false), "Canceling deletion must preserve the selected save"):
		return
	menu._on_delete_confirmed()
	if not _expect(saves.list_saves().size() == 1, "Confirmed deletion must remove only the selected world"):
		return
	menu.save_items.select(0)
	menu._on_load_selected_pressed()
	if not _expect(main.game_started and saves.active_world_id == menu._save_ids[0], "Loading a world must activate its selected save"):
		return
	main.return_to_title()
	paused = false
	menu._on_new_world_pressed()
	menu.name_input.text = "New island"
	menu.seed_input.text = "67890"
	menu.character_option.select(1)
	main.player._cam_mode = 2
	main.player.camera_pivot.rotation.x = 0.5
	main.player.hotbar_tools.clear()
	main.player.hotbar_tools.append("custom_test_tool")
	menu._on_start_pressed()
	var created_snapshot: Dictionary = main.capture_save_snapshot()
	if not _expect(main.game_started and created_snapshot.get("seed") == 67890 and created_snapshot.get("character_id") == "female" and not saves.active_world_id.is_empty(), "New world must save its seed and character choice"):
		return
	if not _expect(main.player._cam_mode == 0 and is_zero_approx(main.player.camera_pivot.rotation.x) and main.player.hotbar_tools == ["hand", "knife", "stone_axe", "stone_pickaxe", "shovel"], "A new world must start with first-person camera pitch and the default hotbar"):
		return
	main.return_to_title()
	var recoverable_id: String = saves.create_save(_valid_save("Recovered island", 88))
	if not _expect(not recoverable_id.is_empty() and saves.write_save(recoverable_id, _valid_save("Recovered island", 89)), "Recovery fixture must have a valid backup"):
		return
	var damaged_path := ProjectSettings.globalize_path("%s/%s.json" % [saves.save_directory, recoverable_id])
	var damaged_file := FileAccess.open(damaged_path, FileAccess.WRITE)
	damaged_file.store_string("{damaged}")
	damaged_file.close()
	menu._on_singleplayer_pressed()
	var recoverable_index: int = menu._save_ids.find(recoverable_id)
	if not _expect(recoverable_index >= 0 and menu._save_loadable[recoverable_index], "A save with a readable backup must remain selectable for recovery"):
		return
	menu.save_items.select(recoverable_index)
	menu._on_save_selected(recoverable_index)
	menu._on_load_selected_pressed()
	if not _expect(main.game_started and saves.active_world_id != recoverable_id and saves.read_save(saves.active_world_id).get("ok", false), "Loading a backup must create a new writable save slot instead of activating the damaged primary"):
		return
	if not _expect(FileAccess.get_file_as_string(damaged_path) == "{damaged}", "Backup recovery must preserve the damaged source file for later inspection"):
		return
	main.return_to_title()
	for save in saves.list_saves():
		saves.delete_save(String(save.get("world_id", "")))
	saves.set_active_world("")
	main.game_started = false
	main.world_id = ""
	main.player = null
	paused = false
	saves.save_directory = previous_save_dir
	player.free()
	print("Main menu save flows smoke test: PASS")
	quit()

func _valid_save(name: String, seed_value: int) -> Dictionary:
	return {
		"save_format_version": 1,
		"world_generation_version": 1,
		"name": name,
		"seed": seed_value,
		"difficulty": "normal",
		"player": {},
		"inventory": [],
		"research": {},
		"buildings": [],
		"world_state": {"resources": {}, "animals": {}}
	}

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
