extends SceneTree

## Run with a graphical renderer at 1280x720, never with --headless.
## Captures real game viewport images and per-frame render metrics.
const OUTPUT_DIRECTORY := "res://docs/diagnostics"
const SAMPLE_FRAMES := 120

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This benchmark requires a graphical renderer")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main = root.get_node("Main")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	assert(main.start_new_world({"name": "Graphics benchmark", "seed": 12345}))
	var generator = world.get_node("IslandGenerator")
	var started := Time.get_ticks_msec()
	while not generator.is_spawn_ready() and Time.get_ticks_msec() - started < 15000:
		await process_frame
	assert(generator.is_spawn_ready())
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_input(false)
	world.get_node("HUD").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 75.0
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var descriptor: Dictionary = generator.island_descriptors[0]
	var cave: Dictionary = descriptor["caves"][0]
	var mouth: Vector2 = cave["mouth"]
	var direction: Vector2 = cave["direction"]
	var beach := _find_beach(generator, descriptor)
	var views := [
		{"name": "forest", "position": Vector3(0.0, 210.0, 250.0), "target": Vector3(0.0, 10.0, 0.0)},
		{"name": "beach", "position": Vector3(beach.x * 1.14, 64.0, beach.y * 1.14), "target": Vector3(beach.x * 0.88, 5.0, beach.y * 0.88)},
		{"name": "cave", "position": Vector3(mouth.x - direction.x * 16.0, float(generator.call("_terrain_height", descriptor, mouth)) + 12.0, mouth.y - direction.y * 16.0), "target": Vector3(mouth.x + direction.x * 18.0, float(generator.call("_terrain_height", descriptor, mouth)) - 2.0, mouth.y + direction.y * 18.0)}
	]
	var results: Array = []
	for view in views:
		camera.global_position = view["position"]
		camera.look_at(view["target"])
		for _warmup in range(30):
			await RenderingServer.frame_post_draw
		var intervals: Array[float] = []
		var draw_calls: Array[float] = []
		var previous := Time.get_ticks_usec()
		for _frame in range(SAMPLE_FRAMES):
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			intervals.append(float(now - previous) / 1000.0)
			previous = now
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		intervals.sort()
		draw_calls.sort()
		var image := root.get_texture().get_image()
		var image_path := "%s/graphic_%s.png" % [OUTPUT_DIRECTORY, view["name"]]
		assert(image.save_png(image_path) == OK)
		results.append({"view": view["name"], "frames": SAMPLE_FRAMES, "average_fps": snappedf(1000.0 / _mean(intervals), 0.1), "average_frame_ms": snappedf(_mean(intervals), 0.01), "p95_frame_ms": snappedf(intervals[ceili(SAMPLE_FRAMES * 0.95) - 1], 0.01), "max_frame_ms": snappedf(intervals[-1], 0.01), "median_draw_calls": draw_calls[SAMPLE_FRAMES / 2], "image": image_path})
	print("GRAPHICS_BENCHMARK=" + JSON.stringify({"display": DisplayServer.get_name(), "viewport": root.get_visible_rect().size, "vsync": DisplayServer.window_get_vsync_mode(), "seed": 12345, "results": results}))
	main.game_started = false
	world.free()
	quit()

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())

func _find_beach(generator: Node3D, descriptor: Dictionary) -> Vector2:
	for index in range(64):
		var angle := TAU * float(index) / 64.0
		var direction := Vector2(cos(angle), sin(angle))
		for radius in range(120, 700, 6):
			var point := direction * float(radius)
			var edge := float(generator.call("_edge_distance", descriptor, point))
			if edge <= 0.0:
				break
			if edge < 10.0 or edge > 20.0:
				continue
			var height := float(generator.call("_terrain_height", descriptor, point))
			if generator.call("_biome_at", descriptor, point, height, edge) == "beach":
				return point
	return Vector2(300.0, 0.0)
