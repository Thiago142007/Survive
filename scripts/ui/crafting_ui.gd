extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var recipe_list: VBoxContainer = $Panel/Margin/VBox/RecipeList
@onready var status_label: Label = $Panel/Margin/VBox/Status
var crafting_system: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_crafting") and Main.game_started:
		_toggle()

func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		crafting_system = Main.player.get_node_or_null("CraftingSystem")
		_refresh()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	if not crafting_system:
		return
	var recipes: Dictionary = crafting_system.get_recipes()
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		var button := Button.new()
		button.text = "%s   [%s]" % [recipe["name"], _format_cost(recipe["cost"])]
		button.custom_minimum_size = Vector2(0, 36)
		button.pressed.connect(_craft_recipe.bind(recipe_id))
		recipe_list.add_child(button)

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in cost:
		parts.append("%s %d" % [_display_name(resource_id), cost[resource_id]])
	return ", ".join(parts)

func _display_name(resource_id: String) -> String:
	return "madeira" if resource_id == "wood" else "pedra"

func _craft_recipe(recipe_id: String) -> void:
	if crafting_system and crafting_system.craft(recipe_id):
		status_label.text = "Item criado"
		_refresh()
	else:
		status_label.text = "Recursos insuficientes"
