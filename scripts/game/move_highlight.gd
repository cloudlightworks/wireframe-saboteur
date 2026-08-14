extends Node2D
class_name MoveHighlight

const CELL = 64

var dims: Vector2i = Vector2i(1, 1)
var highlight_color: Color = Color(0.1, 0.9, 0.3, 1.0)
var dest_cell: Vector2i = Vector2i.ZERO

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var alpha := sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
	var col := Color(highlight_color.r, highlight_color.g, highlight_color.b, alpha)
	var W := float(dims.x * CELL)
	var H := float(dims.y * CELL)
	var inset := 4.0
	draw_rect(Rect2(0, 0, W, H), col, false, 2.5)
	draw_rect(Rect2(inset, inset, W - inset*2, H - inset*2),
		Color(col.r, col.g, col.b, alpha * 0.5), false, 1.0)
	draw_line(Vector2(0, 0),   Vector2(inset, inset),     col, 1.0)
	draw_line(Vector2(W, 0),   Vector2(W - inset, inset), col, 1.0)
	draw_line(Vector2(0, H),   Vector2(inset, H - inset), col, 1.0)
	draw_line(Vector2(W, H),   Vector2(W - inset, H - inset), col, 1.0)
