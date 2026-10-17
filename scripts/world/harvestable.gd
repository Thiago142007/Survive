extends StaticBody3D
class_name Harvestable

@export var resource_id: String = "wood"
@export var resource_qty: int = 3
@export var respawn_time: float = 30.0

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
