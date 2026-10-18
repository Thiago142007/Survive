extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node("Main")
	main.game_started = false
	var world := Node3D.new()
	world.name = "MigratedAnimalTestWorld"
	var menu := CanvasLayer.new()
	menu.name = "MainMenu"
	world.add_child(menu)
	root.add_child(world)
	current_scene = world
	var generator: Node3D = (load("res://scripts/world/island_generator.gd") as GDScript).new()
	generator.name = "IslandGenerator"
	generator.seed = 424242
	generator.island_count = 1
	generator.stream_radius_chunks = 0
	world.add_child(generator)
	await process_frame
	var id: String = generator.call("_persistent_id", generator.island_descriptors[0], "peaceful", 0)
	var migrated_state := {
		"persistent_id": id,
		"species": "deer",
		"behavior": 0,
		"alive": true,
		"health": 22.0,
		"max_health": 45.0,
		"is_tamed": true,
		"position": [720.0, 2.0, 0.0],
		"rotation": [0.0, 0.0, 0.0]
	}
	generator.apply_persistent_state({"resources": {}, "animals": {id: migrated_state}})
	generator.call("_load_chunk", Vector2i(1, 0))
	var animal: Node = generator.call("_find_loaded_entity", id)
	if not _expect(animal != null and animal.get_parent() == generator.loaded_chunks[Vector2i(1, 0)], "Living fauna must stream in the chunk containing its saved position even when its birthplace chunk is unloaded"):
		return
	if not _expect(is_equal_approx(animal.global_position.x, 720.0) and bool(animal.get_save_state().get("is_tamed", false)), "Migrated fauna must retain its position and domestication state"):
		return
	var second_id: String = generator.call("_persistent_id", generator.island_descriptors[0], "peaceful", 1)
	var second_state := migrated_state.duplicate(true)
	second_state["persistent_id"] = second_id
	second_state["position"] = [1450.0, 2.0, 0.0]
	generator.apply_persistent_state({"resources": {}, "animals": {id: migrated_state, second_id: second_state}})
	generator.call("_load_chunk", Vector2i.ZERO)
	if not _expect(generator.call("_find_loaded_entity", id) == animal, "Loading the animal's birthplace after its destination must not create a duplicate"):
		return
	generator.call("_load_chunk", Vector2i(2, 0))
	generator.call("_unload_chunk", Vector2i.ZERO)
	var transferred_animal: Node = generator.call("_find_loaded_entity", second_id)
	if not _expect(transferred_animal != null and transferred_animal.get_parent() == generator.loaded_chunks[Vector2i(2, 0)], "Unloading a birthplace chunk must transfer migrated animals into an already-loaded destination chunk"):
		return
	if not _expect(_count_by_id(generator, id) == 1 and _count_by_id(generator, second_id) == 1 and is_equal_approx(transferred_animal.global_position.x, 1450.0), "Chunk ordering must preserve one instance and the saved position of every migrated animal"):
		return
	main.game_started = false
	world.free()
	print("Migrated animal streaming smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false

func _count_by_id(root_node: Node, persistent_id: String) -> int:
	var count := 0
	for node in root_node.find_children("*", "Node", true, false):
		if node.has_method("get_save_state") and String(node.call("get_save_state").get("persistent_id", "")) == persistent_id:
			count += 1
	return count
