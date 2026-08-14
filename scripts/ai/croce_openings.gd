extends RefCounted
class_name CroceOpenings

# ============================================================
# Croce opening repertoire — designed by Noah Matuszewski.
#
# Format: [designation, x, y, orientation]
#   designation — "A1".."A12", "B1".."B6", "C1".."C3", "General", "Objective"
#   x, y        — TOP-LEFT cell of the footprint
#   orientation — "V" or "H"; only meaningful for B pieces
#
# Blue deploys in rows 0-4, Red in rows 11-15. validate() enforces that,
# plus overlap and the 12/6/3/1/1 counts, so a transcription error shows up
# at load rather than mid-game.
# ============================================================

const BOARD_W := 18
const BLUE_BAND := [0, 4]
const RED_BAND := [11, 15]

const OPENINGS := {
	"fortress": {
		"blue": [
			["A8", 2, 1, "H"], ["A9", 8, 1, "H"], ["A10", 9, 1, "H"],
			["A11", 0, 2, "H"], ["A12", 1, 2, "H"],
			["A1", 3, 3, "H"], ["A2", 4, 3, "H"], ["A4", 5, 3, "H"],
			["A7", 8, 3, "H"], ["A6", 9, 3, "H"],
			["A3", 4, 4, "H"], ["A5", 9, 4, "H"],
			["B1", 2, 2, "V"], ["B3", 5, 1, "V"], ["B6", 8, 2, "H"],
			["B2", 2, 4, "H"], ["B4", 5, 4, "H"], ["B5", 7, 4, "H"],
			["C1", 0, 3, "H"], ["C2", 3, 1, "H"], ["C3", 6, 2, "H"],
			["Objective", 17, 0, "H"], ["General", 17, 1, "H"],
		],
		"red": [
			["A1", 0, 11, "H"], ["A2", 0, 12, "H"],
			["A5", 8, 11, "H"], ["A6", 8, 12, "H"],
			["A11", 10, 11, "H"], ["A12", 10, 12, "H"],
			["A3", 4, 13, "H"], ["A4", 5, 13, "H"],
			["A10", 4, 14, "H"], ["A7", 7, 14, "H"],
			["A9", 4, 15, "H"], ["A8", 7, 15, "H"],
			["B1", 1, 11, "V"], ["B2", 4, 11, "V"], ["B3", 5, 11, "V"],
			["B4", 9, 11, "V"], ["B5", 0, 13, "H"], ["B6", 8, 13, "H"],
			["C1", 2, 11, "H"], ["C2", 6, 11, "H"], ["C3", 5, 14, "H"],
			["General", 16, 11, "H"], ["Objective", 17, 15, "H"],
		],
	},

	"splitflank": {
		"blue": [
			["A11", 9, 0, "H"], ["A12", 12, 0, "H"],
			["A10", 6, 3, "H"], ["A9", 6, 4, "H"],
			["A7", 8, 3, "H"], ["A8", 8, 4, "H"],
			["A5", 12, 3, "H"], ["A2", 13, 3, "H"],
			["A6", 12, 4, "H"], ["A1", 13, 4, "H"],
			["A3", 16, 3, "H"], ["A4", 16, 4, "H"],
			["B4", 9, 1, "V"], ["B5", 12, 1, "V"], ["B6", 10, 2, "H"],
			["B3", 7, 3, "V"], ["B2", 11, 3, "V"], ["B1", 17, 3, "V"],
			["C3", 10, 0, "H"], ["C2", 9, 3, "H"], ["C1", 14, 3, "H"],
			["Objective", 0, 0, "H"], ["General", 1, 3, "H"],
		],
		"red": [
			["A1", 0, 11, "H"], ["A2", 1, 11, "H"],
			["A3", 4, 11, "H"], ["A4", 5, 11, "H"], ["A5", 6, 11, "H"],
			["A6", 7, 11, "H"], ["A7", 8, 11, "H"], ["A8", 9, 11, "H"],
			["A11", 0, 13, "H"], ["A12", 1, 13, "H"],
			["A9", 4, 13, "H"], ["A10", 5, 13, "H"],
			["B1", 0, 12, "H"], ["B2", 4, 12, "H"], ["B3", 6, 12, "V"],
			["B4", 9, 12, "V"], ["B6", 3, 14, "V"], ["B5", 6, 14, "V"],
			["C1", 2, 11, "H"], ["C2", 7, 12, "H"], ["C3", 4, 14, "H"],
			["General", 16, 11, "H"], ["Objective", 17, 15, "H"],
		],
	},

	"lineabreast": {
		"blue": [
			["A1", 0, 3, "H"], ["A2", 1, 3, "H"],
			["A4", 4, 3, "H"], ["A3", 4, 4, "H"],
			["A5", 5, 4, "H"], ["A6", 6, 4, "H"],
			["A7", 7, 2, "H"], ["A10", 10, 2, "H"],
			["A9", 13, 3, "H"], ["A8", 13, 4, "H"],
			["A11", 15, 3, "H"], ["A12", 15, 4, "H"],
			["B2", 0, 2, "H"], ["B1", 0, 4, "H"], ["B3", 5, 3, "H"],
			["B4", 9, 3, "V"], ["B5", 12, 3, "V"], ["B6", 14, 3, "V"],
			["C1", 2, 3, "H"], ["C2", 7, 3, "H"], ["C3", 10, 3, "H"],
			["Objective", 17, 0, "H"], ["General", 17, 1, "H"],
		],
		"red": [
			["A8", 12, 11, "H"], ["A7", 12, 12, "H"],
			["A1", 0, 13, "H"], ["A2", 3, 13, "H"], ["A3", 4, 13, "H"],
			["A4", 7, 13, "H"], ["A5", 8, 13, "H"],
			["A6", 11, 13, "H"], ["A12", 12, 13, "H"],
			["A9", 0, 14, "H"], ["A10", 3, 14, "H"], ["A11", 7, 14, "H"],
			["B1", 0, 11, "V"], ["B2", 3, 11, "V"], ["B3", 4, 11, "V"],
			["B4", 7, 11, "V"], ["B5", 8, 11, "V"], ["B6", 11, 11, "V"],
			["C1", 1, 11, "H"], ["C2", 5, 11, "H"], ["C3", 9, 11, "H"],
			["General", 17, 14, "H"], ["Objective", 17, 15, "H"],
		],
	},

	"wedge": {
		"blue": [
			["A8", 0, 1, "H"], ["A9", 3, 1, "H"], ["A10", 4, 1, "H"],
			["A1", 0, 2, "H"], ["A4", 3, 2, "H"], ["A3", 4, 2, "H"],
			["A6", 7, 2, "H"], ["A7", 8, 2, "H"],
			["A2", 4, 3, "H"], ["A5", 7, 3, "H"],
			["A12", 12, 3, "H"], ["A11", 12, 4, "H"],
			["B1", 0, 3, "V"], ["B2", 3, 3, "V"], ["B5", 8, 3, "V"],
			["B6", 11, 3, "V"], ["B3", 4, 4, "H"], ["B4", 6, 4, "H"],
			["C1", 1, 3, "H"], ["C2", 5, 2, "H"], ["C3", 9, 3, "H"],
			["Objective", 17, 0, "H"], ["General", 17, 1, "H"],
		],
		"red": [
			["A1", 0, 12, "H"], ["A2", 1, 12, "H"],
			["A7", 7, 12, "H"], ["A11", 12, 12, "H"], ["A12", 13, 12, "H"],
			["A3", 1, 13, "H"], ["A4", 3, 13, "H"], ["A5", 4, 13, "H"],
			["A6", 7, 13, "H"], ["A8", 8, 13, "H"],
			["A9", 9, 13, "H"], ["A10", 10, 13, "H"],
			["B1", 0, 11, "H"], ["B2", 4, 11, "V"], ["B3", 5, 11, "H"],
			["B4", 7, 11, "H"], ["B5", 11, 11, "V"], ["B6", 12, 11, "H"],
			["C1", 2, 11, "H"], ["C2", 5, 12, "H"], ["C3", 9, 11, "H"],
			["General", 17, 14, "H"], ["Objective", 17, 15, "H"],
		],
	},

	"phalanx": {
		"blue": [
			["A11", 1, 2, "H"], ["A12", 11, 2, "H"],
			["A2", 1, 3, "H"], ["A3", 4, 3, "H"], ["A5", 5, 3, "H"],
			["A6", 8, 3, "H"], ["A8", 9, 3, "H"], ["A10", 12, 3, "H"],
			["A1", 1, 4, "H"], ["A4", 4, 4, "H"],
			["A7", 9, 4, "H"], ["A9", 12, 4, "H"],
			["B5", 4, 2, "H"], ["B6", 8, 2, "H"], ["B1", 0, 3, "V"],
			["B4", 13, 3, "V"], ["B2", 5, 4, "H"], ["B3", 7, 4, "H"],
			["C1", 2, 3, "H"], ["C2", 6, 2, "H"], ["C3", 10, 3, "H"],
			["Objective", 17, 0, "H"], ["General", 17, 1, "H"],
		],
		"red": [
			["A1", 0, 11, "H"], ["A2", 1, 11, "H"], ["A3", 2, 11, "H"],
			["A4", 4, 11, "H"], ["A7", 7, 11, "H"], ["A11", 11, 11, "H"],
			["A5", 4, 12, "H"], ["A6", 7, 12, "H"], ["A10", 11, 12, "H"],
			["A8", 9, 13, "H"], ["A9", 10, 13, "H"], ["A12", 11, 13, "H"],
			["B2", 3, 11, "V"], ["B3", 5, 11, "H"], ["B5", 10, 11, "V"],
			["B1", 0, 12, "V"], ["B4", 3, 13, "H"], ["B6", 7, 13, "H"],
			["C1", 1, 12, "H"], ["C2", 5, 12, "H"], ["C3", 8, 11, "H"],
			["General", 17, 14, "H"], ["Objective", 17, 15, "H"],
		],
	},
}

# ------------------------------------------------------------

static func names() -> Array:
	return OPENINGS.keys()

static func random_name() -> String:
	var keys := OPENINGS.keys()
	return keys[randi() % keys.size()]

static func entries_for(opening: String, owner: Piece.Owner) -> Array:
	if not OPENINGS.has(opening):
		return []
	var key := "blue" if owner == Piece.Owner.BLUE else "red"
	return OPENINGS[opening].get(key, [])

static func cells_for(designation: String, x: int, y: int, orient: String) -> Array[Vector2i]:
	var letter := designation.substr(0, 1)
	if designation == "General" or designation == "Objective":
		var single: Array[Vector2i] = [Vector2i(x, y)]
		return single
	match letter:
		"C":
			var quad: Array[Vector2i] = [
				Vector2i(x, y), Vector2i(x + 1, y),
				Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
			]
			return quad
		"B":
			var pair: Array[Vector2i] = []
			if orient == "V":
				pair = [Vector2i(x, y), Vector2i(x, y + 1)]
			else:
				pair = [Vector2i(x, y), Vector2i(x + 1, y)]
			return pair
	var one: Array[Vector2i] = [Vector2i(x, y)]
	return one

static func type_for(designation: String) -> Piece.Type:
	if designation == "General":
		return Piece.Type.GENERAL
	if designation == "Objective":
		return Piece.Type.OBJECTIVE
	match designation.substr(0, 1):
		"B":
			return Piece.Type.B
		"C":
			return Piece.Type.C
	return Piece.Type.A

# Returns "" when the layout is sound, or a description of the first fault.
static func validate(opening: String, owner: Piece.Owner) -> String:
	var entries := entries_for(opening, owner)
	if entries.is_empty():
		return "no entries for %s/%s" % [opening, owner]

	var band: Array = BLUE_BAND if owner == Piece.Owner.BLUE else RED_BAND
	var seen: Dictionary = {}
	var counts := {"A": 0, "B": 0, "C": 0, "General": 0, "Objective": 0}

	for e in entries:
		var designation: String = e[0]
		var cells := cells_for(designation, e[1], e[2], e[3])
		for cell in cells:
			if cell.x < 0 or cell.x >= BOARD_W:
				return "%s off board at %s" % [designation, cell]
			if cell.y < band[0] or cell.y > band[1]:
				return "%s outside deployment band at %s" % [designation, cell]
			if seen.has(cell):
				return "%s overlaps %s at %s" % [designation, seen[cell], cell]
			seen[cell] = designation
		if designation == "General" or designation == "Objective":
			counts[designation] += 1
		else:
			counts[designation.substr(0, 1)] += 1

	if counts["A"] != 12:
		return "expected 12 A, found %d" % counts["A"]
	if counts["B"] != 6:
		return "expected 6 B, found %d" % counts["B"]
	if counts["C"] != 3:
		return "expected 3 C, found %d" % counts["C"]
	if counts["General"] != 1 or counts["Objective"] != 1:
		return "missing General or Objective"
	return ""
