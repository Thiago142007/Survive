extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var presentation := player.get_node_or_null("CharacterPresentation")
	if not _expect(presentation != null and presentation.has_method("configure_character") and presentation.has_method("set_camera_mode"), "Player must have a camera-aware character presentation controller"):
		return
	presentation.configure_character("male")
	if not _expect(presentation.get_character_id() == "male" and presentation.get_body_model() != null, "Male selection must load the male body"):
		return
	presentation.configure_character("female")
	if not _expect(presentation.get_character_id() == "female" and presentation.get_body_model().scene_file_path.ends_with("Superhero_Female_FullBody.gltf"), "Female selection must swap the body scene"):
		return
	presentation.set_camera_mode(0)
	if not _expect(presentation.get_body_model().visible == false and presentation.get_arms_model().visible, "First person must show arms and hide full body"):
		return
	presentation.set_held_item("stone_axe")
	var held_model: Node3D = presentation.get_held_item_model()
	if not _expect(presentation.get_held_item_id() == "stone_axe" and held_model != null and not held_model.find_children("*", "MeshInstance3D", true, false).is_empty(), "Equipped tools must have a visible first-person prop model"):
		return
	presentation.set_camera_mode(2)
	if not _expect(presentation.get_body_model().visible and not presentation.get_arms_model().visible, "Third person must show full body and hide camera arms"):
		return
	if not _expect(not held_model.visible, "Held item view models must stay hidden outside first person"):
		return
	presentation.set_held_item("unknown_mod_item")
	if not _expect(presentation.get_held_item_id().is_empty() and presentation.get_held_item_model() == null, "Unknown tools must not create a misleading held prop"):
		return
	presentation.configure_character("invalid_choice")
	if not _expect(presentation.get_character_id() == "male", "Invalid character IDs must safely fall back to male"):
		return
	player.apply_save_state({"character_id": "female"})
	if not _expect(player.character_id == "female" and presentation.get_character_id() == "female", "Restored world choice must update presentation"):
		return
	print("Character presentation smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
