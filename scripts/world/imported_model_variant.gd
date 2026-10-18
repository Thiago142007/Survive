extends Node3D
class_name ImportedModelVariant

## Loads one visual variant from an imported model pack while keeping a local
## fallback visible if Godot cannot import the source asset.

@export_file("*.fbx", "*.dae", "*.gltf", "*.glb", "*.tscn", "*.scn") var source_path: String
@export var variant_index: int = -1
@export var target_height: float = 1.0
@export var model_rotation_degrees := Vector3.ZERO
@export var fallback_path: NodePath

static var _variant_template_cache: Dictionary = {}

var _imported_root: Node3D

static func get_cached_source_count() -> int:
	return _variant_template_cache.size()

static func clear_cache() -> void:
	_variant_template_cache.clear()

func _ready() -> void:
	call_deferred("_load_imported_visual")

func configure(path: String, height: float, index: int = -1, rotation_degrees := Vector3.ZERO) -> void:
	source_path = path
	target_height = height
	variant_index = index
	model_rotation_degrees = rotation_degrees

func _load_imported_visual() -> void:
	# The dummy headless renderer cannot allocate imported mesh RIDs. Keep the
	# lightweight fallback active for server and command-line validation runs.
	if DisplayServer.get_name() == "headless":
		return
	if source_path.is_empty() or not ResourceLoader.exists(source_path):
		return
	var templates := _get_variant_templates()
	if templates.is_empty():
		return
	var selected_index := variant_index
	if selected_index < 0:
		selected_index = _position_variant_index(templates.size())
	selected_index = posmod(selected_index, templates.size())
	var selected_scene := templates[selected_index] as PackedScene
	var selected := selected_scene.instantiate() as Node3D if selected_scene else null
	if not selected:
		return
	add_child(selected)
	_imported_root = selected
	_normalize_candidate(selected)
	selected.name = "ImportedVisual"
	# Preserve the axis correction authored by the source scene. Replacing this
	# rotation with Vector3.ZERO lays Z-up FBX models flat on the ground.
	_imported_root.rotation_degrees += model_rotation_degrees
	_configure_visibility_range(selected)
	_set_fallback_visible(false)

func _get_variant_templates() -> Array:
	if _variant_template_cache.has(source_path):
		return _variant_template_cache[source_path]
	var packed := load(source_path) as PackedScene
	if not packed:
		return []
	var source_instance := packed.instantiate() as Node3D
	if not source_instance:
		return []
	var candidates := _find_variant_candidates(source_instance)
	var templates: Array[PackedScene] = []
	for candidate in candidates:
		var candidate_transform := _transform_relative_to(candidate, source_instance)
		candidate.get_parent().remove_child(candidate)
		candidate.transform = candidate_transform
		_apply_matching_textures(candidate)
		_prepare_for_packing(candidate, candidate)
		var template_scene := PackedScene.new()
		if template_scene.pack(candidate) == OK:
			templates.append(template_scene)
		candidate.free()
	source_instance.free()
	if not templates.is_empty():
		_variant_template_cache[source_path] = templates
	return templates

func _prepare_for_packing(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_prepare_for_packing(child, scene_root)

func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D and parent != ancestor:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

func _find_variant_candidates(root: Node3D) -> Array[Node3D]:
	var current := root
	for _depth in range(5):
		var candidates: Array[Node3D] = []
		for child in current.get_children():
			if child is Node3D and _contains_mesh(child):
				candidates.append(child)
		if candidates.size() > 1:
			return candidates
		if candidates.size() == 1 and not candidates[0] is MeshInstance3D:
			current = candidates[0]
			continue
		return candidates
	return []

func _contains_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh != null
	for child in node.get_children():
		if _contains_mesh(child):
			return true
	return false

func _set_meshes_visible(root: Node, visible_value: bool) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).visible = visible_value
	for child in root.get_children():
		_set_meshes_visible(child, visible_value)

func _configure_visibility_range(root: Node) -> void:
	var maximum_distance := 110.0 if target_height >= 3.0 else 60.0
	var geometry_nodes: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		geometry_nodes.append(root as GeometryInstance3D)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		geometry_nodes.append(node as GeometryInstance3D)
	for geometry in geometry_nodes:
		geometry.visibility_range_end = maximum_distance
		geometry.visibility_range_end_margin = 8.0

func _normalize_candidate(candidate: Node3D) -> void:
	candidate.position = Vector3.ZERO
	var bounds := _candidate_bounds_in_parent(candidate)
	if bounds.size.y <= 0.001:
		return
	var uniform_scale := target_height / bounds.size.y
	candidate.scale *= uniform_scale
	candidate.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * uniform_scale,
		-bounds.position.y * uniform_scale,
		-(bounds.position.z + bounds.size.z * 0.5) * uniform_scale
	)

func _candidate_bounds_in_parent(candidate: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var parent := candidate.get_parent() as Node3D
	var inverse := parent.global_transform.affine_inverse()
	for node in candidate.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var local_bounds: AABB = (inverse * mesh_instance.global_transform) * mesh_instance.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	if candidate is MeshInstance3D and (candidate as MeshInstance3D).mesh:
		bounds = (inverse * candidate.global_transform) * (candidate as MeshInstance3D).get_aabb()
	return bounds

func _apply_matching_textures(candidate: Node3D) -> void:
	var directory := source_path.get_base_dir()
	var files := DirAccess.get_files_at(directory)
	if files.is_empty():
		return
	var mesh_instances: Array[MeshInstance3D] = []
	if candidate is MeshInstance3D:
		mesh_instances.append(candidate as MeshInstance3D)
	for node in candidate.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(node as MeshInstance3D)
	for mesh_instance in mesh_instances:
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var albedo_path := _matching_texture_path(files, directory, mesh_instance.name, candidate.name, "albedo")
		if albedo_path.is_empty():
			continue
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(albedo_path) as Texture2D
		material.roughness = 0.92
		if albedo_path.to_lower().ends_with(".png"):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			# Crossed foliage cards are visible from both sides. Unshaded cutout
			# materials keep the back-facing cards from turning into black planes.
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var normal_path := _matching_texture_path(files, directory, mesh_instance.name, candidate.name, "normal")
		if not normal_path.is_empty():
			material.normal_enabled = true
			material.normal_texture = load(normal_path) as Texture2D
		mesh_instance.material_override = material

func _matching_texture_path(files: PackedStringArray, directory: String, mesh_name: String, candidate_name: String, channel: String) -> String:
	var mesh_key := _compact_asset_key(mesh_name)
	var candidate_key := _compact_asset_key(candidate_name)
	var is_candidate_mesh := mesh_key == candidate_key
	var channel_candidates: Array[String] = []
	for file in files:
		var lower := file.to_lower()
		var supported_image := lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg")
		var has_channel := lower.find(channel) != -1
		if channel == "albedo":
			var looks_like_color := lower.find("normal") == -1 and lower.find("alpha") == -1 and lower.find("ao") == -1
			has_channel = has_channel or lower.find("diffuse") != -1 or looks_like_color
		if not has_channel or not supported_image:
			continue
		channel_candidates.append(file)
		var texture_key := _compact_asset_key(lower.get_basename())
		var matches_mesh := texture_key.begins_with(mesh_key) or texture_key.ends_with(mesh_key)
		var matches_candidate := is_candidate_mesh and (texture_key.begins_with(candidate_key) or texture_key.ends_with(candidate_key))
		if matches_mesh or matches_candidate:
			return directory.path_join(file)
	if channel_candidates.size() == 1:
		return directory.path_join(channel_candidates[0])
	return ""

func _compact_asset_key(value: String) -> String:
	var compact := value.to_lower()
	for token in ["albedo", "diffuse", "normals", "normal", "bake1", "pbr", "texture", "lr"]:
		compact = compact.replace(token, "")
	for separator in ["_", "-", " ", "."]:
		compact = compact.replace(separator, "")
	return compact

func _position_variant_index(count: int) -> int:
	var key := int(round(global_position.x * 31.0))
	key ^= int(round(global_position.z * 67.0))
	key ^= int(round(global_position.y * 13.0))
	return posmod(key, maxi(1, count))

func _set_fallback_visible(visible_value: bool) -> void:
	if fallback_path.is_empty():
		return
	var fallback := get_node_or_null(fallback_path)
	if fallback:
		_set_meshes_visible(fallback, visible_value)
