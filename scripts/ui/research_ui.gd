extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var node_list: VBoxContainer = $Panel/Margin/VBox/NodeList
@onready var points_label: Label = $Panel/Margin/VBox/Points
@onready var status_label: Label = $Panel/Margin/VBox/Status
var research_system: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_research") and Main.game_started:
		panel.visible = not panel.visible
		if panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			research_system = Main.player.get_node_or_null("ResearchSystem")
			_refresh()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh() -> void:
	for child in node_list.get_children():
		child.queue_free()
	if not research_system:
		return
	points_label.text = "Research Points: %d   |   Nível: %d" % [research_system.research_points, research_system.level]
	for node_id in research_system.get_nodes():
		var data: Dictionary = research_system.get_nodes()[node_id]
		var button := Button.new()
		var unlocked: bool = research_system.unlocked.has(node_id)
		button.text = ("✓ " if unlocked else "") + "%s — %s" % [data["name"], data["description"]]
		button.disabled = unlocked
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_unlock.bind(node_id))
		node_list.add_child(button)

func _unlock(node_id: String) -> void:
	if research_system and research_system.unlock(node_id):
		status_label.text = "Pesquisa desbloqueada"
		_refresh()
	else:
		status_label.text = "Research Points insuficientes"
