extends RefCounted
class_name RulesEngine

static func legal_moves_for(piece: Piece, game_state: GameState) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var origin: Vector2i = piece.cells[0]

	match piece.type:
		Piece.Type.A:
			var directions: Array[Vector2i] = [
				Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, 0), Vector2i(1, 0),
			]
			for dir in directions:
				var dest: Vector2i = origin + dir
				if is_on_board(dest, game_state.board):
					moves.append(dest)
		Piece.Type.B:
			var end_a: Vector2i = piece.cells[0]
			var end_b: Vector2i = piece.cells[1]
			var pivots: Array[Vector2i] = [end_a, end_b]
			var swing_steps: Array[Vector2i] = []
			if piece.orientation == Piece.PieceOrientation.HORIZONTAL:
				swing_steps = [Vector2i(0, -1), Vector2i(0, 1)]
			else:
				swing_steps = [Vector2i(-1, 0), Vector2i(1, 0)]
			for pivot in pivots:
				for step in swing_steps:
					var swung_cell: Vector2i = pivot + step
					var new_cells: Array[Vector2i] = [pivot, swung_cell]
					if _all_on_board(new_cells, game_state.board):
						moves.append(swung_cell)
			if piece.orientation == Piece.PieceOrientation.HORIZONTAL:
				var left_end := end_a if end_a.x <= end_b.x else end_b
				var right_end := end_a if end_a.x >= end_b.x else end_b
				var slide_left := left_end + Vector2i(-1, 0)
				var slide_right := right_end + Vector2i(1, 0)
				if is_on_board(slide_left, game_state.board):
					moves.append(slide_left)
				if is_on_board(slide_right, game_state.board):
					moves.append(slide_right)
			else:
				var top_end := end_a if end_a.y <= end_b.y else end_b
				var bot_end := end_a if end_a.y >= end_b.y else end_b
				var slide_up := top_end + Vector2i(0, -1)
				var slide_down := bot_end + Vector2i(0, 1)
				if is_on_board(slide_up, game_state.board):
					moves.append(slide_up)
				if is_on_board(slide_down, game_state.board):
					moves.append(slide_down)
		Piece.Type.C:
			var directions: Array[Vector2i] = [
				Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, 0), Vector2i(1, 0),
			]
			for dir in directions:
				var shifted_cells := _shifted_cells(piece, dir)
				if _all_on_board(shifted_cells, game_state.board):
					moves.append(origin + dir)
		Piece.Type.GENERAL:
			if game_state.is_general_frozen(piece.owner):
				return moves
			var directions: Array[Vector2i] = [
				Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1),
			]
			for dir in directions:
				var dest: Vector2i = origin + dir
				if is_on_board(dest, game_state.board) and is_in_own_half(dest, piece.owner, game_state.board):
					moves.append(dest)
	return moves

static func is_on_board(pos: Vector2i, board: Board) -> bool:
	return pos.x >= 0 and pos.x < board.board_width \
		and pos.y >= 0 and pos.y < board.board_height

static func is_in_own_half(pos: Vector2i, owner: Piece.Owner, board: Board) -> bool:
	if owner == Piece.Owner.BLUE:
		return pos.y < board.home_rows_per_side
	else:
		return pos.y >= board.home_rows_per_side
		
static func _shifted_cells(piece: Piece, delta: Vector2i) -> Array[Vector2i]:
	var shifted: Array[Vector2i] = []
	for cell in piece.cells:
		shifted.append(cell + delta)
	return shifted

static func _all_on_board(cells: Array[Vector2i], board: Board) -> bool:
	for cell in cells:
		if not is_on_board(cell, board):
			return false
	return true

enum CaptureResult { CAPTURED, MUTUAL_DESTROY, ILLEGAL }

static func resolve_capture(attacker: Piece, defender: Piece) -> CaptureResult:
	if defender.type == Piece.Type.GENERAL:
		if attacker.has_status("saboteur"):
			return CaptureResult.CAPTURED
		return CaptureResult.ILLEGAL
	if attacker.type == Piece.Type.GENERAL:
		if defender.type == Piece.Type.GENERAL:
			return CaptureResult.ILLEGAL
		if defender.type == Piece.Type.OBJECTIVE:
			return CaptureResult.ILLEGAL
		if defender.has_status("saboteur"):
			return CaptureResult.ILLEGAL
		return CaptureResult.CAPTURED
	if defender.type == Piece.Type.OBJECTIVE:
		return CaptureResult.CAPTURED
	if attacker.type == defender.type:
		return CaptureResult.MUTUAL_DESTROY
	var beats := {
		Piece.Type.A: Piece.Type.C,
		Piece.Type.C: Piece.Type.B,
		Piece.Type.B: Piece.Type.A,
	}
	if beats.get(attacker.type) == defender.type:
		return CaptureResult.CAPTURED
	return CaptureResult.ILLEGAL
	
static func check_win(game_state: GameState):
	var blue_objective_alive := false
	var red_objective_alive := false

	for piece in game_state.pieces.values():
		if piece.type == Piece.Type.OBJECTIVE:
			if piece.owner == Piece.Owner.BLUE:
				blue_objective_alive = true
			elif piece.owner == Piece.Owner.RED:
				red_objective_alive = true

	if not blue_objective_alive:
		return Piece.Owner.RED
	if not red_objective_alive:
		return Piece.Owner.BLUE

	return null
	
static func can_declare_saboteur(declaring_player: Piece.Owner, game_state: GameState) -> bool:
	for piece in game_state.pieces.values():
		if piece.owner == declaring_player and piece.has_status("saboteur"):
			return false
	return true	

static func designation_from_cards(type_card: Card, chart_card: Card, chosen_type: Piece.Type) -> String:
	if type_card.category != Card.Category.TYPE:
		return ""
	if chart_card.category != Card.Category.CHART:
		return ""
	if not type_card.piece_types.has(chosen_type):
		return ""
	var letter := _type_letter(chosen_type)
	if letter == "":
		return ""
	var number := chart_card.value_for(chosen_type)
	print(">>> DESIG: chosen_type=", chosen_type, " chart_values=", chart_card.chart_values, " -> ", letter, number)
	if number == -1:
		return ""
	return letter + str(number)

static func _type_letter(piece_type: Piece.Type) -> String:
	match piece_type:
		Piece.Type.A:
			return "A"
		Piece.Type.B:
			return "B"
		Piece.Type.C:
			return "C"
		_:
			return ""

# ============================================================
# LEGAL DESTINATIONS — full legality filter
# ------------------------------------------------------------
# legal_moves_for() above returns GEOMETRY ONLY. It does not know about
# occupancy, friendly blocking, or capture legality. This section is the
# authoritative legal-move set, extracted verbatim from the filter that used
# to live inside board_controller._show_highlights().
#
# KNOWN QUIRK (preserved deliberately): the B branch overwrites `target` for
# each overlapping piece, so when a swing covers two enemy pieces only the
# LAST one found is checked for capture legality — and iteration order over
# game_state.pieces is not defined. The non-B branch checks all of them.
# This asymmetry predates the extraction. Do not "fix" it here; it needs a
# hotseat repro and its own commit on main.
# ============================================================

static func legal_destinations_for(piece: Piece, game_state: GameState) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dest in legal_moves_for(piece, game_state):
		if is_destination_legal(piece, dest, game_state):
			out.append(dest)
	return out

static func is_destination_legal(piece: Piece, dest: Vector2i, game_state: GameState) -> bool:
	if piece.type == Piece.Type.B:
		var dest_cells := b_new_cells_for_dest(piece, dest)
		var blocked := false
		var target: Piece = null
		for other in game_state.pieces.values():
			if other.uid == piece.uid:
				continue
			for cell in other.cells:
				if dest_cells.has(cell):
					if other.owner == piece.owner and not game_state.can_capture_own_piece:
						blocked = true
					else:
						target = other
					break
			if blocked:
				break
		if blocked:
			return false
		if target != null:
			if game_state.resolve_capture_with_effects(piece, target, false) == CaptureResult.ILLEGAL:
				return false
		return true

	var dest_cells_nb := cells_at(piece, dest)
	for other in game_state.pieces.values():
		if other.uid == piece.uid:
			continue
		for cell in other.cells:
			if dest_cells_nb.has(cell):
				if other.owner == piece.owner and not game_state.can_capture_own_piece:
					return false
				if game_state.resolve_capture_with_effects(piece, other, false) == CaptureResult.ILLEGAL:
					return false
				break
	return true

# --- Footprint geometry (moved from board_controller; identical behaviour) ---

static func piece_dims(piece: Piece) -> Vector2i:
	match piece.type:
		Piece.Type.B:
			return Vector2i(1, 2) if piece.orientation == Piece.PieceOrientation.VERTICAL else Vector2i(2, 1)
		Piece.Type.C:
			return Vector2i(2, 2)
		_:
			return Vector2i(1, 1)

static func cells_at(piece: Piece, destination: Vector2i) -> Array[Vector2i]:
	var dims := piece_dims(piece)
	var cells: Array[Vector2i] = []
	for r in range(dims.y):
		for c in range(dims.x):
			cells.append(destination + Vector2i(c, r))
	return cells

static func b_new_cells_for_dest(piece: Piece, swung_cell: Vector2i) -> Array[Vector2i]:
	for cell in piece.cells:
		var diff := swung_cell - cell
		if abs(diff.x) + abs(diff.y) == 1:
			var min_cell := cell if (cell.y < swung_cell.y or (cell.y == swung_cell.y and cell.x < swung_cell.x)) else swung_cell
			var max_cell := swung_cell if min_cell == cell else cell
			var result: Array[Vector2i] = [min_cell, max_cell]
			return result
	var fallback: Array[Vector2i] = piece.cells.duplicate()
	return fallback
