extends Node3D
class_name BuildingSystem

const GRID_SIZE := 2.0
var placed_pieces: Array[Node3D] = []
var ghost_piece: Node3D = null

signal piece_placed(piece: Node3D)
signal piece_removed(piece: Node3D)
signal invalid_placement(reason: String)

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
		_spawn_foundation()
	elif event.is_action_pressed("rotate_x"):
		_rotate_ghost_x()
	elif event.is_action_pressed("rotate_y"):
		_rotate_ghost_y()
	elif event.is_action_pressed("remove_piece"):
		_remove_looking_at()

func _spawn_foundation() -> void:
	var foundation := preload("res://scenes/building/foundation.tscn").instantiate()
	var cam = Main.player.get_node("CameraPivot/Camera3D")
	var spawn_pos = cam.global_position + cam.global_transform.basis.z * -5
	foundation.position = spawn_pos
	if can_place(foundation as BuildPiece, spawn_pos, Vector3.ZERO):
		get_tree().current_scene.add_child(foundation)
		place_piece(foundation)
	else:
		foundation.queue_free()

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
