extends SceneTree

const REQUIRED_IDS: Array[StringName] = [
	&"attack_swing",
	&"footstep_grass",
	&"wood_hit",
	&"stone_hit",
	&"animal_hit",
	&"animal_death",
	&"build_place",
	&"build_remove",
	&"build_repair",
	&"build_upgrade",
	&"player_hurt",
	&"player_down",
	&"collect",
	&"ui_click",
	&"ui_confirm",
	&"ui_error",
	&"ocean",
	&"wind",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var effects := root.get_node_or_null("Effects")
	if not _require(effects != null, "Effects autoload must exist"):
		return
	for effect_id in REQUIRED_IDS:
		if not _require(effects.has_effect(effect_id), "Missing effect ID: %s" % effect_id):
			return
	if not _require(not effects.play_world(&"missing", Vector3.ZERO), "Unknown IDs must fail safely"):
		return

	var requests: Array[Dictionary] = []
	effects.effect_requested.connect(func(effect_id: StringName, position: Vector3, spatial: bool) -> void:
		requests.append({"id": effect_id, "position": position, "spatial": spatial})
	)
	if not _require(effects.play_ui(&"ui_click"), "Known UI effect must play"):
		return
	if not _require(requests.size() == 1, "UI playback must emit one request"):
		return
	if not _require(requests[0]["id"] == &"ui_click" and not requests[0]["spatial"], "UI request must be non-spatial"):
		return

	for index in range(20):
		effects.play_world(&"wood_hit", Vector3(index, 0, 0))
	if not _require(effects.get_world_pool_size() == 12, "World audio pool must stop at 12 players"):
		return
	for child in effects.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	await create_timer(0.1, true, false, true).timeout
	print("Effects manager smoke test: PASS")
	quit()

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
