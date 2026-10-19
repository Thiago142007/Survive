extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var script_resource: GDScript = load("res://scripts/world/island_generator_v2.gd")
	var first = script_resource.new()
	first.seed = 12345
	first.island_count = 12
	first.call("_rebuild_layout")
	var same = script_resource.new()
	same.seed = 12345
	same.island_count = 12
	same.call("_rebuild_layout")
	var other = script_resource.new()
	other.seed = 67890
	other.island_count = 12
	other.call("_rebuild_layout")
	var first_layout: Array[Dictionary] = first.get_world_layout_snapshot()
	assert(first_layout == same.get_world_layout_snapshot(), "A mesma seed deve repetir o layout e os campos geograficos")
	assert(first_layout != other.get_world_layout_snapshot(), "Seeds diferentes devem gerar arquipelagos diferentes")
	assert(first_layout.size() >= 5 and first_layout.size() <= 14)
	for index in range(first_layout.size()):
		var island: Dictionary = first_layout[index]
		for previous in range(index):
			var older: Dictionary = first_layout[previous]
			var center: Vector3 = island["center"]
			var older_center: Vector3 = older["center"]
			assert(center.distance_to(older_center) > (float(island["radius"]) + float(older["radius"])) * 1.5)
	var central: Dictionary = first_layout[0]
	var distinct_samples := 0
	for point in [Vector2(-180, -160), Vector2(160, -180), Vector2(140, 160), Vector2(-140, 150)]:
		var a := float(first.call("_terrain_height", central, point))
		var b := float(same.call("_terrain_height", same.get_world_layout_snapshot()[0], point))
		var c := float(other.call("_terrain_height", other.get_world_layout_snapshot()[0], point))
		assert(is_equal_approx(a, b), "O relevo precisa ser reproduzivel")
		if absf(a - c) > 2.0:
			distinct_samples += 1
	assert(distinct_samples >= 2, "A seed deve alterar a topografia, nao apenas mover ilhas")
	var seed_parser = load("res://scripts/world/world_seed.gd")
	for seed_value in [0, -42, seed_parser.parse("ilha tropical")]:
		var probe = script_resource.new()
		probe.seed = seed_value
		probe.call("_rebuild_layout")
		var repeat = script_resource.new()
		repeat.seed = seed_value
		repeat.call("_rebuild_layout")
		assert(probe.get_world_layout_snapshot() == repeat.get_world_layout_snapshot(), "Seeds zero, negativas e textuais precisam repetir o mesmo mundo")
		assert(probe.get_world_layout_snapshot() != first_layout, "Seeds independentes devem mudar a geografia")
		probe.free()
		repeat.free()
	assert(float(first.call("_terrain_height", central, Vector2.ZERO)) > -0.3, "O spawn precisa ser terrestre")
	assert(not central["caves"].is_empty(), "A ilha inicial precisa ter caverna acessivel")
	var cave: Dictionary = central["caves"][0]
	assert(bool(first.call("_inside_cave_opening", central, cave["mouth"])), "A entrada precisa abrir a malha superficial")
	var mesh: ArrayMesh = first.call("_make_terrain_mesh", central)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert(not _surface_covers(vertices, indices, cave["mouth"]), "A boca da caverna precisa atravessar a malha superficial")
	assert(not _surface_covers(vertices, indices, cave["mouth"] + cave["direction"] * 5.0), "O inicio do tunel precisa permanecer aberto")
	for extra_seed in [67890, 424242]:
		var cave_probe = other if extra_seed == 67890 else script_resource.new()
		if extra_seed != 67890:
			cave_probe.seed = extra_seed
			cave_probe.call("_rebuild_layout")
		var probe_island: Dictionary = cave_probe.get_world_layout_snapshot()[0]
		assert(not probe_island["caves"].is_empty())
		var probe_cave: Dictionary = probe_island["caves"][0]
		var probe_mesh: ArrayMesh = cave_probe.call("_make_terrain_mesh", probe_island)
		var probe_arrays := probe_mesh.surface_get_arrays(0)
		assert(not _surface_covers(probe_arrays[Mesh.ARRAY_VERTEX], probe_arrays[Mesh.ARRAY_INDEX], probe_cave["mouth"]), "A seed %d deve deixar a entrada aberta" % extra_seed)
		if extra_seed != 67890:
			cave_probe.free()
	var island_body := StaticBody3D.new()
	first.call("_add_cave", island_body, central, cave, 0)
	var cave_body: StaticBody3D = island_body.get_node("Cave_0")
	assert(cave_body.get_node("CollisionShape3D").shape is ConcavePolygonShape3D, "O tunel precisa de colisao")
	var cave_mesh: ArrayMesh = cave_body.get_node("MeshInstance3D").mesh
	assert(cave_mesh.get_surface_count() > 0, "O tunel precisa de malha navegavel")
	assert(cave_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() > 16 * 7 * 6, "O fundo da caverna precisa ser fechado")
	var cave_vertices: PackedVector3Array = cave_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cave_floor: float = cave_vertices[0].y
	var mouth_height := float(first.call("_terrain_height", central, cave["mouth"]))
	assert(absf(cave_floor - mouth_height) < 1.0, "A entrada precisa conectar o piso ao terreno")
	for section in range(17):
		var floor_height := cave_vertices[section * 8].y
		var roof_height := cave_vertices[section * 8 + 4].y
		assert(roof_height - floor_height >= 4.5, "O tunel precisa ter altura para navegar")
		assert(floor_height > -0.3, "A caverna planejada nao pode afundar sob o oceano")
	var decoration_a := Node3D.new()
	var decoration_b := Node3D.new()
	first.call("_spawn_tropical_details", decoration_a, central)
	same.call("_spawn_tropical_details", decoration_b, same.get_world_layout_snapshot()[0])
	var forest_a: MultiMeshInstance3D = decoration_a.get_node_or_null("ForestCanopies")
	var forest_b: MultiMeshInstance3D = decoration_b.get_node_or_null("ForestCanopies")
	assert(forest_a != null and forest_b != null and forest_a.multimesh.instance_count > 0, "A floresta precisa gerar instancias visiveis")
	assert(forest_a.multimesh.instance_count == forest_b.multimesh.instance_count)
	assert(forest_a.multimesh.get_instance_transform(0) == forest_b.multimesh.get_instance_transform(0), "A decoracao precisa ser reproduzivel")
	print("Procedural v2 layout, relief, cave opening and collision: PASS")
	decoration_a.free()
	decoration_b.free()
	island_body.free()
	first.free()
	same.free()
	other.free()
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
