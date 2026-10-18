extends SceneTree

func _init() -> void:
	var menu_scene := load("res://scenes/ui/main_menu.tscn")
	assert(menu_scene != null, "Main menu scene must load")
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	assert(menu.get_script() != null, "Main menu script must compile")
	assert(menu.get_script().can_instantiate(), "Main menu script must be instantiable without compile errors")

	assert(menu.get_node("Backdrop") is ColorRect, "Menu needs a backdrop")
	assert(menu.get_node("Brand/Title").text == "SURVIVE", "Menu brand must be visible")
	assert(menu.get_node("MainActions/NewWorldButton") is Button, "Menu needs a new world action")
	assert(menu.get_node("CreateWorldPanel").visible == false, "World creation panel starts hidden")

	print("Main menu smoke test: PASS")
	quit()
