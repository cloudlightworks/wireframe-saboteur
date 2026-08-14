extends Node2D

@onready var top_half: Sprite2D = $TopHalf
@onready var bottom_half: Sprite2D = $BottomHalf

func _ready() -> void:
	refresh_colors()

func refresh_colors() -> void:
	# Built-in packs use .svg (imported at build time). Imported user packs are
	# PNG only, because Godot cannot rasterise SVG at runtime. Try both.
	var top := _half_texture(RuleSettings.side_one_color)
	var bottom := _half_texture(RuleSettings.side_two_color)
	if top != null:
		top_half.texture = top
	if bottom != null:
		bottom_half.texture = bottom


func _half_texture(color_key: String) -> Texture2D:
	# Both extensions must be offered as candidates in one call. Asking for the
	# .svg alone would match the DEFAULT theme's svg via fallback before the
	# active theme's .png was ever tried.
	var names: Array = ["board_half_%s.svg" % color_key, "board_half_%s.png" % color_key]
	return TextureManager.resolve("board", names)["texture"]
