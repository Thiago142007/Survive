extends CharacterBody3D
class_name Animal

enum Behavior { PEACEFUL, PREDATOR }
enum State { IDLE, WANDER, CHASE, FLEE, DEAD }

@export var species: String = "capybara"
@export var behavior: Behavior = Behavior.PEACEFUL
@export var max_health: float = 45.0
@export var move_speed: float = 2.2
@export var detection_radius: float = 12.0
@export var attack_damage: float = 12.0
@export var attack_range: float = 1.8
@export var drop_id: String = "meat"
@export var drop_quantity: int = 2
@export var active_period: String = "all"

var health: float = 45.0
var persistent_id: String = ""
var state: State = State.IDLE
var is_tamed: bool = false
var immobilized_time: float = 0.0
var _attack_cooldown: float = 0.0
var _wander_time: float = 0.0
var _wander_direction := Vector3.ZERO
var _target: Node3D

signal damaged(amount: float, remaining_health: float)
signal died(animal: Animal)
signal domesticated(animal: Animal)

func get_save_state() -> Dictionary:
	var position_value := global_position if is_inside_tree() else position
	var rotation_value := global_rotation if is_inside_tree() else rotation
	return {
		"persistent_id": persistent_id,
		"species": species,
		"behavior": int(behavior),
		"alive": state != State.DEAD and health > 0.0,
		"health": health,
		"max_health": max_health,
		"is_tamed": is_tamed,
		"position": [position_value.x, position_value.y, position_value.z],
		"rotation": [rotation_value.x, rotation_value.y, rotation_value.z]
	}

func apply_save_state(saved: Dictionary) -> void:
	if saved.has("persistent_id"):
		persistent_id = String(saved["persistent_id"])
	species = String(saved.get("species", species))
	behavior = int(saved.get("behavior", int(behavior))) as Behavior
	max_health = maxf(1.0, float(saved.get("max_health", max_health)))
	health = clampf(float(saved.get("health", max_health)), 0.0, max_health)
	is_tamed = bool(saved.get("is_tamed", false))
	state = State.IDLE if bool(saved.get("alive", true)) and health > 0.0 else State.DEAD
	_target = null
	_attack_cooldown = 0.0
	_wander_time = 0.0
	_wander_direction = Vector3.ZERO
	if saved.has("position"):
		var saved_position: Array = saved["position"]
		if saved_position.size() == 3:
			var position_value := Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
			if is_inside_tree():
				global_position = position_value
			else:
				position = position_value
	if saved.has("rotation"):
		var saved_rotation: Array = saved["rotation"]
		if saved_rotation.size() == 3:
			var rotation_value := Vector3(float(saved_rotation[0]), float(saved_rotation[1]), float(saved_rotation[2]))
			if is_inside_tree():
				global_rotation = rotation_value
			else:
				rotation = rotation_value
	_configure_visuals()

func _ready() -> void:
	health = max_health
	_configure_visuals()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	immobilized_time = maxf(0.0, immobilized_time - delta)
	var player := _get_player()
	var distance := global_position.distance_to(player.global_position) if player else INF
	if behavior == Behavior.PREDATOR and player and distance <= detection_radius:
		_target = player
		state = State.CHASE
	elif behavior == Behavior.PEACEFUL and player and distance <= detection_radius * 0.55 and not is_tamed:
		_target = player
		state = State.FLEE
	elif state in [State.CHASE, State.FLEE] and (not player or distance > detection_radius * 1.35):
		_target = null
		state = State.IDLE
	if immobilized_time <= 0.0:
		_update_motion(delta)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if behavior == Behavior.PREDATOR and state == State.CHASE and player and distance <= attack_range:
		_attack_player(player)

func _update_motion(delta: float) -> void:
	var direction := Vector3.ZERO
	if state == State.CHASE and is_instance_valid(_target):
		direction = global_position.direction_to(_target.global_position)
		direction.y = 0.0
	elif state == State.FLEE and is_instance_valid(_target):
		direction = _target.global_position.direction_to(global_position)
		direction.y = 0.0
	else:
		_wander_time -= delta
		if _wander_time <= 0.0:
			_wander_time = randf_range(1.0, 3.0)
			_wander_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		direction = _wander_direction
		state = State.WANDER if direction.length_squared() > 0.0 else State.IDLE
	if direction.length_squared() > 0.01:
		velocity.x = direction.x * move_speed * (1.15 if state == State.FLEE else 1.0)
		velocity.z = direction.z * move_speed * (1.15 if state == State.FLEE else 1.0)
		look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
	velocity.y = 0.0

func receive_hit(amount: float, hit_region: String = "body", _source: Node = null) -> void:
	if state == State.DEAD:
		return
	var final_amount := maxf(0.0, amount)
	if hit_region == "head":
		final_amount *= 1.35
	elif hit_region == "legs":
		immobilized_time = maxf(immobilized_time, 2.5)
	if final_amount <= 0.0:
		return
	health = maxf(0.0, health - final_amount)
	damaged.emit(final_amount, health)
	if health <= 0.0:
		_die()

func try_domesticate() -> bool:
	if behavior != Behavior.PEACEFUL or is_tamed or health <= 0.0:
		return false
	var player := _get_player()
	if not player or global_position.distance_to(player.global_position) > 2.5:
		return false
	var inventory: Node = player.get_node_or_null("Inventory")
	if not inventory or inventory.get_count("berry") < 1:
		return false
	inventory.remove_item("berry", 1)
	is_tamed = true
	domesticated.emit(self)
	return true

func _attack_player(player: Node3D) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = 1.25
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	var player := _get_player()
	if player:
		var inventory: Node = player.get_node_or_null("Inventory")
		if inventory:
			inventory.add_item(drop_id, drop_quantity)
		var research: Node = player.get_node_or_null("ResearchSystem")
		if research and research.has_method("add_experience"):
			research.add_experience(drop_quantity)
	died.emit(self)
	queue_free()

func _configure_visuals() -> void:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = _species_color()
	material.roughness = 1.0
	mesh_instance.material_override = material

func _species_color() -> Color:
	if behavior == Behavior.PREDATOR:
		return Color("#9b4b4b")
	match species:
		"deer": return Color("#aa805a")
		"boar": return Color("#725442")
		_: return Color("#8a9f65")

func _get_player() -> Node3D:
	var main := get_node_or_null("/root/Main")
	var player = main.get("player") if main else null
	return player as Node3D if player and is_instance_valid(player) else null
