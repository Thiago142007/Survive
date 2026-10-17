extends Node
# Autoload global. Referência ao jogador atual e configurações globais.
var player: Node3D = null
var world_name: String = "Meu mundo"
var world_description: String = ""
var world_seed: int = 55960
var difficulty: String = "normal"
var game_started: bool = false

func configure_world(new_name: String, new_description: String, new_seed: int, new_difficulty: String) -> void:
	world_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else "Meu mundo"
	world_description = new_description.strip_edges()
	world_seed = new_seed
	difficulty = new_difficulty
	game_started = true
	var generator = get_tree().current_scene.get_node_or_null("IslandGenerator")
	if generator and generator.has_method("apply_seed"):
		generator.apply_seed(world_seed)
	if player and player.has_method("configure_difficulty"):
		player.configure_difficulty(difficulty)

func _ready() -> void:
	# Defer signal connection until the scene tree is fully ready
	call_deferred("_connect_building_signals")

func _connect_building_signals() -> void:
	if player:
		var building_sys = player.get_node_or_null("BuildingSystem")
		if building_sys:
			building_sys.invalid_placement.connect(_on_invalid_placement)

func _on_invalid_placement(reason: String) -> void:
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message(reason)
