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
	root.add_child(generator)
	await process_frame
	var chunk: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	var terrain: Mesh = chunk.get_node("central/MeshInstance3D").mesh
	var layout := generator.get_world_layout_snapshot()
	var canopy: MultiMesh = chunk.get_node("ForestCanopies").multimesh
	var trunk: MultiMesh = chunk.get_node("ForestTrunks").multimesh
	var ground: MultiMesh = chunk.get_node("GroundCover").multimesh
	var stone: MultiMesh = chunk.get_node("StoneCover").multimesh
	var first_tree := canopy.get_instance_transform(0)
	var resource_ids := _resource_ids(chunk)
	assert(canopy.visible_instance_count == canopy.instance_count)
	assert(ground.visible_instance_count == ground.instance_count)

	generator.decoration_quality = "low"
	assert(canopy.visible_instance_count == roundi(canopy.instance_count * 0.5))
	assert(trunk.visible_instance_count == canopy.visible_instance_count)
	assert(ground.visible_instance_count == roundi(ground.instance_count * 0.35))
	assert(stone.visible_instance_count == roundi(stone.instance_count * 0.55))
	assert(chunk.get_node("central/MeshInstance3D").mesh == terrain)
	assert(generator.get_world_layout_snapshot() == layout)
	assert(_resource_ids(chunk) == resource_ids)
	assert(canopy.get_instance_transform(0) == first_tree)

	generator.decoration_quality = "medium"
	assert(canopy.visible_instance_count == roundi(canopy.instance_count * 0.8))
	assert(ground.visible_instance_count == roundi(ground.instance_count * 0.65))
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	chunk = generator.loaded_chunks[Vector2i.ZERO]
	assert(chunk.get_node("central/MeshInstance3D").mesh == terrain)
	assert(chunk.get_node("ForestCanopies").multimesh == canopy)
	assert(canopy.visible_instance_count == roundi(canopy.instance_count * 0.8))
	assert(_resource_ids(chunk) == resource_ids)

	generator.decoration_quality = "high"
	assert(canopy.visible_instance_count == canopy.instance_count)
	assert(ground.visible_instance_count == ground.instance_count)
	assert(canopy.get_instance_transform(0) == first_tree)
	generator.decoration_quality = "invalid"
	assert(generator.decoration_quality == "high")
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	assert(diagnostics["decoration_quality"] == "high")
	assert(int(diagnostics["rendered_instances"]["forest"]) == canopy.instance_count)
	generator.decoration_quality = "low"
	generator.apply_seed(67890)
	chunk = generator.loaded_chunks[Vector2i.ZERO]
	canopy = chunk.get_node("ForestCanopies").multimesh
	assert(canopy.visible_instance_count == roundi(canopy.instance_count * 0.5))
	assert(generator.get_world_layout_snapshot() != layout)
	print("Procedural v2 visual quality profiles: PASS")
	generator.free()
	quit()

func _resource_ids(chunk: Node3D) -> Array[String]:
	var ids: Array[String] = []
	for node in chunk.find_children("*", "StaticBody3D", true, false):
		if node.has_method("get_save_state"):
			ids.append(String(node.call("get_save_state").get("persistent_id", "")))
	ids.sort()
	return ids
