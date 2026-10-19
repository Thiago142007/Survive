extends SceneTree

const GENERATOR = preload("res://scripts/world/island_generator_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for world_seed in [12345, 67890, 424242]:
		var generator = GENERATOR.new()
		generator.seed = world_seed
		generator.call("_rebuild_layout")
		var descriptor: Dictionary = generator.island_descriptors[0]
		var cave: Dictionary = descriptor["caves"][0]
		var mouth: Vector2 = cave["mouth"]
		var direction: Vector2 = cave["direction"]
		var lateral := Vector2(-direction.y, direction.x)
		var arrays: Array = generator.call("_build_terrain_arrays", descriptor)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		print("Checking cave aperture seed ", world_seed)
		assert(_covered(vertices, indices, mouth - direction * 3.0), "O terreno deve cobrir a aproximacao externa da caverna")
		assert(not _covered(vertices, indices, mouth + direction * 5.0), "A entrada deve continuar aberta")
		assert(_covered(vertices, indices, mouth + direction * 12.0), "O terreno deve cobrir a area apos a abertura")
		assert(_covered(vertices, indices, mouth + direction * 3.0 + lateral * float(cave["width"]) * 1.2), "A abertura nao deve expor o oceano ao lado do tunel")
		generator.free()
	print("Procedural v2 cave aperture coverage: PASS")
	quit()

func _covered(vertices: PackedVector3Array, indices: PackedInt32Array, point: Vector2) -> bool:
	for triangle in range(0, indices.size(), 3):
		var va := vertices[indices[triangle]]
		var vb := vertices[indices[triangle + 1]]
		var vc := vertices[indices[triangle + 2]]
		var a := Vector2(va.x, va.z)
		var b := Vector2(vb.x, vb.z)
		var c := Vector2(vc.x, vc.z)
		var ab := (b - a).cross(point - a)
		var bc := (c - b).cross(point - b)
		var ca := (a - c).cross(point - c)
		if (ab >= -0.001 and bc >= -0.001 and ca >= -0.001) or (ab <= 0.001 and bc <= 0.001 and ca <= 0.001):
			return true
	return false
