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

func _try_interact() -> bool:
	ray.force_raycast_update()
	if ray.is_colliding():
		var collider = ray.get_collider()
		if collider.has_method("try_domesticate") and collider.try_domesticate():
			var hud = get_tree().current_scene.get_node_or_null("HUD")
			if hud and hud.has_method("show_message"):
				hud.show_message("Animal domesticado")
			Main.player.emit_presentation_action(&"interact", StringName(Main.player.get_active_tool()))
			return true
		elif collider.has_method("harvest"):
			var tool_id := StringName(Main.player.get_active_tool())
			var harvested: bool = collider.harvest(self, String(tool_id))
			if harvested:
				Main.player.emit_presentation_action(&"harvest", tool_id)
			return harvested
	return false

func register_resource(id: String, qty: int) -> void:
	var inv = Main.player.get_node("Inventory")
	inv.add_item(id, qty)
	var research = Main.player.get_node_or_null("ResearchSystem")
	if research:
		research.add_experience(maxi(1, qty * 2))
	item_collected.emit(id, qty)
