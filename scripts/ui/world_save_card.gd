extends PanelContainer
class_name WorldSaveCard

signal play_requested(world_id: String)
signal delete_requested(world_id: String)

const DIFFICULTY_LABELS := {
	"easy": "Fácil",
	"normal": "Normal",
	"hard": "Difícil"
}

var world_id := ""
var preview: TextureRect
var name_label: Label
var difficulty_label: Label
var seed_label: Label
var play_button: Button
var delete_button: Button

func _ready() -> void:
	_build_ui()
	_update_contents()

func configure(save_data: Dictionary, thumbnail: Texture2D) -> void:
	world_id = String(save_data.get("world_id", ""))
	set_meta("save_data", save_data.duplicate(true))
	if is_node_ready():
		_update_contents(thumbnail)
	else:
		set_meta("thumbnail", thumbnail)

func _build_ui() -> void:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#241a17")
	card_style.border_color = Color("#765440")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", card_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	preview = TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(170, 96)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	var details := VBoxContainer.new()
	details.name = "WorldDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", 7)
	row.add_child(details)
	name_label = Label.new()
	name_label.name = "WorldName"
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color("#ead2bd"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	details.add_child(name_label)
	difficulty_label = Label.new()
	difficulty_label.name = "Difficulty"
	difficulty_label.add_theme_font_size_override("font_size", 14)
	difficulty_label.add_theme_color_override("font_color", Color("#c7a68f"))
	details.add_child(difficulty_label)
	seed_label = Label.new()
	seed_label.name = "WorldSeed"
	seed_label.add_theme_font_size_override("font_size", 12)
	seed_label.add_theme_color_override("font_color", Color("#a98e78"))
	seed_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	seed_label.clip_text = true
	details.add_child(seed_label)
	var actions := VBoxContainer.new()
	actions.name = "WorldActions"
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	play_button = _make_icon_button("PlayButton", "res://assets/ui/icon_play.svg", "Jogar mundo")
	play_button.pressed.connect(_on_play_pressed)
	actions.add_child(play_button)
	delete_button = _make_icon_button("DeleteButton", "res://assets/ui/icon_trash.svg", "Excluir mundo")
	delete_button.pressed.connect(_on_delete_pressed)
	actions.add_child(delete_button)

func _make_icon_button(button_name: String, icon_path: String, accessible_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(40, 40)
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = accessible_name
	button.icon = load(icon_path) as Texture2D
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _action_style(Color("#38271f"), Color("#765440")))
	button.add_theme_stylebox_override("hover", _action_style(Color("#593826"), Color("#d28b5d")))
	button.add_theme_stylebox_override("pressed", _action_style(Color("#75402b"), Color("#f0ad70")))
	button.add_theme_stylebox_override("focus", _action_style(Color("#4b3024"), Color("#f0ad70")))
	button.add_theme_color_override("icon_normal_color", Color("#d9b69c"))
	button.add_theme_color_override("icon_hover_color", Color("#fff0d9"))
	return button

func _action_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _update_contents(thumbnail: Texture2D = null) -> void:
	if not preview:
		return
	var data: Dictionary = get_meta("save_data", {})
	var configured_thumbnail: Texture2D = thumbnail
	if configured_thumbnail == null and has_meta("thumbnail"):
		configured_thumbnail = get_meta("thumbnail") as Texture2D
	preview.texture = configured_thumbnail
	name_label.text = String(data.get("name", "Meu mundo"))
	var difficulty := String(data.get("difficulty", ""))
	difficulty_label.text = String(DIFFICULTY_LABELS.get(difficulty, "Dificuldade indisponível"))
	seed_label.text = "Seed: %s" % String(data.get("seed_source", str(data.get("seed", 0))))
	seed_label.tooltip_text = seed_label.text
	play_button.disabled = not bool(data.get("loadable", false))
	delete_button.disabled = false

func _on_play_pressed() -> void:
	if not world_id.is_empty() and not play_button.disabled:
		play_requested.emit(world_id)

func _on_delete_pressed() -> void:
	if not world_id.is_empty():
		delete_requested.emit(world_id)
