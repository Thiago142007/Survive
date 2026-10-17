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
