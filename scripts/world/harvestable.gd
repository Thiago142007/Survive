extends StaticBody3D
class_name Harvestable

@export var resource_id: String = "wood"
@export var resource_qty: int = 3
@export var respawn_time: float = 30.0
@export var preferred_tool: String = ""

var _depleted: bool = false

func _ready() -> void:
	_apply_visual_materials()

func _apply_visual_materials() -> void:
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node and mesh_node.mesh:
		var mesh := mesh_node.mesh.duplicate()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#6b4426") if resource_id == "wood" else Color("#68727a")
		mesh.material = material
		mesh_node.mesh = mesh
	var canopy := get_node_or_null("Canopy") as MeshInstance3D
	if canopy and canopy.mesh:
		var canopy_mesh := canopy.mesh.duplicate()
		var canopy_material := StandardMaterial3D.new()
		canopy_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		canopy_material.albedo_color = Color("#315b27")
		canopy_mesh.material = canopy_material
		canopy.mesh = canopy_mesh

func harvest(interaction: Node, tool_id: String = "hand") -> void:
	if _depleted:
		return
	var amount := resource_qty
	if tool_id == preferred_tool and not preferred_tool.is_empty():
		amount += 2
	if resource_id == "wood":
		_request_effect(&"wood_hit", global_position, &"wood_splinters")
	else:
		_request_effect(&"stone_hit", global_position, &"stone_sparks")
	interaction.register_resource(resource_id, amount)
	_depleted = true
	$MeshInstance3D.visible = false
	var canopy := get_node_or_null("Canopy") as MeshInstance3D
	if canopy:
		canopy.visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_time).timeout
	_depleted = false
	$MeshInstance3D.visible = true
	if canopy:
		canopy.visible = true
	$CollisionShape3D.set_deferred("disabled", false)

func _request_effect(effect_id: StringName, position: Vector3, vfx_id: StringName = &"") -> void:
	if not is_inside_tree():
		return
	var effects := get_node_or_null("/root/Effects")
	if not effects:
		return
	effects.play_world(effect_id, position)
	if not vfx_id.is_empty():
		effects.spawn_vfx(vfx_id, position)
