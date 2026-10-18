extends CanvasLayer
class_name HUD

@onready var wood_label: Label = $Root/WoodLabel
@onready var stone_label: Label = $Root/StoneLabel
@onready var crosshair: Label = $Root/Crosshair
@onready var message_label: Label = $Root/MessageLabel
@onready var health_label: Label = $Root/HealthLabel
@onready var hunger_label: Label = $Root/HungerLabel
@onready var thirst_label: Label = $Root/ThirstLabel
@onready var energy_label: Label = $Root/EnergyLabel
@onready var tool_label: Label = $Root/ToolLabel

var _inv_cache: Node = null

func _process(_delta: float) -> void:
	if Main.player and not _inv_cache:
		_inv_cache = Main.player.get_node("Inventory")
	if _inv_cache:
		wood_label.text = "Madeira: %d" % _inv_cache.get_count("wood")
		stone_label.text = "Pedra: %d" % _inv_cache.get_count("stone")
	if Main.player:
		health_label.text = "Vida: %d" % Main.player.health
		hunger_label.text = "Fome: %d" % Main.player.hunger
		thirst_label.text = "Sede: %d" % Main.player.thirst
		thirst_label.visible = Main.difficulty != "easy"
		energy_label.visible = Main.difficulty == "hard"
		energy_label.text = "Energia: %d" % Main.player.energy
		tool_label.text = "Ferramenta: %s" % _tool_name(Main.player.get_active_tool())

func _tool_name(tool_id: String) -> String:
	var names := {"hand": "Mãos", "knife": "Faca", "stone_axe": "Machado", "stone_pickaxe": "Picareta", "shovel": "Pá"}
	return names.get(tool_id, tool_id)

func show_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false

func set_inventory_open(is_open: bool) -> void:
	crosshair.visible = not is_open
