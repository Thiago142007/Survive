extends CanvasLayer

@onready var actions: VBoxContainer = $Panel/Margin/Content/Actions
@onready var settings_panel: VBoxContainer = $Panel/Margin/Content/SettingsPanel
@onready var status_label: Label = $Panel/Margin/Content/Status
@onready var continue_button: Button = $Panel/Margin/Content/Actions/ContinueButton
@onready var settings_button: Button = $Panel/Margin/Content/Actions/SettingsButton
@onready var settings_volume: HSlider = $Panel/Margin/Content/SettingsPanel/VolumeSlider
@onready var settings_mode: OptionButton = $Panel/Margin/Content/SettingsPanel/WindowModeOption
@onready var settings_resolution: OptionButton = $Panel/Margin/Content/SettingsPanel/ResolutionOption

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	settings_panel.visible = false
	_setup_settings_controls()
	if not Main.save_status.is_connected(_on_save_status):
		Main.save_status.connect(_on_save_status)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_settings_back_pressed()
		else:
			continue_game()
		get_viewport().set_input_as_handled()

func open_pause() -> void:
	if not Main.game_started:
		return
	visible = true
	actions.visible = true
	settings_panel.visible = false
	status_label.text = ""
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Main.player and Main.player.has_method("set_gameplay_input_enabled"):
		Main.player.set_gameplay_input_enabled(false)
	continue_button.grab_focus()

func open_settings() -> void:
	if not visible:
		return
	var settings: Dictionary = _settings_manager().load_settings()
	settings_volume.value = float(settings["master_volume"])
	settings_mode.select(["windowed", "borderless", "fullscreen"].find(String(settings["window_mode"])))
	settings_resolution.select(_settings_manager().SUPPORTED_RESOLUTIONS.find(String(settings["resolution"])))
	actions.visible = false
	settings_panel.visible = true
	status_label.text = ""
	settings_volume.grab_focus()

func _setup_settings_controls() -> void:
	var settings_manager := _settings_manager()
	for mode in ["Janela", "Sem bordas", "Tela cheia"]:
		settings_mode.add_item(mode)
	for resolution in settings_manager.SUPPORTED_RESOLUTIONS:
		settings_resolution.add_item(resolution)

func _settings_manager() -> Node:
	return get_node("/root/SettingsManager")

func _on_settings_pressed() -> void:
	open_settings()

func _on_settings_apply_pressed() -> void:
	var modes := ["windowed", "borderless", "fullscreen"]
	var manager := _settings_manager()
	var settings := {
		"master_volume": settings_volume.value,
		"window_mode": modes[clampi(settings_mode.selected, 0, modes.size() - 1)],
		"resolution": manager.SUPPORTED_RESOLUTIONS[clampi(settings_resolution.selected, 0, manager.SUPPORTED_RESOLUTIONS.size() - 1)]
	}
	if not manager.save_settings(settings):
		status_label.text = "Não foi possível salvar as configurações."
		return
	manager.apply_settings(settings)
	status_label.text = "Configurações aplicadas."
	_on_settings_back_pressed()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	actions.visible = true
	settings_button.grab_focus()

func continue_game() -> void:
	if not visible:
		return
	visible = false
	settings_panel.visible = false
	actions.visible = true
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
