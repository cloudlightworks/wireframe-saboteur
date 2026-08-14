extends Resource
class_name Piece
enum Type { A, B, C, GENERAL, OBJECTIVE }
enum Owner { BLUE, RED }
enum PieceOrientation { HORIZONTAL, VERTICAL }
var uid: int
var designation: String
var type: Type
var owner: Owner
var original_owner: Owner   # true side; set at creation, never changes on conversion
var cells: Array[Vector2i] = []
var orientation: PieceOrientation
var status_effects: Dictionary = {}
var _original_owner_set: bool = false
func has_status(tag: String) -> bool:
	return status_effects.has(tag)
func apply_saboteur_conversion(new_owner: Owner) -> void:
	if not _original_owner_set:
		original_owner = owner
		_original_owner_set = true
	owner = new_owner
	status_effects["saboteur"] = true

func reverse_saboteur_conversion(restoring_owner: Owner) -> void:
	owner = restoring_owner
	status_effects.erase("saboteur")
