extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = 12345
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.stream_radius_chunks = 0
	generator.async_generation_enabled = true
	root.add_child(generator)
	assert(generator.loaded_chunks.is_empty(), "A primeira ilha nao pode bloquear a entrada na cena")
	var began := Time.get_ticks_msec()
	while not generator.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - began < 10000:
		await process_frame
	assert(generator.loaded_chunks.has(Vector2i.ZERO), "A ilha central precisa terminar de carregar")
	var central: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	assert(central.has_node("central/MeshInstance3D"))
	assert(central.has_node("central/CollisionShape3D"))
	assert(central.has_node("ForestCanopies"))
	var reference = GENERATOR.new()
	reference.seed = 12345
	reference.call("_rebuild_layout")
	var descriptor: Dictionary = reference.get_world_layout_snapshot()[0]
	var expected_mesh: ArrayMesh = reference.call("_make_terrain_mesh", descriptor)
	var expected_arrays: Array = expected_mesh.surface_get_arrays(0)
	var actual_arrays: Array = central.get_node("central/MeshInstance3D").mesh.surface_get_arrays(0)
	for array_index in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		assert(actual_arrays[array_index] == expected_arrays[array_index], "O worker nao pode mudar a geometria")
	var reference_chunk := Node3D.new()
	reference.call("_spawn_tropical_details", reference_chunk, descriptor)
	var expected_canopy: MultiMesh = reference_chunk.get_node("ForestCanopies").multimesh
	var canopy: MultiMesh = central.get_node("ForestCanopies").multimesh
	assert(canopy.instance_count == expected_canopy.instance_count)
	assert(canopy.get_instance_transform(0) == expected_canopy.get_instance_transform(0))
	reference_chunk.free()
	reference.free()
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	assert(int(diagnostics["background_jobs_completed"]) >= 1)
	assert(int(diagnostics["background_jobs_active"]) == 0)
	generator.set_world_active(false)
	assert(not generator.is_spawn_ready())
	generator.set_world_active(true)
	assert(generator.is_spawn_ready(), "Um retorno ao mundo com terreno em cache deve liberar o jogador")
	generator.free()

	var changed = GENERATOR.new()
	changed.seed = 12345
	changed.stream_radius_chunks = 0
	changed.async_generation_enabled = true
	root.add_child(changed)
	changed.call("_refresh_streaming")
	assert(int(changed.get_generation_diagnostics()["background_jobs_active"]) == 1)
	changed.apply_seed(67890)
	var changed_at := Time.get_ticks_msec()
	while not changed.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - changed_at < 10000:
		await process_frame
	assert(changed.loaded_chunks.has(Vector2i.ZERO), "A nova seed precisa carregar")
	assert(changed.seed == 67890)
	assert(int(changed.loaded_chunks[Vector2i.ZERO].get_node("central").get_meta("relief")) == int(changed.island_descriptors[0]["relief"]))
	assert(int(changed.get_generation_diagnostics()["background_jobs_completed"]) == 1, "Um resultado antigo nao pode entrar no mundo novo")
	changed.free()

	var remote = GENERATOR.new()
	remote.seed = 12345
	remote.stream_radius_chunks = 0
	remote.async_generation_enabled = true
	remote.call("_rebuild_layout")
	var destination: Dictionary = remote.island_descriptors[1]
	var focus := Node3D.new()
	root.add_child(focus)
	focus.global_position = destination["center"]
	if main:
		main.player = focus
	root.add_child(remote)
	remote.set_world_active(true)
	assert(not remote.is_spawn_ready(), "Carregar um save distante precisa aguardar sua ilha")
	var remote_started := Time.get_ticks_msec()
	while not remote.loaded_chunks.has(destination["chunk"]) and Time.get_ticks_msec() - remote_started < 10000:
		await process_frame
	assert(remote.loaded_chunks.has(destination["chunk"]))
	assert(remote.is_spawn_ready(), "O spawn distante deve liberar o jogador sem carregar a ilha central")
	remote.free()
	if main:
		main.player = null
	focus.free()
	print("Procedural v2 asynchronous generation: PASS")
	quit()
