extends SceneTree

const IMPORTED_MODEL_VARIANT = preload("res://scripts/world/imported_model_variant.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This smoke test needs a graphical renderer")
	var palm_scene := load("res://scenes/world/palm.tscn") as PackedScene
	assert(palm_scene != null)
	var first_palm := palm_scene.instantiate() as Node3D
	var second_palm := palm_scene.instantiate() as Node3D
	root.add_child(first_palm)
	root.add_child(second_palm)
	await process_frame
	await process_frame

	var first_visual := first_palm.get_node("AssetVisual")
	var second_visual := second_palm.get_node("AssetVisual")
	assert(first_visual.variant_index == 1, "Palm must use the upright source variant")
	assert(first_visual.get_node_or_null("ImportedVisual") != null)
	assert(second_visual.get_node_or_null("ImportedVisual") != null)
	assert(IMPORTED_MODEL_VARIANT.get_cached_source_count() == 1, "The FBX pack must be parsed only once")
	assert(_has_textured_mesh(first_visual), "Imported palm must keep a texture material")
	assert(_has_cutout_material(first_visual), "Leaf textures must use an unshaded alpha cutout instead of black rectangles")
	assert(_is_upright(first_visual), "Palm crown must be above its trunk, not along the ground")

	print("Imported model cache, upright palm and textured meshes: PASS")
	first_palm.queue_free()
	second_palm.queue_free()
	await process_frame
	IMPORTED_MODEL_VARIANT.clear_cache()
	quit()

func _has_textured_mesh(root_node: Node) -> bool:
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material and material.albedo_texture:
				return true
	return false

func _has_cutout_material(root_node: Node) -> bool:
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material and material.albedo_texture \
				and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
				and material.cull_mode == BaseMaterial3D.CULL_DISABLED \
				and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				return true
	return false

func _is_upright(root_node: Node) -> bool:
	var imported := root_node.get_node("ImportedVisual") as Node3D
	var highest_mesh_y := imported.global_position.y
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		highest_mesh_y = maxf(highest_mesh_y, (node as MeshInstance3D).global_position.y)
	return highest_mesh_y - imported.global_position.y > 3.0
