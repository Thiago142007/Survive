extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const EXPECTED_FINGERPRINT := "39106f69ed120928de2de2ed7aa1e2d85160b16c4f69d0dcbdb5847aebbcc243"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.call("_rebuild_layout")
	var record: Array = []
	for island in generator.get_world_layout_snapshot():
		var center: Vector3 = island["center"]
		var caves: Array = []
		for cave in island["caves"]:
			caves.append([cave["mouth"], cave["direction"], cave["length"]])
		record.append([center, island["radius"], island["aspect"], island["relief"], island["temperature"], island["moisture"], caves])
	var central: Dictionary = generator.get_world_layout_snapshot()[0]
	for point in [Vector2.ZERO, Vector2(150.0, 80.0), Vector2(-170.0, -190.0)]:
		var height: float = generator.call("_terrain_height", central, point)
		record.append([point, height, generator.call("_biome_at", central, point, height, generator.call("_edge_distance", central, point))])
	var decoration := Node3D.new()
	generator.call("_spawn_tropical_details", decoration, central)
	var canopy: MultiMeshInstance3D = decoration.get_node("ForestCanopies")
	record.append([canopy.multimesh.instance_count, canopy.multimesh.get_instance_transform(0)])
	var fingerprint := str(record).sha256_text()
	print("PROCEDURAL_V2_FINGERPRINT=", fingerprint)
	if fingerprint != EXPECTED_FINGERPRINT:
		push_error("Version 2 layout, terrain samples or decoration changed unexpectedly")
		decoration.free()
		generator.free()
		quit(1)
		return
	decoration.free()
	generator.free()
	quit()
