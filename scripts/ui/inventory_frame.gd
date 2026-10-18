extends Control

# The panel is drawn at the reference's 736 × 460 coordinate system. The
# inventory controller scales this Control and its interactive slot buttons
# together, so their alignment survives changes in window size.
const BACKDROP := Color("211e1d")
const PANEL_ART := preload("res://assets/ui/inventory_panel_frame.png")
const SHADOW := Color("171312")
const RIM := Color("625350")
const SLOT := Color("1d1918")
const SLOT_EDGE := Color("4d403c")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(736, 460)), BACKDROP)
	draw_texture_rect(PANEL_ART, Rect2(114, 49, 504, 367), false)
	_draw_grid()
	_draw_equipment()
	_draw_side_tabs()
	_draw_title_text()

func _draw_grid() -> void:
	for index in 20:
		var column := index % 4
		var row := index / 4
		_draw_slot(Rect2(398 + column * 50, 125 + row * 50, 44, 44))

func _draw_equipment() -> void:
	for row in 5:
		var top := 125 + row * 50
		_draw_slot(Rect2(145, top, 44, 44))
		_draw_slot(Rect2(329, top, 44, 44))

func _draw_side_tabs() -> void:
	var positions := [Vector2(607, 120), Vector2(607, 177), Vector2(607, 307)]
	for index in 3:
		var position: Vector2 = positions[index]
		draw_rect(Rect2(position + Vector2(2, 3), Vector2(46, 47)), SHADOW)
		draw_rect(Rect2(position, Vector2(46, 47)), RIM)
		draw_rect(Rect2(position + Vector2(3, 3), Vector2(40, 41)), Color("9e8882"))
		draw_rect(Rect2(position + Vector2(6, 6), Vector2(34, 35)), Color("b19b94"))

func _draw_title_text() -> void:
	draw_string(get_theme_default_font(), Vector2(310, 95), "INVENTORY", HORIZONTAL_ALIGNMENT_CENTER, 112, 17, Color("463936"))

func _draw_slot(rect: Rect2) -> void:
	draw_rect(rect, SLOT_EDGE)
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), SLOT)
	draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(rect.size.x - 2, 1), Color("62514b"), 1.0)
	draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(1, rect.size.y - 2), Color("594a45"), 1.0)
	draw_line(rect.position + Vector2(2, rect.size.y - 2), rect.end - Vector2(2, 2), SHADOW, 1.0)

