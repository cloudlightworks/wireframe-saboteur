extends RefCounted
class_name CroceSetup

const REQUIRED_COUNTS := {
	Piece.Type.A: 12,
	Piece.Type.B: 6,
	Piece.Type.C: 3,
	Piece.Type.GENERAL: 1,
	Piece.Type.OBJECTIVE: 1,
}

static func can_place_piece(piece: Piece, destination_cells: Array[Vector2i], game_state: GameState) -> bool:
	for cell in destination_cells:
		if not RulesEngine.is_on_board(cell, game_state.board):
			return false
	for cell in destination_cells:
		if not RulesEngine.is_in_own_half(cell, piece.owner, game_state.board):
			return false
	for cell in destination_cells:
		for existing in game_state.pieces.values():
			if existing.cells.has(cell):
				return false
	return true

static func place_piece(piece: Piece, destination_cells: Array[Vector2i], game_state: GameState) -> bool:
	if not can_place_piece(piece, destination_cells, game_state):
		return false
	piece.cells = destination_cells
	game_state.pieces[piece.uid] = piece
	return true

static func is_setup_complete(player: Piece.Owner, game_state: GameState) -> bool:
	var counts: Dictionary = {}
	for piece in game_state.pieces.values():
		if piece.owner == player:
			counts[piece.type] = counts.get(piece.type, 0) + 1
	for type in REQUIRED_COUNTS:
		if counts.get(type, 0) != REQUIRED_COUNTS[type]:
			return false
	return true
