extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node_or_null("Main")
	assert(main != null)
	main.world_seed = 12345
	var focus := Node3D.new()
	root.add_child(focus)
	main.player = focus
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.stream_radius_chunks = 1
	root.add_child(generator)
	await process_frame
	var descriptor: Dictionary = generator.island_descriptors[0]
	var aspect := float(descriptor["aspect"])
	var reach := float(descriptor["radius"]) * maxf(aspect, 1.0 / aspect) * 1.42 + 45.0
	var chunk: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	var terrain: Mesh = chunk.get_node("central/MeshInstance3D").mesh
	var canopy: MultiMesh = chunk.get_node("ForestCanopies").multimesh
	var trunk: MultiMesh = chunk.get_node("ForestTrunks").multimesh
	var ground: MultiMesh = chunk.get_node("GroundCover").multimesh
	var stone: MultiMesh = chunk.get_node("StoneCover").multimesh
	var tree_transform := canopy.get_instance_transform(0)
	assert(ground.visible_instance_count == ground.instance_count)
	assert(stone.visible_instance_count == stone.instance_count)

	focus.global_position = Vector3(reach + 300.0, 0.0, 0.0)
	await process_frame
	await process_frame
	assert(generator.loaded_chunks.has(Vector2i.ZERO))
	assert(ground.visible_instance_count > 0 and ground.visible_instance_count < ground.instance_count)
	assert(canopy.visible_instance_count == canopy.instance_count)
	assert(trunk.visible_instance_count == canopy.visible_instance_count)

	focus.global_position = Vector3(reach + 600.0, 0.0, 0.0)
	await process_frame
	await process_frame
	assert(generator.loaded_chunks.has(Vector2i.ZERO))
	assert(ground.visible_instance_count == 0)
	assert(stone.visible_instance_count == 0)
	assert(canopy.visible_instance_count > 0 and canopy.visible_instance_count < canopy.instance_count)
	assert(trunk.visible_instance_count == canopy.visible_instance_count)
	assert(chunk.get_node("central/MeshInstance3D").mesh == terrain)
	assert(canopy.get_instance_transform(0) == tree_transform)
	var far_forest := canopy.visible_instance_count

	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	chunk = generator.loaded_chunks[Vector2i.ZERO]
	canopy = chunk.get_node("ForestCanopies").multimesh
	trunk = chunk.get_node("ForestTrunks").multimesh
	ground = chunk.get_node("GroundCover").multimesh
	stone = chunk.get_node("StoneCover").multimesh
	assert(canopy.visible_instance_count == far_forest)
	assert(canopy.get_instance_transform(0) == tree_transform)
	focus.global_position = Vector3.ZERO
	await process_frame
	await process_frame
	assert(ground.visible_instance_count == ground.instance_count)
	assert(stone.visible_instance_count == stone.instance_count)
	assert(canopy.visible_instance_count == canopy.instance_count)
	assert(chunk.get_node("central/MeshInstance3D").mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == terrain.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size())
	generator.decoration_quality = "low"
	var low_near_ground := ground.visible_instance_count
	assert(low_near_ground == roundi(ground.instance_count * 0.35))
	focus.global_position = Vector3(reach + 300.0, 0.0, 0.0)
	await process_frame
	await process_frame
	assert(ground.visible_instance_count < low_near_ground)
	focus.global_position = Vector3.ZERO
	await process_frame
	await process_frame
	assert(ground.visible_instance_count == low_near_ground)
	main.player = null
	focus.free()
	print("Procedural v2 distance LOD: PASS")
	generator.free()
	quit()
