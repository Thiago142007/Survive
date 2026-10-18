extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node_or_null("Main")
	if not _expect(main != null, "Main autoload must be available"):
		return
	main.world_seed = 424242
	main.game_started = true
	var generator_script: GDScript = load("res://scripts/world/island_generator.gd")
	var generator: Node3D = generator_script.new()
	generator.seed = 424242
	generator.island_count = 1
	generator.stream_radius_chunks = 0
	root.add_child(generator)
	await process_frame
	for method_name in ["capture_persistent_state", "apply_persistent_state"]:
		if not _expect(generator.has_method(method_name), "IslandGenerator must expose %s" % method_name):
			return
	var resources := _saveable_nodes(generator, "get_save_state")
	var animals := _saveable_nodes(generator, "get_save_state", true)
	if not _expect(not resources.is_empty() and not animals.is_empty(), "Generated world must expose harvestables and fauna"):
		return
	var original_ids := _ids(resources) + _ids(animals)
	var seen_ids: Dictionary = {}
	for persistent_id in original_ids:
		if not _expect(not persistent_id.is_empty() and not seen_ids.has(persistent_id), "Generated spawn IDs must be present and unique"):
			return
		seen_ids[persistent_id] = true

	var resource = resources[0]
	var resource_state: Dictionary = resource.get_save_state()
	resource_state["depleted"] = true
	resource_state["respawn_remaining"] = 12.0
	resource.apply_save_state(resource_state)
	var animal = animals[0]
	var animal_state: Dictionary = animal.get_save_state()
	animal_state["health"] = 23.0
	animal_state["is_tamed"] = true
	animal.apply_save_state(animal_state)
	var expected_resource_id := String(resource_state.get("persistent_id", ""))
	var expected_animal_id := String(animal_state.get("persistent_id", ""))

	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	var restored_resource = _find_by_id(generator, expected_resource_id)
	var restored_animal = _find_by_id(generator, expected_animal_id)
	if not _expect(restored_resource != null and restored_animal != null, "Chunk reload must restore changed world objects"):
		return
	if not _expect(bool(restored_resource.get_save_state().get("depleted", false)), "Harvested resource must stay depleted after chunk reload"):
		return
	if not _expect(float(restored_resource.get_save_state().get("respawn_remaining", 0.0)) > 0.0, "Resource respawn time must survive chunk reload"):
		return
	if not _expect(is_equal_approx(float(restored_animal.get_save_state().get("health", 0.0)), 23.0) and bool(restored_animal.get_save_state().get("is_tamed", false)), "Animal health and domestication must survive chunk reload"):
		return
	if not _expect(_count_by_id(generator, expected_resource_id) == 1 and _count_by_id(generator, expected_animal_id) == 1, "Restored objects must not be duplicated"):
		return
	if not _expect(_ids(_saveable_nodes(generator, "get_save_state")) + _ids(_saveable_nodes(generator, "get_save_state", true)) == original_ids, "Chunk reload must preserve deterministic spawn IDs"):
		return

	var registry: Dictionary = generator.capture_persistent_state()
	if not _expect(registry.get("resources", {}).has(expected_resource_id) and registry.get("animals", {}).has(expected_animal_id), "Captured registry must include changed objects"):
		return
	var second: Node3D = generator_script.new()
	second.seed = 424242
	second.island_count = 1
	second.stream_radius_chunks = 0
	root.add_child(second)
	await process_frame
	if not _expect(_ids(_saveable_nodes(second, "get_save_state")) + _ids(_saveable_nodes(second, "get_save_state", true)) == original_ids, "Identical seeds must produce identical stable IDs"):
		return
	main.game_started = false
	second.free()
	generator.free()
	print("World save registry smoke test: PASS")
	quit()

func _saveable_nodes(root_node: Node, method_name: String, only_animals: bool = false) -> Array[Node]:
	var result: Array[Node] = []
	for node in root_node.find_children("*", "Node", true, false):
		if not node.has_method(method_name):
			continue
		var state: Dictionary = node.call(method_name)
		var is_animal := state.has("species")
		if is_animal == only_animals:
			result.append(node)
	return result

func _ids(nodes: Array[Node]) -> Array[String]:
	var result: Array[String] = []
	for node in nodes:
		var state: Dictionary = node.call("get_save_state")
		result.append(String(state.get("persistent_id", "")))
	return result

func _find_by_id(root_node: Node, persistent_id: String) -> Node:
	for node in root_node.find_children("*", "Node", true, false):
		if node.has_method("get_save_state") and String(node.call("get_save_state").get("persistent_id", "")) == persistent_id:
			return node
	return null

func _count_by_id(root_node: Node, persistent_id: String) -> int:
	var count := 0
	for node in root_node.find_children("*", "Node", true, false):
		if node.has_method("get_save_state") and String(node.call("get_save_state").get("persistent_id", "")) == persistent_id:
			count += 1
	return count

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
