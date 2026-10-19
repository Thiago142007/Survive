extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")
const GENERATION_JOB = preload("res://scripts/world/island_generation_job.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = GENERATOR.new()
	generator.seed = 12345
	generator.call("_rebuild_layout")
	var job = GENERATION_JOB.new()
	job.generator_script = GENERATOR
	job.world_seed = generator.seed
	job.descriptor = generator.island_descriptors[0].duplicate(true)
	var result: Dictionary = job.run()
	assert(result.has("collision_faces"), "A thread deve preparar os triangulos da colisao")
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result["terrain"])
	var expected: PackedVector3Array = mesh.get_faces()
	var actual: PackedVector3Array = result["collision_faces"]
	var max_delta := 0.0
	for index in range(mini(actual.size(), expected.size())):
		max_delta = maxf(max_delta, actual[index].distance_to(expected[index]))
	assert(expected.size() > 0)
	assert(actual.size() == expected.size() and max_delta <= 0.001, "A colisao deve manter a geometria do terreno")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(actual)
	assert(shape.get_faces() == actual)
	generator.free()
	print("Procedural v2 background collision sampling: PASS")
	quit()
