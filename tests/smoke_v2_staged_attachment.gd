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
	var started := Time.get_ticks_msec()
	while not generator.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - started < 10000:
		await process_frame
	assert(generator.loaded_chunks.has(Vector2i.ZERO))
	var chunk: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	var collision: CollisionShape3D = chunk.get_node("central/CollisionShape3D")
	assert(collision.shape == null, "A colisao deve ser montada em outro frame")
	assert(not generator.is_spawn_ready())
	await process_frame
	assert(collision.shape != null, "A colisao deve entrar no segundo estagio")
	assert(not generator.is_spawn_ready(), "O jogador aguarda tambem os recursos")
	await process_frame
	assert(generator.is_spawn_ready(), "A ilha deve ficar jogavel apos os recursos")
	var resource_count := 0
	for node in chunk.get_children():
		if node.has_method("get_save_state"):
			resource_count += 1
	assert(resource_count > 0)
	await physics_frame
	var hit: Dictionary = generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 30.0, 0.0), Vector3(0.0, -20.0, 0.0)))
	assert(hit.get("collider") == chunk.get_node("central"))
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.set_world_active(true)
	assert(generator.is_spawn_ready(), "A volta pelo cache deve continuar imediata")
	generator.free()

	var changed = GENERATOR.new()
	changed.seed = 12345
	changed.stream_radius_chunks = 0
	changed.async_generation_enabled = true
	root.add_child(changed)
	var changed_started := Time.get_ticks_msec()
	while not changed.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - changed_started < 10000:
		await process_frame
	assert(changed.loaded_chunks.has(Vector2i.ZERO) and not changed.is_spawn_ready())
	changed.apply_seed(67890)
	assert(int(changed.get_generation_diagnostics()["attachment_chunks_pending"]) == 0)
	changed_started = Time.get_ticks_msec()
	while not changed.is_spawn_ready() and Time.get_ticks_msec() - changed_started < 10000:
		await process_frame
	assert(changed.is_spawn_ready() and changed.seed == 67890)
	assert(int(changed.loaded_chunks[Vector2i.ZERO].get_node("central").get_meta("relief")) == int(changed.island_descriptors[0]["relief"]))
	changed.free()
	print("Procedural v2 staged attachment: PASS")
	quit()
