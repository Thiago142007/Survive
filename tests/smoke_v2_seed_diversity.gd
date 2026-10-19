extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const WORLD_SEED = preload("res://scripts/world/world_seed.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seeds: Array[int] = [0, 1, 12345, 67890, 99999, -1, -42, 2, 17, 31, 73, 101, 256, 1024, 2024, 8080, 31415, 65537, WORLD_SEED.parse("ilha tropical"), WORLD_SEED.parse("arquipelago azul")]
	var signatures := {}
	var island_counts := {}
	var relief_bands := {}
	var coast_shapes := {}
	var biome_samples := {}
	for seed_value in seeds:
		var generator = GENERATOR.new()
		generator.seed = seed_value
		generator.call("_rebuild_layout")
		var layout: Array[Dictionary] = generator.get_world_layout_snapshot()
		assert(layout.size() >= 5, "Cada seed precisa gerar um arquipelago valido")
		var central: Dictionary = layout[0]
		var heights: Array[int] = []
		var biomes: Array[String] = []
		var max_height := 0.0
		for point in [Vector2(-180, -160), Vector2(160, -180), Vector2(140, 160), Vector2(-140, 150), Vector2.ZERO]:
			var height := float(generator.call("_terrain_height", central, point))
			max_height = maxf(max_height, height)
			heights.append(roundi(height * 10.0))
			biomes.append(String(generator.call("_biome_at", central, point, height, generator.call("_edge_distance", central, point))))
		assert(not central["caves"].is_empty(), "A ilha inicial precisa ter entrada de caverna")
		var cave_mouth: Vector2 = central["caves"][0]["mouth"]
		var terrain_mesh: ArrayMesh = generator.call("_make_terrain_mesh", central)
		var surface := terrain_mesh.surface_get_arrays(0)
		assert(not _surface_covers(surface[Mesh.ARRAY_VERTEX], surface[Mesh.ARRAY_INDEX], cave_mouth), "A entrada precisa permanecer aberta para a seed %d" % seed_value)
		var signature := str([layout.size(), roundi(float(central["radius"])), roundi(float(central["aspect"]) * 100.0), heights, biomes, cave_mouth.round()])
		assert(not signatures.has(signature), "Seeds independentes nao devem repetir a geografia amostrada")
		signatures[signature] = true
		island_counts[layout.size()] = true
		relief_bands[roundi(max_height / 10.0)] = true
		coast_shapes[roundi(float(central["aspect"]) * 10.0)] = true
		biome_samples[str(biomes)] = true
		generator.free()
	assert(signatures.size() == 20)
	assert(island_counts.size() >= 4, "A quantidade de ilhas precisa variar entre seeds")
	assert(relief_bands.size() >= 3, "A altitude precisa variar entre seeds")
	assert(coast_shapes.size() >= 4, "O formato das ilhas precisa variar entre seeds")
	assert(biome_samples.size() >= 4, "A distribuicao de biomas precisa variar entre seeds")
	print("Procedural v2 diversity and cave openings: PASS, 20 seeds, %d island counts, %d relief bands, %d coast shapes, %d biome patterns" % [island_counts.size(), relief_bands.size(), coast_shapes.size(), biome_samples.size()])
	quit()

func _surface_covers(vertices: PackedVector3Array, indices: PackedInt32Array, point: Vector2) -> bool:
	for triangle in range(0, indices.size(), 3):
		var va := vertices[indices[triangle]]
		var vb := vertices[indices[triangle + 1]]
		var vc := vertices[indices[triangle + 2]]
		var a := Vector2(va.x, va.z)
		var b := Vector2(vb.x, vb.z)
		var c := Vector2(vc.x, vc.z)
		var ab := (b - a).cross(point - a)
		var bc := (c - b).cross(point - b)
		var ca := (a - c).cross(point - c)
		if (ab >= -0.001 and bc >= -0.001 and ca >= -0.001) or (ab <= 0.001 and bc <= 0.001 and ca <= 0.001):
			return true
	return false
