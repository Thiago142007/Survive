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
	var shapes: Array[Shape3D] = []
	for part_index in range(4):
		await process_frame
		var part: CollisionShape3D = chunk.get_node_or_null("central/CollisionShape3D" if part_index == 0 else "central/CollisionShape3D_%d" % part_index)
		assert(part != null, "Cada frame deve criar uma parte da colisao")
		assert(part.shape != null, "Cada frame deve instalar uma parte da colisao")
		shapes.append(part.shape)
		assert(not generator.is_spawn_ready(), "O jogador deve aguardar todas as partes da colisao")
	assert(shapes.size() == 4)
	var mesh: Mesh = chunk.get_node("central/MeshInstance3D").mesh
	var expected_faces: PackedVector3Array = mesh.get_faces()
	var face_offset := 0
	var max_delta := 0.0
	for shape in shapes:
		var part_faces: PackedVector3Array = shape.get_faces()
		for vertex in part_faces:
			assert(face_offset < expected_faces.size())
			max_delta = maxf(max_delta, vertex.distance_to(expected_faces[face_offset]))
			face_offset += 1
	assert(face_offset == expected_faces.size() and max_delta <= 0.001, "As quatro partes devem cobrir exatamente o terreno")
	var entity_stage_frames := 0
	while not generator.is_spawn_ready() and entity_stage_frames < 20:
		await process_frame
		entity_stage_frames += 1
	assert(generator.is_spawn_ready(), "A ilha deve ficar jogavel apos os recursos")
	assert(entity_stage_frames > 1, "A criacao de recursos deve ser distribuida entre frames")
	var resource_count := 0
	for node in chunk.get_children():
		if node.has_method("get_save_state"):
			resource_count += 1
	assert(resource_count > 0)
	await physics_frame
	var hit: Dictionary = generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 30.0, 0.0), Vector3(0.0, -20.0, 0.0)))
	assert(hit.get("collider") == chunk.get_node("central"))
	for shape in shapes:
		var part_faces: PackedVector3Array = shape.get_faces()
		var sample := (part_faces[0] + part_faces[1] + part_faces[2]) / 3.0
		var part_hit: Dictionary = generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 20.0, sample - Vector3.UP * 20.0))
		assert(part_hit.get("collider") == chunk.get_node("central"), "Cada parte deve participar da fisica")
	generator.call("_unload_chunk", Vector2i.ZERO)
	assert(generator._prepared_resource_plans.is_empty(), "Descarregar a ilha deve descartar planos de recursos")
	generator.set_world_active(true)
	assert(generator.is_spawn_ready(), "A volta pelo cache deve continuar imediata")
	var reloaded: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	for part_index in range(4):
		var part: CollisionShape3D = reloaded.get_node("central/CollisionShape3D" if part_index == 0 else "central/CollisionShape3D_%d" % part_index)
		assert(part.shape == shapes[part_index], "O cache deve reutilizar todas as partes da colisao")
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
	await process_frame
	await process_frame
	changed.apply_seed(67890)
	assert(int(changed.get_generation_diagnostics()["attachment_chunks_pending"]) == 0)
	assert(changed._prepared_resource_plans.is_empty(), "Trocar a seed deve descartar planos antigos")
	changed_started = Time.get_ticks_msec()
	while not changed.is_spawn_ready() and Time.get_ticks_msec() - changed_started < 10000:
		await process_frame
	assert(changed.is_spawn_ready() and changed.seed == 67890)
	assert(int(changed.loaded_chunks[Vector2i.ZERO].get_node("central").get_meta("relief")) == int(changed.island_descriptors[0]["relief"]))
	changed.free()
	print("Procedural v2 staged attachment: PASS")
	quit()
