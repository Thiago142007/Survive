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
@onready var fps_counter: Label = $Root/FPSCounter

var _inv_cache: Node = null
var _fps_counter_position := "off"

func _ready() -> void:
	# SettingsManager can call the setter before this scene's @onready references
	# are initialized. Apply the stored choice once the HUD nodes are available.
	_apply_fps_counter_position()

func _process(_delta: float) -> void:
	if _fps_counter_position != "off" and is_instance_valid(fps_counter):
		fps_counter.text = "FPS: %d" % Engine.get_frames_per_second()
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

func set_fps_counter_position(position_name: String) -> void:
	_fps_counter_position = position_name if position_name in ["off", "top_left", "top_right", "bottom_left", "bottom_right"] else "off"
	_apply_fps_counter_position()

func _apply_fps_counter_position() -> void:
	if not is_instance_valid(fps_counter):
		return
	fps_counter.visible = _fps_counter_position != "off"
	if not fps_counter.visible:
		return
	var is_right := _fps_counter_position.ends_with("right")
	var is_bottom := _fps_counter_position.begins_with("bottom")
	fps_counter.anchor_left = 1.0 if is_right else 0.0
	fps_counter.anchor_right = 1.0 if is_right else 0.0
	fps_counter.anchor_top = 1.0 if is_bottom else 0.0
	fps_counter.anchor_bottom = 1.0 if is_bottom else 0.0
	fps_counter.offset_left = -112.0 if is_right else 12.0
	fps_counter.offset_right = -12.0 if is_right else 112.0
	fps_counter.offset_top = -34.0 if is_bottom else 12.0
	fps_counter.offset_bottom = -10.0 if is_bottom else 36.0
	fps_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_right else HORIZONTAL_ALIGNMENT_LEFT
