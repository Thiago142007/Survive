extends Node3D
class_name BuildingSystem

const GRID_SIZE := 2.0
const BUILD_PIECE_SCRIPT = preload("res://scripts/building/build_piece.gd")

var piece_scenes: Dictionary = {
	"foundation": "res://scenes/building/foundation.tscn",
	"pillar_foundation": "res://scenes/building/pillar_foundation.tscn",
	"wall": "res://scenes/building/wall.tscn",
	"roof": "res://scenes/building/roof.tscn",
	"door": "res://scenes/building/door.tscn"
}
var piece_order: Array[String] = ["foundation", "pillar_foundation", "wall", "roof", "door"]
var selected_piece_id: String = "foundation"
var placed_pieces: Array[Node3D] = []
var ghost_piece: Node3D = null
var _build_mode: bool = false
var _stress_timer: float = 0.0

signal piece_placed(piece: Node3D)
signal piece_removed(piece: Node3D)
signal invalid_placement(reason: String)
signal selection_changed(piece_name: String)

func snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE,
		round(pos.z / GRID_SIZE) * GRID_SIZE
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("place_foundation"):
		if _build_mode:
			_clear_ghost()
			_build_mode = false
		else:
			selected_piece_id = "foundation"
			_build_mode = true
			_spawn_ghost()
	elif event.is_action_pressed("cycle_build_piece") and _build_mode:
		_cycle_piece()
	elif event.is_action_pressed("confirm") and _build_mode:
		_confirm_placement()
	elif event.is_action_pressed("rotate_x") and _build_mode:
		_rotate_ghost_x()
	elif event.is_action_pressed("rotate_y") and _build_mode:
		_rotate_ghost_y()
	elif event.is_action_pressed("remove_piece"):
		_remove_looking_at()
	elif event.is_action_pressed("upgrade_piece"):
		_upgrade_looking_at()
	elif event.is_action_pressed("repair_piece"):
		_repair_looking_at()

func _cycle_piece() -> void:
	var index := piece_order.find(selected_piece_id)
	selected_piece_id = piece_order[(index + 1) % piece_order.size()]
	_clear_ghost()
	_spawn_ghost()
	selection_changed.emit(_piece_display_name(selected_piece_id))
	invalid_placement.emit("Peça selecionada: %s" % _piece_display_name(selected_piece_id))

func _spawn_ghost() -> void:
	if ghost_piece:
		return
	ghost_piece = _get_piece_scene().instantiate()
	ghost_piece.position = _get_placement_position()
	_set_ghost_visual(ghost_piece, Color(1, 1, 1, 0.5))
	var collision := ghost_piece.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.disabled = true
	get_tree().current_scene.add_child(ghost_piece)

func _confirm_placement() -> void:
	if not ghost_piece:
		return
	var preview = ghost_piece
	if not _can_afford(preview.get("build_cost")):
		invalid_placement.emit("Materiais insuficientes")
		return
	if not can_place(preview, preview.position, preview.rotation):
		return
	_deduct_cost(preview.get("build_cost"))
	var piece: Node3D = _get_piece_scene().instantiate()
	piece.position = snap_to_grid(preview.position)
	piece.rotation = preview.rotation
	get_tree().current_scene.add_child(piece)
	place_piece(piece)
	_clear_ghost()
	_spawn_ghost()

func can_place(piece: Node3D, pos: Vector3, rot: Vector3) -> bool:
	var snapped := snap_to_grid(pos)
	for placed in placed_pieces:
		if placed.position.distance_to(snapped) < 0.1:
			invalid_placement.emit("Este espaço já está ocupado")
			return false
	var is_foundation: bool = bool(piece.get("is_foundation"))
	var below_pos := snapped + Vector3.DOWN * GRID_SIZE
	var has_support := snapped.y <= 0.1
	for placed in placed_pieces:
		if placed.position.distance_to(below_pos) < 0.1:
			has_support = true
			break
	if not is_foundation and not has_support:
		invalid_placement.emit("Não é possível construir no ar")
		return false
	if is_foundation and snapped.y > 0.1 and not has_support:
		invalid_placement.emit("Fundação precisa de terreno ou suporte")
		return false
	return true

func place_piece(piece: Node3D) -> void:
	piece.position = snap_to_grid(piece.position)
	placed_pieces.append(piece)
	piece_placed.emit(piece)

func get_save_state() -> Array[Dictionary]:
	var saved_pieces: Array[Dictionary] = []
	for piece in placed_pieces:
		if is_instance_valid(piece) and piece.has_method("get_save_state"):
			saved_pieces.append(piece.call("get_save_state"))
	return saved_pieces

func apply_save_state(saved_pieces: Array[Dictionary]) -> void:
	_clear_ghost()
	_build_mode = false
	for piece in placed_pieces.duplicate():
		if is_instance_valid(piece):
			piece.queue_free()
	placed_pieces.clear()
	var world := get_tree().current_scene
	if not world:
		return
	for state in saved_pieces:
		var piece_id := String(state.get("piece_id", ""))
		if not piece_scenes.has(piece_id):
			continue
		var packed := load(String(piece_scenes[piece_id])) as PackedScene
		if not packed:
			continue
		var piece := packed.instantiate() as Node3D
		world.add_child(piece)
		if piece.has_method("apply_save_state"):
			piece.call("apply_save_state", state)
		placed_pieces.append(piece)

func remove_piece(piece: Node3D) -> void:
	if not piece or not placed_pieces.has(piece):
		return
	placed_pieces.erase(piece)
	var build_cost: Dictionary = piece.get("build_cost")
	var player := _get_player()
	if player:
		var inventory: Node = player.get_node("Inventory")
		for resource_id in build_cost:
			inventory.add_item(resource_id, maxi(1, int(ceil(build_cost[resource_id] * 0.15))))
	for neighbor in placed_pieces:
		if neighbor.position.distance_to(piece.position) <= GRID_SIZE * 1.5:
			neighbor.add_stress(25.0)
	piece_removed.emit(piece)
	piece.queue_free()
	call_deferred("_evaluate_structure")

func _evaluate_structure() -> void:
	for piece in placed_pieces.duplicate():
		if is_instance_valid(piece) and not _has_support_path(piece):
			piece.add_stress(35.0)
			if piece.get("stress") >= piece.get("stress_limit"):
				remove_piece(piece)

func _has_support_path(piece: Node3D) -> bool:
	if bool(piece.get("is_foundation")) and piece.position.y <= 0.1:
		return true
	var target := piece.position + Vector3.DOWN * GRID_SIZE
	for other in placed_pieces:
		if other != piece and other.position.distance_to(target) < 0.1:
			return _has_support_path(other)
	return false

func _process(delta: float) -> void:
	if _build_mode and ghost_piece:
		ghost_piece.position = _get_placement_position()
		var affordable := _can_afford(ghost_piece.get("build_cost"))
		var valid := affordable and can_place_preview(ghost_piece)
		_set_ghost_visual(ghost_piece, Color(0.2, 1.0, 0.35, 0.5) if valid else Color(1.0, 0.2, 0.2, 0.5))
	_stress_timer += delta
	if _stress_timer >= 1.0:
		_stress_timer = 0.0
		_evaluate_structure()

func can_place_preview(piece: Node3D) -> bool:
	var snapped := snap_to_grid(piece.position)
	for placed in placed_pieces:
		if placed.position.distance_to(snapped) < 0.1:
			return false
	var is_foundation: bool = bool(piece.get("is_foundation"))
	if snapped.y <= 0.1:
		return is_foundation
	var below := snapped + Vector3.DOWN * GRID_SIZE
	for placed in placed_pieces:
		if placed.position.distance_to(below) < 0.1:
			return true
	return false

func _clear_ghost() -> void:
	if ghost_piece:
		ghost_piece.queue_free()
		ghost_piece = null

func _get_placement_position() -> Vector3:
	var player := _get_player()
	if not player:
		return Vector3.ZERO
	var cam: Camera3D = player.get_node("CameraPivot/Camera3D")
	var from := cam.global_position
	var to := from + cam.global_transform.basis.z * -10.0
	var result := get_tree().root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if result:
		if result.collider.get_script() == BUILD_PIECE_SCRIPT:
			return result.collider.position + Vector3.UP * GRID_SIZE
		return snap_to_grid(result.position + Vector3.UP * 0.1)
	return Vector3.ZERO

func _can_afford(cost: Dictionary) -> bool:
	var player := _get_player()
	if not player:
		return false
	var inventory: Node = player.get_node("Inventory")
	for resource_id in cost:
		if inventory.get_count(resource_id) < cost[resource_id]:
			return false
	return true

func _deduct_cost(cost: Dictionary) -> void:
	var player := _get_player()
	if not player:
		return
	var inventory: Node = player.get_node("Inventory")
	for resource_id in cost:
		inventory.remove_item(resource_id, cost[resource_id])

func _rotate_ghost_x() -> void:
	if ghost_piece:
		ghost_piece.rotate_x(deg_to_rad(15.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0))

func _rotate_ghost_y() -> void:
	if ghost_piece:
		ghost_piece.rotate_y(deg_to_rad(15.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0))

func _set_ghost_visual(root: Node, color: Color) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var material := StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = color
			child.material_override = material
		_set_ghost_visual(child, color)

func _remove_looking_at() -> void:
	var target := _get_build_piece_looking_at()
	if target:
		remove_piece(target)

func _upgrade_looking_at() -> void:
	var target := _get_build_piece_looking_at()
	if not target:
		return
	var cost: Dictionary = target.get_next_improvement_cost()
	if target.get("improvement_level") >= target.get_max_improvements():
		invalid_placement.emit("Esta peça já está no nível máximo")
		return
	if not _can_afford(cost):
		invalid_placement.emit("Materiais insuficientes para melhorar")
		return
	_deduct_cost(cost)
	target.upgrade()
	invalid_placement.emit("Construção melhorada")

func _repair_looking_at() -> void:
	var target := _get_build_piece_looking_at()
	if not target:
		return
	var cost: Dictionary = target.get_repair_cost()
	if not _can_afford(cost):
		invalid_placement.emit("Materiais insuficientes para reparar")
		return
	_deduct_cost(cost)
	target.repair()
	invalid_placement.emit("Construção reparada")

func _get_build_piece_looking_at() -> Node3D:
	var player := _get_player()
	if not player:
		return null
	var cam: Camera3D = player.get_node("CameraPivot/Camera3D")
	var from := cam.global_position
	var to := from + cam.global_transform.basis.z * -5.0
	var result := get_tree().root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if result and result.collider.get_script() == BUILD_PIECE_SCRIPT:
		return result.collider
	return null

func _get_piece_scene() -> PackedScene:
	return load(piece_scenes[selected_piece_id]) as PackedScene

func _piece_display_name(piece_id: String) -> String:
	return piece_id.replace("_", " ").capitalize()

func _get_player() -> Node3D:
	var main := get_node_or_null("/root/Main")
	return main.get("player") as Node3D if main else null
