extends Node

# Set by the menu, read by board_controller._ready(). change_scene_to_file()
# takes no parameters, so mode selection has to live outside the scene tree.
var vs_cpu: bool = false
var cpu_side: Piece.Owner = Piece.Owner.RED
var cpu_tier: int = 1

func reset() -> void:
	vs_cpu = false
	cpu_side = Piece.Owner.RED
	cpu_tier = 1
