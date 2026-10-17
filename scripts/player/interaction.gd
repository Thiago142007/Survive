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
		if collider.has_method("harvest"):
			collider.harvest(self)

func register_resource(id: String, qty: int) -> void:
	var inv = Main.player.get_node("Inventory")
	inv.add_item(id, qty)
	item_collected.emit(id, qty)
