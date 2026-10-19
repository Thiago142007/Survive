extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = root.get_node_or_null("Main")
	if main:
		main.world_seed = 12345
	var generator = load("res://scripts/world/island_generator_v2.gd").new()
	generator.seed = 12345
	generator.stream_radius_chunks = 0
	root.add_child(generator)
	await process_frame
	var central_chunk: Node3D = generator.loaded_chunks[Vector2i.ZERO]
	var first_mesh: Mesh = central_chunk.get_node("central/MeshInstance3D").mesh
	var first_shape: Shape3D = central_chunk.get_node("central/CollisionShape3D").shape
	var first_forest: MultiMesh = central_chunk.get_node("ForestCanopies").multimesh
	var first_transform := first_forest.get_instance_transform(0)
	var resource_id := ""
	for node in central_chunk.find_children("*", "StaticBody3D", true, false):
		if node.has_method("get_save_state") and node.call("get_save_state").has("resource_id"):
			var state: Dictionary = node.call("get_save_state")
			resource_id = String(state["persistent_id"])
			state["depleted"] = true
			state["respawn_remaining"] = 1000.0
			node.call("apply_save_state", state)
			break
	assert(not resource_id.is_empty())
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	central_chunk = generator.loaded_chunks[Vector2i.ZERO]
	var resource_restored := false
	for node in central_chunk.find_children("*", "StaticBody3D", true, false):
		if node.has_method("get_save_state"):
			var state: Dictionary = node.call("get_save_state")
			if String(state.get("persistent_id", "")) == resource_id:
				resource_restored = bool(state["depleted"])
				break
	assert(resource_restored, "O cache nao pode descartar alteracoes persistentes nos recursos")
	assert(central_chunk.get_node("central/MeshInstance3D").mesh == first_mesh, "Recarregar a ilha deve reutilizar a malha de terreno")
	assert(central_chunk.get_node("central/CollisionShape3D").shape == first_shape, "Recarregar a ilha deve reutilizar a colisao do terreno")
	assert(central_chunk.get_node("ForestCanopies").multimesh == first_forest, "Recarregar a ilha deve reutilizar as instancias decorativas")
	assert(central_chunk.get_node("ForestCanopies").multimesh.get_instance_transform(0) == first_transform)
	var diagnostics: Dictionary = generator.get_generation_diagnostics()
	assert(int(diagnostics["cache_hits"]["terrain"]) >= 1)
	assert(int(diagnostics["cache_hits"]["collision"]) >= 1)
	assert(int(diagnostics["cache_hits"]["details"]) >= 1)
	await physics_frame
	var hit: Dictionary = generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 30.0, 0.0), Vector3(0.0, -20.0, 0.0)))
	assert(hit.get("collider") == central_chunk.get_node("central"), "A colisao reutilizada deve continuar ativa na fisica")
	generator.apply_seed(67890)
	central_chunk = generator.loaded_chunks[Vector2i.ZERO]
	var second_mesh: Mesh = central_chunk.get_node("central/MeshInstance3D").mesh
	var second_shape: Shape3D = central_chunk.get_node("central/CollisionShape3D").shape
	assert(second_mesh != first_mesh, "Trocar a seed deve invalidar o cache")
	assert(second_shape != first_shape, "Trocar a seed deve invalidar a colisao em cache")
	var layout: Array[Dictionary] = generator.get_world_layout_snapshot()
	var outer_first: Vector2i = layout[1]["chunk"]
	var outer_second: Vector2i = layout[2]["chunk"]
	assert(outer_first != outer_second)
	generator.call("_load_chunk", outer_first)
	var outer_mesh: Mesh = generator.loaded_chunks[outer_first].get_node(String(layout[1]["id"]) + "/MeshInstance3D").mesh
	var outer_shape: Shape3D = generator.loaded_chunks[outer_first].get_node(String(layout[1]["id"]) + "/CollisionShape3D").shape
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	assert(generator.loaded_chunks[Vector2i.ZERO].get_node("central/MeshInstance3D").mesh == second_mesh, "Usar a ilha novamente deve torna-la a mais recente")
	generator.call("_load_chunk", outer_second)
	assert(int(generator.get_generation_diagnostics()["cache_entries"]) <= 2, "O cache deve ter capacidade limitada")
	generator.call("_unload_chunk", outer_first)
	generator.call("_load_chunk", outer_first)
	assert(generator.loaded_chunks[outer_first].get_node(String(layout[1]["id"]) + "/MeshInstance3D").mesh != outer_mesh, "A ilha menos recente deve ser expulsa do cache")
	assert(generator.loaded_chunks[outer_first].get_node(String(layout[1]["id"]) + "/CollisionShape3D").shape != outer_shape, "A colisao da ilha expulsa nao deve permanecer em cache")
	generator.generation_version = 1
	generator.apply_seed(12345)
	assert(int(generator.get_generation_diagnostics()["cache_entries"]) == 0, "O gerador legado nao deve reter o cache v2")
	var legacy_mesh: Mesh = generator.loaded_chunks[Vector2i.ZERO].get_node("central/MeshInstance3D").mesh
	var legacy_shape: Shape3D = generator.loaded_chunks[Vector2i.ZERO].get_node("central/CollisionShape3D").shape
	generator.call("_unload_chunk", Vector2i.ZERO)
	generator.call("_load_chunk", Vector2i.ZERO)
	assert(generator.loaded_chunks[Vector2i.ZERO].get_node("central/MeshInstance3D").mesh != legacy_mesh, "O gerador v1 deve manter o comportamento original")
	assert(generator.loaded_chunks[Vector2i.ZERO].get_node("central/CollisionShape3D").shape != legacy_shape, "O gerador v1 nao deve reutilizar a colisao")
	print("Procedural v2 bounded chunk cache: PASS")
	generator.free()
	quit()
