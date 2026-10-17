extends StaticBody3D
class_name Harvestable

@export var resource_id: String = "wood"
@export var resource_qty: int = 3
@export var respawn_time: float = 30.0

var _depleted: bool = false

func harvest(interaction: Node) -> void:
	if _depleted:
		return
	interaction.register_resource(resource_id, resource_qty)
	_depleted = true
	$MeshInstance3D.visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_time).timeout
	_depleted = false
	$MeshInstance3D.visible = true
	$CollisionShape3D.set_deferred("disabled", false)
