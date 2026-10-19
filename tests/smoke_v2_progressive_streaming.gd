extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node_or_null("Main")
	assert(main != null)
	main.world_seed = 12345
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.stream_radius_chunks = 2
	root.add_child(generator)
	generator.call("_refresh_streaming")
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	assert("central" in generator.get_loaded_island_ids(), "O chunk do jogador deve carregar imediatamente")
	assert(int(diagnostics["pending_chunks"]) >= 2, "Ilhas distantes devem aguardar na fila")
	var outer: Dictionary = generator.island_descriptors[6]
	assert(generator._pending_chunks.has(outer["chunk"]))
	var aspect := float(outer["aspect"])
	var reach := float(outer["radius"]) * maxf(aspect, 1.0 / aspect) * 1.42 + 45.0
	var focus_node := Node3D.new()
	root.add_child(focus_node)
	focus_node.global_position = outer["center"] + Vector3(reach - 5.0, 0.0, 0.0)
	main.player = focus_node
	generator._last_focus_chunk = generator.call("_world_to_chunk", focus_node.global_position)
	generator._last_stream_focus = focus_node.global_position
	generator.call("_refresh_streaming")
	assert(String(outer["id"]) in generator.get_loaded_island_ids(), "Aproximar-se da ilha no mesmo chunk de foco deve antecipar seu carregamento")
	main.player = null
	generator._last_focus_chunk = Vector2i(999999, 999999)
	generator.call("_refresh_streaming")
	var previous_count := _loaded_island_count(generator)
	for _frame in range(20):
		await process_frame
		var current_count := _loaded_island_count(generator)
		assert(current_count - previous_count <= 1, "No maximo um chunk distante deve gerar por frame")
		previous_count = current_count
		if int(generator.get_generation_diagnostics()["pending_chunks"]) == 0:
			break
	assert(int(generator.get_generation_diagnostics()["pending_chunks"]) == 0)
	assert(_loaded_island_count(generator) > 1)

	var distant_chunk := Vector2i(999999, 999999)
	for descriptor in generator.island_descriptors:
		if int(descriptor["index"]) != 0 and generator.loaded_chunks.has(descriptor["chunk"]):
			distant_chunk = descriptor["chunk"]
			break
	assert(distant_chunk != Vector2i(999999, 999999))
	generator.call("_unload_chunk", distant_chunk)
	generator._last_focus_chunk = Vector2i(999999, 999999)
	generator.call("_refresh_streaming")
	assert(int(generator.get_generation_diagnostics()["pending_chunks"]) >= 1)
	generator.stream_radius_chunks = 0
	generator._last_focus_chunk = Vector2i(999999, 999999)
	generator.call("_refresh_streaming")
	assert(int(generator.get_generation_diagnostics()["pending_chunks"]) == 0, "Chunks fora do alcance devem sair da fila")
	assert("central" in generator.get_loaded_island_ids())
	generator.call("_unload_chunk", outer["chunk"])
	focus_node.global_position = outer["center"] + Vector3(reach - 5.0, 0.0, 0.0)
	assert(generator.call("_world_to_chunk", focus_node.global_position) != outer["chunk"])
	main.player = focus_node
	generator._last_focus_chunk = Vector2i(999999, 999999)
	generator.call("_refresh_streaming")
	assert(String(outer["id"]) in generator.get_loaded_island_ids(), "Uma ilha sob o jogador deve carregar imediatamente")
	main.player = null
	focus_node.free()
	generator.stream_radius_chunks = 2
	generator._last_focus_chunk = Vector2i(999999, 999999)
	generator.call("_refresh_streaming")
	assert(int(generator.get_generation_diagnostics()["pending_chunks"]) > 0)
	generator.set_world_active(false)
	assert(int(generator.get_generation_diagnostics()["pending_chunks"]) == 0)
	assert(generator.loaded_chunks.is_empty())
	print("Procedural v2 progressive streaming: PASS")
	generator.free()
	quit()

func _loaded_island_count(generator: Node3D) -> int:
	var count := 0
	for descriptor in generator.island_descriptors:
		var chunk: Node3D = generator.loaded_chunks.get(descriptor["chunk"])
		if chunk and chunk.get_node_or_null(String(descriptor["id"])):
			count += 1
	return count
