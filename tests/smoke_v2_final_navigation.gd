extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for world_seed in [12345, 67890, 424242]:
		var main = root.get_node_or_null("Main")
		if main:
			main.world_seed = world_seed
		var generator = GENERATOR.new()
		generator.seed = world_seed
		generator.stream_radius_chunks = 0
		root.add_child(generator)
		await process_frame
		assert(generator.loaded_chunks.has(Vector2i.ZERO), "A ilha inicial deve carregar")
		var descriptor: Dictionary = generator.island_descriptors[0]
		var chunk: Node3D = generator.loaded_chunks[Vector2i.ZERO]
		var island: StaticBody3D = chunk.get_node("central")
		await physics_frame
		var physics := generator.get_world_3d().direct_space_state
		var spawn_height := float(generator.call("_terrain_height", descriptor, Vector2.ZERO))
		var spawn_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, spawn_height + 15.0, 0.0), Vector3(0.0, spawn_height - 5.0, 0.0)))
		assert(spawn_hit.get("collider") == island, "O spawn deve ter terreno com colisao na seed %d" % world_seed)
		assert(absf(float(spawn_hit["position"].y) - spawn_height) < 2.0)
		var beach_count := 0
		for direction_index in range(32):
			var angle := TAU * float(direction_index) / 32.0
			var direction := Vector2(cos(angle), sin(angle))
			for radius in range(120, 700, 8):
				var point := direction * float(radius)
				var edge := float(generator.call("_edge_distance", descriptor, point))
				if edge <= 0.0:
					break
				if edge > 24.0 or edge < 8.0 or bool(generator.call("_inside_cave_opening", descriptor, point)):
					continue
				var height := float(generator.call("_terrain_height", descriptor, point))
				if generator.call("_biome_at", descriptor, point, height, edge) != "beach":
					continue
				var hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, height + 8.0, point.y), Vector3(point.x, height - 5.0, point.y)))
				if hit.get("collider") == island and absf(float(hit["position"].y) - height) < 2.0:
					beach_count += 1
					break
		assert(beach_count >= 4, "A seed %d deve ter praias alcancaveis com colisao" % world_seed)
		var resources := 0
		for resource in chunk.get_children():
			var resource_id := str(resource.get("persistent_id"))
			if not resource_id.contains("-tree-") and not resource_id.contains("-rock-"):
				continue
			resources += 1
			var point := Vector2(resource.position.x, resource.position.z)
			var edge := float(generator.call("_edge_distance", descriptor, point))
			assert(edge >= 4.9, "O recurso deve ficar em terra firme")
			assert(not bool(generator.call("_inside_cave_opening", descriptor, point)), "O recurso nao pode bloquear a caverna")
			assert(absf(resource.position.y - float(generator.call("_terrain_height", descriptor, point))) < 0.01, "O recurso deve acompanhar o terreno")
		assert(resources > 0)
		var cave: Dictionary = descriptor["caves"][0]
		var cave_body: StaticBody3D = island.get_node("Cave_0")
		for t in [0.25, 0.5, 0.75]:
			var mouth: Vector2 = cave["mouth"]
			var direction: Vector2 = cave["direction"]
			var lateral := Vector2(-direction.y, direction.x)
			var point: Vector2 = mouth + direction * float(cave["length"]) * t + lateral * sin(t * TAU + float(cave["phase"])) * 2.5 * t
			var floor_height: float = float(generator.call("_terrain_height", descriptor, mouth)) - 0.5 - float(cave["depth"]) * t
			var floor_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, floor_height + 2.0, point.y), Vector3(point.x, floor_height - 2.0, point.y)))
			assert(floor_hit.get("collider") == cave_body, "O tunel deve ter piso fisico na seed %d" % world_seed)
			var clearance_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, floor_height + 0.6, point.y), Vector3(point.x, floor_height + 3.5, point.y)))
			assert(clearance_hit.is_empty(), "O tunel deve ter espaco para o jogador")
		print("Navigation seed %d: beaches=%d resources=%d cave_sections=3" % [world_seed, beach_count, resources])
		generator.free()
		await process_frame
	print("Procedural v2 final navigation: PASS")
	quit()
