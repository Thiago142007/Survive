extends Node3D
class_name BuildPiece

@export var piece_id: String = "foundation"
@export var display_name: String = "Foundation"
@export var material_type: String = "wood"  # wood, stone, metal
@export var build_cost: Dictionary = {"wood": 10}
@export var health: float = 100.0
@export var is_foundation: bool = false
@export var grid_size: Vector3 = Vector3(2, 2, 2)
@export var stress_limit: float = 100.0

var current_health: float = 100.0
var improvement_level: int = 0
var stress: float = 0.0
var base_health: float = 100.0

func _ready() -> void:
	current_health = health
	base_health = health

func get_next_improvement_cost() -> Dictionary:
	var cost := {}
	for res in build_cost:
		cost[res] = int(ceil(build_cost[res] * 0.5))
	return cost

func get_max_improvements() -> int:
	return 3

func add_stress(amount: float) -> void:
	stress = minf(stress_limit, stress + maxf(0.0, amount))

func upgrade() -> void:
	if improvement_level >= get_max_improvements():
		return
	improvement_level += 1
	health = base_health * float(improvement_level + 1)
	current_health = minf(health, current_health + base_health)
	stress_limit += 20.0

func get_repair_cost() -> Dictionary:
	var cost := {}
	for resource_id in build_cost:
		cost[resource_id] = maxi(1, int(ceil(build_cost[resource_id] * 0.25)))
	return cost

func repair() -> void:
	current_health = minf(health, current_health + base_health * 0.25)

func get_save_state() -> Dictionary:
	return {
		"piece_id": piece_id,
		"material_type": material_type,
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation": [rotation.x, rotation.y, rotation.z],
		"scale": [scale.x, scale.y, scale.z],
		"health": health,
		"current_health": current_health,
		"improvement_level": improvement_level,
		"stress": stress,
		"stress_limit": stress_limit
	}

func apply_save_state(state: Dictionary) -> void:
	material_type = String(state.get("material_type", material_type))
	improvement_level = clampi(int(state.get("improvement_level", 0)), 0, get_max_improvements())
	base_health = maxf(1.0, base_health)
	health = maxf(float(state.get("health", health)), base_health * float(improvement_level + 1))
	current_health = maxf(0.0, float(state.get("current_health", health)))
	stress = clampf(float(state.get("stress", 0.0)), 0.0, float(state.get("stress_limit", stress_limit)))
	stress_limit = maxf(1.0, float(state.get("stress_limit", stress_limit)))
	var saved_position: Variant = state.get("position", [])
	var saved_rotation: Variant = state.get("rotation", [])
	var saved_scale: Variant = state.get("scale", [])
	if saved_position is Array and saved_position.size() >= 3:
		global_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	if saved_rotation is Array and saved_rotation.size() >= 3:
		rotation = Vector3(float(saved_rotation[0]), float(saved_rotation[1]), float(saved_rotation[2]))
	if saved_scale is Array and saved_scale.size() >= 3:
		scale = Vector3(float(saved_scale[0]), float(saved_scale[1]), float(saved_scale[2]))
