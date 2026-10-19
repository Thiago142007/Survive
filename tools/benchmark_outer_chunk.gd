extends SceneTree

## Headless CPU benchmark for the first outer island in a fresh process.
const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_seed := int(OS.get_environment("SURVIVE_TEST_SEED")) if not OS.get_environment("SURVIVE_TEST_SEED").is_empty() else 12345
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = world_seed
	var generator = GENERATOR.new()
	generator.seed = world_seed
	generator.async_generation_enabled = true
	generator.stream_radius_chunks = 0
	generator.call("_rebuild_layout")
	var descriptor: Dictionary = generator.island_descriptors[1]
	var focus := Node3D.new()
	root.add_child(focus)
	focus.global_position = descriptor["center"]
	if main:
		main.player = focus
	var before_bytes := OS.get_static_memory_usage()
	var started := Time.get_ticks_msec()
	root.add_child(generator)
	var max_frame_ms := 0.0
	while not generator.is_spawn_ready() and Time.get_ticks_msec() - started < 15000:
		var frame_started := Time.get_ticks_usec()
		await process_frame
		max_frame_ms = maxf(max_frame_ms, float(Time.get_ticks_usec() - frame_started) / 1000.0)
	assert(generator.is_spawn_ready() and generator.loaded_chunks.has(descriptor["chunk"]))
	var load_ms := Time.get_ticks_msec() - started
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	print("OUTER_BENCHMARK=" + JSON.stringify({"seed": world_seed, "island": descriptor["id"], "load_ms": load_ms, "max_observed_frame_ms": max_frame_ms, "memory_delta_bytes": OS.get_static_memory_usage() - before_bytes, "diagnostics": diagnostics}))
	generator.free()
	if main:
		main.player = null
	focus.free()
	quit()
