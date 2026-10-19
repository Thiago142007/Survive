extends SceneTree

const GENERATOR_V1 = preload("res://scripts/world/island_generator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node("Main")
	var world := Node3D.new()
	world.name = "LegacySnapshotWorld"
	root.add_child(world)
	current_scene = world
	var generator = GENERATOR_V1.new()
	generator.name = "IslandGenerator"
	generator.seed = 12345
	generator.stream_radius_chunks = 0
	world.add_child(generator)
	var snapshot: Dictionary = main.capture_save_snapshot()
	assert(int(snapshot["world_generation_version"]) == 1)
	assert(not snapshot["generation_config"].has("coastal_landmarks_enabled"), "O gerador legado nao possui configuracao costeira")
	world.free()
	print("Legacy generator snapshot: PASS")
	quit()
