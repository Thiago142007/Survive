extends Node3D
class_name BuildingSystem

const GRID_SIZE := 2.0
var placed_pieces: Array[Node3D] = []
var ghost_piece: Node3D = null
var _build_mode: bool = false

signal piece_placed(piece: Node3D)
signal piece_removed(piece: Node3D)
signal invalid_placement(reason: String)

func _ready() -> void:
	call_deferred("_toggle_build_mode")

func snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE,
		round(pos.z / GRID_SIZE) * GRID_SIZE
	)

func can_place(piece: BuildPiece, pos: Vector3, rot: Vector3) -> bool:
	var snapped := snap_to_grid(pos)
	# Check if already a piece at the same cell
	for p in placed_pieces:
		if p.position == snapped and p.rotation == rot:
			return false
	# If not a foundation, check for a connected foundation below
	if not piece.is_foundation:
		var has_foundation_below := false
		var below_pos := snapped + Vector3(0, -GRID_SIZE, 0)
		for p in placed_pieces:
			if p.position == below_pos and (p as BuildPiece).is_foundation:
				has_foundation_below = true
				break
		if not has_foundation_below:
			invalid_placement.emit("Foundation required below")
			return false
	return true

func place_piece(piece: Node3D) -> void:
	piece.position = snap_to_grid(piece.position)
	placed_pieces.append(piece)
	piece_placed.emit(piece)

func remove_piece(piece: Node3D) -> void:
	placed_pieces.erase(piece)
	piece_removed.emit(piece)
	# Drop 15% of materials
	var inv = Main.player.get_node("Inventory")
	var bp := piece as BuildPiece
	for res in bp.build_cost:
		var drop_qty := int(ceil(bp.build_cost[res] * 0.15))
		if drop_qty > 0:
			inv.add_item(res, drop_qty)
	piece.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("place_foundation"):
		_toggle_build_mode()
	elif event.is_action_pressed("confirm") and _build_mode:
		_confirm_placement()
	elif event.is_action_pressed("rotate_x") and _build_mode:
		_rotate_ghost_x()
	elif event.is_action_pressed("rotate_y") and _build_mode:
		_rotate_ghost_y()
	elif event.is_action_pressed("remove_piece") and _build_mode:
		_remove_looking_at()

func _confirm_placement() -> void:
	if not ghost_piece:
		return
	var bp := ghost_piece as BuildPiece
	if not _can_afford(bp.build_cost):
		invalid_placement.emit("Not enough materials")
		return
	if not can_place(bp, ghost_piece.position, ghost_piece.rotation):
		return
	_deduct_cost(bp.build_cost)
	var foundation := preload("res://scenes/building/foundation.tscn").instantiate()
	foundation.position = ghost_piece.position
	foundation.rotation = ghost_piece.rotation
	get_tree().current_scene.add_child.call_deferred(foundation)
	place_piece(foundation)

func _toggle_build_mode() -> void:
	_build_mode = not _build_mode
	if _build_mode:
		_spawn_ghost()
	else:
		_clear_ghost()

func _spawn_ghost() -> void:
	if ghost_piece:
		return
	ghost_piece = preload("res://scenes/building/foundation.tscn").instantiate()
	ghost_piece.position = _get_ground_position()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = 1
	ghost_piece.get_node("MeshInstance3D").material_override = mat
	get_tree().current_scene.add_child.call_deferred(ghost_piece)

func _process(_delta: float) -> void:
	if _build_mode and ghost_piece:
		ghost_piece.position = _get_ground_position()
		var bp := ghost_piece as BuildPiece
		if not _can_afford(bp.build_cost):
			ghost_piece.get_node("MeshInstance3D").material_override.albedo_color = Color(1, 0, 0, 0.5)
		else:
			ghost_piece.get_node("MeshInstance3D").material_override.albedo_color = Color(1, 1, 1, 0.5)

func _clear_ghost() -> void:
	if ghost_piece:
		ghost_piece.queue_free()
		ghost_piece = null

func _get_ground_position() -> Vector3:
	var cam = Main.player.get_node("CameraPivot/Camera3D")
	var from = cam.global_position
	var to = from + cam.global_transform.basis.z * -10
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_tree().root.world_3d.direct_space_state.intersect_ray(query)
	if result:
		# If looking at an existing foundation, spawn on top of it
		if result.collider is BuildPiece:
			var bp := result.collider as BuildPiece
			if bp.is_foundation:
				return bp.position + Vector3(0, GRID_SIZE, 0)
		return result.position + Vector3(0, 0.1, 0)
	return Vector3(0, 0.1, 0)

func _can_afford(cost: Dictionary) -> bool:
	var inv = Main.player.get_node("Inventory")
	for res in cost:
		if inv.get_count(res) < cost[res]:
			return false
	return true

func _deduct_cost(cost: Dictionary) -> void:
	var inv = Main.player.get_node("Inventory")
	for res in cost:
		inv.remove_item(res, cost[res])

func _rotate_ghost_x() -> void:
	if ghost_piece:
		var deg := 15.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0
		ghost_piece.rotate_x(deg_to_rad(deg))

func _rotate_ghost_y() -> void:
	if ghost_piece:
		var deg := 15.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0
		ghost_piece.rotate_y(deg_to_rad(deg))

func _remove_looking_at() -> void:
	var cam = Main.player.get_node("CameraPivot/Camera3D")
	var from = cam.global_position
	var to = from + cam.global_transform.basis.z * -5
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_tree().root.world_3d.direct_space_state.intersect_ray(query)
	if result and result.collider is BuildPiece:
		remove_piece(result.collider)
