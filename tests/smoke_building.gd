extends SceneTree

func _init() -> void:
	var paths := [
		"res://scenes/building/foundation.tscn",
		"res://scenes/building/pillar_foundation.tscn",
		"res://scenes/building/wall.tscn",
		"res://scenes/building/roof.tscn",
		"res://scenes/building/door.tscn"
	]
	for path in paths:
		var scene: PackedScene = load(path)
		assert(scene != null)
		var instance := scene.instantiate()
		root.add_child(instance)
		print("Loaded ", path)
		instance.free()

	var building_system := BuildingSystem.new()
	root.add_child(building_system)
	var foundation_scene: PackedScene = load(paths[0])
	var wall_scene: PackedScene = load(paths[2])
	var foundation: Node3D = foundation_scene.instantiate()
	foundation.position = Vector3.ZERO
	assert(building_system.can_place(foundation, foundation.position, foundation.rotation))
	building_system.place_piece(foundation)

	var supported_wall: Node3D = wall_scene.instantiate()
	supported_wall.position = Vector3(0, 2, 0)
	assert(building_system.can_place(supported_wall, supported_wall.position, supported_wall.rotation))
	building_system.place_piece(supported_wall)

	var floating_wall: Node3D = wall_scene.instantiate()
	floating_wall.position = Vector3(0, 6, 0)
	assert(not building_system.can_place(floating_wall, floating_wall.position, floating_wall.rotation))
	floating_wall.free()

	var health_before: float = supported_wall.current_health
	supported_wall.current_health = health_before * 0.5
	var repair_cost: Dictionary = supported_wall.get_repair_cost()
	assert(repair_cost.has("wood"))
	supported_wall.repair()
	assert(supported_wall.current_health > health_before * 0.5)
	supported_wall.upgrade()
	assert(supported_wall.improvement_level == 1)
	assert(supported_wall.health > health_before)

	print("Validated support, repair and upgrade behavior")
	supported_wall.free()
	foundation.free()
	building_system.free()
	quit()
