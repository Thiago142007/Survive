extends SceneTree

const MALE_SCENE := "res://assets/characters/quaternius/Superhero_Male_FullBody.gltf"
const FEMALE_SCENE := "res://assets/characters/quaternius/Superhero_Female_FullBody.gltf"
const ARMS_SCENE := "res://assets/characters/psx_fps_arms/fp_arms_free_model.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_path in [MALE_SCENE, FEMALE_SCENE, ARMS_SCENE]:
		if not _expect(ResourceLoader.exists(scene_path), "Required imported character asset is missing: %s" % scene_path):
			return
	var male_scene := ResourceLoader.load(MALE_SCENE) as PackedScene
	var female_scene := ResourceLoader.load(FEMALE_SCENE) as PackedScene
	var arms_scene := ResourceLoader.load(ARMS_SCENE) as PackedScene
	if not _expect(male_scene != null and female_scene != null and arms_scene != null, "Male, female and arms assets must import as scenes"):
		return
	var rig_root := Node3D.new()
	root.add_child(rig_root)
	var male := male_scene.instantiate()
	var female := female_scene.instantiate()
	var arms := arms_scene.instantiate()
	rig_root.add_child(male)
	rig_root.add_child(female)
	rig_root.add_child(arms)
	await process_frame
	if not _expect(_has_descendant(male, "Skeleton3D") and _has_descendant(female, "Skeleton3D"), "Both body scenes must contain a rigged skeleton"):
		return
	if not _expect(_has_descendant(arms, "Skeleton3D") and _has_descendant(arms, "AnimationPlayer"), "First-person arms must include a skeleton and animation player"):
		return
	print("Character asset smoke test: PASS")
	quit()

func _has_descendant(node: Node, type_name: String) -> bool:
	if node.get_class() == type_name:
		return true
	for child in node.get_children():
		if _has_descendant(child, type_name):
			return true
	return false

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
