extends StaticBody3D
class_name Harvestable

@export var resource_id: String = "wood"
@export var resource_qty: int = 3
@export var respawn_time: float = 30.0
@export var preferred_tool: String = ""

var persistent_id: String = ""
var _depleted: bool = false
var _respawn_remaining: float = 0.0

func _ready() -> void:
	_apply_visual_materials()
	_set_depleted_visuals(_depleted)

func _process(delta: float) -> void:
	if not _depleted:
		return
	_respawn_remaining = maxf(0.0, _respawn_remaining - delta)
	if _respawn_remaining <= 0.0:
		_depleted = false
		_set_depleted_visuals(false)

func _apply_visual_materials() -> void:
	# Keep scene-authored materials and color only meshes that have no material.
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not mesh_node or not mesh_node.mesh:
			continue
		if mesh_node.material_override or mesh_node.mesh.surface_get_material(0):
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#6b4426") if resource_id == "wood" else Color("#68727a")
		material.roughness = 0.95
		mesh_node.material_override = material

func _set_visuals_enabled(enabled: bool) -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node:
			mesh_node.visible = enabled

func _set_depleted_visuals(depleted: bool) -> void:
	_set_visuals_enabled(not depleted)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", depleted)

func get_save_state() -> Dictionary:
	var position_value := global_position if is_inside_tree() else position
	var rotation_value := global_rotation if is_inside_tree() else rotation
	return {
		"persistent_id": persistent_id,
		"resource_id": resource_id,
		"resource_qty": resource_qty,
		"depleted": _depleted,
		"respawn_remaining": _respawn_remaining,
		"position": [position_value.x, position_value.y, position_value.z],
		"rotation": [rotation_value.x, rotation_value.y, rotation_value.z]
	}

func apply_save_state(state: Dictionary) -> void:
	if state.has("persistent_id"):
		persistent_id = String(state["persistent_id"])
	resource_id = String(state.get("resource_id", resource_id))
	resource_qty = int(state.get("resource_qty", resource_qty))
	_depleted = bool(state.get("depleted", false))
	_respawn_remaining = maxf(0.0, float(state.get("respawn_remaining", 0.0)))
	if state.has("position"):
		var saved_position: Array = state["position"]
		if saved_position.size() == 3:
			var position_value := Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
			if is_inside_tree():
				global_position = position_value
			else:
				position = position_value
	if state.has("rotation"):
		var saved_rotation: Array = state["rotation"]
		if saved_rotation.size() == 3:
			var rotation_value := Vector3(float(saved_rotation[0]), float(saved_rotation[1]), float(saved_rotation[2]))
			if is_inside_tree():
				global_rotation = rotation_value
			else:
				rotation = rotation_value
	_set_depleted_visuals(_depleted)

func harvest(interaction: Node, tool_id: String = "hand") -> bool:
	if _depleted:
		return false
	var amount := resource_qty
	if tool_id == preferred_tool and not preferred_tool.is_empty():
		amount += 2
	interaction.register_resource(resource_id, amount)
	_depleted = true
	_respawn_remaining = respawn_time
	_set_depleted_visuals(true)
	return true
