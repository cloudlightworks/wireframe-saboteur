extends Node2D
class_name PieceGhost

const CELL = 64
const BOARD_ORIGIN = Vector2(-576, -512)

var piece_type: Piece.Type = Piece.Type.A
var orientation: Piece.PieceOrientation = Piece.PieceOrientation.VERTICAL
var valid: bool = true
var grid_pos: Vector2i = Vector2i.ZERO

func _process(_delta: float) -> void:
	valid = true
	var mouse := get_global_mouse_position()
	var local := mouse - BOARD_ORIGIN
	var col := int(local.x / CELL)
	var row := int(local.y / CELL)
	grid_pos = Vector2i(col, row)
	position = BOARD_ORIGIN + Vector2(col * CELL, row * CELL)
	queue_redraw()

func _draw() -> void:
	var alpha := sin(Time.get_ticks_msec() * 0.006) * 0.35 + 0.65
	var color := Color(0.1, 0.95, 0.3, alpha) if valid else Color(0.95, 0.2, 0.1, alpha)
	var dims := _get_dims()
	var W := float(dims.x * CELL)
	var H := float(dims.y * CELL)
	var inset := 4.0
	# Outer border
	draw_rect(Rect2(0, 0, W, H), color, false, 2.0)
	# Inner wireframe border
	draw_rect(Rect2(inset, inset, W - inset*2, H - inset*2), Color(color.r, color.g, color.b, alpha * 0.55), false, 1.0)
	# Corner diagonals — matching piece sprite style
	draw_line(Vector2(0, 0),   Vector2(inset, inset),     color, 1.0)
	draw_line(Vector2(W, 0),   Vector2(W - inset, inset), color, 1.0)
	draw_line(Vector2(0, H),   Vector2(inset, H - inset), color, 1.0)
	draw_line(Vector2(W, H),   Vector2(W - inset, H - inset), color, 1.0)

func _get_dims() -> Vector2i:
	match piece_type:
		Piece.Type.B:
			return Vector2i(1, 2) if orientation == Piece.PieceOrientation.VERTICAL else Vector2i(2, 1)
		Piece.Type.C:
			return Vector2i(2, 2)
		_:
			return Vector2i(1, 1)

func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dims := _get_dims()
	for r in range(dims.y):
		for c in range(dims.x):
			cells.append(grid_pos + Vector2i(c, r))
	return cells

func toggle_orientation() -> void:
	if piece_type != Piece.Type.B:
		return
	orientation = Piece.PieceOrientation.HORIZONTAL \
		if orientation == Piece.PieceOrientation.VERTICAL \
		else Piece.PieceOrientation.VERTICAL
