extends CanvasLayer

@onready var name_input: LineEdit = $Panel/Margin/VBox/NameInput
@onready var description_input: LineEdit = $Panel/Margin/VBox/DescriptionInput
@onready var seed_input: LineEdit = $Panel/Margin/VBox/SeedInput
@onready var difficulty_option: OptionButton = $Panel/Margin/VBox/DifficultyOption
@onready var error_label: Label = $Panel/Margin/VBox/ErrorLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	difficulty_option.select(1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.visible = false
	get_tree().paused = true

func _on_start_pressed() -> void:
	var parsed_seed := int(seed_input.text)
	if seed_input.text.strip_edges().is_empty():
		parsed_seed = randi()
	var difficulties := ["easy", "normal", "hard"]
	var selected: String = String(difficulties[difficulty_option.selected])
	var main := get_node_or_null("/root/Main")
	if not main:
		_request_ui(&"ui_error")
		return
	main.configure_world(name_input.text, description_input.text, parsed_seed, selected)
	_request_ui(&"ui_confirm")
	visible = false
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quit_pressed() -> void:
	_request_ui(&"ui_click")
	get_tree().quit()

func _request_ui(effect_id: StringName) -> void:
	var effects := get_node_or_null("/root/Effects")
	if effects:
		effects.play_ui(effect_id)
