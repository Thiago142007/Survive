extends CanvasLayer
class_name HUD

@onready var wood_label: Label = $Root/WoodLabel
@onready var stone_label: Label = $Root/StoneLabel
@onready var crosshair: Label = $Root/Crosshair
@onready var message_label: Label = $Root/MessageLabel

func _process(_delta: float) -> void:
	if Main.player:
		var inv = Main.player.get_node("Inventory")
		wood_label.text = "Madeira: %d" % inv.get_count("wood")
		stone_label.text = "Pedra: %d" % inv.get_count("stone")

func show_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false
