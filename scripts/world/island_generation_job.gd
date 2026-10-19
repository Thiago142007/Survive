extends RefCounted

## Samples CPU-only island data on an isolated generator outside the scene tree.
## Meshes, physics shapes, MultiMeshes and nodes are created by the caller.
var generator_script: GDScript
var world_seed: int
var descriptor: Dictionary

func run() -> Dictionary:
	var sampler = generator_script.new()
	sampler.seed = world_seed
	sampler.generation_version = 2
	sampler.call("_cache_coast", descriptor)
	var terrain_started := Time.get_ticks_msec()
	var terrain: Array = sampler.call("_build_terrain_arrays", descriptor)
	var terrain_ms := Time.get_ticks_msec() - terrain_started
	var collision_started := Time.get_ticks_msec()
	var vertices: PackedVector3Array = terrain[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = terrain[Mesh.ARRAY_INDEX]
	var collision_faces := PackedVector3Array()
	collision_faces.resize(indices.size())
	for index in range(indices.size()):
		collision_faces[index] = vertices[indices[index]]
	var collision_ms := Time.get_ticks_msec() - collision_started
	var detail_started := Time.get_ticks_msec()
	var details: Dictionary = sampler.call("_build_detail_transforms", descriptor)
	var detail_ms := Time.get_ticks_msec() - detail_started
	sampler.free()
	return {"terrain": terrain, "collision_faces": collision_faces, "details": details, "terrain_ms": terrain_ms, "collision_ms": collision_ms, "decoration_ms": detail_ms}
