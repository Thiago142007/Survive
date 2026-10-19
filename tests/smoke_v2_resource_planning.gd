extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const JOB = preload("res://scripts/world/island_generation_job.gd")

func _init() -> void:
	call_deferred("_run")

func _fingerprint(chunk: Node3D) -> String:
	var entries: Array[String] = []
	for node in chunk.get_children():
		var resource_id: String = str(node.get("persistent_id"))
		if not resource_id.contains("-tree-") and not resource_id.contains("-rock-"):
			continue
		entries.append("%s|%s|%s|%s" % [resource_id, node.position, node.rotation.y, node.scale])
	return "\n".join(entries).sha256_text()

func _snapshot(seed_value: int, island_index: int, landmarks: bool) -> String:
	var generator = GENERATOR.new()
	generator.seed = seed_value
	generator.configure_coastal_landmarks(landmarks)
	generator.call("_rebuild_layout")
	var descriptor: Dictionary = generator.island_descriptors[island_index]
	var chunk := Node3D.new()
	generator.call("_spawn_resources", chunk, descriptor)
	var fingerprint := _fingerprint(chunk)
	chunk.free()
	generator.free()
	return fingerprint

func _run() -> void:
	var baselines := [
		[12345, 0, true, "f59332769392d2c30fa9490230b07211ba0ca76350646099b3e28997abe964c3"],
		[67890, 0, true, "1c022383a56945744a15a236a689b8b0f049d13851c0b61f1d49c43003116dc4"],
		[12345, 1, true, "10cb7458edacb686e40f7d66a274dae5c83bd6e0cc70c608fe194c72257325b8"],
		[12345, 0, false, "eff4607e07943586d36dc1f4558502a0c1b077f09d7b12d3535b1ed62e462ef5"]
	]
	for setup in baselines:
		assert(_snapshot(setup[0], setup[1], setup[2]) == setup[3], "A seed nao pode mover recursos ou mudar IDs")
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.call("_rebuild_layout")
	var job = JOB.new()
	job.generator_script = GENERATOR
	job.world_seed = 12345
	job.descriptor = generator.island_descriptors[0].duplicate(true)
	var result: Dictionary = job.run()
	assert(result.has("resources"), "O worker deve preparar as posicoes dos recursos")
	assert(result["resources"].size() > 0)
	generator.free()
	var async_generator = GENERATOR.new()
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = 12345
	async_generator.seed = 12345
	async_generator.stream_radius_chunks = 0
	async_generator.async_generation_enabled = true
	root.add_child(async_generator)
	var began := Time.get_ticks_msec()
	while not async_generator.loaded_chunks.has(Vector2i.ZERO) and Time.get_ticks_msec() - began < 10000:
		await process_frame
	assert(async_generator.loaded_chunks.has(Vector2i.ZERO))
	assert(async_generator._prepared_resource_plans.has("central"), "O plano deve aguardar a montagem dos recursos")
	while not async_generator.is_spawn_ready() and Time.get_ticks_msec() - began < 10000:
		await process_frame
	assert(async_generator.is_spawn_ready())
	assert(_fingerprint(async_generator.loaded_chunks[Vector2i.ZERO]) == baselines[0][3])
	assert(async_generator._prepared_resource_plans.is_empty(), "O plano consumido deve ser liberado")
	async_generator.free()
	print("Procedural v2 resource planning: PASS")
	quit()
