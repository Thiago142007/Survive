extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var card_scene := load("res://scenes/ui/world_save_card.tscn") as PackedScene
	if not _expect(card_scene != null, "World save card scene must be loadable"):
		return
	var card := card_scene.instantiate()
	root.add_child(card)
	await process_frame
	var image := Image.create(32, 18, false, Image.FORMAT_RGB8)
	image.fill(Color("#d88645"))
	var preview := ImageTexture.create_from_image(image)
	card.configure({
		"world_id": "c9011b20-7bcc-353c-7109-8d7d311a7e61",
		"name": "Ilha do Poente",
		"difficulty": "hard",
		"loadable": true
	}, preview)
	if not _expect(card.world_id == "c9011b20-7bcc-353c-7109-8d7d311a7e61", "Card must retain the stable world ID"):
		return
	if not _expect(card.name_label.text == "Ilha do Poente" and card.difficulty_label.text == "Difícil", "Card must render the world name and localized difficulty"):
		return
	if not _expect(card.preview.texture == preview, "Card must display the supplied gameplay thumbnail"):
		return
	if not _expect(card.play_button.focus_mode == Control.FOCUS_ALL and card.delete_button.focus_mode == Control.FOCUS_ALL, "Play and Delete must have independent keyboard focus"):
		return
	if not _expect(not card.play_button.get_global_rect().intersects(card.delete_button.get_global_rect()), "Play and Delete must use separate hitboxes"):
		return
	if not _expect(card.play_button.tooltip_text == "Jogar mundo" and card.delete_button.tooltip_text == "Excluir mundo", "Icon buttons must have accessible labels"):
		return
	var play_events: Array[String] = []
	var delete_events: Array[String] = []
	card.play_requested.connect(func(id: String) -> void: play_events.append(id))
	card.delete_requested.connect(func(id: String) -> void: delete_events.append(id))
	card.play_button.pressed.emit()
	card.delete_button.pressed.emit()
	if not _expect(play_events == [card.world_id] and delete_events == [card.world_id], "Card actions must emit their own stable world ID"):
		return
	card.configure({"world_id": card.world_id, "name": "Save indisponível", "loadable": false}, preview)
	if not _expect(card.play_button.disabled and not card.delete_button.disabled, "Non-loadable saves must disable Play without disabling Delete"):
		return
	card.queue_free()
	await process_frame
	print("World save card smoke test: PASS")
	quit()

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
