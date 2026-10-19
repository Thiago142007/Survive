extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud := (load("res://scenes/hud/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	var counter := hud.get_node_or_null("Root/FPSCounter") as Label
	assert(counter != null, "O HUD precisa conter o contador configuravel de FPS")
	hud.set_fps_counter_position("top_right")
	assert(counter.visible)
	hud.set_fps_counter_position("off")
	assert(not counter.visible)
	hud.free()
	print("HUD FPS counter: PASS")
	quit()
