extends SceneTree

func _init() -> void:
	var parser = load("res://scripts/world/world_seed.gd")
	assert(parser.parse("0") == 0)
	assert(parser.parse("-42") == -42)
	assert(parser.parse(" 12345 ") == 12345)
	assert(parser.parse("ilha tropical") == parser.parse("ilha tropical"))
	assert(parser.parse("ilha tropical") != parser.parse("ilha gelada"))
	assert(parser.derive(42, "terrain") != parser.derive(42, "vegetation"))
	var saves = root.get_node_or_null("SaveManager")
	if saves:
		assert(saves.handle_world_generator_version(1).get("status") == "supported")
		assert(saves.handle_world_generator_version(2).get("status") == "supported")
		assert(saves.handle_world_generator_version(3).get("status") == "incompatible")
	print("World seed parsing and independent streams: PASS")
	quit()
