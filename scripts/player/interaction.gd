extends Node3D
class_name Interaction

@export var raycast_length: float = 3.0
@onready var ray: RayCast3D = $RayCast3D

signal item_collected(id: String, qty: int)

func _ready() -> void:
	ray.force_raycast_update()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	ray.force_raycast_update()
	if ray.is_colliding():
		var collider = ray.get_collider()
		if collider.has_method("try_domesticate") and collider.try_domesticate():
			var hud = get_tree().current_scene.get_node_or_null("HUD")
			if hud and hud.has_method("show_message"):
				hud.show_message("Animal domesticado")
		elif collider.has_method("harvest"):
			var main := get_node_or_null("/root/Main")
			var player = main.get("player") if main else null
			collider.harvest(self, player.get_active_tool() if player else "hand")

func register_resource(id: String, qty: int) -> void:
	var main := get_node_or_null("/root/Main")
	var player = main.get("player") if main else null
	if not player:
		return
	var inv = player.get_node("Inventory")
	inv.add_item(id, qty)
	var research = player.get_node_or_null("ResearchSystem")
	if research:
		research.add_experience(maxi(1, qty * 2))
	_request_effect(&"collect", global_position)
	item_collected.emit(id, qty)

func _request_effect(effect_id: StringName, position: Vector3, vfx_id: StringName = &"") -> void:
	if not is_inside_tree():
		return
	var effects := get_node_or_null("/root/Effects")
	if not effects:
		return
	effects.play_world(effect_id, position)
	if not vfx_id.is_empty():
		effects.spawn_vfx(vfx_id, position)
