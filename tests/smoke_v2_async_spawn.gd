extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	var main := root.get_node("Main")
	var generator = world.get_node("IslandGenerator")
	var player: CharacterBody3D = world.get_node("Player")
	assert(generator.async_generation_enabled)
	main.world_generation_version = 2
	main.game_started = true
	paused = false
	player.global_position = Vector3(0.0, 2.0, 0.0)
	generator.set_world_active(true)
	assert(not generator.is_spawn_ready())
	var start_y := player.global_position.y
	var started := Time.get_ticks_msec()
	while not generator.is_spawn_ready() and Time.get_ticks_msec() - started < 10000:
		await physics_frame
		assert(is_equal_approx(player.global_position.y, start_y), "O jogador nao pode cair antes da colisao existir")
	assert(generator.is_spawn_ready())
	assert(generator.loaded_chunks.has(Vector2i.ZERO))
	main.game_started = false
	world.free()
	print("Procedural v2 asynchronous safe spawn: PASS")
	quit()
