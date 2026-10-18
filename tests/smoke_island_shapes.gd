extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script: GDScript = load("res://scripts/world/island_generator.gd")
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = 424242
	var generator = generator_script.new()
	generator.seed = 424242
	generator.island_count = 12
	generator.call("_rebuild_layout")
	var layout: Array[Dictionary] = generator.get_world_layout_snapshot()
	var central: Dictionary = layout[0]
	assert(is_equal_approx(float(central["radius"]), 480.0), "A ilha inicial precisa ter 10x o raio anterior")
	assert(float(central["radius"]) * 1.32 < generator.chunk_size, "A ilha deve continuar carregada ate a costa")
	for descriptor in layout.slice(1):
		assert(float(descriptor["radius"]) >= 280.0 and float(descriptor["radius"]) <= 440.0)
		var center: Vector3 = descriptor["center"]
		assert(center.length() >= 2700.0 and center.length() <= 4500.0, "Centros precisam estar 20x mais distantes")

	var coastline_heights: Array[float] = []
	for index in range(72):
		var angle := TAU * float(index) / 72.0
		var point := Vector2(cos(angle), sin(angle)) * float(central["radius"]) * 0.85
		coastline_heights.append(float(generator.call("_terrain_height", central, point)))
	var land_count := 0
	var water_count := 0
	for height in coastline_heights:
		if height > -0.3:
			land_count += 1
		else:
			water_count += 1
	assert(land_count > 0 and water_count > 0, "A costa deve formar saliencias e enseadas")
	assert(float(generator.call("_terrain_height", central, Vector2.ZERO)) > -0.3, "O centro deve ser terra para o spawn")
	assert(not central["lakes"].is_empty(), "A ilha inicial deve ter lago")
	var lake: Dictionary = central["lakes"][0]
	assert(float(generator.call("_terrain_height", central, lake["center"])) < -0.3, "O lago deve ficar abaixo da agua")
	var highest_point := 0.0
	for z in range(-20, 21):
		for x in range(-20, 21):
			highest_point = maxf(highest_point, float(generator.call("_terrain_height", central, Vector2(x * 20.0, z * 20.0))))
	assert(highest_point > 14.0, "A ilha deve ter elevacoes visiveis e nao apenas uma planicie")
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = 51
	for sample in range(80):
		var placement: Vector3 = generator.call("_resource_position", placement_rng, central, 6.0)
		var ground_point := Vector2(placement.x, placement.z)
		assert(float(generator.call("_edge_distance", central, ground_point)) > 6.0, "Recursos devem surgir em terra firme")
		assert(is_equal_approx(placement.y, float(generator.call("_terrain_height", central, ground_point))), "Recursos devem seguir o relevo")

	root.add_child(generator)
	await process_frame
	var chunk = generator.loaded_chunks[Vector2i.ZERO]
	var island = chunk.get_node("central")
	var nearby_vegetation := 0
	for child in chunk.get_children():
		if not child is Node3D:
			continue
		var child_name := (child as Node3D).name
		var is_vegetation := child_name.begins_with("Palm_") \
			or child_name.begins_with("CoastalShrub_") \
			or child_name.begins_with("Foliage_") \
			or child_name.begins_with("Flowers_") \
			or child_name.begins_with("Sticks_") \
			or child_name.begins_with("Fruit_")
		if is_vegetation and (child as Node3D).position.distance_to(Vector3.ZERO) <= 160.0:
			nearby_vegetation += 1
	assert(nearby_vegetation >= 20, "A ilha inicial precisa de vegetacao visivel perto do spawn")
	assert(island.get_node("CollisionShape3D").shape is ConcavePolygonShape3D, "A colisao deve seguir a costa e o relevo")
	var terrain_mesh = island.get_node("MeshInstance3D").mesh
	assert(terrain_mesh is ArrayMesh, "O terreno precisa ser uma malha irregular")
	assert(terrain_mesh.get_surface_count() >= 1, "A malha precisa conter triangulos visiveis")
	var arrays: Array = terrain_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var face_normal: Vector3 = (vertices[indices[1]] - vertices[indices[0]]).cross(vertices[indices[2]] - vertices[indices[0]])
	assert(face_normal.y < 0.0, "A face superior precisa usar a orientacao frontal do Godot")
	await physics_frame
	var space: PhysicsDirectSpaceState3D = generator.get_world_3d().direct_space_state
	var land_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 100, 0), Vector3(0, -10, 0)))
	assert(not land_hit.is_empty() and land_hit["position"].y > -0.3, "A colisao do centro deve ficar acima da agua")
	var lake_center: Vector2 = lake["center"]
	var lake_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(lake_center.x, 100, lake_center.y), Vector3(lake_center.x, -10, lake_center.y)))
	assert(not lake_hit.is_empty() and lake_hit["position"].y < -0.3, "A colisao do lago deve ficar sob a agua")
	print("Island size, spacing, coves, lakes and terrain collision: PASS")
	generator.free()
	quit()
