extends Node3D

## Gera um arquipelago deterministico e mantem apenas os chunks proximos do jogador.
## O layout e os recursos de cada ilha dependem exclusivamente da seed e do indice.

@export var seed: int = 55960
@export var island_count: int = 12
@export var ring_distance: float = 180.0
@export var chunk_size: float = 180.0
@export var stream_radius_chunks: int = 1

const ISLAND_HEIGHT := 2.5
const WATER_SIZE := 1400.0
const RESOURCE_SCENE_PATHS := {
	"tree": "res://scenes/world/tree.tscn",
	"rock": "res://scenes/world/rock.tscn",
	"animal": "res://scenes/fauna/animal.tscn"
}
const BIOMES := ["temperate", "arid", "tundra", "swamp", "volcanic"]
const BIOME_COLORS := {
	"temperate": Color("#4c6248"),
	"arid": Color("#a88755"),
	"tundra": Color("#78909c"),
	"swamp": Color("#405b43"),
	"volcanic": Color("#684941")
}

var island_descriptors: Array[Dictionary] = []
var loaded_chunks: Dictionary = {}
var _last_focus_chunk := Vector2i(999999, 999999)
var _layout_seed: int = 0
var _water: MeshInstance3D

func _ready() -> void:
	var main := get_node_or_null("/root/Main")
	if main:
		seed = int(main.get("world_seed"))
	_generate_water()
	_rebuild_layout()
	call_deferred("_refresh_streaming")

func _process(_delta: float) -> void:
	_refresh_streaming()

func apply_seed(new_seed: int) -> void:
	seed = new_seed
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.free()
	loaded_chunks.clear()
	_last_focus_chunk = Vector2i(999999, 999999)
	_rebuild_layout()
	_refresh_streaming()

func _rebuild_layout() -> void:
	island_descriptors.clear()
	_layout_seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var safe_count := maxi(1, island_count)
	island_descriptors.append(_make_descriptor(0, "central", Vector3.ZERO, 48.0, rng))
	if safe_count == 1:
		_update_respawn_graph()
		return
	for index in range(1, safe_count):
		var angle := (TAU / float(safe_count - 1)) * float(index - 1)
		angle += rng.randf_range(-0.18, 0.18)
		var distance := rng.randf_range(ring_distance * 0.75, ring_distance * 1.25)
		var radius := rng.randf_range(28.0, 44.0)
		var center := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		island_descriptors.append(_make_descriptor(index, "island_%d" % index, center, radius, rng))
	_update_respawn_graph()

func _make_descriptor(index: int, island_id: String, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var biome: String = "temperate" if index == 0 else String(BIOMES[(index - 1) % BIOMES.size()])
	var island_rng := RandomNumberGenerator.new()
	island_rng.seed = _stable_seed(index, rng.randi())
	var danger: String = "safe" if index == 0 else String(["safe", "hostile", "disaster"][index % 3])
	return {
		"id": island_id,
		"index": index,
		"center": center,
		"radius": radius,
		"biome": biome,
		"climate": _climate_for_biome(biome),
		"danger": danger,
		"has_inhabitants": index > 0 and index % 4 == 0,
		"resource_multiplier": snappedf(island_rng.randf_range(0.75, 1.45), 0.01),
		"tree_count": island_rng.randi_range(3, 7) if index != 0 else 6,
		"rock_count": island_rng.randi_range(2, 5) if index != 0 else 4,
		"peaceful_count": island_rng.randi_range(1, 3) if index != 0 else 2,
		"predator_count": 0 if index == 0 else (2 if danger != "safe" else 1),
		"chunk": _world_to_chunk(center)
	}

func _update_respawn_graph() -> void:
	for descriptor in island_descriptors:
		descriptor["respawn_neighbors"] = []
	if island_descriptors.size() <= 1:
		return
	var outer_count := island_descriptors.size() - 1
	var central_links: Array[int] = [0, floori(float(outer_count) / 3.0), floori(float(outer_count * 2) / 3.0)]
	for index in range(outer_count):
		var current := island_descriptors[index + 1]
		var neighbors: Array = current["respawn_neighbors"]
		neighbors.append(island_descriptors[(index - 1 + outer_count) % outer_count + 1]["id"])
		neighbors.append(island_descriptors[(index + 1) % outer_count + 1]["id"])
		if index in central_links:
			neighbors.append("central")
		current["respawn_neighbors"] = neighbors
		if index in central_links:
			var central_neighbors: Array = island_descriptors[0]["respawn_neighbors"]
			central_neighbors.append(current["id"])
			island_descriptors[0]["respawn_neighbors"] = central_neighbors

func _refresh_streaming() -> void:
	var focus_chunk := _world_to_chunk(_get_focus_position())
	if focus_chunk == _last_focus_chunk:
		return
	_last_focus_chunk = focus_chunk
	var desired: Dictionary = {}
	for x in range(focus_chunk.x - stream_radius_chunks, focus_chunk.x + stream_radius_chunks + 1):
		for z in range(focus_chunk.y - stream_radius_chunks, focus_chunk.y + stream_radius_chunks + 1):
			desired[Vector2i(x, z)] = true
	for key in desired:
		if not loaded_chunks.has(key):
			_load_chunk(key)
	for key in loaded_chunks.keys().duplicate():
		if not desired.has(key):
			_unload_chunk(key)

func _load_chunk(chunk_key: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	chunk.set_meta("chunk_key", chunk_key)
	add_child(chunk)
	loaded_chunks[chunk_key] = chunk
	for descriptor in island_descriptors:
		if descriptor["chunk"] == chunk_key:
			_create_island(chunk, descriptor)

func _unload_chunk(chunk_key: Vector2i) -> void:
	var chunk = loaded_chunks.get(chunk_key)
	if is_instance_valid(chunk):
		chunk.free()
	loaded_chunks.erase(chunk_key)

func _create_island(chunk: Node3D, descriptor: Dictionary) -> void:
	var island := StaticBody3D.new()
	island.name = String(descriptor["id"])
	island.position = descriptor["center"] + Vector3(0.0, -ISLAND_HEIGHT * 0.5, 0.0)
	for key in descriptor:
		if key != "center" and key != "chunk":
			island.set_meta(key, descriptor[key])
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(descriptor["radius"]) * 0.92
	mesh.bottom_radius = float(descriptor["radius"])
	mesh.height = ISLAND_HEIGHT
	mesh.material = _make_biome_material(String(descriptor["biome"]))
	mesh_instance.mesh = mesh
	island.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(descriptor["radius"])
	shape.height = ISLAND_HEIGHT
	collision.shape = shape
	island.add_child(collision)
	chunk.add_child(island)
	_spawn_resources(chunk, descriptor)
	_spawn_fauna(chunk, descriptor)

func _spawn_resources(chunk: Node3D, descriptor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(int(descriptor["index"]), _layout_seed)
	var tree_scene: PackedScene = load(RESOURCE_SCENE_PATHS["tree"])
	var rock_scene: PackedScene = load(RESOURCE_SCENE_PATHS["rock"])
	for _index in range(int(descriptor["tree_count"])):
		var tree := tree_scene.instantiate()
		tree.position = descriptor["center"] + _resource_position(rng, float(descriptor["radius"]), 2.5)
		chunk.add_child(tree)
	for _index in range(int(descriptor["rock_count"])):
		var rock := rock_scene.instantiate()
		rock.position = descriptor["center"] + _resource_position(rng, float(descriptor["radius"]), 3.5)
		chunk.add_child(rock)

func _resource_position(rng: RandomNumberGenerator, radius: float, margin: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(2.0, maxf(2.0, radius - margin))
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

func _spawn_fauna(chunk: Node3D, descriptor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(int(descriptor["index"]) + 1000, _layout_seed)
	var animal_scene: PackedScene = load(RESOURCE_SCENE_PATHS["animal"])
	for index in range(int(descriptor["peaceful_count"])):
		var animal: Animal = animal_scene.instantiate()
		animal.species = "deer" if int(descriptor["index"]) % 2 == 0 else "boar"
		animal.behavior = Animal.Behavior.PEACEFUL
		animal.drop_id = "meat"
		animal.drop_quantity = 2
		animal.position = descriptor["center"] + _resource_position(rng, float(descriptor["radius"]), 5.0)
		chunk.add_child(animal)
	for index in range(int(descriptor["predator_count"])):
		var animal: Animal = animal_scene.instantiate()
		animal.species = "wolf"
		animal.behavior = Animal.Behavior.PREDATOR
		animal.max_health = 65.0
		animal.attack_damage = 14.0
		animal.move_speed = 2.8
		animal.detection_radius = 16.0
		animal.drop_id = "hide"
		animal.drop_quantity = 1
		animal.position = descriptor["center"] + _resource_position(rng, float(descriptor["radius"]), 5.0)
		chunk.add_child(animal)

func _generate_water() -> void:
	if is_instance_valid(_water):
		return
	_water = MeshInstance3D.new()
	_water.name = "Ocean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WATER_SIZE, WATER_SIZE)
	mesh.material = _make_water_material()
	_water.mesh = mesh
	_water.position.y = -0.3
	add_child(_water)

func _make_biome_material(biome: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BIOME_COLORS.get(biome, BIOME_COLORS["temperate"])
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _make_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#163c58")
	material.roughness = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _get_focus_position() -> Vector3:
	var main := get_node_or_null("/root/Main")
	var player = main.get("player") if main else null
	return player.global_position if player and is_instance_valid(player) else Vector3.ZERO

func _world_to_chunk(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / chunk_size), floori(position.z / chunk_size))

func _stable_seed(index: int, salt: int) -> int:
	return int((int(seed) * 1103515245 + index * 12345 + salt * 2654435761) & 0x7fffffff)

func _climate_for_biome(biome: String) -> String:
	match biome:
		"arid": return "hot_dry"
		"tundra": return "cold_windy"
		"swamp": return "humid"
		"volcanic": return "hot_dangerous"
		_: return "mild"

func get_world_layout_snapshot() -> Array[Dictionary]:
	return island_descriptors.duplicate(true)

func get_active_chunk_count() -> int:
	return loaded_chunks.size()

func get_loaded_island_ids() -> Array[String]:
	var ids: Array[String] = []
	for chunk in loaded_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for child in chunk.get_children():
			if child is StaticBody3D:
				ids.append(child.name)
	return ids
