extends Node
# Autoload global. Referência ao jogador atual e configurações globais.
var player: Node3D = null
var world_name: String = "Meu mundo"
var world_description: String = ""
var world_seed: int = 55960
var difficulty: String = "normal"
var game_started: bool = false
var _ambience_active: bool = false

func configure_world(new_name: String, new_description: String, new_seed: int, new_difficulty: String) -> void:
	world_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else "Meu mundo"
	world_description = new_description.strip_edges()
	world_seed = new_seed
	difficulty = new_difficulty
	set_game_started(true)
	var current_scene := get_tree().current_scene
	var generator = current_scene.get_node_or_null("IslandGenerator") if current_scene else null
	if generator and generator.has_method("apply_seed"):
		generator.apply_seed(world_seed)
	if player and player.has_method("configure_difficulty"):
		player.configure_difficulty(difficulty)

func _ready() -> void:
	# Defer signal connection until the scene tree is fully ready
	call_deferred("_connect_building_signals")
	call_deferred("_sync_ambience")

func _exit_tree() -> void:
	if _is_autoload_instance():
		_stop_ambience()

func set_game_started(started: bool) -> void:
	game_started = started
	_sync_ambience()

func _sync_ambience() -> void:
	if not _is_autoload_instance():
		return
	var effects := get_node_or_null("/root/Effects")
	if not effects:
		return
	if game_started:
		effects.start_ambience(&"ocean")
		effects.start_ambience(&"wind")
		_ambience_active = true
	elif _ambience_active:
		_stop_ambience()

func _stop_ambience() -> void:
	var effects := get_node_or_null("/root/Effects")
	if effects:
		effects.stop_ambience(&"ocean")
		effects.stop_ambience(&"wind")
	_ambience_active = false

func _is_autoload_instance() -> bool:
	return is_inside_tree() and get_tree().root.get_node_or_null("Main") == self

func _connect_building_signals() -> void:
	if player:
		var building_sys = player.get_node_or_null("BuildingSystem")
		if building_sys and not building_sys.invalid_placement.is_connected(_on_invalid_placement):
			building_sys.invalid_placement.connect(_on_invalid_placement)
		if building_sys and not building_sys.status_message.is_connected(_on_building_status):
			building_sys.status_message.connect(_on_building_status)

func _on_invalid_placement(reason: String) -> void:
	var effects := get_node_or_null("/root/Effects")
	if effects:
		effects.play_ui(&"ui_error")
	_show_hud_message(reason)

func _on_building_status(message: String) -> void:
	_show_hud_message(message)

func _show_hud_message(message: String) -> void:
	var current_scene := get_tree().current_scene
	var hud = current_scene.get_node_or_null("HUD") if current_scene else null
	if hud and hud.has_method("show_message"):
		hud.show_message(message)
