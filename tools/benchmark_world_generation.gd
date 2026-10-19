extends SceneTree

## Usage: SURVIVE_TEST_SEED=12345 SURVIVE_DECORATION_QUALITY=low godot --headless --path . --script res://tools/benchmark_world_generation.gd
## Headless measurements cover CPU generation and process memory, not GPU draw calls or FPS.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed_value := int(OS.get_environment("SURVIVE_TEST_SEED")) if not OS.get_environment("SURVIVE_TEST_SEED").is_empty() else 12345
	var version := int(OS.get_environment("SURVIVE_GENERATOR_VERSION")) if not OS.get_environment("SURVIVE_GENERATOR_VERSION").is_empty() else 2
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = seed_value
	var generator_script: GDScript = load("res://scripts/world/island_generator_v2.gd")
	var before_bytes := OS.get_static_memory_usage()
	var generator = generator_script.new()
	generator.generation_version = version
	generator.seed = seed_value
	var quality := OS.get_environment("SURVIVE_DECORATION_QUALITY")
	var async_mode := OS.get_environment("SURVIVE_ASYNC_GENERATION") == "1"
	generator.async_generation_enabled = async_mode
	if not quality.is_empty():
		generator.decoration_quality = quality
	generator.stream_radius_chunks = 0
	var started := Time.get_ticks_msec()
	root.add_child(generator)
	var max_frame_ms := 0.0
	var frame_count := 0
	while not generator.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - started < 15000:
		var frame_started := Time.get_ticks_usec()
		await process_frame
		max_frame_ms = maxf(max_frame_ms, float(Time.get_ticks_usec() - frame_started) / 1000.0)
		frame_count += 1
	assert(generator.loaded_chunks.has(Vector2i.ZERO), "Initial island generation exceeded 15 seconds")
	var load_wall_ms := Time.get_ticks_msec() - started
	var loaded_bytes := OS.get_static_memory_usage()
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	var terrain_triangles := 0
	for chunk in generator.loaded_chunks.values():
		for island in chunk.get_children():
			if island is StaticBody3D and island.has_node("MeshInstance3D"):
				var terrain: Mesh = island.get_node("MeshInstance3D").mesh
				if terrain is ArrayMesh:
					terrain_triangles += terrain.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	generator.call("_unload_chunk", Vector2i.ZERO)
	var reload_started := Time.get_ticks_msec()
	generator.call("_load_chunk", Vector2i.ZERO)
	var reload_wall_ms := Time.get_ticks_msec() - reload_started
	var reloaded_bytes := OS.get_static_memory_usage()
	var reloaded_diagnostics: Dictionary = generator.get_generation_diagnostics()
	generator.free()
	await process_frame
	var unloaded_bytes := OS.get_static_memory_usage()
	print(JSON.stringify({
		"seed": seed_value,
		"version": version,
		"async_generation": async_mode,
		"frames_until_load": frame_count,
		"max_observed_frame_ms": max_frame_ms,
		"load_wall_ms": load_wall_ms,
		"reload_wall_ms": reload_wall_ms,
		"diagnostics": diagnostics,
		"reloaded_cache_hits": reloaded_diagnostics["cache_hits"],
		"terrain_triangles": terrain_triangles,
		"process_memory_before_bytes": before_bytes,
		"process_memory_loaded_bytes": loaded_bytes,
		"process_memory_reloaded_bytes": reloaded_bytes,
		"process_memory_delta_bytes": loaded_bytes - before_bytes,
		"process_memory_unloaded_bytes": unloaded_bytes
	}))
	quit()
