extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed_value := 12345
	if not OS.get_environment("SURVIVE_TEST_SEED").is_empty():
		seed_value = int(OS.get_environment("SURVIVE_TEST_SEED"))
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = seed_value
	var generator = load("res://scripts/world/island_generator_v2.gd").new()
	generator.seed = seed_value
	generator.stream_radius_chunks = 0
	root.add_child(generator)
	await process_frame
	assert(generator.get_active_chunk_count() >= 1)
	assert("central" in generator.get_loaded_island_ids())
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	assert(int(diagnostics["version"]) == 2)
	assert(int(diagnostics["instances"]["forest"]) > 0)
	assert(int(diagnostics["instances"]["ground"]) > 0)
	assert(int(diagnostics["instances"]["caves"]) >= 1)
	await physics_frame
	var central: Dictionary = generator.get_world_layout_snapshot()[0]
	var cave: Dictionary = central["caves"][0]
	var mouth: Vector2 = cave["mouth"]
	var direction: Vector2 = cave["direction"]
	var mouth_height := float(generator.call("_terrain_height", central, mouth))
	var from := Vector3(mouth.x - direction.x * 4.0, mouth_height + 1.4, mouth.y - direction.y * 4.0)
	var to := Vector3(mouth.x + direction.x * 10.0, mouth_height + 0.3, mouth.y + direction.y * 10.0)
	var hit: Dictionary = generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	assert(hit.is_empty(), "A entrada da caverna nao pode estar bloqueada por colisao")
	var first_forest := int(diagnostics["instances"]["forest"])
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	var reloaded: Dictionary = generator.get_generation_diagnostics()
	assert(int(reloaded["instances"]["forest"]) == first_forest)
	var first_layout: Array[Dictionary] = generator.get_world_layout_snapshot()
	var outer_chunk: Vector2i = first_layout[1]["chunk"]
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", outer_chunk)
	generator.call("_load_chunk", Vector2i.ZERO)
	assert(int(generator.get_generation_diagnostics()["instances"]["forest"]) >= first_forest)
	assert("central" in generator.get_loaded_island_ids())
	assert(String(first_layout[1]["id"]) in generator.get_loaded_island_ids())
	print("Procedural v2 streaming: PASS ", diagnostics)
	generator.free()
	quit()
