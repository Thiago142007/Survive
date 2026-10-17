extends Resource
class_name ItemData

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_stack: int = 100
@export var category: String = "resource"  # resource, tool, weapon, food, building
@export var tool_type: String = ""
@export var gather_bonus: int = 0
@export var damage: float = 0.0
