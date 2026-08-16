extends Node2D
class_name PieceView

const CELL = 64

var piece: Piece
var _saboteur_pulse_tween: Tween
var _select_pulse_tween: Tween

func setup(p: Piece) -> void:
	piece = p
	_update_sprite()
	_update_position()

func _update_sprite() -> void:
	var sprite := Sprite2D.new()
	var names: Array = _sprite_names()
	var needs_label: bool = false
	if names.size() > 0:
		var r: Dictionary = TextureManager.resolve("pieces", names)
		sprite.texture = r["texture"]
		# Label only when a blank from the active theme matched. The numbered
		# candidate is always index 0, so anything past it is a blank.
		needs_label = r["own"] and r["rel"] != names[0]
	sprite.centered = false
	sprite.scale = Vector2(0.5, 0.5)

	# Guard: if the sprite path was empty or the PNG failed to load, texture is
	# null and null.get_size() would throw -- which previously aborted piece-view
	# building mid-loop (this is what wedged the tutorial after the first lesson).
	# Fall back to a cell-sized placeholder so a missing sprite degrades to a
	# visible box instead of crashing.
	var tex_size: Vector2
	if sprite.texture != null:
		tex_size = sprite.texture.get_size() * 0.5
	else:
		var span_x := 1
		var span_y := 1
		if piece != null and piece.cells.size() > 0:
			var minx := piece.cells[0].x
			var maxx := piece.cells[0].x
			var miny := piece.cells[0].y
			var maxy := piece.cells[0].y
			for c in piece.cells:
				minx = mini(minx, c.x); maxx = maxi(maxx, c.x)
				miny = mini(miny, c.y); maxy = maxi(maxy, c.y)
			span_x = maxx - minx + 1
			span_y = maxy - miny + 1
		tex_size = Vector2(span_x * CELL, span_y * CELL) * 0.5
		# Visible placeholder fill so the piece still shows.
		var fill := ColorRect.new()
		fill.color = Color(0.6, 0.6, 0.6, 0.85)
		fill.size = tex_size
		fill.position = Vector2.ZERO
		sprite.add_child(fill)

	# The rectangular backing plate only reads as an outline when the art fills
	# its bounding box. Round or irregular art (Rose Court cameos) shows it in
	# the corners as a black square. The sprite's own outline shader follows the
	# alpha silhouette correctly, so themes that opt out get the shader alone.
	if TextureManager.active().get("plate", true):
		var border := ColorRect.new()
		border.color = Color(0.08, 0.08, 0.08, 0.9)
		border.size = tex_size + Vector2(4, 4)
		border.position = Vector2(-2, -2)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)
	add_child(sprite)
	if needs_label:
		add_child(_make_designation_label(tex_size))

	# Only apply the outline shader when there's a real texture (the shader keys
	# off the sprite's alpha edges; a null-texture placeholder has none).
	if sprite.texture != null:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/piece_outline.gdshader")
		mat.set_shader_parameter("outline_width", 2.0)
		mat.set_shader_parameter("state", 0)
		sprite.material = mat

# Draws the piece designation over a type blank. Sized from the sprite so B and
# C pieces get proportionally larger text.
func _make_designation_label(tex_size: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = piece.designation
	lbl.size = tex_size
	lbl.position = Vector2.ZERO
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var short_side: float = minf(tex_size.x, tex_size.y)
	var fsize: int = int(clampf(short_side * 0.42, 9.0, 30.0))
	var lf: Font = TextureManager.label_font()
	if lf != null:
		lbl.add_theme_font_override("font", lf)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", TextureManager.label_color())
	lbl.add_theme_color_override("font_outline_color", _label_outline())
	lbl.add_theme_constant_override("outline_size", maxi(2, int(fsize * 0.14)))
	return lbl


func _label_outline() -> Color:
	var c: Color = TextureManager.label_color()
	if c.get_luminance() < 0.5:
		return Color(1, 1, 1, 0.85)
	return Color(0, 0, 0, 0.75)
	
func _update_position() -> void:
	position = BoardView.cells_to_world(piece.cells)

# Returns candidate filenames, best first: the exact numbered file, then the
# type blank when the active theme wants engine-drawn designations.
func _sprite_names() -> Array:
	if piece.has_status("saboteur"):
		var accent_cap: String = "Orange" if RuleSettings.green_in_play() else "Green"
		var accent_low: String = "orange" if RuleSettings.green_in_play() else "green"
		var back: String = ("blackOn%s" % accent_cap) if piece.owner == Piece.Owner.BLUE else ("%sOnBlack" % accent_low)
		match piece.type:
			Piece.Type.A:
				return ["back_%s_A.png" % back]
			Piece.Type.B:
				var orient: String = "horizontal" if piece.orientation == Piece.PieceOrientation.HORIZONTAL else "vertical"
				return ["back_%s_B_%s.png" % [back, orient]]
			Piece.Type.C:
				return ["back_%s_C.png" % back]
			_:
				pass
	var side: String = RuleSettings.side_one_color if piece.owner == Piece.Owner.BLUE else RuleSettings.side_two_color
	var use_blanks: bool = TextureManager.labels_enabled()
	match piece.type:
		Piece.Type.A:
			var a: Array = ["%s_%s.png" % [side, piece.designation]]
			if use_blanks:
				a.append("%s_A.png" % side)
			return a
		Piece.Type.B:
				var orient: String = "horizontal" if piece.orientation == Piece.PieceOrientation.HORIZONTAL else "vertical"
				var b: Array = ["%s_%s_%s.png" % [side, piece.designation, orient]]
				if use_blanks:
					b.append("%s_B_%s.png" % [side, orient])
				return b
		Piece.Type.C:
			var c: Array = ["%s_%s.png" % [side, piece.designation]]
			if use_blanks:
				c.append("%s_C.png" % side)
			return c
		Piece.Type.GENERAL:
			return ["general_%s.png" % side]
		Piece.Type.OBJECTIVE:
			return ["objective_%s.png" % side]
	return []

func set_outline_width(w: float) -> void:
	for child in get_children():
		if child is Sprite2D and child.material is ShaderMaterial:
			child.material.set_shader_parameter("outline_width", w)

func set_state(state: int) -> void:
	for child in get_children():
		if child is Sprite2D and child.material is ShaderMaterial:
			child.material.set_shader_parameter("state", state)

# Whole-piece green pulse for "eligible to be confirmed as Saboteur". Mirrors
# HandPanel's discard-mode red pulse on cards: a looping tween alternating the
# node's modulate between a tint and white. This tints the sprite AND its border
# together (the whole piece), not just the outline. Works because
# piece_outline.gdshader now multiplies COLOR by MODULATE at the end; at white
# it's a no-op, so no other state is affected.
func set_saboteur_pulse(active: bool) -> void:
	if _saboteur_pulse_tween:
		_saboteur_pulse_tween.kill()
		_saboteur_pulse_tween = null
	if active:
		modulate = Color.WHITE
		_saboteur_pulse_tween = create_tween().set_loops()
		_saboteur_pulse_tween.tween_property(self, "modulate", TextureManager.pulse_color(), 0.5)
		_saboteur_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	else:
		modulate = Color.WHITE

func refresh_position() -> void:
	_update_position()

# Pulsing gold selection outline. Thicker and faster than the old static 5.0.
# Tweak MIN/MAX for thickness and PERIOD for speed.
func set_selection_pulse(active: bool) -> void:
	const MIN_W := 6.0
	const MAX_W := 14.0
	const PERIOD := 0.5
	if _select_pulse_tween:
		_select_pulse_tween.kill()
		_select_pulse_tween = null
	if active:
		_select_pulse_tween = create_tween().set_loops()
		_select_pulse_tween.tween_method(set_outline_width, MIN_W, MAX_W, PERIOD)
		_select_pulse_tween.tween_method(set_outline_width, MAX_W, MIN_W, PERIOD)
	else:
		set_outline_width(2.0)
