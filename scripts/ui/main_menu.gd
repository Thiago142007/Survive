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
const WORLD_SAVE_CARD_SCENE: PackedScene = preload("res://scenes/ui/world_save_card.tscn")
const WORLD_THUMBNAIL_PLACEHOLDER: Texture2D = preload("res://assets/ui/world_thumbnail_placeholder.png")

@onready var main_actions: VBoxContainer = $MainActions
@onready var create_world_panel: Panel = $CreateWorldPanel
@onready var name_input: LineEdit = $CreateWorldPanel/Margin/FormScroll/VBox/NameInput
@onready var description_input: LineEdit = $CreateWorldPanel/Margin/FormScroll/VBox/DescriptionInput
@onready var seed_input: LineEdit = $CreateWorldPanel/Margin/FormScroll/VBox/SeedInput
@onready var difficulty_option: OptionButton = $CreateWorldPanel/Margin/FormScroll/VBox/DifficultyOption
@onready var error_label: Label = $CreateWorldPanel/Margin/FormScroll/VBox/ErrorLabel

var title_hotspots: Control
var save_list_panel: PanelContainer
var card_list: VBoxContainer
var world_scroll: ScrollContainer
var empty_saves_label: Label
var world_cards: Array[WorldSaveCard] = []
var new_world_button: Button
var delete_confirmation: ConfirmationDialog
var character_option: OptionButton
var _settings_volume: HSlider
var _settings_mode: OptionButton
var _settings_resolution: OptionButton
var _pending_delete_world_id := ""
var _pending_delete_world_name := ""
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
	get_viewport().size_changed.connect(_on_viewport_size_changed)
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

func _on_viewport_size_changed() -> void:
	_layout_title_hotspots()
	if is_instance_valid(save_list_panel):
		_layout_secondary_panel(save_list_panel)
	if is_instance_valid(create_world_panel):
		_layout_secondary_panel(create_world_panel)
	if is_instance_valid(_settings_panel):
		_layout_secondary_panel(_settings_panel)

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
	header.text = "ESCOLHA SEU MUNDO"
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color("#ead2bd"))
	column.add_child(header)
	var caption := Label.new()
	caption.text = "Continue de onde parou ou crie uma nova ilha."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color("#bfa89a"))
	column.add_child(caption)
	world_scroll = ScrollContainer.new()
	world_scroll.name = "WorldScroll"
	world_scroll.custom_minimum_size = Vector2(0, 180)
	world_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(world_scroll)
	card_list = VBoxContainer.new()
	card_list.name = "WorldCards"
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 10)
	world_scroll.add_child(card_list)
	empty_saves_label = Label.new()
	empty_saves_label.name = "EmptySavesPrompt"
	empty_saves_label.text = "Ainda não há mundos salvos. Crie sua primeira ilha."
	empty_saves_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_saves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_saves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_saves_label.add_theme_color_override("font_color", Color("#c7a68f"))
	empty_saves_label.visible = false
	column.add_child(empty_saves_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	new_world_button = _make_action_button("Novo mundo")
	new_world_button.name = "NewWorldButton"
	new_world_button.pressed.connect(_on_new_world_pressed)
	actions.add_child(new_world_button)
	var back := _make_action_button("Voltar")
	back.pressed.connect(_on_save_list_back_pressed)
	actions.add_child(back)
	save_list_panel.visible = false
	_layout_secondary_panel(save_list_panel)

func _create_delete_confirmation() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.name = "DeleteSaveConfirmation"
	delete_confirmation.title = "Excluir mundo?"
	delete_confirmation.dialog_text = "Esta ação remove o mundo selecionado."
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
	var vbox := $CreateWorldPanel/Margin/FormScroll/VBox as VBoxContainer
	vbox.add_child(character_option)
	vbox.move_child(character_option, vbox.get_node("ErrorLabel").get_index())

func _create_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_apply_panel_style(_settings_panel)
	add_child(_settings_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % edge, 24 if edge in ["left", "right"] else 8)
	_settings_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
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
	_settings_volume.custom_minimum_size = Vector2(0, 18)
	_settings_volume.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_volume)
	var mode_label := Label.new()
	mode_label.text = "Modo de janela"
	column.add_child(mode_label)
	_settings_mode = OptionButton.new()
	_settings_mode.add_item("Janela", 0)
	_settings_mode.add_item("Sem bordas", 1)
	_settings_mode.add_item("Tela cheia", 2)
	_settings_mode.custom_minimum_size = Vector2(0, 32)
	_settings_mode.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_mode)
	var resolution_label := Label.new()
	resolution_label.text = "Resolução"
	column.add_child(resolution_label)
	_settings_resolution = OptionButton.new()
	for resolution in _settings_manager().SUPPORTED_RESOLUTIONS:
		_settings_resolution.add_item(resolution)
	_settings_resolution.custom_minimum_size = Vector2(0, 32)
	_settings_resolution.focus_mode = Control.FOCUS_ALL
	column.add_child(_settings_resolution)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var save_button := _make_action_button("Aplicar e salvar")
	save_button.custom_minimum_size.y = 36
	save_button.pressed.connect(_on_settings_save_pressed)
	actions.add_child(save_button)
	var back_button := _make_action_button("Voltar")
	back_button.custom_minimum_size.y = 36
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

func _on_world_card_play_requested(world_id: String) -> void:
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

func _on_world_card_delete_requested(world_id: String) -> void:
	var card := get_world_card(world_id)
	if card == null:
		return
	_pending_delete_world_id = world_id
	_pending_delete_world_name = card.name_label.text
	delete_confirmation.dialog_text = "Excluir “%s”? Esta ação não pode ser desfeita." % _pending_delete_world_name
	delete_confirmation.popup_centered()

func get_world_card(world_id: String) -> WorldSaveCard:
	for card in world_cards:
		if card.world_id == world_id:
			return card
	return null

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

func get_secondary_panel_rect(panel_kind: String, viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var preferred_size := Vector2(960.0, 600.0)
	match panel_kind:
		"create", "world_creation":
			preferred_size = Vector2(520.0, 580.0)
		"settings":
			preferred_size = Vector2(520.0, 500.0)
		"saves", "save_selection", "singleplayer":
			preferred_size = Vector2(960.0, 600.0)
		_:
			return Rect2()
	var available_size := Vector2(maxf(0.0, viewport_size.x - 32.0), maxf(0.0, viewport_size.y - 32.0))
	var panel_size := Vector2(minf(preferred_size.x, available_size.x), minf(preferred_size.y, available_size.y))
	return Rect2((viewport_size - panel_size) * 0.5, panel_size)

func _layout_secondary_panel(panel: Control) -> void:
	var panel_kind := "settings"
	if panel == save_list_panel:
		panel_kind = "saves"
	elif panel == create_world_panel:
		panel_kind = "create"
	var rect := get_secondary_panel_rect(panel_kind, get_viewport().get_visible_rect().size)
	panel.position = rect.position
	panel.size = rect.size

func refresh_save_list() -> void:
	if not is_instance_valid(card_list):
		return
	for old_card in world_cards:
		card_list.remove_child(old_card)
		old_card.queue_free()
	world_cards.clear()
	var saves: Array = _save_manager().list_saves()
	for save in saves:
		var world_id := String(save.get("world_id", ""))
		var thumbnail := _save_manager().load_world_thumbnail(world_id) as Texture2D
		if thumbnail == null:
			thumbnail = WORLD_THUMBNAIL_PLACEHOLDER
		var card := WORLD_SAVE_CARD_SCENE.instantiate() as WorldSaveCard
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.configure(save, thumbnail)
		card.play_requested.connect(_on_world_card_play_requested)
		card.delete_requested.connect(_on_world_card_delete_requested)
		card_list.add_child(card)
		world_cards.append(card)
	world_scroll.visible = not saves.is_empty()
	empty_saves_label.visible = saves.is_empty()

func _on_singleplayer_pressed() -> void:
	refresh_save_list()
	$TitleHotspots.visible = false
	save_list_panel.visible = true
	_layout_secondary_panel(save_list_panel)
	if world_cards.is_empty():
		new_world_button.grab_focus()
	else:
		var first_card := world_cards[0]
		(first_card.delete_button if first_card.play_button.disabled else first_card.play_button).grab_focus()

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
	var source := seed_input.text.strip_edges()
	if source.is_empty():
		source = str(randi())
		seed_input.text = source
	var parsed_seed: int = load("res://scripts/world/world_seed.gd").parse(source)
	var difficulties := ["easy", "normal", "hard"]
	var selected: String = String(difficulties[clampi(difficulty_option.selected, 0, difficulties.size() - 1)])
	var character := "female" if character_option.selected == 1 else "male"
	var main_config = get_node_or_null("/root/Main")
	var config := {"name": name_input.text, "description": description_input.text, "seed": parsed_seed, "seed_source": source, "difficulty": selected, "character_id": character}
	if not main_config or not main_config.start_new_world(config):
		error_label.text = "Não foi possível iniciar este mundo."
		return
	if not _save_manager().save_active_world():
		main_config.game_started = false
		error_label.text = "Não foi possível criar o save. Verifique o armazenamento."
		main_config._set_game_ui(false)
		return
	visible = false

func _on_delete_confirmed() -> void:
	if _pending_delete_world_id.is_empty():
		return
	var world_id := _pending_delete_world_id
	var save_manager := _save_manager()
	if save_manager.delete_save(world_id):
		if save_manager.active_world_id == world_id:
			save_manager.set_active_world("")
		refresh_save_list()
	else:
		_show_feedback("Não foi possível excluir este mundo.")
	_pending_delete_world_id = ""
	_pending_delete_world_name = ""

func _show_feedback(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_quit_pressed() -> void:
	get_tree().quit()
