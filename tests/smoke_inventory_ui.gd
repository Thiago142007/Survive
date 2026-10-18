extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var inventory_scene: PackedScene = load("res://scenes/ui/inventory_ui.tscn")
	assert(inventory_scene != null, "A cena do inventario deve existir")

	var inventory: Node = load("res://scripts/inventory/inventory.gd").new()
	inventory.add_item("wood", 12)
	inventory.add_item("stone", 4)

	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	var main := root.get_node_or_null("Main")
	assert(main != null, "O autoload Main deve estar disponivel")
	var player := Node3D.new()
	player.add_child(inventory)
	var crafting_system: Node = load("res://scripts/crafting/crafting_system.gd").new()
	crafting_system.name = "CraftingSystem"
	player.add_child(crafting_system)
	var research_system: Node = load("res://scripts/progression/research_system.gd").new()
	research_system.name = "ResearchSystem"
	player.add_child(research_system)
	scene.add_child(player)
	main.player = player
	main.game_started = true

	var crafting_ui: CanvasLayer = load("res://scenes/ui/crafting_ui.tscn").instantiate()
	var research_ui: CanvasLayer = load("res://scenes/ui/research_ui.tscn").instantiate()
	var inventory_ui: CanvasLayer = inventory_scene.instantiate()
	scene.add_child(crafting_ui)
	scene.add_child(research_ui)
	scene.add_child(inventory_ui)
	var frame := inventory_ui.get_node_or_null("Overlay/Reference/Background")
	assert(frame is Control and not frame is TextureRect and frame.get_script() != null, "O painel deve ser desenhado por UI nativa")
	inventory_ui.bind_inventory(inventory)
	assert(not inventory_ui.is_open(), "O inventario deve iniciar fechado")

	crafting_ui._toggle()
	research_ui._unhandled_input(_pressed_key(KEY_Y))
	assert(crafting_ui.panel.visible and research_ui.panel.visible, "Os paineis auxiliares devem estar abertos no cenario de teste")
	inventory_ui.open()
	assert(inventory_ui.is_open(), "E deve abrir o inventario")
	assert(not crafting_ui.panel.visible and not research_ui.panel.visible, "Abrir o inventario deve fechar outros paineis")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Abrir deve liberar o mouse")
	assert(inventory_ui.get_visible_item_count() == 2, "A grade deve exibir os slots reais")
	assert(inventory_ui.get_slot_text(0).contains("12"), "A quantidade do item deve aparecer")
	inventory.add_item("berry", 3)
	await process_frame
	assert(inventory_ui.get_visible_item_count() == 3, "A grade deve atualizar enquanto estiver aberta")
	for index in range(21):
		inventory.add_item("test_item_%d" % index, 1)
	assert(inventory_ui.get_visible_item_count() == 24, "Nenhum stack real pode ficar oculto")
	assert(inventory_ui.get_page_count() == 2, "Itens excedentes devem aparecer em outra pagina")
	inventory_ui.get_node("Overlay/Reference/Pager/Next").pressed.emit()
	assert(inventory_ui.get_slot_text(3).contains("1"), "A segunda pagina deve mostrar o item excedente")

	crafting_ui._unhandled_input(_pressed_key(KEY_K))
	assert(not crafting_ui.panel.visible, "Crafting nao pode abrir sobre o inventario")
	research_ui._unhandled_input(_pressed_key(KEY_Y))
	assert(not research_ui.panel.visible, "Pesquisa nao pode abrir sobre o inventario")

	inventory_ui.handle_action("open_inventory")
	assert(not inventory_ui.is_open(), "E deve fechar o inventario aberto")

	inventory_ui.open()
	inventory_ui.handle_action("ui_cancel")
	assert(not inventory_ui.is_open(), "Esc deve fechar o inventario aberto")

	assert(_action_uses_key("open_inventory", KEY_E), "O inventario deve usar E")
	assert(_action_uses_key("interact", KEY_C), "Interagir deve usar C")
	assert(not _action_uses_key("interact", KEY_E), "E nao pode continuar conflitando com interagir")

	print("Inventory UI smoke test: PASS")
	main.player = null
	main.game_started = false
	scene.queue_free()
	quit()

func _action_uses_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event
