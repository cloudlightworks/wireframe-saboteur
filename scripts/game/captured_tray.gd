extends CanvasLayer
class_name CapturedTray

signal captured_piece_clicked(piece: Piece)

# ---- Placement (left margin; tray sits below the turn indicator / End Turn button) ----
const TRAY_X := 12.0
const TRAY_TOP := 200.0
const TRAY_W := 255.0
const TILE := 26.0
const DRAG_THRESHOLD := 6.0

# ---- Palette ----
const COL_INK := Color("#141414")
const COL_GOLD := Color("#FFD400")

var game_state: GameState

var _window: PanelContainer
var _red_grid: HFlowContainer
var _blue_grid: HFlowContainer
var _red_half: PanelContainer
var _blue_half: PanelContainer
var _red_bar: ColorRect
var _blue_bar: ColorRect
var _red_header: Label
var _blue_header: Label

var _dragging: bool = false
var _drag_moved: bool = false
var _drag_press_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

func setup(gs: GameState) -> void:
	game_state = gs
	_build_frame()
	refresh()

# Global-space rect of the tray window, for external UI that anchors to it.
# Returns Rect2.ZERO before the frame is built.
func window_rect() -> Rect2:
	if _window == null:
		return Rect2()
	return Rect2(_window.global_position, _window.size)
	
func _build_frame() -> void:
	var window := PanelContainer.new()
	window.position = Vector2(TRAY_X, TRAY_TOP)
	window.custom_minimum_size = Vector2(TRAY_W, 0)
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.gui_input.connect(_on_window_input)
	_window = window
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = Color.WHITE
	win_sb.set_corner_radius_all(12)
	win_sb.shadow_color = Color(0, 0, 0, 0.45)
	win_sb.shadow_size = 9
	win_sb.shadow_offset = Vector2(0, 5)
	win_sb.content_margin_left = 12
	win_sb.content_margin_right = 12
	win_sb.content_margin_top = 12
	win_sb.content_margin_bottom = 14
	window.add_theme_stylebox_override("panel", win_sb)
	add_child(window)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	window.add_child(col)

	var title := Label.new()
	title.text = "Captured Pieces"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", COL_INK)
	col.add_child(title)

	var rule := VBoxContainer.new()
	rule.add_theme_constant_override("separation", 4)
	_red_bar = ColorRect.new()
	_red_bar.color = RuleSettings.COLOR_HEX[RuleSettings.side_two_color]
	_red_bar.custom_minimum_size = Vector2(0, 2)
	_blue_bar = ColorRect.new()
	_blue_bar.color = RuleSettings.COLOR_HEX[RuleSettings.side_one_color]
	_blue_bar.custom_minimum_size = Vector2(0, 2)
	rule.add_child(_red_bar)
	rule.add_child(_blue_bar)
	col.add_child(rule)

	var frame_outer := PanelContainer.new()
	var fo_sb := StyleBoxFlat.new()
	fo_sb.bg_color = Color.WHITE
	fo_sb.set_border_width_all(2)
	fo_sb.border_color = COL_INK
	fo_sb.set_corner_radius_all(10)
	fo_sb.content_margin_left = 3
	fo_sb.content_margin_right = 3
	fo_sb.content_margin_top = 3
	fo_sb.content_margin_bottom = 3
	frame_outer.add_theme_stylebox_override("panel", fo_sb)
	col.add_child(frame_outer)

	var frame_inner := PanelContainer.new()
	var fi_sb := StyleBoxFlat.new()
	fi_sb.bg_color = Color.WHITE
	fi_sb.set_border_width_all(1)
	fi_sb.border_color = COL_INK
	fi_sb.set_corner_radius_all(7)
	frame_inner.add_theme_stylebox_override("panel", fi_sb)
	frame_outer.add_child(frame_inner)

	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 0)
	frame_inner.add_child(halves)

	_red_half = _build_half(RuleSettings.display_name(Piece.Owner.RED), RuleSettings.COLOR_HEX[RuleSettings.side_two_color], false, Piece.Owner.RED)
	_blue_half = _build_half(RuleSettings.display_name(Piece.Owner.BLUE), RuleSettings.COLOR_HEX[RuleSettings.side_one_color], true, Piece.Owner.BLUE)
	_red_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blue_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(_red_half)
	halves.add_child(_blue_half)

func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_moved = false
			_drag_press_pos = event.global_position
			_drag_offset = _window.global_position - event.global_position
		else:
			_dragging = false
			_drag_moved = false
	elif event is InputEventMouseMotion and _dragging:
		if not _drag_moved and event.global_position.distance_to(_drag_press_pos) > DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			_window.global_position = event.global_position + _drag_offset

func _build_half(header_text: String, color: Color, has_divider: bool, owner: Piece.Owner) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _half_style(false, has_divider))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 7)
	inner.custom_minimum_size = Vector2(0, 162)
	panel.add_child(inner)

	var header := Label.new()
	header.text = header_text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", color)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_theme_constant_override("outline_size", 4)
	inner.add_child(header)

	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(grid)

	if owner == Piece.Owner.RED:
		_red_grid = grid
		_red_header = header
	else:
		_blue_grid = grid
		_blue_header = header

	return panel

func refresh_colors() -> void:
	if _red_bar == null:
		return
	var red_color: Color = RuleSettings.COLOR_HEX[RuleSettings.side_two_color]
	var blue_color: Color = RuleSettings.COLOR_HEX[RuleSettings.side_one_color]

	_red_bar.color = red_color
	_blue_bar.color = blue_color

	_red_header.text = RuleSettings.display_name(Piece.Owner.RED)
	_red_header.add_theme_color_override("font_color", red_color)
	_blue_header.text = RuleSettings.display_name(Piece.Owner.BLUE)
	_blue_header.add_theme_color_override("font_color", blue_color)

	refresh()

func _half_style(active: bool, has_divider: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	if has_divider:
		sb.border_width_left = 1
		sb.border_color = COL_INK
	if active:
		sb.set_border_width_all(3)
		sb.border_color = TextureManager.ityd_color()
		sb.set_corner_radius_all(6)
	return sb

func refresh() -> void:
	if _red_grid == null or _blue_grid == null:
		return
	for c in _red_grid.get_children():
		c.queue_free()
	for c in _blue_grid.get_children():
		c.queue_free()

	var blue_active := (game_state.current_player == Piece.Owner.BLUE)
	var red_active := (game_state.current_player == Piece.Owner.RED)

	_red_half.add_theme_stylebox_override("panel", _half_style(red_active, false))
	_blue_half.add_theme_stylebox_override("panel", _half_style(blue_active, true))

	_populate(_red_grid, Piece.Owner.RED, red_active)
	_populate(_blue_grid, Piece.Owner.BLUE, blue_active)

func _populate(grid: HFlowContainer, side: Piece.Owner, clickable: bool) -> void:
	for piece in game_state.captured_pieces[side]:
		grid.add_child(_make_tile(piece, clickable))

func _make_tile(piece: Piece, clickable: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TILE, TILE)

	var side := RuleSettings.side_one_color if piece.owner == Piece.Owner.BLUE else RuleSettings.side_two_color
	var names: Array = ["tray/tray_%s_%s.png" % [side, piece.designation]]
	if TextureManager.labels_enabled():
		var tkey: String = ""
		match piece.type:
			Piece.Type.A:
				tkey = "A"
			Piece.Type.B:
				tkey = "B"
			Piece.Type.C:
				tkey = "C"
		if tkey != "":
			names.append("tray/tray_%s_%s.png" % [side, tkey])
	var res: Dictionary = TextureManager.resolve("pieces", names)
	var tex: Texture2D = res["texture"]
	var tray_needs_label: bool = res["own"] and res["rel"] != names[0]
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(TILE, TILE)
		tr.custom_minimum_size = Vector2(TILE, TILE)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	if tray_needs_label:
			var lbl := Label.new()
			lbl.text = piece.designation
			lbl.size = Vector2(TILE, TILE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fs: int = int(clampf(TILE * 0.46, 9.0, 22.0))
			lbl.add_theme_font_size_override("font_size", fs)
			lbl.add_theme_color_override("font_color", TextureManager.label_color())
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			lbl.add_theme_constant_override("outline_size", 3)
			holder.add_child(lbl)

	if clickable:
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.gui_input.connect(_on_tile_input.bind(piece))
		holder.mouse_entered.connect(_on_tile_hover.bind(holder, true))
		holder.mouse_exited.connect(_on_tile_hover.bind(holder, false))
	else:
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.modulate = Color(0.78, 0.78, 0.78)

	return holder

func _on_tile_hover(holder: Control, entering: bool) -> void:
	holder.modulate = Color(1.2, 1.2, 0.8) if entering else Color.WHITE

func _on_tile_input(event: InputEvent, piece: Piece) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print(">>> tile clicked, emitting: ", piece.designation)
		captured_piece_clicked.emit(piece)
