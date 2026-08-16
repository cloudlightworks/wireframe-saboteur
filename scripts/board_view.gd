extends Node
# BoardView — the single owner of grid <-> pixel conversion.
#
# Presentation only. RulesEngine and GameState work purely in Vector2i cells and
# never see pixels, so nothing in this file can affect gameplay.
#
# Source of truth for CELL and BOARD_ORIGIN, which were previously copy-pasted
# into seven scripts.

const CELL := 64
const BOARD_ORIGIN := Vector2(-576, -512)  # board centered at 0,0; top-left offset

var board_width: int = 18
var board_height: int = 16

# When true the board is drawn rotated 180 degrees, so the local player's home
# rows sit at the bottom of the screen. Sprites and text are NOT rotated — a
# 180 degree flip preserves axis alignment, so everything stays upright and
# B-piece orientation is unaffected.
var flipped: bool = false

# Top-left pixel of a single cell.
func grid_to_world(cell: Vector2i) -> Vector2:
	var c := _apply(cell)
	return BOARD_ORIGIN + Vector2(c.x * CELL, c.y * CELL)

# Center pixel of a single cell.
func grid_to_world_center(cell: Vector2i) -> Vector2:
	return grid_to_world(cell) + Vector2(CELL * 0.5, CELL * 0.5)

func world_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - BOARD_ORIGIN
	# int() truncation preserved from the original _mouse_to_grid; floori would
	# change how clicks just off the top-left edge are rejected.
	return _apply(Vector2i(int(local.x / CELL), int(local.y / CELL)))

# Top-left pixel of a multi-cell piece's bounding box.
#
# This must be computed from the flipped positions, not by flipping the minimum
# cell: under a flip the minimum cell becomes the maximum, so taking min() of
# the raw cells would place every B piece one cell off.
func cells_to_world(cells: Array) -> Vector2:
	var best := grid_to_world(cells[0])
	for cell in cells:
		var p := grid_to_world(cell)
		best.x = minf(best.x, p.x)
		best.y = minf(best.y, p.y)
	return best

# The flip is its own inverse, so one function serves both directions.
func _apply(cell: Vector2i) -> Vector2i:
	if not flipped:
		return cell
	return Vector2i(board_width - 1 - cell.x, board_height - 1 - cell.y)
