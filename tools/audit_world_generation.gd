extends SceneTree

## Run in separate Godot processes with SURVIVE_TEST_SEED set to a number or text.
## The fingerprint covers layout, sampled terrain/biomes, caves, decoration and resources.
const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const WORLD_SEED = preload("res://scripts/world/world_seed.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var input := OS.get_environment("SURVIVE_TEST_SEED")
	if input.is_empty():
		input = "12345"
	var world_seed: int = WORLD_SEED.parse(input)
	var generator = GENERATOR.new()
	generator.seed = world_seed
	generator.call("_rebuild_layout")
	var layout: Array[Dictionary] = generator.get_world_layout_snapshot()
	var record: Array = []
	for descriptor in layout:
		var caves: Array = []
		for cave in descriptor["caves"]:
			caves.append([cave["mouth"], cave["direction"], cave["length"], cave["width"], cave["depth"]])
		record.append([descriptor["id"], descriptor["center"], descriptor["radius"], descriptor["aspect"], descriptor["relief"], descriptor["temperature"], descriptor["moisture"], descriptor["landmark"], caves])
	var metrics: Array[Dictionary] = []
	for island_index in range(mini(2, layout.size())):
		var descriptor: Dictionary = layout[island_index]
		var heights: Array = []
		var biomes: Array = []
		var max_height := -INF
		var beach_samples := 0
		for z in range(-9, 10):
			for x in range(-9, 10):
				var point := Vector2(float(x), float(z)) * float(descriptor["radius"]) / 11.0
				var edge := float(generator.call("_edge_distance", descriptor, point))
				var height := float(generator.call("_terrain_height", descriptor, point))
				if edge <= 0.0:
					continue
				var biome: String = generator.call("_biome_at", descriptor, point, height, edge)
				max_height = maxf(max_height, height)
				heights.append(snappedf(height, 0.001))
				biomes.append(biome)
				if biome == "beach":
					beach_samples += 1
		var details: Dictionary = generator.call("_build_detail_transforms", descriptor)
		var resources: Array = generator.call("_build_resource_plan", descriptor)
		var resource_record: Array = []
		for placement in resources:
			resource_record.append([placement["type"], placement["index"], placement["point"], placement["rotation"], placement["scale"]])
		var canopies: Array = details["canopies"]
		var canopy_record: Array = []
		for index in range(mini(5, canopies.size())):
			canopy_record.append(canopies[index])
		record.append([descriptor["id"], heights, biomes, canopy_record, resource_record])
		metrics.append({"island": descriptor["id"], "max_sampled_height": snappedf(max_height, 0.1), "beach_grid_samples": beach_samples, "forest_instances": canopies.size(), "caves": descriptor["caves"].size(), "resources": resources.size()})
	print("WORLD_AUDIT=" + JSON.stringify({"seed_input": input, "seed": world_seed, "islands": layout.size(), "fingerprint": str(record).sha256_text(), "samples": metrics}))
	generator.free()
	quit()
