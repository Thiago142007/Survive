extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var has_f5_binding := false
	for event in InputMap.action_get_events("toggle_camera"):
		if event is InputEventKey and (event.physical_keycode == KEY_F5 or event.keycode == KEY_F5):
			has_f5_binding = true
	if not _expect(has_f5_binding, "F5 must be bound to toggle_camera"):
		return
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame
	player.set_gameplay_input_enabled(true)
	var toggle := InputEventAction.new()
	toggle.action = "toggle_camera"
	toggle.pressed = true
	player._unhandled_input(toggle)
	if not _expect(player._cam_mode == 1 and is_equal_approx(player.camera.position.z, 4.0), "First toggle must select the second-person camera distance"):
		return
	player._unhandled_input(toggle)
	if not _expect(player._cam_mode == 2 and is_equal_approx(player.camera.position.z, 6.0), "Second toggle must select the third-person camera distance"):
		return
	player._unhandled_input(toggle)
	if not _expect(player._cam_mode == 0 and is_zero_approx(player.camera.position.z), "Third toggle must cycle back to first person"):
		return
	player.queue_free()
	print("Camera toggle smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
