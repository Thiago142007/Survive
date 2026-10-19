extends SceneTree

const OUTPUT_DIRECTORY := "res://docs/diagnostics"
const SIZE := 256

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var script_resource: GDScript = load("res://scripts/world/island_generator_v2.gd")
	for world_seed in [12345, 67890, 424242]:
		var generator = script_resource.new()
		generator.seed = world_seed
		generator.call("_rebuild_layout")
		var descriptor: Dictionary = generator.get_world_layout_snapshot()[0]
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
		for cave in descriptor["caves"]:
			var mouth: Vector2 = cave["mouth"]
			var pixel := Vector2i(roundi((mouth.x / extent + 1.0) * 0.5 * float(SIZE - 1)), roundi((mouth.y / extent + 1.0) * 0.5 * float(SIZE - 1)))
			for offset_y in range(-2, 3):
				for offset_x in range(-2, 3):
					var target := pixel + Vector2i(offset_x, offset_y)
					if target.x >= 0 and target.x < SIZE and target.y >= 0 and target.y < SIZE:
						image.set_pixelv(target, Color("#ef553b"))
		var path := "%s/seed_%d.png" % [OUTPUT_DIRECTORY, world_seed]
		assert(image.save_png(path) == OK)
		var overview := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		overview.fill(Color("#17516e"))
		var world_extent := 6000.0
		for island in generator.get_world_layout_snapshot():
			var center: Vector3 = island["center"]
			var island_aspect := float(island["aspect"])
			var reach := float(island["radius"]) * maxf(island_aspect, 1.0 / island_aspect) * 1.45
			var min_pixel := Vector2i(clampi(floori((center.x - reach + world_extent) / (2.0 * world_extent) * 511.0), 0, 511), clampi(floori((center.z - reach + world_extent) / (2.0 * world_extent) * 511.0), 0, 511))
			var max_pixel := Vector2i(clampi(ceili((center.x + reach + world_extent) / (2.0 * world_extent) * 511.0), 0, 511), clampi(ceili((center.z + reach + world_extent) / (2.0 * world_extent) * 511.0), 0, 511))
			for map_y in range(min_pixel.y, max_pixel.y + 1):
				for map_x in range(min_pixel.x, max_pixel.x + 1):
					var local := Vector2(float(map_x) / 511.0 * 2.0 * world_extent - world_extent - center.x, float(map_y) / 511.0 * 2.0 * world_extent - world_extent - center.z)
					var shore := float(generator.call("_edge_distance", island, local))
					if shore <= 0.0:
						continue
					var land_color: Color = generator.call("_ground_color", String(island["biome"]), shore, 0.2)
					overview.set_pixel(map_x, map_y, land_color)
		var overview_path := "%s/archipelago_%d.png" % [OUTPUT_DIRECTORY, world_seed]
		assert(overview.save_png(overview_path) == OK)
		print("Rendered ", path, " and ", overview_path, " islands=", generator.get_world_layout_snapshot().size(), " caves=", descriptor["caves"].size())
		generator.free()
	quit()
