extends SceneTree

func _init() -> void:
	var animal_scene: PackedScene = load("res://scenes/fauna/animal.tscn")
	assert(animal_scene != null)
	var peaceful: Animal = animal_scene.instantiate()
	peaceful.behavior = Animal.Behavior.PEACEFUL
	peaceful.max_health = 40.0
	root.add_child(peaceful)
	await process_frame
	assert(peaceful.health == 40.0)
	peaceful.receive_hit(5.0, "legs")
	assert(peaceful.health == 35.0)
	assert(peaceful.immobilized_time > 0.0)
	peaceful.receive_hit(100.0, "head")
	assert(peaceful.state == Animal.State.DEAD)

	var predator: Animal = animal_scene.instantiate()
	predator.behavior = Animal.Behavior.PREDATOR
	predator.max_health = 65.0
	root.add_child(predator)
	await process_frame
	predator.receive_hit(10.0)
	assert(predator.health == 55.0)
	assert(predator.state != Animal.State.DEAD)
	predator.free()

	print("Fauna smoke test: PASS")
	quit()
