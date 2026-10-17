extends Node3D
class_name BuildPiece

@export var piece_id: String = "foundation"
@export var display_name: String = "Foundation"
@export var material_type: String = "wood"  # wood, stone, metal
@export var build_cost: Dictionary = {"wood": 10}
@export var health: float = 100.0
@export var is_foundation: bool = false
@export var grid_size: Vector3 = Vector3(2, 2, 2)

var current_health: float = 100.0
var improvement_level: int = 0

func _ready() -> void:
	current_health = health

func get_next_improvement_cost() -> Dictionary:
	var cost := {}
	for res in build_cost:
		cost[res] = int(ceil(build_cost[res] * 0.5))
	return cost

func get_max_improvements() -> int:
	return 3
