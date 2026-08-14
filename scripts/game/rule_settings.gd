extends Node

# ---- Persisted rule choices ----
# true = base/standard game, false = house-rule variant, matching GameRules.
var close_call_shields_all_simultaneous_mutuals: bool = true
var c_captures_resolve_independently: bool = true
var general_can_capture_cycle_pieces: bool = true
var mutual_destruction_both_draw: bool = true
var blitzkrieg_old_different_piece: bool = true
var require_move_to_end_turn: bool = true

var objective_saboteurs_only: bool = true

var ityd_deployment_zone_only: bool = true

# ---- Player colors ----
# Six selectable side colors: red, blue, green, yellow, magenta, lavender.
var side_one_color: String = "blue"
var side_two_color: String = "red"

func apply_to(rules: GameRules) -> void:
	rules.close_call_shields_all_simultaneous_mutuals = close_call_shields_all_simultaneous_mutuals
	rules.c_captures_resolve_independently = c_captures_resolve_independently
	rules.general_can_capture_cycle_pieces = general_can_capture_cycle_pieces
	rules.mutual_destruction_both_draw = mutual_destruction_both_draw
	rules.blitzkrieg_old_different_piece = blitzkrieg_old_different_piece
	rules.require_move_to_end_turn = require_move_to_end_turn
	rules.objective_saboteurs_only = objective_saboteurs_only


# ---- Derived color scheme (General / Saboteur reveal / legal-move highlight) ----
const GENERAL_SCHEME := {
	"blue":     {"bg": "yellow",   "fg": "black"},
	"red":      {"bg": "black",    "fg": "yellow"},
	"yellow":   {"bg": "magenta",  "fg": "black"},
	"magenta":  {"bg": "black",    "fg": "lavender"},
	"green":    {"bg": "lavender", "fg": "black"},
	"lavender": {"bg": "black",    "fg": "magenta"},
}

const COLOR_HEX_DEFAULT := {
	"red":      Color("#EA2B3D"),
	"blue":     Color("#3A5FEE"),
	"green":    Color("#39FF14"),
	"yellow":   Color("#FFCC00"),
	"magenta":  Color("#FF00FF"),
	"lavender": Color("#CB94F7"),
	"orange":   Color("#FD6A00"),
	"black":    Color("#141414"),
}

# Compatibility property. Twelve scripts already read RuleSettings.COLOR_HEX[k],
# so keeping the name means none of them need editing. Returns whichever palette
# the active texture pack supplies, with any missing key falling back to default.
var COLOR_HEX: Dictionary:
	get:
		var tm: Node = get_node_or_null("/root/TextureManager")
		if tm == null:
			return COLOR_HEX_DEFAULT
		return tm.palette()

func general_colors(side: int) -> Dictionary:
	var key: String = side_one_color if side == 1 else side_two_color
	var scheme = GENERAL_SCHEME.get(key, GENERAL_SCHEME["blue"])
	return { "bg": COLOR_HEX[scheme["bg"]], "fg": COLOR_HEX[scheme["fg"]] }

func green_in_play() -> bool:
	return side_one_color == "green" or side_two_color == "green"

# owner_is_first_player: true for Blue (fixed by turn order), false for Red.
func saboteur_colors(owner_is_first_player: bool) -> Dictionary:
	var accent: Color = COLOR_HEX["orange"] if green_in_play() else COLOR_HEX["green"]
	var black: Color = COLOR_HEX["black"]
	if owner_is_first_player:
		return { "bg": accent, "fg": black }
	return { "bg": black, "fg": accent }

func ghost_frame_color() -> Color:
	return COLOR_HEX["orange"] if green_in_play() else COLOR_HEX["green"]
