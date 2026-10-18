extends Control

var item_id := ""
var item_texture: Texture2D = null

func set_item(id: String, texture: Texture2D = null) -> void:
	item_id = id
	item_texture = texture
	queue_redraw()

func _draw() -> void:
	if item_id.is_empty():
		return
	if item_texture:
		draw_texture_rect(item_texture, Rect2(Vector2.ZERO, size), false)
		return
	match item_id:
		"wood":
			_draw_wood()
		"stone":
			_draw_stone()
		"berry":
			_draw_berries()
		"stone_axe", "stone_pickaxe", "shovel", "knife", "spear":
			_draw_tool()
		_:
			_draw_generic()

func _draw_wood() -> void:
	var bark := Color("91725b")
	var edge := Color("c3a489")
	for shift in [-5.0, 0.0, 5.0]:
		draw_line(Vector2(7 + shift, 21), Vector2(16 + shift, 5), bark, 5.0, true)
		draw_line(Vector2(8 + shift, 20), Vector2(17 + shift, 6), edge, 1.0, true)

func _draw_stone() -> void:
	var points := PackedVector2Array([
		Vector2(5, 19), Vector2(7, 9), Vector2(17, 4),
		Vector2(25, 11), Vector2(21, 22), Vector2(12, 24),
	])
	draw_colored_polygon(points, Color("8f8a83"))
	draw_line(Vector2(7, 9), Vector2(17, 4), Color("d0c8bd"), 1.5, true)
	draw_line(Vector2(17, 4), Vector2(25, 11), Color("d0c8bd"), 1.5, true)
	draw_line(Vector2(12, 24), Vector2(17, 12), Color("5f5b58"), 1.5, true)

func _draw_berries() -> void:
	var fruit := Color("9b5a59")
	for point in [Vector2(10, 14), Vector2(19, 13), Vector2(14, 20)]:
		draw_circle(point, 5.0, fruit)
		draw_circle(point + Vector2(-1.5, -1.5), 1.0, Color("d8a5a0"))
	draw_line(Vector2(14, 9), Vector2(14, 4), Color("7e8860"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 5), Vector2(22, 3), Vector2(17, 9)]), Color("8c976b"))

func _draw_tool() -> void:
	draw_line(Vector2(8, 23), Vector2(20, 6), Color("9a765b"), 4.0, true)
	draw_line(Vector2(8, 23), Vector2(20, 6), Color("d0aa83"), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, 4), Vector2(25, 5), Vector2(26, 13), Vector2(19, 11),
	]), Color("a8a6a1"))
	draw_line(Vector2(17, 4), Vector2(25, 5), Color("d0cbc3"), 1.0, true)

func _draw_generic() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, 3), Vector2(25, 14), Vector2(14, 25), Vector2(3, 14),
	]), Color("a18b71"))
	draw_line(Vector2(14, 3), Vector2(25, 14), Color("d2c1a8"), 1.0, true)
