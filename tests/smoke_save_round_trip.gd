extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node_or_null("Main")
	var player_script: GDScript = load("res://scripts/player/player.gd")
	var inventory_script: GDScript = load("res://scripts/inventory/inventory.gd")
	var research_script: GDScript = load("res://scripts/progression/research_system.gd")
	var building_script: GDScript = load("res://scripts/building/building_system.gd")
	var player_probe: Node = player_script.new()
	var inventory_probe: Node = inventory_script.new()
	var research_probe: Node = research_script.new()
	var building_probe: Node = building_script.new()
	for probe in [main, player_probe, inventory_probe, research_probe, building_probe]:
		for method_name in ["capture_save_snapshot"] if probe == main else ["get_save_state", "apply_save_state"]:
			if not _expect(probe.has_method(method_name), "%s must expose %s" % [probe.name if probe != main else "Main", method_name]):
				return
	player_probe.free()
	inventory_probe.free()
	research_probe.free()
	building_probe.free()
	if not _expect(main.has_method("start_world_from_save"), "Main must expose start_world_from_save"):
		return

	var world := Node3D.new()
	world.name = "SaveRoundTripWorld"
	root.add_child(world)
	current_scene = world
	main.world_seed = 431
	main.game_started = true
	var generator: Node3D = load("res://scripts/world/island_generator.gd").new()
	generator.name = "IslandGenerator"
	generator.island_count = 1
	generator.stream_radius_chunks = 0
	world.add_child(generator)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	main.player = player
	player.global_position = Vector3(12.0, 3.5, -9.0)
	player.rotation.y = 0.73
	player.camera_pivot.rotation.x = -0.31
	player._cam_mode = 2
	player._cam_distance = 6.0
	player.camera.position.z = 6.0
	player.health = 71.0
	player.hunger = 42.0
	player.thirst = 55.0
	player.energy = 28.0
	player.active_tool = "knife"
	player.character_id = "female"
	var inventory: Node = player.get_node("Inventory")
	inventory.add_item("wood", 12)
	inventory.add_item("unknown_mod_item", 7)
	var research: Node = player.get_node("ResearchSystem")
	research.level = 4
	research.experience = 18
	research.research_points = 3
	research.unlocked["agriculture"] = true
	var building_system: Node = player.get_node("BuildingSystem")
	var foundation: Node3D = load("res://scenes/building/foundation.tscn").instantiate()
	world.add_child(foundation)
	foundation.position = Vector3(6.0, 0.0, 8.0)
	building_system.place_piece(foundation)
	foundation.improvement_level = 2
	foundation.current_health = 173.0
	foundation.stress = 21.0
	var wall: Node3D = load("res://scenes/building/wall.tscn").instantiate()
	world.add_child(wall)
	wall.position = Vector3(6.0, 2.0, 8.0)
	building_system.place_piece(wall)
	building_system.remove_piece(wall)

	var snapshot: Dictionary = main.capture_save_snapshot()
	if not _expect(snapshot.get("seed") == 431 and snapshot.get("difficulty") == "normal", "World seed and difficulty must be captured"):
		return
	if not _expect(snapshot.get("player", {}).get("position") == [12.0, 3.5, -9.0], "Player transform must be captured"):
		return
	if not _expect(snapshot.get("inventory", []).size() == 2 and snapshot["inventory"][1].get("id") == "unknown_mod_item", "Inventory order and unknown IDs must be captured"):
		return
	if not _expect(snapshot.get("research", {}).get("level") == 4 and snapshot["research"].get("unlocked", {}).has("agriculture"), "Research state must be captured"):
		return
	if not _expect(snapshot.get("buildings", []).size() == 1 and snapshot["buildings"][0].get("improvement_level") == 2, "Only existing upgraded buildings must be captured"):
		return

	player.global_position = Vector3.ZERO
	player.health = 1.0
	player.apply_save_state(snapshot["player"])
	inventory.clear()
	inventory.apply_save_state(snapshot["inventory"])
	research.level = 1
	research.unlocked.clear()
	research.apply_save_state(snapshot["research"])
	building_system.apply_save_state(snapshot["buildings"])
	if not _expect(player.global_position.is_equal_approx(Vector3(12.0, 3.5, -9.0)) and is_equal_approx(player.health, 71.0), "Player state must be restored"):
		return
	var presentation := player.get_node_or_null("CharacterPresentation")
	if not _expect(presentation != null and presentation.camera_mode == 2 and presentation.get_body_model().visible and not presentation.get_arms_model().visible, "Restored camera mode must also update body and first-person-arm visibility"):
		return
	if not _expect(inventory.slots.size() == 2 and inventory.slots[1]["id"] == "unknown_mod_item", "Unknown inventory IDs must survive restoration"):
		return
	if not _expect(research.level == 4 and research.unlocked.has("agriculture"), "Research progression must be restored"):
		return
	if not _expect(building_system.placed_pieces.size() == 1 and is_equal_approx(building_system.placed_pieces[0].current_health, 173.0), "Building damage and upgrades must be restored (count=%d health=%s state=%s)" % [building_system.placed_pieces.size(), str(building_system.placed_pieces[0].get("current_health")) if building_system.placed_pieces.size() > 0 else "none", str(snapshot["buildings"]) ]):
		return

	var old_seed: int = main.world_seed
	var title_menu := CanvasLayer.new()
	title_menu.name = "MainMenu"
	world.add_child(title_menu)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	world.add_child(hud)
	main.return_to_title()
	if not _expect(title_menu.visible and not hud.visible and not main.game_started, "Returning to title must leave menu active before loading"):
		return
	if not _expect(not main.start_world_from_save({"save_format_version": 999, "seed": 7}), "Unsupported save must be rejected"):
		return
	if not _expect(main.world_seed == old_seed and not main.game_started and title_menu.visible, "Rejected save must not mutate world metadata or hide the title"):
		return
	var malformed_snapshot: Dictionary = snapshot.duplicate(true)
	malformed_snapshot["inventory"] = ["invalid slot"]
	if not _expect(not main.start_world_from_save(malformed_snapshot), "Malformed inventory entries must be rejected before activation"):
		return
	malformed_snapshot = snapshot.duplicate(true)
	malformed_snapshot["world_state"]["animals"] = {"animal-1": {"persistent_id": "animal-1", "position": "bad"}}
	if not _expect(not main.start_world_from_save(malformed_snapshot) and main.world_seed == old_seed and not main.game_started, "Malformed animal records must be rejected without mutating the active title state"):
		return
	malformed_snapshot = snapshot.duplicate(true)
	malformed_snapshot["player"]["rotation_y"] = "bad"
	if not _expect(not main.start_world_from_save(malformed_snapshot), "Malformed player rotations must be rejected before loading"):
		return
	malformed_snapshot = snapshot.duplicate(true)
	malformed_snapshot["world_state"]["resources"] = {"resource-1": {"persistent_id": "resource-1", "rotation": "bad"}}
	if not _expect(not main.start_world_from_save(malformed_snapshot) and main.world_seed == old_seed and not main.game_started, "Malformed resource rotations must be rejected without mutating the title state"):
		return
	main.player = null
	main.game_started = false
	world.free()
	print("Save round-trip smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
