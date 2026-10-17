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

signal survival_stats_changed(health: float, hunger: float, thirst: float)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Main.player = self
	health = max_health
	hunger = max_hunger
	thirst = max_thirst
	configure_difficulty(Main.difficulty)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -PI / 2, PI / 2)
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera()

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
