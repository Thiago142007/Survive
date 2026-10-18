extends CanvasLayer

const IMAGE_SIZE := Vector2(1672.0, 941.0)
const HOTSPOT_PIXELS := {
	"singleplayer": Rect2(141.0, 346.0, 337.0, 66.0),
	"multiplayer": Rect2(141.0, 427.0, 337.0, 66.0),
	"settings": Rect2(141.0, 510.0, 337.0, 66.0),
	"quit": Rect2(141.0, 592.0, 337.0, 66.0)
}
const BUTTON_TEXTURES := {
	"singleplayer": "res://assets/ui/main_menu_button_singleplayer.png",
	"multiplayer": "res://assets/ui/main_menu_button_multiplayer.png",
	"settings": "res://assets/ui/main_menu_button_settings.png",
	"quit": "res://assets/ui/main_menu_button_quit.png"
}
const BUTTON_HOVER_OFFSET := 12.0
const BUTTON_HOVER_DURATION := 0.16

@onready var main_actions: VBoxContainer = $MainActions
@onready var create_world_panel: Panel = $CreateWorldPanel
@onready var name_input: LineEdit = $CreateWorldPanel/Margin/VBox/NameInput
@onready var description_input: LineEdit = $CreateWorldPanel/Margin/VBox/DescriptionInput
@onready var seed_input: LineEdit = $CreateWorldPanel/Margin/VBox/SeedInput
@onready var difficulty_option: OptionButton = $CreateWorldPanel/Margin/VBox/DifficultyOption
@onready var error_label: Label = $CreateWorldPanel/Margin/VBox/ErrorLabel

var title_hotspots: Control
var save_list_panel: PanelContainer
var save_items: ItemList
var load_button: Button
var delete_button: Button
var delete_confirmation: ConfirmationDialog
var character_option: OptionButton
var _settings_volume: HSlider
var _settings_mode: OptionButton
var _settings_resolution: OptionButton
var _save_ids: Array[String] = []
var _save_loadable: Array[bool] = []
var _return_to_saves := true
var _settings_panel: Control
var _button_tweens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.visible = false
	get_tree().paused = true
	$Backdrop.visible = false
	$TopShade.visible = false
	$Brand.visible = false
	$MainActions.visible = false
	$Hint.visible = false
	$Version.visible = false
	create_world_panel.visible = false
	_create_title_hotspots()
	_create_save_list_panel()
	_create_delete_confirmation()
	_create_character_selector()
	_create_settings_panel()
	_layout_title_hotspots()
	get_viewport().size_changed.connect(_layout_title_hotspots)
	get_viewport().set_input_as_handled()

func show_title() -> void:
	visible = true
	$TitleHotspots.visible = true
	create_world_panel.visible = false
	if save_list_panel:
		save_list_panel.visible = false
	if _settings_panel:
		_settings_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if create_world_panel.visible:
			_on_back_pressed()
		elif save_list_panel and save_list_panel.visible:
			_on_save_list_back_pressed()
		elif _settings_panel and _settings_panel.visible:
			_settings_panel.visible = false
			$TitleHotspots.visible = true
		get_viewport().set_input_as_handled()

func _create_title_hotspots() -> void:
	title_hotspots = Control.new()
	title_hotspots.name = "TitleHotspots"
	title_hotspots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_hotspots)
	var definitions := [
		["Singleplayer", "singleplayer", Callable(self, "_on_singleplayer_pressed")],
		["Multiplayer", "multiplayer", Callable(self, "_on_multiplayer_pressed")],
		["Configs", "settings", Callable(self, "_on_settings_pressed")],
		["Quit", "quit", Callable(self, "_on_quit_pressed")]
	]
	for definition in definitions:
		var button := TextureButton.new()
		button.name = String(definition[0])
		button.tooltip_text = String(definition[0])
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.texture_normal = load(BUTTON_TEXTURES[String(definition[1])])
		button.texture_hover = button.texture_normal
		button.texture_pressed = button.texture_normal
		button.texture_focused = button.texture_normal
		button.pressed.connect(definition[2])
		button.mouse_entered.connect(_animate_title_button.bind(button, true))
		button.mouse_exited.connect(_animate_title_button.bind(button, false))
		button.focus_entered.connect(_animate_title_button.bind(button, true))
		button.focus_exited.connect(_animate_title_button.bind(button, false))
		button.set_meta("hotspot_id", String(definition[1]))
		title_hotspots.add_child(button)
		if String(definition[1]) == "multiplayer":
			button.disabled = true
			button.tooltip_text = "Multiplayer — Em breve"
			button.set_meta("disabled_message", "Multiplayer — Em breve")
			var badge := Label.new()
			badge.name = "ComingSoon"
			badge.text = "EM BREVE"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_font_size_override("font_size", 10)
			badge.add_theme_color_override("font_color", Color("#c7a68f"))
			button.add_child(badge)

func _hotspot_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func get_title_button_rect(button_id: String, viewport_size: Vector2) -> Rect2:
	if not HOTSPOT_PIXELS.has(button_id) or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var scale_factor := maxf(viewport_size.x / IMAGE_SIZE.x, viewport_size.y / IMAGE_SIZE.y)
	var rendered_size := IMAGE_SIZE * scale_factor
	var crop_offset := (rendered_size - viewport_size) * 0.5
	var source: Rect2 = HOTSPOT_PIXELS[button_id]
	return Rect2(source.position * scale_factor - crop_offset, source.size * scale_factor)

func _layout_title_hotspots() -> void:
	if not is_instance_valid(title_hotspots):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for button in title_hotspots.get_children():
		var hotspot_id := String(button.get_meta("hotspot_id", ""))
		if not hotspot_id.is_empty():
			var rect := get_title_button_rect(hotspot_id, viewport_size)
			button.position = rect.position
			button.size = rect.size
			button.set_meta("rest_position", rect.position)
			var badge := button.get_node_or_null("ComingSoon") as Label
			if badge:
				badge.position = Vector2(button.size.x * 0.77, 0.0)
				badge.size = Vector2(button.size.x * 0.20, button.size.y)
	var enabled_buttons: Array[Control] = []
	for button in title_hotspots.get_children():
		if not button.disabled:
			enabled_buttons.append(button)
	for index in range(enabled_buttons.size()):
		enabled_buttons[index].focus_neighbor_top = enabled_buttons[(index - 1 + enabled_buttons.size()) % enabled_buttons.size()].get_path()
		enabled_buttons[index].focus_neighbor_bottom = enabled_buttons[(index + 1) % enabled_buttons.size()].get_path()

func _animate_title_button(button: TextureButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var previous_tween: Tween = _button_tweens.get(button)
	if previous_tween and previous_tween.is_running():
		previous_tween.kill()
	var rest_position: Vector2 = button.get_meta("rest_position", button.position)
	var scale_factor := button.size.x / 337.0
	var target_position := rest_position + Vector2(BUTTON_HOVER_OFFSET * scale_factor, 0.0) if hovered else rest_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if hovered else Tween.EASE_IN_OUT)
	tween.tween_property(button, "position", target_position, BUTTON_HOVER_DURATION)
	_button_tweens[button] = tween

func _create_save_list_panel() -> void:
	save_list_panel = PanelContainer.new()
	save_list_panel.name = "SaveListPanel"
	_apply_panel_style(save_list_panel)
	add_child(save_list_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	save_list_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := Label.new()
	header.text = "SINGLEPLAYER"
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color("#ead2bd"))
	column.add_child(header)
	var caption := Label.new()
	caption.text = "Escolha um mundo para continuar ou crie uma nova ilha."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color("#bfa89a"))
	column.add_child(caption)
	save_items = ItemList.new()
	save_items.name = "WorldSaves"
	save_items.custom_minimum_size = Vector2(390, 290)
	save_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_items.item_selected.connect(_on_save_selected)
	column.add_child(save_items)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var new_button := _make_action_button("Novo mundo")
	new_button.pressed.connect(_on_new_world_pressed)
	actions.add_child(new_button)
	load_button = _make_action_button("Carregar")
	load_button.disabled = true
	load_button.pressed.connect(_on_load_selected_pressed)
	actions.add_child(load_button)
	delete_button = _make_action_button("Excluir")
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_selected_pressed)
	actions.add_child(delete_button)
	var back := _make_action_button("Voltar")
	back.pressed.connect(_on_save_list_back_pressed)
	column.add_child(back)
	save_list_panel.visible = false
	_layout_secondary_panel(save_list_panel)

func _create_delete_confirmation() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.name = "DeleteSaveConfirmation"
	delete_confirmation.title = "Excluir mundo?"
	delete_confirmation.dialog_text = "Esta ação remove o save selecionado."
	delete_confirmation.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirmation)

func _create_character_selector() -> void:
	character_option = OptionButton.new()
	character_option.name = "CharacterOption"
	character_option.add_item("Masculino", 0)
	character_option.add_item("Feminino", 1)
	character_option.custom_minimum_size = Vector2(0, 40)
	character_option.add_theme_color_override("font_color", Color("#ead2bd"))
	character_option.add_theme_stylebox_override("normal", _hotspot_style(Color("#211713"), Color("#815c49")))
	var vbox := $CreateWorldPanel/Margin/VBox as VBoxContainer
	vbox.add_child(character_option)
	vbox.move_child(character_option, vbox.get_node("ErrorLabel").get_index())

func _create_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_apply_panel_style(_settings_panel)
	add_child(_settings_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % edge, 24 if edge in ["left", "right"] else 20)
	_settings_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CONFIGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#ead2bd"))
	column.add_child(title)
	var volume_label := Label.new()
	volume_label.text = "Volume geral"
	column.add_child(volume_label)
	_settings_volume = HSlider.new()
	_settings_volume.min_value = 0.0
	_settings_volume.max_value = 1.0
	_settings_volume.step = 0.01
	_settings_volume.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_volume)
	var mode_label := Label.new()
	mode_label.text = "Modo de janela"
	column.add_child(mode_label)
	_settings_mode = OptionButton.new()
	_settings_mode.add_item("Janela", 0)
	_settings_mode.add_item("Sem bordas", 1)
	_settings_mode.add_item("Tela cheia", 2)
	_settings_mode.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_mode)
	var resolution_label := Label.new()
	resolution_label.text = "Resolução"
	column.add_child(resolution_label)
	_settings_resolution = OptionButton.new()
	for resolution in _settings_manager().SUPPORTED_RESOLUTIONS:
		_settings_resolution.add_item(resolution)
	_settings_resolution.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_resolution)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var save_button := _make_action_button("Aplicar e salvar")
	save_button.pressed.connect(_on_settings_save_pressed)
	actions.add_child(save_button)
	var back_button := _make_action_button("Voltar")
	back_button.pressed.connect(_on_settings_back_pressed)
	actions.add_child(back_button)
	_settings_panel.visible = false
	_layout_secondary_panel(_settings_panel)
	_load_settings_into_controls()

func _load_settings_into_controls() -> void:
	var settings_manager := _settings_manager()
	var settings: Dictionary = settings_manager.load_settings()
	_settings_volume.value = float(settings["master_volume"])
	_settings_mode.select(["windowed", "borderless", "fullscreen"].find(String(settings["window_mode"])))
	_settings_resolution.select(settings_manager.SUPPORTED_RESOLUTIONS.find(String(settings["resolution"])))

func _on_settings_save_pressed() -> void:
	var settings_manager := _settings_manager()
	var modes := ["windowed", "borderless", "fullscreen"]
	var resolution_index := clampi(_settings_resolution.selected, 0, settings_manager.SUPPORTED_RESOLUTIONS.size() - 1)
	var settings := {
		"master_volume": _settings_volume.value,
		"window_mode": modes[clampi(_settings_mode.selected, 0, modes.size() - 1)],
		"resolution": settings_manager.SUPPORTED_RESOLUTIONS[resolution_index]
	}
	if settings_manager.save_settings(settings):
		settings_manager.apply_settings(settings)
		_on_settings_back_pressed()
	else:
		_show_feedback("Não foi possível salvar as configurações.")

func _settings_manager() -> Node:
	return get_node("/root/SettingsManager")

func _save_manager() -> Node:
	return get_node("/root/SaveManager")

func _on_settings_back_pressed() -> void:
	_settings_panel.visible = false
	$TitleHotspots.visible = true

func _apply_panel_style(panel: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.075, 0.07, 0.96)
	style.border_color = Color("#956b54")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)

func _make_action_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 42)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color("#ead2bd"))
	button.add_theme_color_override("font_hover_color", Color("#fff0d9"))
	button.add_theme_stylebox_override("normal", _hotspot_style(Color("#39271f"), Color("#785541")))
	button.add_theme_stylebox_override("hover", _hotspot_style(Color("#75402b"), Color("#e2a06a")))
	button.add_theme_stylebox_override("focus", _hotspot_style(Color("#4b3024"), Color("#f0ad70")))
	return button

func _layout_secondary_panel(panel: Control) -> void:
	var size := get_viewport().get_visible_rect().size
	panel.position = Vector2(size.x * 0.62, size.y * 0.10)
	panel.size = Vector2(minf(480.0, size.x * 0.35), size.y * 0.80)
	if panel == create_world_panel:
		panel.position = Vector2(size.x * 0.62, size.y * 0.10)
		panel.size = Vector2(minf(460.0, size.x * 0.35), size.y * 0.80)

func refresh_save_list() -> void:
	if not is_instance_valid(save_items):
		return
	save_items.clear()
	_save_ids.clear()
	_save_loadable.clear()
	for save in _save_manager().list_saves():
		var world_id := String(save.get("world_id", ""))
		var loadable := bool(save.get("loadable", true))
		var label := "%s\nSeed %d  •  %s  •  %s" % [String(save.get("name", "Meu mundo")), int(save.get("seed", 0)), String(save.get("difficulty", "normal")).capitalize(), String(save.get("saved_at", ""))]
		if not loadable:
			label = "Save indisponível\n%s" % String(save.get("error", "Versão incompatível"))
		elif bool(save.get("recovered_from_backup", false)):
			label += "  •  Recuperável do backup"
		save_items.add_item(label)
		_save_ids.append(world_id)
		_save_loadable.append(loadable)
	load_button.disabled = true
	delete_button.disabled = true

func _on_save_selected(index: int) -> void:
	var valid := index >= 0 and index < _save_ids.size()
	load_button.disabled = not valid or not _save_loadable[index]
	delete_button.disabled = not valid

func _on_singleplayer_pressed() -> void:
	refresh_save_list()
	$TitleHotspots.visible = false
	save_list_panel.visible = true
	_layout_secondary_panel(save_list_panel)
	save_items.grab_focus()

func _on_multiplayer_pressed() -> void:
	# Intentionally unavailable; the hotspot is disabled in the title menu.
	pass

func _on_settings_pressed() -> void:
	_load_settings_into_controls()
	_settings_panel.visible = true
	$TitleHotspots.visible = false
	_layout_secondary_panel(_settings_panel)

func _on_new_world_pressed() -> void:
	_return_to_saves = save_list_panel.visible
	save_list_panel.visible = false
	$TitleHotspots.visible = false
	create_world_panel.visible = true
	_layout_secondary_panel(create_world_panel)
	name_input.grab_focus()

func _on_back_pressed() -> void:
	create_world_panel.visible = false
	if _return_to_saves:
		save_list_panel.visible = true
		_layout_secondary_panel(save_list_panel)
	else:
		$TitleHotspots.visible = true

func _on_save_list_back_pressed() -> void:
	save_list_panel.visible = false
	$TitleHotspots.visible = true

func _on_start_pressed() -> void:
	var parsed_seed := int(seed_input.text) if not seed_input.text.strip_edges().is_empty() else randi()
	var difficulties := ["easy", "normal", "hard"]
	var selected: String = String(difficulties[clampi(difficulty_option.selected, 0, difficulties.size() - 1)])
	var character := "female" if character_option.selected == 1 else "male"
	var main_config = get_node_or_null("/root/Main")
	var config := {"name": name_input.text, "description": description_input.text, "seed": parsed_seed, "difficulty": selected, "character_id": character}
	if not main_config or not main_config.start_new_world(config):
		error_label.text = "Não foi possível iniciar este mundo."
		return
	if not _save_manager().save_active_world():
		main_config.game_started = false
		error_label.text = "Não foi possível criar o save. Verifique o armazenamento."
		main_config._set_game_ui(false)
		return
	visible = false

func _on_load_selected_pressed() -> void:
	var selected := save_items.get_selected_items()
	if selected.is_empty():
		return
	var world_id := _save_ids[selected[0]]
	var save_manager := _save_manager()
	var result: Dictionary = save_manager.read_save(world_id)
	if not result.get("ok", false):
		_show_feedback(String(result.get("error", "Save inválido")))
		return
	var main_config = get_node_or_null("/root/Main")
	if not main_config or not main_config.is_save_snapshot_supported(result["data"]):
		_show_feedback("Este save está incompleto, corrompido ou não é compatível com esta versão.")
		return
	if bool(result.get("recovered_from_backup", false)):
		var recovered_id: String = save_manager.create_save(result["data"])
		if recovered_id.is_empty():
			_show_feedback("Não foi possível criar uma cópia segura do backup recuperado.")
			return
		world_id = recovered_id
		result["data"]["world_id"] = recovered_id
	if not main_config.start_world_from_save(result["data"]):
		_show_feedback("Este save não é compatível com esta versão do jogo.")
		return
	save_manager.set_active_world(world_id)
	visible = false

func _on_delete_selected_pressed() -> void:
	if save_items.get_selected_items().is_empty():
		return
	delete_confirmation.popup_centered()

func _on_delete_confirmed() -> void:
	var selected := save_items.get_selected_items()
	if selected.is_empty():
		return
	var world_id := _save_ids[selected[0]]
	var save_manager := _save_manager()
	if save_manager.delete_save(world_id):
		if save_manager.active_world_id == world_id:
			save_manager.set_active_world("")
		refresh_save_list()
	else:
		_show_feedback("Não foi possível excluir este mundo.")

func _show_feedback(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_quit_pressed() -> void:
	get_tree().quit()
