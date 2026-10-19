extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for world_seed in [12345, 67890, 424242]:
		var generator = GENERATOR.new()
		generator.seed = world_seed
		generator.call("_rebuild_layout")
		var layout: Array[Dictionary] = generator.get_world_layout_snapshot()
		var bay: Dictionary = layout[0]
		var headland: Dictionary = layout[1]
		assert(bay.has("landmark") and headland.has("landmark"), "As ilhas devem planejar marcos costeiros")
		assert(bay["landmark"]["type"] == "sheltered_bay")
		assert(headland["landmark"]["type"] == "rocky_headland")
		var bay_angle := float(bay["landmark"]["angle"])
		var bay_without := bay.duplicate(true)
		bay_without["landmark"] = {}
		var bay_baseline := float(generator.call("_coast_radius_raw", bay_without, bay_angle))
		var bay_radius := float(generator.call("_coast_radius_raw", bay, bay_angle))
		assert(bay_baseline - bay_radius > float(bay["radius"]) * 0.10, "A baia deve recuar a costa de forma perceptivel")
		var headland_angle := float(headland["landmark"]["angle"])
		var headland_without := headland.duplicate(true)
		headland_without["landmark"] = {}
		var headland_baseline := float(generator.call("_coast_radius_raw", headland_without, headland_angle))
		var headland_radius := float(generator.call("_coast_radius_raw", headland, headland_angle))
		assert(headland_radius > headland_baseline + float(headland["radius"]) * 0.02, "O promontorio deve avancar sobre o mar")
		var direction := Vector2(cos(headland_angle), sin(headland_angle))
		var cliff_point := direction * (headland_radius - 45.0)
		var cliff_height := float(generator.call("_terrain_height_from_edge", headland, cliff_point, 45.0))
		var baseline_height := float(generator.call("_terrain_height_from_edge", headland_without, cliff_point, 45.0))
		assert(cliff_height - baseline_height > 12.0, "O promontorio deve criar relevo costeiro visivel")
		var aspect := float(headland["aspect"])
		var mesh_extent := float(headland["radius"]) * maxf(aspect, 1.0 / aspect) * 1.42 + 45.0
		assert(headland_radius < mesh_extent - 10.0, "O promontorio deve caber na malha")
		generator.free()
	print("Procedural v2 coastal landmarks: PASS")
	quit()
