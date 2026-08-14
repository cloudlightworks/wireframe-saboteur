extends Resource
class_name Card

enum Category { CHART, TYPE, MINOR_POWER, MAJOR_POWER }
enum MinorEffect { GET_MOVE_ON, CLOSE_CALL, I_THOUGHT_YOU_WERE_DEAD, JUST_IN_CASE }
enum MajorEffect { INEFFECTIVE_LEADERSHIP, HE_SEEMED_SUSPICIOUS, JUST_THIS_ONCE, BLITZKRIEG, IM_ON_TO_YOU, ONE_MAN_ARMY, DOUBLE_AGENT }

var uid: int
var category: Category

# TYPE cards only — array covers both single (e.g. [A]) and multi (e.g. [A, B]) type cards
var piece_types: Array[Piece.Type] = []

# CHART cards only
var chart_values: Dictionary = {}   # { Piece.Type.A: 1, Piece.Type.B: 3, Piece.Type.C: 2 }

func value_for(target_type: Piece.Type) -> int:
	return chart_values.get(target_type, -1)

# MINOR_POWER cards only
var minor_effect: MinorEffect
var effect_piece_type: Piece.Type   # GET_MOVE_ON, CLOSE_CALL, I_THOUGHT_YOU_WERE_DEAD only; unused for JUST_IN_CASE

# MAJOR_POWER cards only
var major_effect: MajorEffect
