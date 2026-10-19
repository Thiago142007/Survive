extends SceneTree

## Usage: SURVIVE_TEST_SEED=12345 godot --headless --path . --script res://tools/benchmark_world_generation.gd
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
	generator.stream_radius_chunks = 0
	var started := Time.get_ticks_msec()
	root.add_child(generator)
	await process_frame
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
	generator.free()
	await process_frame
	var unloaded_bytes := OS.get_static_memory_usage()
	print(JSON.stringify({
		"seed": seed_value,
		"version": version,
		"load_wall_ms": load_wall_ms,
		"diagnostics": diagnostics,
		"terrain_triangles": terrain_triangles,
		"process_memory_before_bytes": before_bytes,
		"process_memory_loaded_bytes": loaded_bytes,
		"process_memory_delta_bytes": loaded_bytes - before_bytes,
		"process_memory_unloaded_bytes": unloaded_bytes
	}))
	quit()
