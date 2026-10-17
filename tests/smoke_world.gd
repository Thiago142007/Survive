extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script: GDScript = load("res://scripts/world/island_generator.gd")
	var first = generator_script.new()
	first.seed = 424242
	first.island_count = 12
	first.stream_radius_chunks = 0
	root.add_child(first)
	await process_frame

	var first_layout: Array[Dictionary] = first.get_world_layout_snapshot()
	assert(first_layout.size() == 12)
	assert(first.get_active_chunk_count() == 1)
	assert("central" in first.get_loaded_island_ids())
	var biome_ids: Array = []
	for descriptor in first_layout:
		assert(descriptor["respawn_neighbors"].size() >= 2)
		assert(descriptor["respawn_neighbors"].size() <= 3)
		if not biome_ids.has(descriptor["biome"]):
			biome_ids.append(descriptor["biome"])
	assert(biome_ids.size() >= 4)

	first.call("_load_chunk", Vector2i(1, 0))
	assert(first.get_active_chunk_count() == 2)
	first.call("_unload_chunk", Vector2i(1, 0))
	assert(first.get_active_chunk_count() == 1)

	var second = generator_script.new()
	second.seed = 424242
	second.island_count = 12
	second.stream_radius_chunks = 0
	root.add_child(second)
	await process_frame
	assert(first_layout == second.get_world_layout_snapshot())

	print("Validated deterministic layout, biome diversity, respawn graph and chunk unload")
	first.free()
	second.free()
	quit()
