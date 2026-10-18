extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := root.get_node("Main")
	var world := Node3D.new()
	world.name = "FirstPersonActionTestWorld"
	root.add_child(world)
	current_scene = world
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	await process_frame
	var presentation := player.get_node("CharacterPresentation")
	if not _expect(presentation.has_method("play_action") and player.has_signal("presentation_action"), "Actions must be routed through the presentation event"):
		return
	var animation_player := _find_animation_player(presentation.get_arms_model())
	if not _expect(animation_player != null, "Arms rig must expose an AnimationPlayer"):
		return
	var interact_events := InputMap.action_get_events("interact")
	var c_is_bound := false
	for input_event in interact_events:
		if input_event is InputEventKey and input_event.physical_keycode == KEY_C:
			c_is_bound = true
	if not _expect(c_is_bound, "C must remain the interaction key"):
		return
	player.set_physics_process(false)
	main.game_started = true
	player.get_node("Inventory").add_item("knife", 1)
	player.active_tool = "knife"
	player._perform_attack()
	if not _expect(animation_player.current_animation == "kitchen_knife_stab", "Accepted knife attacks must play the matching clip (current=%s clips=%s)" % [animation_player.current_animation, str(animation_player.get_animation_list())]):
		return
	var previous_animation := animation_player.current_animation
	player._attack_cooldown = 0.2
	player._perform_attack()
	if not _expect(animation_player.current_animation == previous_animation, "Rejected cooldown attacks must not trigger an animation"):
		return
	player._attack_cooldown = 0.0
	player.is_blocking = true
	player._perform_attack()
	if not _expect(animation_player.current_animation == previous_animation, "Blocked attacks must not trigger an animation"):
		return
	player.is_blocking = false
	player.active_tool = "stone_axe"
	player._attack_cooldown = 0.0
	player._perform_attack()
	if not _expect(animation_player.current_animation == "unarmed_punch_r", "Unsupported tools must use the safe unarmed attack clip"):
		return
	var tree := (load("res://scenes/world/tree.tscn") as PackedScene).instantiate()
	var interaction: Node = player.get_node("Interaction")
	tree.position = Vector3(0.0, 0.0, -2.0)
	world.add_child(tree)
	await physics_frame
	var test_ray: RayCast3D = interaction.get_node("RayCast3D")
	test_ray.force_raycast_update()
	var inventory: Node = player.get_node("Inventory")
	var before_count: int = inventory.get_count("wood")
	if not _expect(interaction._try_interact(), "Available C interaction must accept the harvest (ray=%s target=%s tree=%s)" % [str(test_ray.is_colliding()), str(test_ray.get_collider()), str(tree.global_position)]):
		return
	if not _expect(animation_player.current_animation == "unarmed_pickup" and inventory.get_count("wood") > before_count, "Accepted harvest must animate and collect through existing inventory logic"):
		return
	var collected_count: int = inventory.get_count("wood")
	presentation.play_action(&"harvest", &"unknown_mod_item")
	if not _expect(animation_player.current_animation == "unarmed_pickup" and inventory.get_count("wood") == collected_count, "Missing item-specific clips must fall back without changing inventory"):
		return
	await physics_frame
	var after_harvest_animation := animation_player.current_animation
	interaction._try_interact()
	if not _expect(animation_player.current_animation == after_harvest_animation, "Depleted harvestable must not trigger another action"):
		return
	presentation.play_action(&"attack", &"knife")
	presentation.call("_on_animation_finished", &"kitchen_knife_stab")
	if not _expect(animation_player.current_animation == "kitchen_knife_idle", "Finished action clips must return to the idle pose for the held tool"):
		return
	main.game_started = false
	main.player = null
	world.free()
	print("First-person actions smoke test: PASS")
	quit()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
