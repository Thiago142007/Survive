extends "res://scripts/world/island_generator.gd"

## Version 1 stays intact for existing saves. Version 2 samples geography from
## independent seed streams, so streaming order cannot change the world.
const WORLD_SEED = preload("res://scripts/world/world_seed.gd")
const GENERATION_VERSION := 2
const FOREST_CANDIDATES := 820
const GROUND_CANDIDATES := 1250
const ROCK_CANDIDATES := 150
const CACHED_ISLAND_LIMIT := 2
const DECORATION_QUALITY_SCALE := {
	"low": {"ForestTrunks": 0.5, "ForestCanopies": 0.5, "GroundCover": 0.35, "StoneCover": 0.55},
	"medium": {"ForestTrunks": 0.8, "ForestCanopies": 0.8, "GroundCover": 0.65, "StoneCover": 0.8},
	"high": {"ForestTrunks": 1.0, "ForestCanopies": 1.0, "GroundCover": 1.0, "StoneCover": 1.0}
}

@export_range(1, 4, 1) var max_distant_chunks_per_frame: int = 1
var _decoration_quality := "high"
@export_enum("low", "medium", "high") var decoration_quality: String:
	get:
		return _decoration_quality
	set(value):
		if not DECORATION_QUALITY_SCALE.has(value):
			return
		_decoration_quality = value
		if is_inside_tree() and generation_version == GENERATION_VERSION:
			_apply_decoration_quality()

var _fields: Dictionary = {}
var _coast_cache: Dictionary = {}
var _generation_msec: int = 0
var _phase_msec: Dictionary = {"terrain": 0, "collision": 0, "resources": 0, "decoration": 0, "caves": 0}
var _island_cache: Dictionary = {}
var _cache_order: Array[String] = []
var _cache_hits: Dictionary = {"terrain": 0, "collision": 0, "details": 0}
var _pending_chunks: Array[Vector2i] = []
var _last_stream_focus := Vector3.INF

func _init() -> void:
	generation_version = GENERATION_VERSION

func apply_seed(new_seed: int) -> void:
	_pending_chunks.clear()
	_last_stream_focus = Vector3.INF
	_fields.clear()
	_coast_cache.clear()
	_generation_msec = 0
	_phase_msec = {"terrain": 0, "collision": 0, "resources": 0, "decoration": 0, "caves": 0}
	super.apply_seed(new_seed)

func _rebuild_layout() -> void:
	_pending_chunks.clear()
	_last_stream_focus = Vector3.INF
	_island_cache.clear()
	_cache_order.clear()
	_cache_hits = {"terrain": 0, "collision": 0, "details": 0}
	if generation_version == 1:
		super._rebuild_layout()
		return
	var started := Time.get_ticks_msec()
	island_descriptors.clear()
	_layout_seed = seed
	_fields.clear()
	_coast_cache.clear()
	var layout_rng := _stream("archipelago", 0)
	var layout_type := layout_rng.randi_range(0, 3)
	var target_count := maxi(5, island_count + layout_rng.randi_range(-4 if layout_type == 1 else -2, 1 if layout_type == 1 else 2))
	var central_radius := layout_rng.randf_range(440.0, 505.0)
	island_descriptors.append(_make_descriptor(0, "central", Vector3.ZERO, central_radius, layout_rng))
	var axis := layout_rng.randf_range(0.0, TAU)
	var twin_center := Vector2(cos(axis), sin(axis)) * layout_rng.randf_range(2300.0, 3300.0)
	for index in range(1, target_count):
		var radius := layout_rng.randf_range(175.0, 320.0) if layout_type == 1 else layout_rng.randf_range(220.0, 500.0)
		if layout_type == 2 and index == 1:
			radius = layout_rng.randf_range(480.0, 620.0)
		var center := Vector3.ZERO
		var valid := false
		for _attempt in range(100):
			var angle := layout_rng.randf_range(0.0, TAU)
			var distance := layout_rng.randf_range(1250.0, ring_distance * 1.3)
			match layout_type:
				1:
					distance = layout_rng.randf_range(1200.0, 2900.0)
				2:
					if index == 1:
						center = Vector3(twin_center.x, 0.0, twin_center.y)
					else:
						var anchor := twin_center if index % 2 == 0 else Vector2.ZERO
						var offset := Vector2(cos(angle), sin(angle)) * layout_rng.randf_range(1600.0, 3000.0)
						center = Vector3(anchor.x + offset.x, 0.0, anchor.y + offset.y)
				3:
					angle = axis + float(index - 1) / float(maxi(1, target_count - 2)) * PI * 1.65 + layout_rng.randf_range(-0.32, 0.32)
					distance = layout_rng.randf_range(1700.0, 3900.0)
				_:
					# The open type has irregular spacing rather than a fixed ring.
					distance *= 0.74 + 0.26 * sin(angle * 2.0 + float(seed & 255))
			if layout_type != 2:
				center = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			valid = center.length() + radius * 1.7 < WATER_SIZE * 0.5 - 100.0
			for existing in island_descriptors:
				var other: Vector3 = existing["center"]
				if center.distance_to(other) < (radius + float(existing["radius"])) * 1.8 + 170.0:
					valid = false
					break
			if valid:
				break
		if not valid:
			continue
		island_descriptors.append(_make_descriptor(index, "island_%d" % index, center, radius, layout_rng))
	for descriptor in island_descriptors:
		descriptor["archipelago_type"] = layout_type
	_update_respawn_graph()
	_generation_msec = Time.get_ticks_msec() - started

func _make_descriptor(index: int, island_id: String, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var descriptor: Dictionary = super._make_descriptor(index, island_id, center, radius, rng)
	if generation_version == 1:
		return descriptor
	var shape_rng := _stream("shape", index)
	var climate_rng := _stream("climate", index)
	var relief_rng := _stream("relief", index)
	var lake_rng := _stream("lakes", index)
	var mountain_rng := _stream("mountains", index)
	var wildlife_rng := _stream("wildlife", index)
	var lakes: Array[Dictionary] = []
	var lake_count := 1 if index == 0 else lake_rng.randi_range(0, 2)
	for _lake_index in range(lake_count):
		var lake_angle := lake_rng.randf_range(0.0, TAU)
		lakes.append({
			"center": Vector2(cos(lake_angle), sin(lake_angle)) * radius * lake_rng.randf_range(0.28, 0.46),
			"radius": radius * lake_rng.randf_range(0.055, 0.105),
			"phase": lake_rng.randf_range(0.0, TAU)
		})
	descriptor["lakes"] = lakes
	var highlands: Array[Dictionary] = []
	for _highland_index in range(mountain_rng.randi_range(2, 4)):
		var mountain_angle := mountain_rng.randf_range(0.0, TAU)
		highlands.append({
			"center": Vector2(cos(mountain_angle), sin(mountain_angle)) * radius * mountain_rng.randf_range(0.27, 0.52),
			"width": radius * mountain_rng.randf_range(0.12, 0.21),
			"height": mountain_rng.randf_range(21.0, 45.0)
		})
	descriptor["highlands"] = highlands
	var aspect := shape_rng.randf_range(0.72, 1.42) if index == 0 else shape_rng.randf_range(0.70, 1.32)
	if shape_rng.randf() < 0.18:
		aspect = shape_rng.randf_range(1.38, 1.65)
	descriptor["aspect"] = aspect
	descriptor["orientation"] = shape_rng.randf_range(0.0, TAU)
	descriptor["relief"] = relief_rng.randf_range(36.0, 95.0) if index != 0 else relief_rng.randf_range(45.0, 85.0)
	descriptor["ridge_angle"] = relief_rng.randf_range(0.0, TAU)
	descriptor["temperature"] = climate_rng.randf_range(0.2, 0.95)
	descriptor["moisture"] = climate_rng.randf_range(0.15, 0.95)
	descriptor["biome"] = _primary_biome(descriptor)
	descriptor["climate"] = _climate_for_biome(String(descriptor["biome"]))
	descriptor["forest_density"] = climate_rng.randf_range(0.72, 1.35)
	descriptor["danger"] = "safe" if index == 0 else String(["safe", "hostile", "disaster"][wildlife_rng.randi_range(0, 2)])
	descriptor["has_inhabitants"] = index > 0 and wildlife_rng.randf() < 0.23
	descriptor["peaceful_count"] = 2 if index == 0 else wildlife_rng.randi_range(1, 3)
	descriptor["predator_count"] = 0 if index == 0 else wildlife_rng.randi_range(0, 2)
	descriptor["tree_count"] = maxi(6, roundi(radius / 17.0 * float(descriptor["forest_density"])))
	descriptor["rock_count"] = maxi(5, roundi(radius / 35.0))
	_cache_coast(descriptor)
	descriptor["caves"] = _plan_caves(descriptor)
	return descriptor

func _primary_biome(descriptor: Dictionary) -> String:
	var temperature := float(descriptor["temperature"])
	var moisture := float(descriptor["moisture"])
	if temperature < 0.33:
		return "tundra"
	if temperature > 0.77 and moisture < 0.35:
		return "arid"
	if moisture > 0.77 and temperature > 0.50:
		return "swamp"
	return "temperate"

func _update_respawn_graph() -> void:
	if generation_version == 1:
		super._update_respawn_graph()
		return
	for descriptor in island_descriptors:
		var candidates: Array[Dictionary] = []
		for other in island_descriptors:
			if other["id"] == descriptor["id"]:
				continue
			var other_center: Vector3 = other["center"]
			var current_center: Vector3 = descriptor["center"]
			candidates.append({"id": other["id"], "distance": (other_center - current_center).length_squared()})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
		var neighbors: Array[String] = []
		for candidate in candidates.slice(0, mini(3, candidates.size())):
			neighbors.append(String(candidate["id"]))
		descriptor["respawn_neighbors"] = neighbors

func _stream(system: String, index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED.derive(seed, system, index)
	return rng

func _field(descriptor: Dictionary, name: String, frequency: float) -> FastNoiseLite:
	var island_id: String = descriptor["id"]
	var island_fields: Dictionary = _fields.get(island_id, {})
	if island_fields.has(name):
		return island_fields[name]
	var noise := FastNoiseLite.new()
	noise.seed = WORLD_SEED.derive(seed, name, int(descriptor["index"]))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	island_fields[name] = noise
	_fields[island_id] = island_fields
	return noise

func _coast_radius(descriptor: Dictionary, angle: float) -> float:
	if generation_version == 1:
		return super._coast_radius(descriptor, angle)
	var key := String(descriptor["id"])
	if _coast_cache.has(key):
		var samples: PackedFloat32Array = _coast_cache[key]
		var position := fposmod(angle, TAU) * float(samples.size()) / TAU
		var first := floori(position)
		return lerpf(samples[first], samples[(first + 1) % samples.size()], position - float(first))
	return _coast_radius_raw(descriptor, angle)

func _cache_coast(descriptor: Dictionary) -> void:
	var samples := PackedFloat32Array()
	samples.resize(1024)
	for index in range(samples.size()):
		samples[index] = _coast_radius_raw(descriptor, TAU * float(index) / float(samples.size()))
	_coast_cache[String(descriptor["id"])] = samples

func _coast_radius_raw(descriptor: Dictionary, angle: float) -> float:
	var rotated := angle - float(descriptor["orientation"])
	var aspect := float(descriptor["aspect"])
	var ellipse := 1.0 / sqrt(pow(cos(rotated) / aspect, 2.0) + pow(sin(rotated) * aspect, 2.0))
	var coast_noise := _field(descriptor, "coast", 0.006)
	var radius := float(descriptor["radius"])
	var shoreline := coast_noise.get_noise_2d(cos(angle) * radius, sin(angle) * radius)
	var bays := _field(descriptor, "bays", 0.014).get_noise_2d(cos(angle) * radius, sin(angle) * radius)
	return radius * ellipse * clampf(1.0 + 0.23 * shoreline + 0.085 * bays, 0.63, 1.38)

func _edge_distance(descriptor: Dictionary, point: Vector2) -> float:
	if generation_version == 1:
		return super._edge_distance(descriptor, point)
	var warp_x := _field(descriptor, "warp_x", 0.008).get_noise_2d(point.x, point.y)
	var warp_y := _field(descriptor, "warp_y", 0.008).get_noise_2d(point.x, point.y)
	var warped := point + Vector2(warp_x, warp_y) * 25.0
	var coast := _coast_radius(descriptor, warped.angle()) - warped.length()
	for lake in descriptor["lakes"]:
		var lake_center: Vector2 = lake["center"]
		var offset: Vector2 = point - lake_center
		var lake_radius := float(lake["radius"]) * (1.0 + 0.12 * sin(5.0 * offset.angle() + float(lake["phase"])))
		coast = minf(coast, offset.length() - lake_radius)
	return coast

func _terrain_height(descriptor: Dictionary, point: Vector2) -> float:
	if generation_version == 1:
		return super._terrain_height(descriptor, point)
	return _terrain_height_from_edge(descriptor, point, _edge_distance(descriptor, point))

func _terrain_height_from_edge(descriptor: Dictionary, point: Vector2, edge: float) -> float:
	if edge <= 0.0:
		return -minf(14.0, -edge * 0.09)
	var broad := _field(descriptor, "broad", 0.0035).get_noise_2d(point.x, point.y)
	var detail := _field(descriptor, "detail", 0.027).get_noise_2d(point.x, point.y)
	var angle := float(descriptor["ridge_angle"])
	var along := point.x * cos(angle) + point.y * sin(angle)
	var across := -point.x * sin(angle) + point.y * cos(angle)
	var ridge_noise := _field(descriptor, "ridge", 0.006).get_noise_2d(along * 0.68, across * 1.7)
	var ridge := pow(maxf(0.0, 1.0 - absf(ridge_noise)), 3.0)
	var ridge_mask := smoothstep(40.0, 115.0, edge)
	var valleys := maxf(0.0, -_field(descriptor, "valley", 0.006).get_noise_2d(point.x, point.y))
	var height := 4.0 + 10.0 * maxf(0.0, broad + 0.3) + 2.7 * detail
	height += float(descriptor["relief"]) * ridge * ridge_mask * 0.42
	for highland in descriptor["highlands"]:
		var highland_center: Vector2 = highland["center"]
		var offset: Vector2 = point - highland_center
		var width := float(highland["width"]) * 1.4
		var rotated := offset.rotated(-angle)
		var distance := pow(rotated.x / (width * 2.0), 2.0) + pow(rotated.y / width, 2.0)
		height += float(highland["height"]) * 1.5 * exp(-distance * 1.4)
	height -= valleys * float(descriptor["relief"]) * 0.20 * ridge_mask
	var beach_width := 26.0 + 16.0 * _field(descriptor, "beach", 0.008).get_noise_2d(point.x, point.y)
	var cliff_field := _field(descriptor, "cliff_coast", 0.005).get_noise_2d(point.x, point.y)
	beach_width = lerpf(beach_width, 7.0, smoothstep(0.35, 0.66, cliff_field))
	var inland := smoothstep(0.0, maxf(10.0, beach_width), edge)
	var spawn_clearance := smoothstep(26.0, 85.0, point.length()) if int(descriptor["index"]) == 0 else 1.0
	return maxf(0.5, height * inland * spawn_clearance + 1.2)

func _biome_at(descriptor: Dictionary, point: Vector2, height: float, edge: float, slope: float = -1.0) -> String:
	if slope < 0.0:
		slope = _slope(descriptor, point)
	if edge < 25.0:
		return "rocky_coast" if slope > 0.6 or height > 9.0 else "beach"
	if height > 72.0 or slope > 1.35:
		return "alpine"
	var temperature := float(descriptor["temperature"]) - height * 0.0035
	var moisture := float(descriptor["moisture"]) + _field(descriptor, "moisture", 0.004).get_noise_2d(point.x, point.y) * 0.32
	if temperature < 0.32:
		return "tundra"
	if temperature > 0.68 and moisture < 0.39:
		return "arid"
	if moisture > 0.75 and height < 14.0:
		return "swamp"
	if moisture < 0.38:
		return "grassland"
	return "forest"

func _slope(descriptor: Dictionary, point: Vector2) -> float:
	var step := 8.0
	var x := _terrain_height(descriptor, point + Vector2(step, 0.0)) - _terrain_height(descriptor, point - Vector2(step, 0.0))
	var z := _terrain_height(descriptor, point + Vector2(0.0, step)) - _terrain_height(descriptor, point - Vector2(0.0, step))
	return Vector2(x, z).length() / (2.0 * step)

func _plan_caves(descriptor: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng := _stream("caves", int(descriptor["index"]))
	var target := 1 if int(descriptor["index"]) == 0 else rng.randi_range(0, 2)
	for _cave_index in range(target):
		for _attempt in range(50):
			var angle := rng.randf_range(0.0, TAU)
			var distance := float(descriptor["radius"]) * rng.randf_range(0.32, 0.56)
			var mouth := Vector2(cos(angle), sin(angle)) * distance
			if _edge_distance(descriptor, mouth) < 45.0:
				continue
			var height := _terrain_height(descriptor, mouth)
			if height < 9.0 or _slope(descriptor, mouth) > 1.5:
				continue
			var far_enough := true
			for previous in result:
				var previous_mouth: Vector2 = previous["mouth"]
				if mouth.distance_to(previous_mouth) < 100.0:
					far_enough = false
			if not far_enough:
				continue
			result.append({
				"mouth": mouth,
				"direction": -mouth.normalized().rotated(rng.randf_range(-0.38, 0.38)),
				"length": rng.randf_range(48.0, 82.0),
				"width": rng.randf_range(5.0, 7.0),
				"depth": rng.randf_range(4.0, 7.0),
				"phase": rng.randf_range(0.0, TAU)
			})
			break
	if target > 0 and result.is_empty():
		var best := Vector2.ZERO
		var best_height := -INF
		for sample in range(32):
			var angle := TAU * float(sample) / 32.0
			var point := Vector2(cos(angle), sin(angle)) * float(descriptor["radius"]) * 0.42
			if _edge_distance(descriptor, point) < 35.0:
				continue
			var height := _terrain_height(descriptor, point)
			if height > best_height:
				best = point
				best_height = height
		if best_height > 5.0:
			result.append({"mouth": best, "direction": -best.normalized(), "length": 54.0, "width": 6.0, "depth": 5.0, "phase": 0.0})
	return result

func _inside_cave_opening(descriptor: Dictionary, point: Vector2, padding: float = 0.0) -> bool:
	for cave in descriptor["caves"]:
		var mouth: Vector2 = cave["mouth"]
		var direction: Vector2 = cave["direction"]
		var relative := point - mouth
		var along := relative.dot(direction)
		var across := absf(relative.cross(direction))
		if along >= -3.0 - padding and along <= 11.0 + padding and across < float(cave["width"]) * 0.83 + padding:
			return true
	return false

func _make_terrain_mesh(descriptor: Dictionary) -> ArrayMesh:
	if generation_version == 1:
		return super._make_terrain_mesh(descriptor)
	var cache_key := String(descriptor["id"])
	var cached: Dictionary = _island_cache.get(cache_key, {})
	if cached.has("terrain"):
		_cache_hits["terrain"] += 1
		_touch_cached_island(cache_key)
		return cached["terrain"]
	var started := Time.get_ticks_msec()
	var aspect := float(descriptor["aspect"])
	var extent := float(descriptor["radius"]) * maxf(aspect, 1.0 / aspect) * 1.42 + 45.0
	var cell_count := ceili(extent * 2.0 / 15.0)
	var step := extent * 2.0 / float(cell_count)
	var row_size := cell_count + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var edges := PackedFloat32Array()
	for z in range(row_size):
		for x in range(row_size):
			var point := Vector2(-extent + float(x) * step, -extent + float(z) * step)
			var edge := _edge_distance(descriptor, point)
			edges.append(edge)
			vertices.append(Vector3(point.x, _terrain_height_from_edge(descriptor, point, edge), point.y))
			uvs.append(point * 0.015)
	for z in range(row_size):
		for x in range(row_size):
			var index := z * row_size + x
			var left := vertices[z * row_size + maxi(x - 1, 0)].y
			var right := vertices[z * row_size + mini(x + 1, cell_count)].y
			var back := vertices[maxi(z - 1, 0) * row_size + x].y
			var front := vertices[mini(z + 1, cell_count) * row_size + x].y
			var slope := Vector2(left - right, back - front).length() / (2.0 * step)
			normals.append(Vector3(left - right, 2.0 * step, back - front).normalized())
			var vertex: Vector3 = vertices[index]
			var point := Vector2(vertex.x, vertex.z)
			var edge: float = edges[index]
			var biome := _biome_at(descriptor, point, vertex.y, edge, slope)
			colors.append(_ground_color(biome, edge, slope))
	var indices := PackedInt32Array()
	for z in range(cell_count):
		for x in range(cell_count):
			var a := z * row_size + x
			var b := a + 1
			var c := a + row_size
			var d := c + 1
			var center := Vector2((vertices[a].x + vertices[d].x) * 0.5, (vertices[a].z + vertices[d].z) * 0.5)
			if not _inside_cave_opening(descriptor, center, step * 0.75):
				indices.append(a)
				indices.append(b)
				indices.append(c)
				indices.append(b)
				indices.append(d)
				indices.append(c)
				continue
			# Only the cells around a cave need finer triangles. Their border vertices
			# interpolate the original cell, so adjacent coarse cells stay connected.
			var subdivisions := 4
			var patch_start := vertices.size()
			for patch_z in range(subdivisions + 1):
				var v := float(patch_z) / float(subdivisions)
				for patch_x in range(subdivisions + 1):
					var u := float(patch_x) / float(subdivisions)
					var x_pos := lerpf(vertices[a].x, vertices[b].x, u)
					var z_pos := lerpf(vertices[a].z, vertices[c].z, v)
					var height := lerpf(lerpf(vertices[a].y, vertices[b].y, u), lerpf(vertices[c].y, vertices[d].y, u), v)
					vertices.append(Vector3(x_pos, height, z_pos))
					uvs.append(Vector2(x_pos, z_pos) * 0.015)
					normals.append(normals[a].lerp(normals[b], u).lerp(normals[c].lerp(normals[d], u), v).normalized())
					colors.append(colors[a].lerp(colors[b], u).lerp(colors[c].lerp(colors[d], u), v))
			for patch_z in range(subdivisions):
				for patch_x in range(subdivisions):
					var local_a := patch_start + patch_z * (subdivisions + 1) + patch_x
					var local_b := local_a + 1
					var local_c := local_a + subdivisions + 1
					var local_d := local_c + 1
					var local_center := Vector2((vertices[local_a].x + vertices[local_d].x) * 0.5, (vertices[local_a].z + vertices[local_d].z) * 0.5)
					if _inside_cave_opening(descriptor, local_center, step / float(subdivisions) * 0.72):
						continue
					indices.append(local_a)
					indices.append(local_b)
					indices.append(local_c)
					indices.append(local_b)
					indices.append(local_d)
					indices.append(local_c)
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
	_remember_island_resource(cache_key, "terrain", mesh)
	_phase_msec["terrain"] += Time.get_ticks_msec() - started
	return mesh

func _make_terrain_collision_shape(mesh: Mesh, descriptor: Dictionary) -> Shape3D:
	if generation_version == 1:
		return super._make_terrain_collision_shape(mesh, descriptor)
	var cache_key := String(descriptor["id"])
	var cached: Dictionary = _island_cache.get(cache_key, {})
	if cached.has("collision"):
		_cache_hits["collision"] += 1
		_touch_cached_island(cache_key)
		return cached["collision"]
	var started := Time.get_ticks_msec()
	var shape: Shape3D = mesh.create_trimesh_shape()
	_remember_island_resource(cache_key, "collision", shape)
	_phase_msec["collision"] += Time.get_ticks_msec() - started
	return shape

func _touch_cached_island(cache_key: String) -> void:
	_cache_order.erase(cache_key)
	_cache_order.append(cache_key)

func _remember_island_resource(cache_key: String, resource_name: String, value: Variant) -> void:
	var entry: Dictionary = _island_cache.get(cache_key, {})
	entry[resource_name] = value
	_island_cache[cache_key] = entry
	_touch_cached_island(cache_key)
	while _cache_order.size() > CACHED_ISLAND_LIMIT:
		_island_cache.erase(_cache_order.pop_front())

func _ground_color(biome: String, edge: float, slope: float) -> Color:
	var color: Color
	match biome:
		"beach": color = Color("#d6c38d")
		"rocky_coast", "alpine": color = Color("#797c79")
		"tundra": color = Color("#98a7a6")
		"arid": color = Color("#a99467")
		"swamp": color = Color("#455e48")
		"grassland": color = Color("#70804d")
		_: color = Color("#49654a")
	if biome != "beach" and edge < 43.0:
		color = Color("#d6c38d").lerp(color, smoothstep(12.0, 43.0, edge))
	return color.lerp(Color("#777a78"), clampf((slope - 0.45) * 0.35, 0.0, 0.55))

func _create_island(chunk: Node3D, descriptor: Dictionary) -> void:
	if generation_version == 1:
		super._create_island(chunk, descriptor)
		return
	var started := Time.get_ticks_msec()
	super._create_island(chunk, descriptor)
	var island: StaticBody3D = chunk.get_node(String(descriptor["id"]))
	for cave_index in range(descriptor["caves"].size()):
		_add_cave(island, descriptor, descriptor["caves"][cave_index], cave_index)
	_generation_msec += Time.get_ticks_msec() - started

func _add_cave(island: StaticBody3D, descriptor: Dictionary, cave: Dictionary, cave_index: int) -> void:
	var started := Time.get_ticks_msec()
	var mouth: Vector2 = cave["mouth"]
	var direction: Vector2 = cave["direction"]
	var lateral := Vector2(-direction.y, direction.x)
	var width := float(cave["width"])
	var length := float(cave["length"])
	var phase := float(cave["phase"])
	var cross_section_count := 8
	var segment_count := 16
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for segment in range(segment_count + 1):
		var t := float(segment) / float(segment_count)
		var point := mouth + direction * length * t + lateral * sin(t * TAU + phase) * 2.5 * t
		var ground := _terrain_height(descriptor, point)
		var floor := _terrain_height(descriptor, mouth) - 0.5 - float(cave["depth"]) * t
		var chamber := exp(-pow((t - 0.72) / 0.16, 2.0))
		var ceiling := minf(ground - 1.0, floor + 9.0 + chamber * 3.8 + sin(t * 12.0 + phase) * 1.3)
		if segment == 0:
			ceiling = ground + 4.0
		ceiling = maxf(ceiling, floor + 4.6)
		var local_width := width * (1.0 + chamber * 1.2 + 0.17 * sin(t * 14.0 + phase))
		for side in range(cross_section_count):
			var across: float
			var y: float
			match side:
				0: across = -local_width; y = floor
				1: across = local_width; y = floor
				2: across = local_width; y = floor + (ceiling - floor) * 0.57
				3: across = local_width * 0.72; y = floor + (ceiling - floor) * 0.88
				4: across = 0.0; y = ceiling
				5: across = -local_width * 0.72; y = floor + (ceiling - floor) * 0.88
				6: across = -local_width; y = floor + (ceiling - floor) * 0.57
				_: across = -local_width; y = floor
			var position := point + lateral * across
			vertices.append(Vector3(position.x, y, position.y))
	for segment in range(segment_count):
		for side in range(cross_section_count - 1):
			var a := segment * cross_section_count + side
			var b := a + 1
			var c := a + cross_section_count
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var final_ring := segment_count * cross_section_count
	for side in range(1, cross_section_count - 2):
		indices.append_array(PackedInt32Array([final_ring, final_ring + side, final_ring + side + 1]))
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#595e5b")
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.name = "Cave_%d" % cave_index
	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	island.add_child(body)
	var formations: Array[Transform3D] = []
	var detail_rng := _stream("cave_formations", int(descriptor["index"]) * 4 + cave_index)
	for detail in range(10):
		var t := detail_rng.randf_range(0.25, 0.92)
		var point := mouth + direction * length * t + lateral * sin(t * TAU + phase) * 2.5 * t
		var center_floor := _terrain_height(descriptor, mouth) - 0.5 - float(cave["depth"]) * t
		var spread := width * (1.0 + 1.2 * exp(-pow((t - 0.72) / 0.16, 2.0)))
		var offset := spread * detail_rng.randf_range(0.54, 0.83) * (1.0 if detail % 2 == 0 else -1.0)
		var scale := detail_rng.randf_range(0.8, 2.4)
		var location := point + lateral * offset
		formations.append(Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale * 1.8, scale)), Vector3(location.x, center_floor + scale * 0.72, location.y)))
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.52
	spike.height = 1.0
	spike.radial_segments = 6
	_add_instances(body, "CaveFormations", spike, Color("#777d78"), formations)
	_phase_msec["caves"] += Time.get_ticks_msec() - started

func _persistent_id(descriptor: Dictionary, category: String, ordinal: int) -> String:
	if generation_version == 1:
		return super._persistent_id(descriptor, category, ordinal)
	return "g2-s%d-i%d-%s-%03d" % [seed, int(descriptor["index"]), category, ordinal]

func _pick_surface(rng: RandomNumberGenerator, descriptor: Dictionary, margin: float, near_spawn: bool = false) -> Vector3:
	var radius := float(descriptor["radius"]) * (0.38 if near_spawn else 1.25)
	for _attempt in range(90):
		var point := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if near_spawn and point.length() < 24.0:
			continue
		var edge := _edge_distance(descriptor, point)
		if edge < margin or _inside_cave_opening(descriptor, point):
			continue
		var height := _terrain_height_from_edge(descriptor, point, edge)
		if height <= 0.0:
			continue
		var east := _terrain_height(descriptor, point + Vector2(8.0, 0.0))
		var north := _terrain_height(descriptor, point + Vector2(0.0, 8.0))
		if Vector2(east - height, north - height).length() / 8.0 > 0.94:
			continue
		return Vector3(point.x, height, point.y)
	return Vector3.INF

func _resource_position(rng: RandomNumberGenerator, descriptor: Dictionary, margin: float) -> Vector3:
	if generation_version == 1:
		return super._resource_position(rng, descriptor, margin)
	var point := _pick_surface(rng, descriptor, margin, int(descriptor["index"]) == 0)
	return point if point != Vector3.INF else Vector3(0.0, _terrain_height(descriptor, Vector2.ZERO), 0.0)

func _spawn_resources(chunk: Node3D, descriptor: Dictionary) -> void:
	if generation_version == 1:
		super._spawn_resources(chunk, descriptor)
		return
	var started := Time.get_ticks_msec()
	var tree_scene: PackedScene = load(RESOURCE_SCENE_PATHS["tree"])
	var rock_scene: PackedScene = load(RESOURCE_SCENE_PATHS["rock"])
	var center: Vector3 = descriptor["center"]
	var index_id := int(descriptor["index"])
	var tree_rng := _stream("collectible_trees", index_id)
	var rock_rng := _stream("collectible_rocks", index_id)
	for index in range(int(descriptor["tree_count"])):
		var point := _pick_surface(tree_rng, descriptor, 12.0, index_id == 0 and index < 8)
		if point == Vector3.INF:
			continue
		var biome := _biome_at(descriptor, Vector2(point.x, point.z), point.y, _edge_distance(descriptor, Vector2(point.x, point.z)))
		if index_id != 0 and biome in ["alpine", "rocky_coast", "beach"]:
			continue
		if index_id != 0 and index >= 4:
			var ecology_chance := 0.28 if biome in ["arid", "tundra"] else (0.55 if biome == "grassland" else 1.0)
			if tree_rng.randf() > ecology_chance:
				continue
		var tree := tree_scene.instantiate() as Node3D
		var tree_id := _persistent_id(descriptor, "tree", index)
		tree.set("persistent_id", tree_id)
		tree.position = center + point
		tree.rotation.y = tree_rng.randf_range(0.0, TAU)
		tree.scale = Vector3.ONE * tree_rng.randf_range(0.80, 1.35)
		chunk.add_child(tree)
		_apply_saved_object_state(tree, "resources", tree_id)
	for index in range(int(descriptor["rock_count"])):
		var point := _pick_surface(rock_rng, descriptor, 5.0, index_id == 0 and index < 5)
		if point == Vector3.INF:
			continue
		var rock := rock_scene.instantiate() as Node3D
		var rock_id := _persistent_id(descriptor, "rock", index)
		rock.set("persistent_id", rock_id)
		rock.position = center + point
		rock.rotation.y = rock_rng.randf_range(0.0, TAU)
		rock.scale = Vector3.ONE * rock_rng.randf_range(0.75, 1.45)
		chunk.add_child(rock)
		_apply_saved_object_state(rock, "resources", rock_id)
	_phase_msec["resources"] += Time.get_ticks_msec() - started

func _spawn_tropical_details(chunk: Node3D, descriptor: Dictionary) -> void:
	if generation_version == 1:
		super._spawn_tropical_details(chunk, descriptor)
		return
	var cache_key := String(descriptor["id"])
	var cached: Dictionary = _island_cache.get(cache_key, {})
	if cached.has("details"):
		var details: Dictionary = cached["details"]
		for label in details:
			var visual := MultiMeshInstance3D.new()
			visual.name = label
			visual.multimesh = details[label]["multimesh"]
			visual.material_override = details[label]["material"]
			chunk.add_child(visual)
			_set_visual_quality(visual)
		_cache_hits["details"] += 1
		_touch_cached_island(cache_key)
		return
	var started := Time.get_ticks_msec()
	var forest_rng := _stream("forest_instances", int(descriptor["index"]))
	var ground_rng := _stream("ground_instances", int(descriptor["index"]))
	var rock_rng := _stream("rock_instances", int(descriptor["index"]))
	var trunks: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var ground: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var island_center: Vector3 = descriptor["center"]
	var area_scale := pow(float(descriptor["radius"]) / 480.0, 2.0)
	for _index in range(roundi(FOREST_CANDIDATES * area_scale)):
		var point := _pick_surface(forest_rng, descriptor, 17.0)
		if point == Vector3.INF:
			continue
		var local := Vector2(point.x, point.z)
		var edge := _edge_distance(descriptor, local)
		var biome := _biome_at(descriptor, local, point.y, edge, 0.3)
		var density := _vegetation_density(descriptor, local, biome)
		if forest_rng.randf() > density:
			continue
		if int(descriptor["index"]) == 0 and local.length() < 19.0:
			continue
		var scale := forest_rng.randf_range(0.75, 1.45)
		var base: Vector3 = island_center + point
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.9 * scale, 2.8 * scale, 0.9 * scale)), base + Vector3.UP * (1.4 * scale)))
		canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.4 * scale, 2.1 * scale, 2.4 * scale)), base + Vector3.UP * (4.1 * scale)))
	for _index in range(roundi(GROUND_CANDIDATES * area_scale)):
		var point := _pick_surface(ground_rng, descriptor, 8.0)
		if point == Vector3.INF:
			continue
		var local := Vector2(point.x, point.z)
		var biome := _biome_at(descriptor, local, point.y, _edge_distance(descriptor, local), 0.3)
		if ground_rng.randf() > _vegetation_density(descriptor, local, biome) * 0.9:
			continue
		var scale := ground_rng.randf_range(0.35, 1.15)
		ground.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.65 * scale, 0.45 * scale, 0.65 * scale)), island_center + point + Vector3.UP * (0.18 * scale)))
	for _index in range(roundi(ROCK_CANDIDATES * area_scale)):
		var point := _pick_surface(rock_rng, descriptor, 4.0)
		if point == Vector3.INF:
			continue
		var local := Vector2(point.x, point.z)
		var slope := _slope(descriptor, local)
		var biome := _biome_at(descriptor, local, point.y, _edge_distance(descriptor, local), slope)
		var chance := 0.55 if biome in ["alpine", "rocky_coast"] else 0.16 + slope * 0.25
		if rock_rng.randf() > chance:
			continue
		var scale := rock_rng.randf_range(0.65, 2.0)
		rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale * 0.72, scale)), island_center + point + Vector3.UP * (scale * 0.12)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.19
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 3
	var shrub_mesh := SphereMesh.new()
	shrub_mesh.radius = 1.0
	shrub_mesh.height = 1.0
	shrub_mesh.radial_segments = 6
	shrub_mesh.rings = 2
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.0
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 2
	_add_instances(chunk, "ForestTrunks", trunk_mesh, Color("#654733"), trunks)
	_add_instances(chunk, "ForestCanopies", canopy_mesh, Color("#315f38"), canopies)
	_add_instances(chunk, "GroundCover", shrub_mesh, Color("#597746"), ground)
	_add_instances(chunk, "StoneCover", rock_mesh, Color("#757b78"), rocks)
	var details := {}
	for label in ["ForestTrunks", "ForestCanopies", "GroundCover", "StoneCover"]:
		var visual: MultiMeshInstance3D = chunk.get_node_or_null(label)
		if visual:
			_set_visual_quality(visual)
			details[label] = {"multimesh": visual.multimesh, "material": visual.material_override}
	_remember_island_resource(cache_key, "details", details)
	_phase_msec["decoration"] += Time.get_ticks_msec() - started

func _apply_decoration_quality() -> void:
	for chunk in loaded_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for child in chunk.get_children():
			if child is MultiMeshInstance3D:
				_set_visual_quality(child)

func _set_visual_quality(visual: MultiMeshInstance3D) -> void:
	if not visual.multimesh:
		return
	var scale := float(DECORATION_QUALITY_SCALE[_decoration_quality].get(visual.name, 1.0))
	visual.multimesh.visible_instance_count = roundi(float(visual.multimesh.instance_count) * scale)

func _vegetation_density(descriptor: Dictionary, point: Vector2, biome: String) -> float:
	var base: float
	match biome:
		"forest": base = 0.78
		"swamp": base = 0.64
		"grassland": base = 0.30
		"tundra": base = 0.20
		"arid": base = 0.10
		"beach": base = 0.08
		_: base = 0.015
	var cluster := _field(descriptor, "forest_clusters", 0.009).get_noise_2d(point.x, point.y)
	var clearing := _field(descriptor, "clearings", 0.016).get_noise_2d(point.x, point.y)
	var mask := clampf(0.65 + cluster * 1.1, 0.0, 1.35)
	if clearing > 0.42:
		mask *= 0.14
	return clampf(base * mask * float(descriptor["forest_density"]), 0.0, 1.0)

func _add_instances(parent: Node3D, label: String, mesh: Mesh, color: Color, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	visual.material_override = material
	parent.add_child(visual)

func _refresh_streaming() -> void:
	if generation_version == 1:
		super._refresh_streaming()
		return
	var focus: Vector3 = _get_focus_position()
	var focus_chunk := _world_to_chunk(focus)
	if focus_chunk == _last_focus_chunk and Vector2(focus.x - _last_stream_focus.x, focus.z - _last_stream_focus.z).length_squared() < 225.0:
		_load_urgent_pending_islands(focus)
		return
	_last_focus_chunk = focus_chunk
	_last_stream_focus = focus
	var desired: Dictionary = {}
	var island_chunks: Dictionary = {}
	var immediate: Dictionary = {focus_chunk: true}
	for x in range(focus_chunk.x - stream_radius_chunks, focus_chunk.x + stream_radius_chunks + 1):
		for z in range(focus_chunk.y - stream_radius_chunks, focus_chunk.y + stream_radius_chunks + 1):
			desired[Vector2i(x, z)] = true
	for descriptor in island_descriptors:
		var center: Vector3 = descriptor["center"]
		var reach := _island_reach(descriptor)
		var island_chunk: Vector2i = descriptor["chunk"]
		island_chunks[island_chunk] = true
		var distance := Vector2(focus.x - center.x, focus.z - center.z).length()
		if distance < reach + maxf(20.0, float(stream_radius_chunks) * chunk_size):
			desired[island_chunk] = true
		if distance < reach + 20.0:
			immediate[island_chunk] = true
	for key in loaded_chunks.keys().duplicate():
		if not desired.has(key):
			_unload_chunk(key)
	_pending_chunks.clear()
	for key in desired:
		if loaded_chunks.has(key):
			continue
		if immediate.has(key) or not island_chunks.has(key):
			_load_chunk(key)
		else:
			_pending_chunks.append(key)
	_pending_chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance := (a.x - focus_chunk.x) * (a.x - focus_chunk.x) + (a.y - focus_chunk.y) * (a.y - focus_chunk.y)
		var b_distance := (b.x - focus_chunk.x) * (b.x - focus_chunk.x) + (b.y - focus_chunk.y) * (b.y - focus_chunk.y)
		if a_distance != b_distance:
			return a_distance < b_distance
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	)

func _island_reach(descriptor: Dictionary) -> float:
	var aspect := float(descriptor["aspect"])
	return float(descriptor["radius"]) * maxf(aspect, 1.0 / aspect) * 1.42 + 45.0

func _load_urgent_pending_islands(focus: Vector3) -> void:
	for descriptor in island_descriptors:
		var chunk_key: Vector2i = descriptor["chunk"]
		if not _pending_chunks.has(chunk_key):
			continue
		var center: Vector3 = descriptor["center"]
		if Vector2(focus.x - center.x, focus.z - center.z).length() < _island_reach(descriptor) + 20.0:
			_pending_chunks.erase(chunk_key)
			_load_chunk(chunk_key)

func _process(_delta: float) -> void:
	if not _world_is_active():
		return
	_refresh_streaming()
	if generation_version == 1:
		return
	for _index in range(maxi(1, max_distant_chunks_per_frame)):
		if _pending_chunks.is_empty():
			break
		var chunk_key: Vector2i = _pending_chunks.pop_front()
		if not loaded_chunks.has(chunk_key):
			_load_chunk(chunk_key)

func set_world_active(active: bool) -> void:
	if not active:
		_pending_chunks.clear()
		_last_stream_focus = Vector3.INF
	super.set_world_active(active)

func get_generation_diagnostics() -> Dictionary:
	var counts := {"forest": 0, "ground": 0, "rocks": 0, "caves": 0}
	var rendered := {"forest": 0, "ground": 0, "rocks": 0}
	for chunk in loaded_chunks.values():
		if not is_instance_valid(chunk):
			continue
		for node in chunk.get_children():
			if node is MultiMeshInstance3D:
				var amount: int = node.multimesh.instance_count
				var visible_amount: int = node.multimesh.visible_instance_count
				if visible_amount < 0:
					visible_amount = amount
				if node.name == "ForestCanopies": counts["forest"] += amount
				if node.name == "GroundCover": counts["ground"] += amount
				if node.name == "StoneCover": counts["rocks"] += amount
				if node.name == "ForestCanopies": rendered["forest"] += visible_amount
				if node.name == "GroundCover": rendered["ground"] += visible_amount
				if node.name == "StoneCover": rendered["rocks"] += visible_amount
			if node is StaticBody3D:
				for child in node.get_children():
					if child.name.begins_with("Cave_"):
						counts["caves"] += 1
	return {"seed": seed, "version": generation_version, "islands": island_descriptors.size(), "chunks": loaded_chunks.size(), "pending_chunks": _pending_chunks.size(), "instances": counts, "rendered_instances": rendered, "decoration_quality": _decoration_quality, "generation_ms": _generation_msec, "phase_ms": _phase_msec.duplicate(), "cache_entries": _island_cache.size(), "cache_hits": _cache_hits.duplicate()}
