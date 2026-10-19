extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node("Main")
	var saves = root.get_node("SaveManager")
	saves.save_directory = "user://smoke_generation_versions"
	var world := Node3D.new()
	world.name = "VersionTestWorld"
	var title := CanvasLayer.new()
	title.name = "MainMenu"
	world.add_child(title)
	root.add_child(world)
	current_scene = world
	var generator = load("res://scripts/world/island_generator_v2.gd").new()
	generator.name = "IslandGenerator"
	generator.island_count = 1
	generator.stream_radius_chunks = 0
	world.add_child(generator)
	for version in [1, 2]:
		main.world_seed = 314159
		main.world_generation_version = version
		generator.generation_version = version
		generator.coastal_landmarks_enabled = version == 2
		generator.apply_seed(314159)
		var snapshot: Dictionary = main.capture_save_snapshot()
		assert(int(snapshot["world_generation_version"]) == version)
		var world_id: String = saves.create_save(snapshot)
		assert(not world_id.is_empty())
		var loaded: Dictionary = saves.read_save(world_id)
		assert(bool(loaded.get("ok", false)))
		assert(int(loaded["data"]["world_generation_version"]) == version, "O save nao pode migrar implicitamente entre geradores")
		assert(main.start_world_from_save(loaded["data"]))
		assert(generator.generation_version == version)
		assert(generator.get_world_layout_snapshot().size() >= 1)
		if version == 2:
			assert(snapshot["generation_config"].has("coastal_landmarks_enabled"), "Mundos novos devem registrar a geografia costeira no save")
			assert(bool(snapshot["generation_config"]["coastal_landmarks_enabled"]))
			var old_v2_save: Dictionary = loaded["data"].duplicate(true)
			old_v2_save["generation_config"].erase("coastal_landmarks_enabled")
			assert(main.start_world_from_save(old_v2_save))
			assert(not bool(generator.get("coastal_landmarks_enabled")), "Saves v2 antigos devem manter a costa anterior")
			assert(generator.get_world_layout_snapshot()[0]["landmark"].is_empty())
			assert(main.start_new_world({"seed": 314159}))
			assert(bool(generator.get("coastal_landmarks_enabled")), "Um mundo novo deve recuperar os marcos costeiros")
			assert(main.start_world_from_save(loaded["data"]))
			assert(bool(generator.get("coastal_landmarks_enabled")))
		assert(saves.save_active_world())
		assert(int(saves.read_save(world_id)["data"]["world_generation_version"]) == version, "Resalvar deve preservar a versao original")
		main.game_started = false
		generator.set_world_active(false)
		assert(saves.delete_save(world_id))
	print("Generator save version 1 and 2 round trips: PASS")
	world.free()
	quit()
