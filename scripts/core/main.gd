extends Node
# Autoload global. Keeps the active world metadata and coordinates saves.
var player: Node3D = null
var world_name: String = "Meu mundo"
var world_description: String = ""
var world_seed: int = 55960
var difficulty: String = "normal"
var character_id: String = "male"
var world_id: String = ""
var created_at: String = ""
var playtime_seconds: float = 0.0
var game_started: bool = false
var autosave_interval_seconds: float = 120.0
var _autosave_elapsed: float = 0.0
signal save_status(success: bool, message: String)

func _process(delta: float) -> void:
	if game_started and not get_tree().paused:
		playtime_seconds += delta
		_autosave_elapsed += delta
		if _autosave_elapsed >= maxf(1.0, autosave_interval_seconds):
			_autosave_elapsed = fmod(_autosave_elapsed, maxf(1.0, autosave_interval_seconds))
			var saved: bool = SaveManager.save_active_world()
			save_status.emit(saved, "Salvo automaticamente" if saved else "Falha no salvamento automático")

func configure_world(new_name: String, new_description: String, new_seed: int, new_difficulty: String) -> void:
	start_new_world({"name": new_name, "description": new_description, "seed": new_seed, "difficulty": new_difficulty})

func start_new_world(config: Dictionary) -> bool:
	world_name = String(config.get("name", "Meu mundo")).strip_edges()
	if world_name.is_empty():
		world_name = "Meu mundo"
	world_description = String(config.get("description", "")).strip_edges()
	world_seed = int(config.get("seed", randi()))
	difficulty = String(config.get("difficulty", "normal"))
	if difficulty not in ["easy", "normal", "hard"]:
		difficulty = "normal"
	character_id = String(config.get("character_id", "male"))
	if character_id not in ["male", "female"]:
		character_id = "male"
	world_id = ""
	SaveManager.set_active_world("")
	created_at = Time.get_datetime_string_from_system(true, true)
	playtime_seconds = 0.0
	game_started = false
	get_tree().paused = false
	var world := _current_world()
	var generator = world.get_node_or_null("IslandGenerator") if world else null
	if generator:
		generator.set_world_active(false)
		generator.apply_persistent_state({"resources": {}, "animals": {}})
		generator.apply_seed(world_seed)
	if player:
		player.configure_difficulty(difficulty)
		player.character_id = character_id
		var presentation = player.get_node_or_null("CharacterPresentation")
		if presentation and presentation.has_method("configure_character"):
			presentation.configure_character(character_id)
		if presentation and presentation.has_method("set_camera_mode"):
			presentation.set_camera_mode(0)
		if presentation and presentation.has_method("set_held_item"):
			presentation.set_held_item("hand")
		player.global_position = Vector3(0.0, 2.0, 0.0)
		player.rotation = Vector3.ZERO
		player.camera_pivot.rotation = Vector3.ZERO
		player.health = player.max_health
		player.hunger = player.max_hunger
		player.thirst = player.max_thirst
		player.energy = 100.0
		player.active_tool = "hand"
		player._cam_mode = 0
		player._cam_distance = 0.0
		player.camera.position.z = 0.0
		player.hotbar_tools.clear()
		for tool_id in ["hand", "knife", "stone_axe", "stone_pickaxe", "shovel"]:
			player.hotbar_tools.append(tool_id)
		var inventory = player.get_node_or_null("Inventory")
		if inventory:
			inventory.clear()
		var research = player.get_node_or_null("ResearchSystem")
		if research:
			research.apply_save_state({"level": 1, "experience": 0, "research_points": 0, "unlocked": {"basic_tools": true}})
		var buildings = player.get_node_or_null("BuildingSystem")
		if buildings:
			var empty_buildings: Array[Dictionary] = []
			buildings.apply_save_state(empty_buildings)
	game_started = true
	if generator:
		generator.set_world_active(true)
	_set_game_ui(true)
	return true

func capture_save_snapshot() -> Dictionary:
	var snapshot := {
		"save_format_version": SaveManager.SAVE_FORMAT_VERSION,
		"world_generation_version": SaveManager.WORLD_GENERATION_VERSION,
		"world_id": world_id,
		"name": world_name,
		"description": world_description,
		"created_at": created_at if not created_at.is_empty() else Time.get_datetime_string_from_system(true, true),
		"playtime_seconds": playtime_seconds,
		"seed": world_seed,
		"difficulty": difficulty,
		"character_id": character_id,
		"player": {},
		"inventory": [],
		"research": {},
		"buildings": [],
		"world_state": {"resources": {}, "animals": {}}
	}
	if player:
		snapshot["player"] = player.get_save_state()
		var inventory = player.get_node_or_null("Inventory")
		if inventory:
			snapshot["inventory"] = inventory.get_save_state()
		var research = player.get_node_or_null("ResearchSystem")
		if research:
			snapshot["research"] = research.get_save_state()
		var building_system = player.get_node_or_null("BuildingSystem")
		if building_system:
			snapshot["buildings"] = building_system.get_save_state()
	var world := _current_world()
	var generator = world.get_node_or_null("IslandGenerator") if world else null
	if generator:
		snapshot["world_state"] = generator.capture_persistent_state()
	return snapshot

func start_world_from_save(snapshot: Dictionary) -> bool:
	if not _is_supported_snapshot(snapshot):
		return false
	# All schema checks happen before mutating the active world.
	var new_seed := int(snapshot["seed"])
	var new_difficulty := String(snapshot["difficulty"])
	var new_character := String(snapshot.get("character_id", "male"))
	var player_state: Dictionary = snapshot["player"]
	var inventory_state: Array[Dictionary] = []
	for slot in snapshot["inventory"]:
		if slot is Dictionary:
			inventory_state.append(slot)
	var research_state: Dictionary = snapshot["research"]
	var building_state: Array[Dictionary] = []
	for piece in snapshot["buildings"]:
		if piece is Dictionary:
			building_state.append(piece)
	world_id = String(snapshot.get("world_id", ""))
	SaveManager.set_active_world(world_id)
	world_name = String(snapshot.get("name", "Meu mundo"))
	world_description = String(snapshot.get("description", ""))
	created_at = String(snapshot.get("created_at", ""))
	playtime_seconds = maxf(0.0, float(snapshot.get("playtime_seconds", 0.0)))
	world_seed = new_seed
	difficulty = new_difficulty
	character_id = new_character
	game_started = false
	get_tree().paused = false
	var world := _current_world()
	var generator = world.get_node_or_null("IslandGenerator") if world else null
	if generator:
		generator.set_world_active(false)
		generator.apply_persistent_state(snapshot["world_state"])
		generator.apply_seed(world_seed)
	if player:
		player.configure_difficulty(difficulty)
		player.apply_save_state(player_state)
		player.character_id = character_id
		var inventory = player.get_node_or_null("Inventory")
		if inventory:
			inventory.apply_save_state(inventory_state)
		var research = player.get_node_or_null("ResearchSystem")
		if research:
			research.apply_save_state(research_state)
		var buildings = player.get_node_or_null("BuildingSystem")
		if buildings:
			buildings.apply_save_state(building_state)
	game_started = true
	if generator:
		generator.set_world_active(true)
	_set_game_ui(true)
	return true

func _is_supported_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("save_format_version", -1)) != SaveManager.SAVE_FORMAT_VERSION:
		return false
	if int(snapshot.get("world_generation_version", -1)) != SaveManager.WORLD_GENERATION_VERSION:
		return false
	if not snapshot.has("seed") or not snapshot.has("difficulty"):
		return false
	if String(snapshot["difficulty"]) not in ["easy", "normal", "hard"]:
		return false
	if not (snapshot.get("player") is Dictionary and snapshot.get("inventory") is Array and snapshot.get("research") is Dictionary and snapshot.get("buildings") is Array and snapshot.get("world_state") is Dictionary):
		return false
	var player_state: Dictionary = snapshot["player"]
	if player_state.has("position") and not _is_finite_vector(player_state["position"], 3):
		return false
	for key in ["rotation_y", "camera_pitch", "camera_distance", "health", "hunger", "thirst", "energy"]:
		if player_state.has(key) and not _is_finite_number(player_state[key]):
			return false
	if player_state.has("camera_mode") and not _is_finite_number(player_state["camera_mode"]):
		return false
	if player_state.has("active_tool") and not player_state["active_tool"] is String:
		return false
	var inventory_state: Array = snapshot["inventory"]
	for slot in inventory_state:
		if not slot is Dictionary or not slot.get("id", "") is String or String(slot.get("id", "")).is_empty():
			return false
		if not _is_finite_number(slot.get("qty", null)) or int(slot["qty"]) <= 0:
			return false
	var research_state: Dictionary = snapshot["research"]
	for key in ["level", "experience", "research_points"]:
		if research_state.has(key) and (not _is_finite_number(research_state[key]) or int(research_state[key]) < 0):
			return false
	if research_state.has("unlocked") and not research_state["unlocked"] is Dictionary:
		return false
	var building_states: Array = snapshot["buildings"]
	for piece in building_states:
		if not piece is Dictionary or not piece.get("piece_id", "") is String or String(piece.get("piece_id", "")).is_empty():
			return false
		for key in ["position", "rotation", "scale"]:
			if piece.has(key) and not _is_finite_vector(piece[key], 3):
				return false
		for key in ["health", "current_health", "stress", "stress_limit", "improvement_level"]:
			if piece.has(key) and not _is_finite_number(piece[key]):
				return false
	var world_state: Dictionary = snapshot["world_state"]
	if not (world_state.get("resources", {}) is Dictionary and world_state.get("animals", {}) is Dictionary):
		return false
	for category in ["resources", "animals"]:
		var records: Dictionary = world_state.get(category, {})
		for persistent_id in records:
			var record: Variant = records[persistent_id]
			if not record is Dictionary or not record.get("persistent_id", "") is String or String(record.get("persistent_id", "")) != String(persistent_id):
				return false
			for key in ["position", "rotation"]:
				if record.has(key) and not _is_finite_vector(record[key], 3):
					return false
			for key in ["health", "max_health", "respawn_remaining", "resource_qty", "behavior"]:
				if record.has(key) and not _is_finite_number(record[key]):
					return false
	return true

func is_save_snapshot_supported(snapshot: Dictionary) -> bool:
	return _is_supported_snapshot(snapshot)

func _is_finite_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	return is_finite(float(value))

func _is_finite_vector(value: Variant, dimensions: int) -> bool:
	if not value is Array or value.size() < dimensions:
		return false
	for index in range(dimensions):
		if not _is_finite_number(value[index]):
			return false
	return true

func return_to_title() -> void:
	if game_started and not SaveManager.save_active_world():
		save_status.emit(false, "Não foi possível salvar; seu mundo continua aberto")
		return
	game_started = false
	var world := _current_world()
	var generator = world.get_node_or_null("IslandGenerator") if world else null
	if generator:
		generator.set_world_active(false)
	_set_game_ui(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game_started:
		SaveManager.save_active_world()
		get_tree().quit()

func _set_game_ui(in_game: bool) -> void:
	var world := _current_world()
	if not world:
		return
	var hud = world.get_node_or_null("HUD")
	var menu = world.get_node_or_null("MainMenu")
	if player and player.has_method("set_gameplay_input_enabled"):
		player.set_gameplay_input_enabled(in_game)
	if hud:
		hud.visible = in_game
	if menu:
		menu.visible = not in_game
		if not in_game and menu.has_method("show_title"):
			menu.show_title()
	get_tree().paused = not in_game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if in_game else Input.MOUSE_MODE_VISIBLE

func _current_world() -> Node:
	return get_tree().current_scene

func _ready() -> void:
	call_deferred("_connect_building_signals")

func _connect_building_signals() -> void:
	if player:
		var building_sys = player.get_node_or_null("BuildingSystem")
		if building_sys and not building_sys.invalid_placement.is_connected(_on_invalid_placement):
			building_sys.invalid_placement.connect(_on_invalid_placement)

func _on_invalid_placement(reason: String) -> void:
	var world := _current_world()
	var hud = world.get_node_or_null("HUD") if world else null
	if hud and hud.has_method("show_message"):
		hud.show_message(reason)
