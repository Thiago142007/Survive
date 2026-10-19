extends SceneTree

## Top-down diagnostic maps. Colors are sampled terrain/biomes, not 3D screenshots.
const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const WORLD_SEED = preload("res://scripts/world/world_seed.gd")
const OUTPUT_DIRECTORY := "res://docs/diagnostics"
const SIZE := 384

const CASES := [
	["dense_forest", "424242", 1],
	["high_mountain", "99999", 0],
	["wide_beaches", "ilha tropical", 1],
	["cave_region", "67890", 1],
	["sheltered_bay", "12345", 0]
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	for entry in CASES:
		var generator = GENERATOR.new()
		generator.seed = WORLD_SEED.parse(entry[1])
		generator.call("_rebuild_layout")
		var descriptor: Dictionary = generator.island_descriptors[entry[2]]
		var path := "%s/final_%s.png" % [OUTPUT_DIRECTORY, entry[0]]
		_render_map(generator, descriptor, path)
		print("Rendered %s seed=%s island=%s" % [path, entry[1], descriptor["id"]])
		generator.free()
	quit()

func _render_map(generator: Node3D, descriptor: Dictionary, path: String) -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var aspect := float(descriptor["aspect"])
	var extent := float(descriptor["radius"]) * maxf(aspect, 1.0 / aspect) * 1.48
	for y in range(SIZE):
		for x in range(SIZE):
			var point := Vector2((float(x) / float(SIZE - 1) * 2.0 - 1.0) * extent, (float(y) / float(SIZE - 1) * 2.0 - 1.0) * extent)
			var edge := float(generator.call("_edge_distance", descriptor, point))
			var height := float(generator.call("_terrain_height_from_edge", descriptor, point, edge))
			var color := Color("#17516e")
			if height > -0.3:
				var biome: String = generator.call("_biome_at", descriptor, point, height, edge, 0.2)
				color = generator.call("_ground_color", biome, edge, 0.2)
				color = color.lerp(Color("#d7d9ce"), clampf((height - 35.0) / 105.0, 0.0, 0.78))
			image.set_pixel(x, y, color)
	var details: Dictionary = generator.call("_build_detail_transforms", descriptor)
	var center: Vector3 = descriptor["center"]
	for canopy in details["canopies"]:
		var local: Vector3 = canopy.origin - center
		var pixel := _to_pixel(Vector2(local.x, local.z), extent)
		if pixel.x >= 0 and pixel.x < SIZE and pixel.y >= 0 and pixel.y < SIZE:
			image.set_pixelv(pixel, Color("#173c2b"))
	for cave in descriptor["caves"]:
		var pixel := _to_pixel(cave["mouth"], extent)
		for offset_y in range(-3, 4):
			for offset_x in range(-3, 4):
				var target := pixel + Vector2i(offset_x, offset_y)
				if target.x >= 0 and target.x < SIZE and target.y >= 0 and target.y < SIZE:
					image.set_pixelv(target, Color("#ef553b"))
	assert(image.save_png(path) == OK)

func _to_pixel(point: Vector2, extent: float) -> Vector2i:
	return Vector2i(roundi((point.x / extent + 1.0) * 0.5 * float(SIZE - 1)), roundi((point.y / extent + 1.0) * 0.5 * float(SIZE - 1)))
