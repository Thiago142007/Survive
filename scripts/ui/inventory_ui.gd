extends CanvasLayer
class_name InventoryUI

const PAGE_SIZE := 20
const REFERENCE_SIZE := Vector2(736.0, 460.0)
const SLOT_ORIGIN := Vector2(399.0, 126.0)
const SLOT_STEP := 50.0
const SLOT_SIZE := Vector2(42.0, 43.0)

const ITEM_NAMES := {
	"wood": "Madeira",
	"stone": "Pedra",
	"berry": "Frutas silvestres",
	"fiber": "Fibra",
	"knife": "Faca",
	"stone_axe": "Machado de pedra",
	"stone_pickaxe": "Picareta de pedra",
	"shovel": "Pá",
	"spear": "Lança",
}
const ITEM_ICON_SCRIPT := preload("res://scripts/ui/inventory_item_icon.gd")
const EQUIPMENT_ICON_ATLAS := preload("res://assets/ui/inventory_equipment_atlas.png")
const CHARACTER_SILHOUETTE := preload("res://assets/ui/inventory_character_silhouette.png")
const EQUIPMENT_SILHOUETTE_SHADER := preload("res://assets/ui/inventory_silhouette.gdshader")

@onready var reference: Control = $Overlay/Reference
@onready var slots_layer: Control = $Overlay/Reference/Slots
@onready var equipment_icons_layer: Control = $Overlay/Reference/EquipmentIcons
@onready var item_info: Label = $Overlay/Reference/ItemInfo
@onready var pager: HBoxContainer = $Overlay/Reference/Pager
@onready var previous_button: Button = $Overlay/Reference/Pager/Previous
@onready var page_number: Label = $Overlay/Reference/Pager/PageNumber
@onready var next_button: Button = $Overlay/Reference/Pager/Next

var _inventory: Node = null
var _slot_buttons: Array[Button] = []
var _page := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_slots()
	_build_character_silhouette()
	_build_equipment_icons()
	previous_button.pressed.connect(previous_page)
	next_button.pressed.connect(next_page)
	get_viewport().size_changed.connect(_layout_reference)
	_layout_reference()
	if Main.player:
		bind_inventory(Main.player.get_node_or_null("Inventory"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory") and Main.game_started:
		handle_action(&"open_inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and is_open():
		handle_action(&"ui_cancel")
		get_viewport().set_input_as_handled()
	elif is_open() and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			next_page()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			previous_page()

func handle_action(action: StringName) -> void:
	if action == &"open_inventory":
		if is_open():
			close()
		else:
			open()
	elif action == &"ui_cancel" and is_open():
		close()

func bind_inventory(inventory: Node) -> void:
	if _inventory and _inventory.has_signal("changed") and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	if _inventory and _inventory.has_signal("changed") and not _inventory.changed.is_connected(_refresh):
		_inventory.changed.connect(_refresh)
	_refresh()

func open() -> void:
	if not _inventory and Main.player:
		bind_inventory(Main.player.get_node_or_null("Inventory"))
	_close_other_panels()
	_page = 0
	item_info.visible = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_gameplay_enabled(false)
	_refresh()

func close() -> void:
	visible = false
	item_info.visible = false
	_set_gameplay_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_open() -> bool:
	return visible

func get_visible_item_count() -> int:
	return _inventory.get_all().size() if _inventory else 0

func get_page_count() -> int:
	return maxi(1, ceili(float(get_visible_item_count()) / float(PAGE_SIZE)))

func get_slot_text(index: int) -> String:
	if index < 0 or index >= _slot_buttons.size():
		return ""
	return String(_slot_buttons[index].get_meta("quantity", ""))

func next_page() -> void:
	_page = mini(_page + 1, get_page_count() - 1)
	item_info.visible = false
	_refresh()

func previous_page() -> void:
	_page = maxi(_page - 1, 0)
	item_info.visible = false
	_refresh()

func _layout_reference() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	reference.scale = Vector2.ONE * factor
	reference.position = (viewport_size - REFERENCE_SIZE * factor) * 0.5

func _build_slots() -> void:
	var empty_style := StyleBoxEmpty.new()
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.56, 0.45, 0.39, 0.25)
	active_style.border_color = Color(0.72, 0.61, 0.53, 0.8)
	active_style.set_border_width_all(1)
	for index in PAGE_SIZE:
		var button := Button.new()
		button.position = SLOT_ORIGIN + Vector2(index % 4, index / 4) * SLOT_STEP
		button.size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", empty_style)
		button.add_theme_stylebox_override("disabled", empty_style)
		button.add_theme_stylebox_override("hover", active_style)
		button.add_theme_stylebox_override("pressed", active_style)
		button.add_theme_stylebox_override("focus", active_style)
		button.add_theme_color_override("font_color", Color(0.88, 0.8, 0.7, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.8, 1))
		button.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.8, 1))
		button.add_theme_font_size_override("font_size", 14)
		var icon := Control.new()
		icon.name = "Icon"
		icon.position = Vector2(7, 2)
		icon.size = Vector2(28, 26)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_script(ITEM_ICON_SCRIPT)
		button.add_child(icon)
		var quantity_label := Label.new()
		quantity_label.name = "Quantity"
		quantity_label.position = Vector2(2, 28)
		quantity_label.size = Vector2(38, 14)
		quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.add_theme_color_override("font_color", Color(0.89, 0.8, 0.7, 1))
		quantity_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		quantity_label.add_theme_font_size_override("font_size", 11)
		button.add_child(quantity_label)
		button.pressed.connect(_on_slot_pressed.bind(index))
		slots_layer.add_child(button)
		_slot_buttons.append(button)

func _build_equipment_icons() -> void:
	# Atlas cells are ordered left-to-right, top-to-bottom in the generated sheet.
	var icon_specs: Array[Dictionary] = [
		{"cell": Vector2i(0, 0), "position": Vector2(148, 128), "size": Vector2(38, 36), "name": "Capacete"},
		{"cell": Vector2i(1, 0), "position": Vector2(148, 178), "size": Vector2(38, 36), "name": "Amuleto"},
		{"cell": Vector2i(2, 0), "position": Vector2(148, 228), "size": Vector2(38, 36), "name": "Armadura"},
		{"cell": Vector2i(3, 0), "position": Vector2(148, 278), "size": Vector2(38, 36), "name": "Calças"},
		{"cell": Vector2i(0, 1), "position": Vector2(148, 328), "size": Vector2(38, 36), "name": "Espada"},
		{"cell": Vector2i(1, 1), "position": Vector2(332, 128), "size": Vector2(38, 36), "name": "Aljava"},
		{"cell": Vector2i(2, 1), "position": Vector2(332, 178), "size": Vector2(38, 36), "name": "Botas"},
		{"cell": Vector2i(3, 1), "position": Vector2(332, 228), "size": Vector2(38, 36), "name": "Cinto"},
		{"cell": Vector2i(0, 2), "position": Vector2(332, 278), "size": Vector2(38, 36), "name": "Anel"},
		{"cell": Vector2i(1, 2), "position": Vector2(332, 328), "size": Vector2(38, 36), "name": "Escudo"},
		{"cell": Vector2i(2, 2), "position": Vector2(611, 123), "size": Vector2(38, 39), "name": "Mochila"},
		{"cell": Vector2i(3, 2), "position": Vector2(611, 180), "size": Vector2(38, 39), "name": "Personagem"},
		{"cell": Vector2i(0, 3), "position": Vector2(611, 311), "size": Vector2(38, 39), "name": "Ferramentas"},
	]
	var cell_size := Vector2(313.5, 313.5)
	for spec in icon_specs:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = EQUIPMENT_ICON_ATLAS
		atlas_texture.region = Rect2(Vector2(spec["cell"]) * cell_size, cell_size)
		var icon := TextureRect.new()
		icon.name = String(spec["name"]).to_pascal_case()
		icon.position = spec["position"]
		icon.size = spec["size"]
		icon.texture = atlas_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var silhouette_material := ShaderMaterial.new()
		silhouette_material.shader = EQUIPMENT_SILHOUETTE_SHADER
		icon.material = silhouette_material
		icon.tooltip_text = String(spec["name"])
		equipment_icons_layer.add_child(icon)

func _build_character_silhouette() -> void:
	var character := TextureRect.new()
	character.name = "CharacterSilhouette"
	character.position = Vector2(164, 100)
	character.size = Vector2(192, 282)
	character.texture = CHARACTER_SILHOUETTE
	character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character.stretch_mode = TextureRect.STRETCH_SCALE
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_icons_layer.add_child(character)

func _refresh() -> void:
	if _slot_buttons.is_empty():
		return
	var items: Array[Dictionary] = []
	if _inventory:
		items = _inventory.get_all()
	_page = clampi(_page, 0, get_page_count() - 1)
	for index in PAGE_SIZE:
		var button := _slot_buttons[index]
		var item_index := _page * PAGE_SIZE + index
		if item_index < items.size():
			var slot: Dictionary = items[item_index]
			var item_id := String(slot.get("id", ""))
			var quantity := int(slot.get("qty", 0))
			var data: Resource = slot.get("data")
			var texture: Texture2D = data.icon if data and "icon" in data else null
			button.get_node("Icon").set_item(item_id, texture)
			button.get_node("Quantity").text = str(quantity)
			button.set_meta("quantity", str(quantity))
			button.tooltip_text = "%s — %d" % [_display_name(item_id, slot.get("data")), quantity]
			button.disabled = false
		else:
			button.get_node("Icon").set_item("")
			button.get_node("Quantity").text = ""
			button.set_meta("quantity", "")
			button.tooltip_text = "Espaço vazio"
			button.disabled = true
	pager.visible = get_page_count() > 1
	page_number.text = "%d/%d" % [_page + 1, get_page_count()]
	previous_button.disabled = _page == 0
	next_button.disabled = _page >= get_page_count() - 1

func _on_slot_pressed(index: int) -> void:
	if not _inventory:
		return
	var items: Array[Dictionary] = _inventory.get_all()
	var item_index := _page * PAGE_SIZE + index
	if item_index >= items.size():
		return
	var slot: Dictionary = items[item_index]
	var item_id := String(slot.get("id", ""))
	item_info.text = "%s   x%d" % [_display_name(item_id, slot.get("data")), int(slot.get("qty", 0))]
	item_info.visible = true

func _display_name(item_id: String, data: Resource = null) -> String:
	if data and "display_name" in data and not data.display_name.is_empty():
		return data.display_name
	return ITEM_NAMES.get(item_id, item_id.capitalize())

func _set_gameplay_enabled(enabled: bool) -> void:
	if Main.player and Main.player.has_method("set_gameplay_input_enabled"):
		Main.player.set_gameplay_input_enabled(enabled)
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null("HUD") if scene else null
	if hud and hud.has_method("set_inventory_open"):
		hud.set_inventory_open(not enabled)

func _close_other_panels() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	for panel_name in [&"CraftingUI", &"ResearchUI"]:
		var panel := scene.get_node_or_null(NodePath(panel_name))
		if panel and panel.has_method("close"):
			panel.close()
