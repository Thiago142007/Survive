extends SceneTree

var _requests: Array[Dictionary] = []
var _observed_harvestable: Node = null
var _observation := {"wood_hit_visible": false, "wood_splinters_visible": false}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var effects := root.get_node_or_null("Effects")
	if not _require(effects != null, "Effects autoload must exist"):
		return
	var request_handler := func(effect_id: StringName, position: Vector3, spatial: bool) -> void:
		_requests.append({"id": effect_id, "position": position, "spatial": spatial})
		if _observed_harvestable and effect_id == &"wood_hit":
			_observation["wood_hit_visible"] = _visuals_visible(_observed_harvestable)
		if _observed_harvestable and effect_id == &"wood_splinters":
			_observation["wood_splinters_visible"] = _visuals_visible(_observed_harvestable)
	effects.effect_requested.connect(request_handler)

	var main := root.get_node("Main")
	var resource_player := Node3D.new()
	var inventory: Node = load("res://scripts/inventory/inventory.gd").new()
	inventory.name = "Inventory"
	resource_player.add_child(inventory)
	root.add_child(resource_player)
	main.player = resource_player
	var interaction := Interaction.new()
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	interaction.add_child(ray)
	root.add_child(interaction)
	var wood := (load("res://scenes/world/tree.tscn") as PackedScene).instantiate()
	wood.respawn_time = 0.01
	root.add_child(wood)
	_observed_harvestable = wood
	wood.harvest(interaction, "stone_axe")
	if not _require(_requested_all([&"wood_hit", &"collect", &"wood_splinters"]), "Wood harvesting must request hit, collection, and splinters"):
		return
	if not _require(_observation["wood_hit_visible"] and _observation["wood_splinters_visible"], "Wood effects must be requested before visuals are hidden"):
		return
	await create_timer(0.02).timeout

	_requests.clear()
	_observed_harvestable = null
	var rock := (load("res://scenes/world/rock.tscn") as PackedScene).instantiate()
	rock.respawn_time = 0.01
	root.add_child(rock)
	rock.harvest(interaction, "stone_pickaxe")
	if not _require(_requested_all([&"stone_hit", &"collect", &"stone_sparks"]), "Stone harvesting must request hit, collection, and sparks"):
		return
	await create_timer(0.02).timeout

	_requests.clear()
	var animal_scene := load("res://scenes/fauna/animal.tscn") as PackedScene
	var animal := animal_scene.instantiate() as Animal
	animal.max_health = 40.0
	root.add_child(animal)
	await process_frame
	animal.receive_hit(5.0)
	if not _require(_requested_all([&"animal_hit", &"damage"]), "Animal damage must request impact feedback"):
		return
	_requests.clear()
	animal.receive_hit(100.0)
	if not _require(_requested_all([&"animal_hit", &"damage", &"animal_death", &"dust"]), "Animal death must request hit and death feedback"):
		return
	await process_frame

	inventory.add_item("wood", 200)
	var building := BuildingSystem.new()
	root.add_child(building)
	var foundation_scene := load("res://scenes/building/foundation.tscn") as PackedScene
	var foundation := foundation_scene.instantiate() as Node3D
	root.add_child(foundation)
	_requests.clear()
	building.place_piece(foundation)
	if not _require(_requested_all([&"build_place", &"dust"]), "Placement must request build feedback"):
		return
	_requests.clear()
	building.remove_piece(foundation)
	if not _require(_requested_all([&"build_remove", &"wood_splinters"]), "Removal must request destruction feedback"):
		return
	await process_frame

	var maintained_piece := foundation_scene.instantiate() as Node3D
	root.add_child(maintained_piece)
	maintained_piece.current_health = maintained_piece.health * 0.5
	_requests.clear()
	if not _require(building.repair_piece(maintained_piece), "Repair must succeed with enough resources"):
		return
	if not _require(_requested_all([&"build_repair", &"dust"]), "Repair must request repair feedback"):
		return
	_requests.clear()
	if not _require(building.upgrade_piece(maintained_piece), "Upgrade must succeed with enough resources"):
		return
	if not _require(_requested_all([&"build_upgrade", &"stone_sparks"]), "Upgrade must request upgrade feedback"):
		return

	main.player = null
	interaction.free()
	resource_player.free()
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	_requests.clear()
	player.call("_perform_attack")
	if not _require(_requested_all([&"attack_swing", &"slash"]), "Every attack must request swing feedback"):
		return
	_requests.clear()
	player.call("_advance_footsteps", 0.51, true, 2.0, false)
	if not _require(_requested_all([&"footstep_grass"]), "Ground movement must request footsteps at the walk interval"):
		return
	_requests.clear()
	player.take_damage(10.0)
	if not _require(_requested_all([&"player_hurt", &"damage"]), "Player damage must request hurt feedback"):
		return
	var respawn_positions: Array[Vector3] = []
	player.respawned.connect(func(position: Vector3) -> void: respawn_positions.append(position))
	_requests.clear()
	player.take_damage(1000.0)
	if not _require(_requested_all([&"player_hurt", &"damage", &"player_down"]), "Lethal damage must request down feedback"):
		return
	if not _require(respawn_positions.size() == 1 and player.health == player.max_health and player.hunger == player.max_hunger * 0.5 and player.thirst == player.max_thirst * 0.5, "Respawn feedback must not change reset values"):
		return

	var offline_animal := animal_scene.instantiate() as Animal
	offline_animal.max_health = 40.0
	root.add_child(offline_animal)
	await process_frame
	root.remove_child(effects)
	offline_animal.receive_hit(5.0)
	if not _require(offline_animal.health == 35.0, "Gameplay must continue when Effects is unavailable"):
		return
	root.add_child(effects)
	effects.name = "Effects"

	effects.effect_requested.disconnect(request_handler)
	await create_timer(1.0).timeout
	for child in effects.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	await create_timer(0.1, true, false, true).timeout
	print("Effect integration smoke test: PASS")
	quit()

func _requested_all(effect_ids: Array[StringName]) -> bool:
	var requested_ids: Array[StringName] = []
	for request in _requests:
		requested_ids.append(request["id"])
	for effect_id in effect_ids:
		if not requested_ids.has(effect_id):
			return false
	return true

func _visuals_visible(node: Node) -> bool:
	for visual in node.find_children("*", "MeshInstance3D", true, false):
		if (visual as MeshInstance3D).visible:
			return true
	return false

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
