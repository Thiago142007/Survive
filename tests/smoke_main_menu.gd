extends SceneTree

func _init() -> void:
	var menu_scene := load("res://scenes/ui/main_menu.tscn")
	assert(menu_scene != null, "Main menu scene must load")
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu.get_script() != null, "Main menu script must compile")
	assert(menu.get_script().can_instantiate(), "Main menu script must be instantiable without compile errors")

	assert(menu.get_node("Backdrop") is ColorRect, "Menu needs a backdrop")
	assert(menu.get_node("Brand/Title").text == "SURVIVE", "Menu brand must be visible")
	assert(menu.get_node("MainActions/NewWorldButton") is Button, "Menu needs a new world action")
	assert(menu.get_node("CreateWorldPanel").visible == false, "World creation panel starts hidden")
	assert(menu.has_method("get_secondary_panel_rect"), "Secondary panels need a responsive layout helper")
	for viewport_size in [Vector2(1600, 900), Vector2(1280, 800), Vector2(640, 480)]:
		for panel_kind in ["saves", "create", "settings"]:
			var rect: Rect2 = menu.get_secondary_panel_rect(panel_kind, viewport_size)
			assert(Rect2(Vector2.ZERO, viewport_size).encloses(rect), "%s panel must fit %s" % [panel_kind, str(viewport_size)])
			assert(rect.get_center().is_equal_approx(viewport_size * 0.5), "%s panel must be centered at %s" % [panel_kind, str(viewport_size)])
	menu._on_settings_pressed()
	var settings_rect: Rect2 = menu.get_secondary_panel_rect("settings", menu.get_viewport().get_visible_rect().size)
	assert(menu._settings_panel.get_rect().is_equal_approx(settings_rect), "Settings screen must use the centered responsive rectangle")
	menu._on_new_world_pressed()
	var create_rect: Rect2 = menu.get_secondary_panel_rect("create", menu.get_viewport().get_visible_rect().size)
	assert(menu.create_world_panel.get_rect().is_equal_approx(create_rect), "World creation screen must use the centered responsive rectangle")

	print("Main menu smoke test: PASS")
	quit()
