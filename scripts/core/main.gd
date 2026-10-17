extends Node
# Autoload global. Referência ao jogador atual e configurações globais.
var player: Node3D = null

func _ready() -> void:
	# Defer signal connection until the scene tree is fully ready
	call_deferred("_connect_building_signals")

func _connect_building_signals() -> void:
	if player:
		var building_sys = player.get_node_or_null("BuildingSystem")
		if building_sys:
			building_sys.invalid_placement.connect(_on_invalid_placement)

func _on_invalid_placement(reason: String) -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message(reason)
