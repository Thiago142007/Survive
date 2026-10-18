extends Node3D
class_name CharacterPresentation

const MALE_BODY_PATH := "res://assets/characters/quaternius/Superhero_Male_FullBody.gltf"
const FEMALE_BODY_PATH := "res://assets/characters/quaternius/Superhero_Female_FullBody.gltf"
const ARMS_PATH := "res://assets/characters/psx_fps_arms/fp_arms_free_model.glb"

var character_id: String = "male"
var camera_mode: int = 0
var _body_root: Node3D
var _body_model: Node3D
var _arms_model: Node3D
var _camera: Camera3D
var _animation_player: AnimationPlayer
var _held_item_anchor: Node3D
var _held_item_model: Node3D
var _held_item_id: String = ""
var _last_action: StringName = &""

func _ready() -> void:
	_body_root = Node3D.new()
	_body_root.name = "BodyModel"
	add_child(_body_root)
	var player := get_parent()
	_camera = player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if _camera:
		var arms_scene := load(ARMS_PATH) as PackedScene
		if arms_scene:
			_arms_model = arms_scene.instantiate() as Node3D
			_arms_model.name = "FirstPersonArms"
			_arms_model.rotation.y = PI
			_arms_model.position = Vector3(0.0, -0.12, 0.0)
			_camera.add_child(_arms_model)
			_held_item_anchor = Node3D.new()
			_held_item_anchor.name = "HeldItemAnchor"
			_held_item_anchor.position = Vector3(0.28, -0.26, -0.52)
			_camera.add_child(_held_item_anchor)
			var animation_players := _arms_model.find_children("*", "AnimationPlayer", true, false)
			if not animation_players.is_empty():
				_animation_player = animation_players[0] as AnimationPlayer
				_animation_player.animation_finished.connect(_on_animation_finished)
	if player.has_signal("presentation_action"):
		player.presentation_action.connect(play_action)
	configure_character(String(player.get("character_id")))
	set_camera_mode(int(player.get("_cam_mode")))
	set_held_item(String(player.call("get_active_tool")))
	play_action(&"idle", &"hand")

func configure_character(requested_id: String) -> void:
	character_id = requested_id if requested_id in ["male", "female"] else "male"
	if not is_instance_valid(_body_root):
		return
	if _body_model:
		_body_model.queue_free()
		_body_model = null
	var body_path := FEMALE_BODY_PATH if character_id == "female" else MALE_BODY_PATH
	var body_scene := load(body_path) as PackedScene
	if body_scene:
		_body_model = body_scene.instantiate() as Node3D
		_body_model.name = "FemaleBody" if character_id == "female" else "MaleBody"
		_body_model.set_meta("character_id", character_id)
		_body_root.add_child(_body_model)
	if _arms_model:
		_arms_model.set_meta("character_id", character_id)
	_apply_camera_visibility()

func set_camera_mode(mode: int) -> void:
	camera_mode = clampi(mode, 0, 2)
	_apply_camera_visibility()

func get_character_id() -> String:
	return character_id

func get_body_model() -> Node3D:
	return _body_model

func get_arms_model() -> Node3D:
	return _arms_model

func get_last_action() -> StringName:
	return _last_action

func get_held_item_id() -> String:
	return _held_item_id

func get_held_item_model() -> Node3D:
	return _held_item_model

func set_held_item(item_id: String) -> void:
	var normalized_id := item_id if item_id in ["knife", "stone_axe", "stone_pickaxe", "shovel", "spear", "flashlight"] else ""
	if normalized_id == _held_item_id and is_instance_valid(_held_item_model):
		return
	_held_item_id = normalized_id
	if _held_item_model:
		_held_item_model.free()
		_held_item_model = null
	if not _held_item_anchor or normalized_id.is_empty():
		_apply_camera_visibility()
		return
	_held_item_model = _build_held_item(normalized_id)
	_held_item_anchor.add_child(_held_item_model)
	_apply_camera_visibility()

func _build_held_item(item_id: String) -> Node3D:
	var model := Node3D.new()
	model.name = "Held_%s" % item_id
	model.scale = Vector3.ONE * 0.82
	var wood := _held_material(Color("#735038"), 0.0)
	var metal := _held_material(Color("#84898c"), 0.48)
	var dark_metal := _held_material(Color("#4c5358"), 0.42)
	var grip := _held_box(Vector3(0.045, 0.28, 0.045), Vector3(0.0, -0.12, 0.0), wood)
	model.add_child(grip)
	match item_id:
		"knife":
			grip.position.y = -0.19
			grip.scale = Vector3(0.72, 0.52, 0.72)
			model.add_child(_held_box(Vector3(0.035, 0.27, 0.025), Vector3(0.0, 0.13, -0.025), metal))
			model.add_child(_held_box(Vector3(0.10, 0.025, 0.045), Vector3(0.0, -0.005, 0.0), dark_metal))
		"stone_axe":
			model.add_child(_held_box(Vector3(0.19, 0.12, 0.085), Vector3(-0.075, 0.09, 0.0), metal))
			model.add_child(_held_box(Vector3(0.11, 0.18, 0.085), Vector3(-0.16, 0.09, 0.0), dark_metal))
		"stone_pickaxe":
			model.add_child(_held_box(Vector3(0.28, 0.075, 0.08), Vector3(0.0, 0.12, 0.0), dark_metal))
			model.add_child(_held_box(Vector3(0.12, 0.07, 0.09), Vector3(-0.17, 0.105, 0.0), metal))
			model.add_child(_held_box(Vector3(0.12, 0.07, 0.09), Vector3(0.17, 0.105, 0.0), metal))
		"shovel":
			model.add_child(_held_box(Vector3(0.12, 0.17, 0.055), Vector3(0.0, 0.16, 0.0), metal))
		"spear":
			model.add_child(_held_box(Vector3(0.075, 0.19, 0.06), Vector3(0.0, 0.23, 0.0), metal))
		"flashlight":
			model.add_child(_held_box(Vector3(0.075, 0.14, 0.075), Vector3(0.0, 0.12, 0.0), dark_metal))
			var lens_material := _held_material(Color("#e9d99b"), 0.0)
			model.add_child(_held_box(Vector3(0.055, 0.035, 0.055), Vector3(0.0, 0.205, 0.0), lens_material))
	return model

func _held_box(dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = local_position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance

func _held_material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.78 if metallic == 0.0 else 0.48
	return material

func play_action(action: StringName, item_id: StringName = &"") -> void:
	if not item_id.is_empty():
		set_held_item(String(item_id))
	if not _animation_player:
		return
	var candidate := _animation_for_action(action, String(item_id))
	if not _animation_player.has_animation(candidate):
		candidate = _fallback_animation(action)
	if not _animation_player.has_animation(candidate):
		return
	_animation_player.play(candidate)
	_last_action = action

func _on_animation_finished(_animation_name: StringName) -> void:
	if not _animation_player or String(_animation_player.current_animation).ends_with("_idle"):
		return
	var idle_item := _held_item_id if not _held_item_id.is_empty() else "hand"
	play_action(&"idle", StringName(idle_item))

func _animation_for_action(action: StringName, item_id: String) -> StringName:
	var prefix := "unarmed"
	if item_id == "knife":
		prefix = "kitchen_knife"
	elif item_id == "flashlight":
		prefix = "flashlight"
	match action:
		&"idle":
			return StringName(prefix + "_idle")
		&"equip":
			return StringName(prefix + "_draw")
		&"attack":
			if prefix == "kitchen_knife":
				return &"kitchen_knife_stab"
			if prefix == "flashlight":
				return &"flashlight_swing"
			return &"unarmed_punch_r"
		&"harvest":
			return &"unarmed_pickup"
		&"interact":
			return &"unarmed_interact"
		_:
			return _fallback_animation(action)

func _fallback_animation(action: StringName) -> StringName:
	match action:
		&"attack": return &"unarmed_punch_r"
		&"equip": return &"unarmed_draw"
		&"harvest": return &"unarmed_pickup"
		&"interact": return &"unarmed_interact"
		_: return &"unarmed_idle"

func _apply_camera_visibility() -> void:
	if _body_model:
		_body_model.visible = camera_mode != 0
	if _arms_model:
		_arms_model.visible = camera_mode == 0
	if _held_item_model:
		_held_item_model.visible = camera_mode == 0
