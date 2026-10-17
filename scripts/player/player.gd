extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var _cam_mode: int = 0  # 0=1st, 1=2nd, 2=3rd
var _cam_distance: float = 0.0
var health: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var energy: float = 100.0
var difficulty: String = "normal"
var thirst_enabled: bool = true
var energy_enabled: bool = false
var hunger_rate_multiplier: float = 1.0
var active_tool: String = "hand"
var hotbar_tools: Array[String] = ["hand", "knife", "stone_axe", "stone_pickaxe", "shovel"]
var is_blocking: bool = false
var _attack_cooldown: float = 0.0

signal survival_stats_changed(health: float, hunger: float, thirst: float)
signal combat_hit(target: Node, damage: float)
signal player_damaged(amount: float, remaining_health: float)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Main.player = self
	health = max_health
	hunger = max_hunger
	thirst = max_thirst
	configure_difficulty(Main.difficulty)

func _input(event: InputEvent) -> void:
	# Mouse motion is handled before CanvasLayer/UI input so menus cannot swallow
	# the camera controls while the gameplay cursor is captured.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera_from_mouse(event.relative)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		_set_gameplay_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_set_gameplay_mouse(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera()
	if event.is_action_pressed("attack"):
		_perform_attack()
	if event.is_action_pressed("block"):
		is_blocking = true
	if event.is_action_released("block"):
		is_blocking = false
	for index in range(hotbar_tools.size()):
		if event.is_action_pressed("select_tool_%d" % (index + 1)):
			active_tool = hotbar_tools[index]

func _rotate_camera_from_mouse(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -PI / 2, PI / 2)

func _set_gameplay_mouse(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func get_active_tool() -> String:
	var inventory = get_node_or_null("Inventory")
	if active_tool != "hand" and (not inventory or inventory.get_count(active_tool) <= 0):
		return "hand"
	return active_tool

func _toggle_camera() -> void:
	_cam_mode = (_cam_mode + 1) % 3
	match _cam_mode:
		0:
			_cam_distance = 0.0  # 1st person
		1:
			_cam_distance = 4.0  # 2nd person
		2:
			_cam_distance = 6.0  # 3rd person
	camera.position.z = _cam_distance

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
	if energy_enabled and energy <= 0.0:
		current_speed *= 0.55
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	_update_survival(delta, current_speed)

func _perform_attack() -> void:
	if _attack_cooldown > 0.0 or is_blocking:
		return
	_attack_cooldown = 0.45
	var damage := _get_attack_damage()
	var from := camera.global_position
	var to := from + camera.global_transform.basis.z * -3.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return
	var target = result.collider
	if target.has_method("receive_hit"):
		var hit_region := "legs" if result.position.y < target.global_position.y + 0.45 else "body"
		target.receive_hit(damage, hit_region, self)
		combat_hit.emit(target, damage)

func _get_attack_damage() -> float:
	match get_active_tool():
		"knife": return 16.0
		"stone_axe": return 18.0
		"stone_pickaxe": return 14.0
		"spear": return 28.0
		_: return 8.0

func take_damage(amount: float) -> void:
	var final_amount := amount * (0.35 if is_blocking else 1.0)
	health = maxf(0.0, health - final_amount)
	player_damaged.emit(final_amount, health)
	if health <= 0.0:
		_respawn()

func _update_survival(delta: float, current_speed: float) -> void:
	var movement_cost := 0.015 if velocity.length() > 0.2 else 0.0
	var sprint_cost := 0.025 if current_speed > speed else 0.0
	hunger = clampf(hunger - delta * (0.035 + movement_cost + sprint_cost) * hunger_rate_multiplier, 0.0, max_hunger)
	if thirst_enabled:
		thirst = clampf(thirst - delta * (0.055 + movement_cost * 1.5 + sprint_cost), 0.0, max_thirst)
	else:
		thirst = max_thirst
	if energy_enabled:
		var energy_drain := 0.0
		if Input.is_action_pressed("sprint") and velocity.length() > 0.2:
			energy_drain = 8.0
		elif velocity.length() <= 0.2:
			energy = minf(100.0, energy + delta * 5.0)
		energy = clampf(energy - delta * energy_drain, 0.0, 100.0)
	else:
		energy = 100.0
	var needs_empty := hunger <= 0.0 or (thirst_enabled and thirst <= 0.0)
	if needs_empty:
		health = maxf(0.0, health - delta * 2.0)
	elif hunger > 60.0 and (not thirst_enabled or thirst > 60.0):
		health = minf(max_health, health + delta * 0.35)
	survival_stats_changed.emit(health, hunger, thirst)
	if health <= 0.0:
		_respawn()

func configure_difficulty(new_difficulty: String) -> void:
	difficulty = new_difficulty
	thirst_enabled = difficulty != "easy"
	energy_enabled = difficulty == "hard"
	hunger_rate_multiplier = 0.55 if difficulty == "easy" else 1.0

func _respawn() -> void:
	global_position = Vector3(0.0, 2.0, 0.0)
	velocity = Vector3.ZERO
	health = max_health
	hunger = max_hunger * 0.5
	thirst = max_thirst * 0.5
	var inventory := get_node_or_null("Inventory")
	if inventory:
		inventory.slots.clear()
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message("Você morreu e renasceu. Seus itens foram perdidos.")
