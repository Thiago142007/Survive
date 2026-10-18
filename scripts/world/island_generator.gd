extends Node3D

## Gera um arquipelago deterministico e mantem apenas os chunks proximos do jogador.
## O layout e os recursos de cada ilha dependem exclusivamente da seed e do indice.

@export var seed: int = 55960
@export var island_count: int = 12
@export var ring_distance: float = 3600.0
@export var chunk_size: float = 700.0
@export var stream_radius_chunks: int = 1

const WATER_SIZE := 12000.0
const TERRAIN_STEP := 10.0
const WATER_LEVEL := -0.3
const WORLD_GENERATION_VERSION := 1
const IMPORTED_MODEL_VARIANT = preload("res://scripts/world/imported_model_variant.gd")
const RESOURCE_SCENE_PATHS := {
	"tree": "res://scenes/world/tree.tscn",
	"rock": "res://scenes/world/rock.tscn",
	"animal": "res://scenes/fauna/animal.tscn",
	"palm": "res://scenes/world/palm.tscn"
}
const DECORATION_MODEL_PATHS := {
	"shrub": "res://assets/models/shrubs/shrubs_clean.scn",
	"foliage": "res://assets/models/foliage/Foliage_01.dae",
	"flowers": "res://assets/models/flowers/Flowers.fbx",
	"fruit": "res://assets/models/fruits/fruits.fbx",
	"sticks": "res://assets/models/sticks/sticks.fbx"
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
var _sand_texture: NoiseTexture2D
var _persistent_state: Dictionary = {"resources": {}, "animals": {}}

func _ready() -> void:
	var main := get_node_or_null("/root/Main")
	if main:
		seed = int(main.get("world_seed"))
	_generate_water()
	_rebuild_layout()
	if _world_is_active():
		call_deferred("_refresh_streaming")

func _process(_delta: float) -> void:
	if _world_is_active():
		_refresh_streaming()

func apply_seed(new_seed: int) -> void:
	seed = new_seed
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.free()
	loaded_chunks.clear()
	_last_focus_chunk = Vector2i(999999, 999999)
	_rebuild_layout()
	if _world_is_active():
		_refresh_streaming()

func set_world_active(active: bool) -> void:
	if active:
		_last_focus_chunk = Vector2i(999999, 999999)
		_refresh_streaming()
		return
	for key in loaded_chunks.keys().duplicate():
		_unload_chunk(key)
	_last_focus_chunk = Vector2i(999999, 999999)

func _world_is_active() -> bool:
	var main := get_node_or_null("/root/Main")
	if main and bool(main.get("game_started")):
		return true
	var scene := get_tree().current_scene
	return scene == null or scene.get_node_or_null("MainMenu") == null

func _rebuild_layout() -> void:
	island_descriptors.clear()
	_layout_seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var safe_count := maxi(1, island_count)
	island_descriptors.append(_make_descriptor(0, "central", Vector3.ZERO, 480.0, rng))
	if safe_count == 1:
		_update_respawn_graph()
		return
	for index in range(1, safe_count):
		var angle := (TAU / float(safe_count - 1)) * float(index - 1)
		angle += rng.randf_range(-0.18, 0.18)
		var distance := rng.randf_range(ring_distance * 0.75, ring_distance * 1.25)
		var radius := rng.randf_range(280.0, 440.0)
		var center := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		island_descriptors.append(_make_descriptor(index, "island_%d" % index, center, radius, rng))
	_update_respawn_graph()

func _make_descriptor(index: int, island_id: String, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var biome: String = "temperate" if index == 0 else String(BIOMES[(index - 1) % BIOMES.size()])
	var island_rng := RandomNumberGenerator.new()
	island_rng.seed = _stable_seed(index, rng.randi())
	var danger: String = "safe" if index == 0 else String(["safe", "hostile", "disaster"][index % 3])
	var lakes: Array[Dictionary] = []
	var lake_count := 1 if index == 0 else island_rng.randi_range(0, 2)
	for lake_index in range(lake_count):
		var lake_angle := island_rng.randf_range(0.0, TAU)
		var lake_distance := radius * island_rng.randf_range(0.34, 0.52)
		lakes.append({
			"center": Vector2(cos(lake_angle), sin(lake_angle)) * lake_distance,
			"radius": radius * island_rng.randf_range(0.075, 0.12),
			"phase": island_rng.randf_range(0.0, TAU)
		})
	var highlands: Array[Dictionary] = []
	var highland_count := 2 if index == 0 else island_rng.randi_range(1, 3)
	for highland_index in range(highland_count):
		var highland_angle := island_rng.randf_range(0.0, TAU)
		var highland_distance := radius * island_rng.randf_range(0.28, 0.48)
		highlands.append({
			"center": Vector2(cos(highland_angle), sin(highland_angle)) * highland_distance,
			"width": radius * island_rng.randf_range(0.12, 0.19),
			"height": island_rng.randf_range(22.0, 36.0)
		})
	return {
		"id": island_id,
		"index": index,
		"center": center,
		"radius": radius,
		"coast_phases": Vector3(island_rng.randf_range(0.0, TAU), island_rng.randf_range(0.0, TAU), island_rng.randf_range(0.0, TAU)),
		"cove_angle": island_rng.randf_range(0.0, TAU),
		"lakes": lakes,
		"highlands": highlands,
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
	_spawn_migrated_animals(chunk_key, chunk)

func _spawn_migrated_animals(chunk_key: Vector2i, chunk: Node3D) -> void:
	var records: Dictionary = _persistent_state.get("animals", {})
	for persistent_id in records:
		var state: Variant = records[persistent_id]
		if not state is Dictionary or not bool(state.get("alive", true)):
			continue
		var saved_position: Variant = state.get("position", [])
		if not saved_position is Array or saved_position.size() < 3:
			continue
		var position := Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
		if _world_to_chunk(position) != chunk_key or _find_loaded_entity(String(persistent_id)) != null:
			continue
		var animal_scene := load(RESOURCE_SCENE_PATHS["animal"]) as PackedScene
		if not animal_scene:
			continue
		var animal := animal_scene.instantiate() as Animal
		animal.persistent_id = String(persistent_id)
		animal.species = String(state.get("species", "deer"))
		animal.behavior = int(state.get("behavior", Animal.Behavior.PEACEFUL)) as Animal.Behavior
		if animal.behavior == Animal.Behavior.PREDATOR:
			animal.drop_id = "hide"
			animal.drop_quantity = 1
			animal.attack_damage = 14.0
			animal.move_speed = 2.8
			animal.detection_radius = 16.0
		chunk.add_child(animal)
		animal.died.connect(_on_animal_died)
		animal.apply_save_state(state)

func _find_loaded_entity(persistent_id: String) -> Node:
	for chunk in loaded_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for node in chunk.find_children("*", "Node", true, false):
			if not node.has_method("get_save_state"):
				continue
			if String(node.call("get_save_state").get("persistent_id", "")) == persistent_id:
				return node
	return null

func _unload_chunk(chunk_key: Vector2i) -> void:
	var chunk = loaded_chunks.get(chunk_key)
	if is_instance_valid(chunk):
		_transfer_migrated_animals(chunk_key, chunk)
		_capture_chunk_persistent_state(chunk)
		chunk.free()
	loaded_chunks.erase(chunk_key)

func _transfer_migrated_animals(source_key: Vector2i, source_chunk: Node3D) -> void:
	for node in source_chunk.find_children("*", "Node", true, false):
		if not node.has_method("get_save_state") or not node is Animal:
			continue
		var destination_key := _world_to_chunk(node.global_position)
		if destination_key == source_key:
			continue
		var destination = loaded_chunks.get(destination_key)
		if is_instance_valid(destination):
			node.reparent(destination, true)

func capture_persistent_state() -> Dictionary:
	var resources: Dictionary = _persistent_state.get("resources", {}).duplicate(true)
	var animals: Dictionary = _persistent_state.get("animals", {}).duplicate(true)
	for chunk in loaded_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for node in chunk.find_children("*", "Node", true, false):
			if not node.has_method("get_save_state"):
				continue
			var state: Dictionary = node.call("get_save_state")
			var persistent_id := String(state.get("persistent_id", ""))
			if persistent_id.is_empty():
				continue
			if state.has("species"):
				animals[persistent_id] = state
			elif bool(state.get("depleted", false)):
				resources[persistent_id] = state
			else:
				resources.erase(persistent_id)
	_persistent_state = {"resources": resources, "animals": animals}
	return _persistent_state.duplicate(true)

func apply_persistent_state(state: Dictionary) -> void:
	var resources: Variant = state.get("resources", {})
	var animals: Variant = state.get("animals", {})
	_persistent_state = {
		"resources": resources.duplicate(true) if resources is Dictionary else {},
		"animals": animals.duplicate(true) if animals is Dictionary else {}
	}
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			_apply_persistent_state_to_chunk(chunk)

func _capture_chunk_persistent_state(chunk: Node) -> void:
	var resources: Dictionary = _persistent_state.get("resources", {}).duplicate(true)
	var animals: Dictionary = _persistent_state.get("animals", {}).duplicate(true)
	for node in chunk.find_children("*", "Node", true, false):
		if not node.has_method("get_save_state"):
			continue
		var state: Dictionary = node.call("get_save_state")
		var persistent_id := String(state.get("persistent_id", ""))
		if persistent_id.is_empty():
			continue
		if state.has("species"):
			animals[persistent_id] = state
		elif bool(state.get("depleted", false)):
			resources[persistent_id] = state
		else:
			resources.erase(persistent_id)
	_persistent_state = {"resources": resources, "animals": animals}

func _apply_persistent_state_to_chunk(chunk: Node) -> void:
	for node in chunk.find_children("*", "Node", true, false):
		if not node.has_method("get_save_state"):
			continue
		var current: Dictionary = node.call("get_save_state")
		var persistent_id := String(current.get("persistent_id", ""))
		var category := "animals" if current.has("species") else "resources"
		var records: Dictionary = _persistent_state.get(category, {})
		if records.has(persistent_id) and node.has_method("apply_save_state"):
			node.call("apply_save_state", records[persistent_id])

func _persistent_record(category: String, persistent_id: String) -> Dictionary:
	var records: Dictionary = _persistent_state.get(category, {})
	var record: Variant = records.get(persistent_id, {})
	return record if record is Dictionary else {}

func _persistent_id(descriptor: Dictionary, category: String, ordinal: int) -> String:
	return "g%d-s%d-i%d-%s-%03d" % [WORLD_GENERATION_VERSION, _layout_seed, int(descriptor["index"]), category, ordinal]

func _on_animal_died(animal: Node) -> void:
	if not is_instance_valid(animal) or not animal.has_method("get_save_state"):
		return
	var state: Dictionary = animal.call("get_save_state")
	var persistent_id := String(state.get("persistent_id", ""))
	if persistent_id.is_empty():
		return
	var animals: Dictionary = _persistent_state.get("animals", {}).duplicate(true)
	animals[persistent_id] = state
	_persistent_state["animals"] = animals

func _create_island(chunk: Node3D, descriptor: Dictionary) -> void:
	var island := StaticBody3D.new()
	island.name = String(descriptor["id"])
	island.position = descriptor["center"]
	for key in descriptor:
		if key != "center" and key != "chunk":
			island.set_meta(key, descriptor[key])
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := _make_terrain_mesh(descriptor)
	mesh_instance.mesh = mesh
	island.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = mesh.create_trimesh_shape()
	island.add_child(collision)
	chunk.add_child(island)
	_spawn_resources(chunk, descriptor)
	_spawn_tropical_details(chunk, descriptor)
	_spawn_fauna(chunk, descriptor)

func _coast_radius(descriptor: Dictionary, angle: float) -> float:
	var phases: Vector3 = descriptor["coast_phases"]
	var cove_delta := wrapf(angle - float(descriptor["cove_angle"]), -PI, PI)
	var cove := 0.28 * exp(-pow(cove_delta / 0.28, 2.0))
	var variation := 0.14 * sin(3.0 * angle + phases.x)
	variation += 0.09 * sin(5.0 * angle + phases.y)
	variation += 0.045 * sin(11.0 * angle + phases.z)
	return float(descriptor["radius"]) * (1.0 + variation - cove)

func _edge_distance(descriptor: Dictionary, point: Vector2) -> float:
	var coast := _coast_radius(descriptor, point.angle()) - point.length()
	for lake in descriptor["lakes"]:
		var offset: Vector2 = point - Vector2(lake["center"])
		var angle := offset.angle()
		var lake_radius := float(lake["radius"]) * (1.0 + 0.12 * sin(5.0 * angle + float(lake["phase"])))
		coast = minf(coast, offset.length() - lake_radius)
	return coast

func _terrain_height(descriptor: Dictionary, point: Vector2) -> float:
	var edge := _edge_distance(descriptor, point)
	if edge <= 0.0:
		return -2.8 * clampf(-edge / 18.0, 0.0, 1.0)
	var phases: Vector3 = descriptor["coast_phases"]
	var hills := maxf(0.0, sin(point.x * 0.012 + phases.x) * sin(point.y * 0.011 + phases.y) + 0.18)
	hills += 0.45 * maxf(0.0, sin(point.x * 0.028 + phases.z) * cos(point.y * 0.025 + phases.x))
	hills *= 4.5
	for highland in descriptor["highlands"]:
		var offset: Vector2 = point - Vector2(highland["center"])
		var width := float(highland["width"])
		hills += float(highland["height"]) * exp(-offset.length_squared() / (2.0 * width * width))
	var inland := smoothstep(0.0, 42.0, edge)
	var spawn_clearance := smoothstep(20.0, 65.0, point.length()) if int(descriptor["index"]) == 0 else 1.0
	return hills * inland * spawn_clearance

func _make_terrain_mesh(descriptor: Dictionary) -> ArrayMesh:
	var extent := float(descriptor["radius"]) * 1.32
	var cell_count := ceili(extent * 2.0 / TERRAIN_STEP)
	var grid_step := extent * 2.0 / float(cell_count)
	var row_size := cell_count + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var biome_color: Color = BIOME_COLORS.get(String(descriptor["biome"]), BIOME_COLORS["temperate"])
	var sand_color := Color("#d9c48d") if String(descriptor["biome"]) != "tundra" else Color("#c5cbc4")
	for z in range(row_size):
		for x in range(row_size):
			var point := Vector2(-extent + float(x) * grid_step, -extent + float(z) * grid_step)
			var height := _terrain_height(descriptor, point)
			vertices.append(Vector3(point.x, height, point.y))
			uvs.append(point * 0.015)
			var edge := _edge_distance(descriptor, point)
			var color := sand_color.lerp(biome_color, smoothstep(0.0, 30.0, edge))
			color = color.lerp(Color("#77766e"), smoothstep(13.0, 27.0, height) * 0.72)
			colors.append(color)
	for z in range(row_size):
		for x in range(row_size):
			var left: float = vertices[z * row_size + maxi(x - 1, 0)].y
			var right: float = vertices[z * row_size + mini(x + 1, cell_count)].y
			var back: float = vertices[maxi(z - 1, 0) * row_size + x].y
			var front: float = vertices[mini(z + 1, cell_count) * row_size + x].y
			normals.append(Vector3(left - right, 2.0 * grid_step, back - front).normalized())
	var indices := PackedInt32Array()
	for z in range(cell_count):
		for x in range(cell_count):
			var a := z * row_size + x
			var b := a + 1
			var c := a + row_size
			var d := c + 1
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_terrain_material())
	return mesh

func _spawn_resources(chunk: Node3D, descriptor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(int(descriptor["index"]), _layout_seed)
	var tree_scene: PackedScene = load(RESOURCE_SCENE_PATHS["tree"])
	var rock_scene: PackedScene = load(RESOURCE_SCENE_PATHS["rock"])
	for index in range(int(descriptor["tree_count"]) * 5):
		var tree := tree_scene.instantiate()
		var tree_id := _persistent_id(descriptor, "tree", index)
		tree.set("persistent_id", tree_id)
		tree.position = descriptor["center"] + _resource_position(rng, descriptor, 6.0)
		chunk.add_child(tree)
		_apply_saved_object_state(tree, "resources", tree_id)
	for index in range(int(descriptor["rock_count"]) * 3):
		var rock := rock_scene.instantiate()
		var rock_id := _persistent_id(descriptor, "rock", index)
		rock.set("persistent_id", rock_id)
		rock.position = descriptor["center"] + _resource_position(rng, descriptor, 4.0)
		chunk.add_child(rock)
		_apply_saved_object_state(rock, "resources", rock_id)

func _resource_position(rng: RandomNumberGenerator, descriptor: Dictionary, margin: float) -> Vector3:
	var placement_radius := float(descriptor["radius"]) * 0.94
	# Keep the starter island's vegetation and resources around the spawn so the
	# first-person view has readable environmental detail instead of an empty
	# foreground and props scattered beyond the visibility range.
	if int(descriptor["index"]) == 0:
		placement_radius = minf(placement_radius, 160.0)
	for attempt in range(64):
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * placement_radius
		var point := Vector2(cos(angle), sin(angle)) * distance
		if _edge_distance(descriptor, point) > margin:
			return Vector3(point.x, _terrain_height(descriptor, point), point.y)
	return Vector3.ZERO

func _spawn_fauna(chunk: Node3D, descriptor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(int(descriptor["index"]) + 1000, _layout_seed)
	var animal_scene: PackedScene = load(RESOURCE_SCENE_PATHS["animal"])
	for index in range(int(descriptor["peaceful_count"])):
		var animal_id := _persistent_id(descriptor, "peaceful", index)
		if _find_loaded_entity(animal_id) != null:
			continue
		var animal_state := _persistent_record("animals", animal_id)
		if not animal_state.is_empty() and not bool(animal_state.get("alive", true)):
			continue
		var animal: Animal = animal_scene.instantiate()
		animal.persistent_id = animal_id
		animal.species = "deer" if int(descriptor["index"]) % 2 == 0 else "boar"
		animal.behavior = Animal.Behavior.PEACEFUL
		animal.drop_id = "meat"
		animal.drop_quantity = 2
		animal.position = descriptor["center"] + _resource_position(rng, descriptor, 5.0)
		chunk.add_child(animal)
		animal.died.connect(_on_animal_died)
		_apply_saved_object_state(animal, "animals", animal_id)
	for index in range(int(descriptor["predator_count"])):
		var animal_id := _persistent_id(descriptor, "predator", index)
		if _find_loaded_entity(animal_id) != null:
			continue
		var animal_state := _persistent_record("animals", animal_id)
		if not animal_state.is_empty() and not bool(animal_state.get("alive", true)):
			continue
		var animal: Animal = animal_scene.instantiate()
		animal.persistent_id = animal_id
		animal.species = "wolf"
		animal.behavior = Animal.Behavior.PREDATOR
		animal.max_health = 65.0
		animal.attack_damage = 14.0
		animal.move_speed = 2.8
		animal.detection_radius = 16.0
		animal.drop_id = "hide"
		animal.drop_quantity = 1
		animal.position = descriptor["center"] + _resource_position(rng, descriptor, 5.0)
		chunk.add_child(animal)
		animal.died.connect(_on_animal_died)
		_apply_saved_object_state(animal, "animals", animal_id)

func _apply_saved_object_state(node: Node, category: String, persistent_id: String) -> void:
	var state := _persistent_record(category, persistent_id)
	if not state.is_empty() and node.has_method("apply_save_state"):
		node.call("apply_save_state", state)

func _spawn_tropical_details(chunk: Node3D, descriptor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(int(descriptor["index"]) + 5000, _layout_seed)
	var palm_scene: PackedScene = load(RESOURCE_SCENE_PATHS["palm"])
	var island_center: Vector3 = descriptor["center"]
	for index in range(12):
		var palm := palm_scene.instantiate() as Node3D
		palm.name = "Palm_%02d" % index
		palm.position = island_center + _resource_position(rng, descriptor, 8.0)
		palm.rotation.y = rng.randf_range(0.0, TAU)
		palm.scale = Vector3.ONE * rng.randf_range(0.82, 1.12)
		chunk.add_child(palm)
	for index in range(24):
		var shrub := _make_shrub(rng)
		shrub.name = "CoastalShrub_%02d" % index
		shrub.position = island_center + _resource_position(rng, descriptor, 4.0)
		shrub.rotation.y = rng.randf_range(0.0, TAU)
		chunk.add_child(shrub)
	_spawn_decoration_group(chunk, descriptor, rng, "foliage", 20, 0.75, "foliage", Color("#3f713b"))
	_spawn_decoration_group(chunk, descriptor, rng, "flowers", 8, 0.45, "flower", Color("#e8c96b"))
	_spawn_decoration_group(chunk, descriptor, rng, "sticks", 12, 0.28, "stick", Color("#715038"))
	_spawn_decoration_group(chunk, descriptor, rng, "fruit", 4, 0.42, "fruit", Color("#b64b36"))

func _make_shrub(rng: RandomNumberGenerator) -> Node3D:
	var shrub := Node3D.new()
	var fallback := Node3D.new()
	fallback.name = "FallbackVisual"
	shrub.add_child(fallback)
	var greens: Array[Color] = [Color("#315b32"), Color("#47733b"), Color("#6b8743")]
	for index in range(3):
		var leaf := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.35, 0.52)
		mesh.height = rng.randf_range(0.55, 0.8)
		mesh.radial_segments = 7
		mesh.rings = 3
		leaf.mesh = mesh
		leaf.position = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.25, 0.55), rng.randf_range(-0.35, 0.35))
		leaf.rotation.y = rng.randf_range(0.0, TAU)
		var material := StandardMaterial3D.new()
		material.albedo_color = greens[rng.randi_range(0, greens.size() - 1)]
		material.roughness = 1.0
		leaf.material_override = material
		fallback.add_child(leaf)
	var imported = IMPORTED_MODEL_VARIANT.new()
	imported.name = "AssetVisual"
	imported.fallback_path = NodePath("../FallbackVisual")
	imported.configure(DECORATION_MODEL_PATHS["shrub"], 1.25, rng.randi_range(0, 15))
	shrub.add_child(imported)
	return shrub

func _spawn_decoration_group(chunk: Node3D, descriptor: Dictionary, rng: RandomNumberGenerator, model_key: String, count: int, height: float, fallback_kind: String, fallback_color: Color) -> void:
	for index in range(count):
		var prop := _make_imported_prop(DECORATION_MODEL_PATHS[model_key], height, rng.randi(), fallback_kind, fallback_color)
		prop.name = "%s_%02d" % [model_key.capitalize(), index]
		prop.position = descriptor["center"] + _resource_position(rng, descriptor, 3.0)
		prop.rotation.y = rng.randf_range(0.0, TAU)
		chunk.add_child(prop)

func _make_imported_prop(path: String, height: float, index: int, fallback_kind: String, fallback_color: Color) -> Node3D:
	var prop := Node3D.new()
	var fallback := Node3D.new()
	fallback.name = "FallbackVisual"
	var fallback_mesh := MeshInstance3D.new()
	fallback_mesh.mesh = _make_fallback_mesh(fallback_kind)
	var fallback_material := StandardMaterial3D.new()
	fallback_material.albedo_color = fallback_color
	fallback_material.roughness = 1.0
	fallback_mesh.material_override = fallback_material
	fallback.add_child(fallback_mesh)
	prop.add_child(fallback)
	var imported = IMPORTED_MODEL_VARIANT.new()
	imported.name = "AssetVisual"
	imported.fallback_path = NodePath("../FallbackVisual")
	imported.configure(path, height, index)
	prop.add_child(imported)
	return prop

func _make_fallback_mesh(kind: String) -> PrimitiveMesh:
	if kind == "stick":
		var stick := CylinderMesh.new()
		stick.top_radius = 0.035
		stick.bottom_radius = 0.05
		stick.height = 0.65
		stick.radial_segments = 6
		return stick
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	match kind:
		"foliage":
			mesh.radius = 0.38
			mesh.height = 0.25
		"flower":
			mesh.radius = 0.14
			mesh.height = 0.38
		"fruit":
			mesh.radius = 0.2
			mesh.height = 0.32
	return mesh

func _generate_water() -> void:
	if is_instance_valid(_water):
		return
	_water = MeshInstance3D.new()
	_water.name = "Ocean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WATER_SIZE, WATER_SIZE)
	mesh.material = _make_water_material()
	_water.mesh = mesh
	_water.position.y = WATER_LEVEL
	add_child(_water)

func _make_terrain_material() -> StandardMaterial3D:
	if not _sand_texture:
		var sand_noise := FastNoiseLite.new()
		sand_noise.seed = 78421
		sand_noise.frequency = 0.055
		sand_noise.fractal_octaves = 3
		var sand_ramp := Gradient.new()
		sand_ramp.set_color(0, Color("#d7d7d7"))
		sand_ramp.set_color(1, Color.WHITE)
		_sand_texture = NoiseTexture2D.new()
		_sand_texture.noise = sand_noise
		_sand_texture.color_ramp = sand_ramp
		_sand_texture.width = 256
		_sand_texture.height = 256
		_sand_texture.seamless = true
	var material := StandardMaterial3D.new()
	material.albedo_texture = _sand_texture
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	return material

func _make_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#155273")
	material.roughness = 0.28
	material.metallic = 0.12
	material.metallic_specular = 0.7
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
