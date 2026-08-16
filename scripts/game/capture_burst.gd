extends Sprite2D
class_name CaptureBurst

# Player colors for tinting (fill is white in the asset so modulate sets the hue)
const BLUE_TINT := Color(0.30, 0.50, 0.95)
const RED_TINT := Color(0.90, 0.28, 0.28)

const GROW_TIME := 0.14
const HOLD_POP := 0.06
const FADE_TIME := 0.22
const PEAK_SCALE := 1.15   # overshoot past final size for the "pop"
const FINAL_SCALE := 0.9   # relative to one cell after normalizing
const SPIN_DEGREES := 22.0

func _ready() -> void:
	texture = load("res://assets/sprites/fx/capture_burst.png")
	centered = true
	z_index = 100  # draw above pieces

# cells: the Array[Vector2i] the destroyed piece occupied. owner: its side (for tint).
func play_at(cells: Array[Vector2i], owner: Piece.Owner) -> void:
	position = _centroid_world(cells)
	var side_key := RuleSettings.side_one_color if owner == Piece.Owner.BLUE else RuleSettings.side_two_color
	modulate = RuleSettings.COLOR_HEX[side_key]

	# Normalize: 1024px art scaled so FINAL_SCALE ≈ one cell for a 1x1 piece.
	# Larger pieces (B/C) get a proportionally bigger burst via cell span.
	var span := _cell_span(cells)
	var base := (float(BoardView.CELL) * span * FINAL_SCALE) / 1024.0
	scale = Vector2.ZERO
	rotation_degrees = -SPIN_DEGREES * 0.5

	var tw := create_tween().set_parallel(true)
	# Grow with slight overshoot
	tw.tween_property(self, "scale", Vector2(base, base) * PEAK_SCALE, GROW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Gentle spin throughout
	tw.tween_property(self, "rotation_degrees", SPIN_DEGREES * 0.5, GROW_TIME + FADE_TIME)
	# After the grow, settle + fade out
	tw.chain()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(self, "scale", Vector2(base, base), HOLD_POP)
	tw2.chain().tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw2.parallel().tween_property(self, "scale", Vector2(base, base) * 1.05, FADE_TIME)
	tw2.chain().tween_callback(queue_free)

func _centroid_world(cells: Array[Vector2i]) -> Vector2:
	# Convert each cell to its center first, then average the world positions.
	# Averaging cells and then converting would also work unflipped, but this
	# order stays correct under a board flip.
	var sum := Vector2.ZERO
	for c in cells:
		sum += BoardView.grid_to_world_center(c)
	return sum / float(cells.size())

func _cell_span(cells: Array[Vector2i]) -> float:
	if cells.size() <= 1:
		return 1.0
	var min_c := cells[0]
	var max_c := cells[0]
	for c in cells:
		min_c.x = mini(min_c.x, c.x); min_c.y = mini(min_c.y, c.y)
		max_c.x = maxi(max_c.x, c.x); max_c.y = maxi(max_c.y, c.y)
	# average of width/height in cells, so a 2x2 C burst is bigger than a 1x1 A
	return (float(max_c.x - min_c.x + 1) + float(max_c.y - min_c.y + 1)) * 0.5
