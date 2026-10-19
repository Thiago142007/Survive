extends CanvasLayer

@onready var status_label: Label = $Panel/Margin/Actions/Status
@onready var continue_button: Button = $Panel/Margin/Actions/ContinueButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not Main.save_status.is_connected(_on_save_status):
		Main.save_status.connect(_on_save_status)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		continue_game()
		get_viewport().set_input_as_handled()

func open_pause() -> void:
	if not Main.game_started:
		return
	visible = true
	status_label.text = ""
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Main.player and Main.player.has_method("set_gameplay_input_enabled"):
		Main.player.set_gameplay_input_enabled(false)
	continue_button.grab_focus()

func continue_game() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	if Main.player and Main.player.has_method("set_gameplay_input_enabled"):
		Main.player.set_gameplay_input_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func save_now() -> bool:
	var success: bool = SaveManager.save_active_world()
	status_label.text = "Jogo salvo." if success else "Falha ao salvar. Mantenha o jogo aberto."
	return success

func return_to_title() -> void:
	var returned: bool = await Main.return_to_title()
	if returned:
		visible = false
	else:
		status_label.text = "Falha ao salvar. Seu mundo continua aberto."

func _on_save_status(success: bool, message: String) -> void:
	if visible:
		status_label.text = message if success else "Falha ao salvar. Seu mundo continua aberto."
