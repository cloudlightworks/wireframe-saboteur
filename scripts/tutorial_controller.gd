extends Control
signal finished

const CELL := 64.0
const BOARD_ORIGIN := Vector2(-576, -512)
const GRID_SIZE := Vector2i(18, 16)
const TUTORIAL_DATA := preload("res://scripts/tutorial_data.gd")

const BLUE := Color("#4169E1")
const RED := Color("#E32636")
const GREEN := Color("#20c46b")
const GOLD := Color("#f0c52e")
const INK := Color("#141414")
const MUTED := Color("#6d6962")
const PAPER := Color("#fffefd")
const TIMELINE_HEIGHT := 54.0

# Tutorial-only card sizing. These do not alter cards in ordinary matches.
const HAND_CARD_WIDTH := 112.0
const LIMIT_CARD_WIDTH := 78.0
const HAND_AREA_HEIGHT := 240.0
const CATALOG_CARD_WIDTH := 168.0
const CATALOG_LABEL_WIDTH := 168.0

@onready var board_area: Control = $BoardArea
@onready var world: Node2D = $BoardArea/World
@onready var highlight_layer: Node2D = $BoardArea/World/HighlightLayer
@onready var piece_layer: Node2D = $BoardArea/World/PieceLayer
@onready var hand_layer: Control = $BoardArea/HandLayer
@onready var overlay = $Overlay

var steps: Array[Dictionary] = []
var step_index := -1
var pieces_by_uid: Dictionary = {}
var pieces_by_key: Dictionary = {}
var key_by_uid: Dictionary = {}
var views_by_uid: Dictionary = {}
var next_uid := 1
var selected_piece_key := ""
var croce_b_orientation := Piece.PieceOrientation.VERTICAL
var croce_hover_cell := Vector2i(-999, -999)
var legal_move_options: Array[Dictionary] = []
var input_locked := false
var lesson_resolved := false
var completed_steps: Dictionary = {}
var timeline_bar: PanelContainer = null
var timeline_buttons: Array[Button] = []
var catalog_layer: Control = null

var selected_cards: Array[String] = []
var card_panels: Dictionary = {}
var deploy_button: Button = null
var hand_mode := ""
var close_call_armed := false

func _ready() -> void:
	BoardView.flipped = false   # the tutorial is always in default orientation
	$BoardArea/World/Board.refresh_colors()
	steps = TUTORIAL_DATA.build_steps()
	overlay.next_pressed.connect(_on_next_pressed)
	overlay.action_pressed.connect(_on_action_pressed)
	overlay.restart_pressed.connect(_on_restart_pressed)
	overlay.exit_pressed.connect(_on_exit_pressed)
	board_area.gui_input.connect(_on_board_gui_input)
	resized.connect(_on_layout_changed)
	get_viewport().size_changed.connect(_on_layout_changed)
	_build_timeline()
	call_deferred("_begin")

func _begin() -> void:
	step_index = 0
	_enter_step()

func _process(_delta: float) -> void:
	if input_locked:
		return
	if _current_step().get("action", "") != "place":
		return

	var cell := _cell_from_mouse()
	if cell != croce_hover_cell:
		croce_hover_cell = cell
		_render_croce_ghost()

func _current_step() -> Dictionary:
	if step_index < 0 or step_index >= steps.size():
		return {}
	return steps[step_index]

func _enter_step() -> void:
	if step_index < 0 or step_index >= steps.size():
		finished.emit()
		return

	input_locked = false
	lesson_resolved = false
	selected_piece_key = ""
	legal_move_options.clear()
	croce_hover_cell = Vector2i(-999, -999)

	var step := _current_step()
	overlay.show_step(step, step_index, steps.size())
	_load_setup(step.get("setup", "empty"))

	if step.has("convert_piece"):
		var convert_key: String = step.get("convert_piece", "")
		if pieces_by_key.has(convert_key):
			var converted: Piece = pieces_by_key[convert_key]
			converted.apply_saboteur_conversion(step.get("convert_owner", Piece.Owner.BLUE))
			_refresh_piece_views()

	close_call_armed = step.get("close_call_armed", false)

	if step.has("hand"):
		_configure_hand(step.get("hand", ""))
	else:
		_clear_hand()

	_configure_overlay_buttons(step.get("action", "continue"))
	_prepare_step_highlights()
	_update_timeline()
	call_deferred("_apply_focus")

func _configure_overlay_buttons(action: String) -> void:
	match action:
		"continue":
			overlay.configure_buttons(true, "Continue")
		"place":
			var piece_type: Piece.Type = _current_step().get("piece_type", Piece.Type.A)
			if piece_type == Piece.Type.B:
				overlay.configure_buttons(false, "", true, "Rotate B")
			else:
				overlay.configure_buttons(false)
		"complete":
			overlay.configure_buttons(true, "Return to menu")
		_:
			overlay.configure_buttons(false)

func _on_next_pressed() -> void:
	var action: String = _current_step().get("action", "continue")
	if action == "complete":
		completed_steps[step_index] = true
		finished.emit()
		return
	if lesson_resolved or action == "continue":
		completed_steps[step_index] = true
		_advance()

func _on_action_pressed() -> void:
	if input_locked:
		return
	var step := _current_step()
	if step.get("action", "") == "place" and step.get("piece_type", Piece.Type.A) == Piece.Type.B:
		_toggle_pending_b_orientation()

func _on_restart_pressed() -> void:
	_enter_step()

func _on_timeline_pressed(index: int) -> void:
	if index < 0 or index >= steps.size():
		return
	step_index = index
	_enter_step()

func _on_exit_pressed() -> void:
	finished.emit()

func _advance() -> void:
	step_index += 1
	_enter_step()

func _build_timeline() -> void:
	timeline_bar = PanelContainer.new()
	timeline_bar.name = "Timeline"
	timeline_bar.z_index = 100
	timeline_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(timeline_bar)
	timeline_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	timeline_bar.offset_left = 0
	timeline_bar.offset_top = 0
	timeline_bar.offset_right = 0
	timeline_bar.offset_bottom = TIMELINE_HEIGHT

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.98)
	panel_style.border_color = Color("#c9c5bc")
	panel_style.border_width_bottom = 1
	panel_style.shadow_color = Color(0, 0, 0, 0.18)
	panel_style.shadow_size = 5
	panel_style.shadow_offset = Vector2(0, 2)
	timeline_bar.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	timeline_bar.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	timeline_buttons.clear()
	for i in range(steps.size()):
		var button := Button.new()
		button.text = "%02d" % [i + 1]
		button.tooltip_text = "%02d — %s" % [i + 1, steps[i].get("title", "Lesson")]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(24, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_timeline_pressed.bind(i))
		row.add_child(button)
		timeline_buttons.append(button)

	_update_timeline()

func _update_timeline() -> void:
	for i in range(timeline_buttons.size()):
		var button := timeline_buttons[i]
		var background := Color("#ece9e2")
		var border := Color("#bdb8ae")
		var text_color := INK

		if i == step_index:
			background = GOLD
			border = INK
		elif completed_steps.has(i):
			background = BLUE
			border = BLUE.darkened(0.18)
			text_color = Color.WHITE

		var normal := _timeline_style(background, border)
		var hover := _timeline_style(background.lightened(0.1), border)
		var pressed := _timeline_style(background.darkened(0.08), border)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", normal)
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)

func _timeline_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			var step := _current_step()
			if not input_locked and step.get("action", "") == "place" and step.get("piece_type", Piece.Type.A) == Piece.Type.B:
				_toggle_pending_b_orientation()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_show_exit_confirm()
			get_viewport().set_input_as_handled()

var _exit_confirm: CanvasLayer = null

func _show_exit_confirm() -> void:
	if _exit_confirm != null:
		return   # already open — Escape again does nothing

	_exit_confirm = CanvasLayer.new()
	_exit_confirm.layer = 80
	add_child(_exit_confirm)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.position = Vector2.ZERO
	shade.size = get_viewport().get_visible_rect().size
	_exit_confirm.add_child(shade)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = get_viewport().get_visible_rect().size
	_exit_confirm.add_child(center)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text = "Leave the tutorial?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Your progress won't be saved."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var stay := Button.new()
	stay.text = "Keep Going"
	stay.custom_minimum_size = Vector2(160, 46)
	stay.pressed.connect(_close_exit_confirm)
	row.add_child(stay)

	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(160, 46)
	leave.pressed.connect(func():
		_close_exit_confirm()
		finished.emit()
	)
	row.add_child(leave)

	col.add_child(row)
	box.add_child(col)
	center.add_child(box)
	stay.grab_focus()

func _close_exit_confirm() -> void:
	if _exit_confirm != null:
		_exit_confirm.queue_free()
		_exit_confirm = null
		
# -----------------------------------------------------------------------------
# Board layout and input
# -----------------------------------------------------------------------------

func _on_layout_changed() -> void:
	call_deferred("_apply_focus")

func _apply_focus() -> void:
	if not is_instance_valid(board_area):
		return

	# The tutorial is inserted beneath MenuRoot, whose scene root is a plain Node.
	# Anchor-based Control layout can therefore arrive one or more frames late.
	# BoardArea also clips its children, so a zero-sized rect hides the board,
	# pieces, and highlights completely. Establish usable geometry directly from
	# the viewport whenever either the tutorial root or BoardArea has not laid out.
	var viewport_size := get_viewport().get_visible_rect().size

	if size.x <= 1.0 or size.y <= 1.0:
		position = Vector2.ZERO
		size = viewport_size

	var root_size := size
	if root_size.x <= 1.0 or root_size.y <= 1.0:
		root_size = viewport_size

	var area_size := board_area.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		area_size = Vector2(
			maxf(100.0, root_size.x * 0.72),
			maxf(100.0, root_size.y)
		)
		board_area.position = Vector2.ZERO
		board_area.size = area_size

	# Use the derived dimensions for this pass even if Godot has not yet
	# propagated the Control layout internally.
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		push_warning("Tutorial: could not establish a usable BoardArea size.")
		return

	var region: Rect2i = _current_step().get("focus", Rect2i(0, 0, 18, 16))
	var hand_height := HAND_AREA_HEIGHT if hand_layer.visible else 0.0
	var top_inset := TIMELINE_HEIGHT + 14.0
	var available := Rect2(
		Vector2(14, top_inset),
		Vector2(
			maxf(100.0, area_size.x - 28.0),
			maxf(100.0, area_size.y - top_inset - 14.0 - hand_height)
		)
	)

	var region_center := BOARD_ORIGIN + Vector2(
		(float(region.position.x) + float(region.size.x) * 0.5) * CELL,
		(float(region.position.y) + float(region.size.y) * 0.5) * CELL
	)
	var margin := Vector2(220, 220) if region.size == GRID_SIZE else Vector2(150, 150)
	var region_pixels := Vector2(region.size) * CELL + margin
	var scale_value := minf(
		available.size.x / region_pixels.x,
		available.size.y / region_pixels.y
	)
	scale_value = clampf(scale_value, 0.34, 1.28)

	world.scale = Vector2(scale_value, scale_value)
	world.position = available.position + available.size * 0.5 - region_center * scale_value

func _on_board_gui_input(event: InputEvent) -> void:
	if input_locked:
		return

	if event is InputEventMouseMotion:
		if _current_step().get("action", "") == "place":
			croce_hover_cell = _cell_from_mouse()
			_render_croce_ghost()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_from_mouse()
		if _is_on_board(cell):
			_handle_cell_click(cell)
		board_area.accept_event()

func _cell_from_mouse() -> Vector2i:
	# World is translated and scaled for each lesson. Asking World for its local
	# mouse position applies the inverse transform directly and avoids the
	# coordinate drift that prevented A1 from being selected.
	var world_position := world.get_local_mouse_position()
	return Vector2i(
		floori((world_position.x - BOARD_ORIGIN.x) / CELL),
		floori((world_position.y - BOARD_ORIGIN.y) / CELL)
	)

func _is_on_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y

func _handle_cell_click(cell: Vector2i) -> void:
	var action: String = _current_step().get("action", "")
	match action:
		"place":
			_handle_place_click(cell)
		"move", "try_illegal":
			_handle_move_click(cell)
		_:
			overlay.set_status("This lesson advances from the controls on the right.")

# -----------------------------------------------------------------------------
# Piece setup and views
# -----------------------------------------------------------------------------

func _load_setup(name: String) -> void:
	_clear_pieces()
	croce_b_orientation = Piece.PieceOrientation.VERTICAL
	close_call_armed = false
	for spec in TUTORIAL_DATA.setup_pieces(name):
		_create_piece_from_spec(spec)
	_refresh_piece_views()

func _clear_pieces() -> void:
	pieces_by_uid.clear()
	pieces_by_key.clear()
	key_by_uid.clear()
	views_by_uid.clear()
	next_uid = 1
	_clear_children(piece_layer)
	_clear_children(highlight_layer)

func _create_piece_from_spec(spec: Dictionary) -> Piece:
	var piece := Piece.new()
	piece.uid = next_uid
	next_uid += 1
	piece.designation = spec.get("designation", "A1")
	piece.type = spec.get("type", Piece.Type.A)
	piece.owner = spec.get("owner", Piece.Owner.BLUE)
	piece.original_owner = piece.owner
	piece._original_owner_set = true
	piece.orientation = spec.get("orientation", Piece.PieceOrientation.VERTICAL)
	var typed_cells: Array[Vector2i] = []
	for cell in spec.get("cells", []):
		typed_cells.append(cell)
	piece.cells = typed_cells
	var key: String = spec.get("key", piece.designation)
	pieces_by_uid[piece.uid] = piece
	pieces_by_key[key] = piece
	key_by_uid[piece.uid] = key
	return piece

func _create_piece(key: String, designation: String, type: Piece.Type, owner: Piece.Owner, cells: Array[Vector2i], orientation: Piece.PieceOrientation = Piece.PieceOrientation.VERTICAL) -> Piece:
	return _create_piece_from_spec({
		"key": key,
		"designation": designation,
		"type": type,
		"owner": owner,
		"cells": cells,
		"orientation": orientation,
	})

func _refresh_piece_views() -> void:
	_clear_children(piece_layer)
	views_by_uid.clear()

	for piece in pieces_by_uid.values():
		var view := PieceView.new()
		view.setup(piece)

		# PieceView contains a decorative ColorRect border. Controls default to
		# MOUSE_FILTER_STOP, which prevents BoardArea from receiving clicks made
		# directly on the piece.
		for child in view.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

		piece_layer.add_child(view)
		views_by_uid[piece.uid] = view

func _remove_piece(key: String) -> void:
	if not pieces_by_key.has(key):
		return
	var piece: Piece = pieces_by_key[key]
	pieces_by_key.erase(key)
	pieces_by_uid.erase(piece.uid)
	key_by_uid.erase(piece.uid)

func _piece_at_cell(cell: Vector2i) -> Piece:
	for piece in pieces_by_uid.values():
		if piece.cells.has(cell):
			return piece
	return null

func _key_for_piece(piece: Piece) -> String:
	return key_by_uid.get(piece.uid, "")

func _piece_cells_for_placement(type: Piece.Type, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match type:
		Piece.Type.B:
			cells.append(anchor)
			cells.append(anchor + (Vector2i.RIGHT if croce_b_orientation == Piece.PieceOrientation.HORIZONTAL else Vector2i.DOWN))
		Piece.Type.C:
			cells.append(anchor)
			cells.append(anchor + Vector2i.RIGHT)
			cells.append(anchor + Vector2i.DOWN)
			cells.append(anchor + Vector2i(1, 1))
		_:
			cells.append(anchor)
	return cells

# -----------------------------------------------------------------------------
# Highlights
# -----------------------------------------------------------------------------

func _prepare_step_highlights() -> void:
	_clear_children(highlight_layer)
	legal_move_options.clear()

	for view in views_by_uid.values():
		view.set_state(0)
		view.set_outline_width(2.0)

	var step := _current_step()
	var action: String = step.get("action", "")

	if action == "place":
		_render_croce_ghost()
		return

	if action == "move" or action == "try_illegal":
		if selected_piece_key.is_empty():
			return
		if not pieces_by_key.has(selected_piece_key):
			return

		_mark_piece(selected_piece_key, GOLD)
		var piece: Piece = pieces_by_key[selected_piece_key]
		legal_move_options = _legal_move_options_for(piece)
	for option in legal_move_options:
		var highlight_cells: Array[Vector2i] = []

		for cell in option.get("highlight_cells", option.get("new_cells", [])):
			highlight_cells.append(cell)

		_add_highlight(highlight_cells, GREEN)

		# Also outline every legally attackable opponent piece covered by this move.
		for target_key in option.get("targets", []):
			if not pieces_by_key.has(target_key):
				continue

			var target: Piece = pieces_by_key[target_key]
			var target_cells: Array[Vector2i] = []

			for target_cell in target.cells:
				target_cells.append(target_cell)

			_add_highlight(target_cells, GREEN)

func _mark_piece(key: String, _color: Color) -> void:
	if not pieces_by_key.has(key):
		return
	var piece: Piece = pieces_by_key[key]
	var view: PieceView = views_by_uid.get(piece.uid)
	if view:
		view.set_outline_width(5.0)
		view.set_state(1)

func _add_highlight(cells: Array[Vector2i], color: Color) -> void:
	if cells.is_empty():
		return

	var min_cell := cells[0]
	var max_cell := cells[0]

	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	var highlight := MoveHighlight.new()
	highlight.dest_cell = min_cell
	highlight.dims = max_cell - min_cell + Vector2i.ONE
	highlight.highlight_color = color
	highlight.position = BOARD_ORIGIN + Vector2(min_cell) * CELL

	# Render the frame above piece sprites, so occupied capture squares remain visible.
	highlight.z_index = 20

	highlight_layer.add_child(highlight)

# -----------------------------------------------------------------------------
# Croce placement
# -----------------------------------------------------------------------------

func _render_croce_ghost() -> void:
	if _current_step().get("action", "") != "place":
		return

	_clear_children(highlight_layer)

	var anchor := croce_hover_cell
	if anchor.x < -100:
		anchor = _cell_from_mouse()
		croce_hover_cell = anchor

	if not _is_on_board(anchor):
		return

	var step := _current_step()
	var type: Piece.Type = step.get("piece_type", Piece.Type.A)
	var owner: Piece.Owner = step.get("owner", Piece.Owner.BLUE)
	var cells := _piece_cells_for_placement(type, anchor)
	var valid := _can_place_in_croce(cells, owner)
	_add_highlight(cells, GREEN if valid else RED)

func _can_place_in_croce(cells: Array[Vector2i], owner: Piece.Owner) -> bool:
	for cell in cells:
		if not _is_on_board(cell):
			return false
		if not _in_deployment_zone(cell, owner):
			return false
		if _piece_at_cell(cell) != null:
			return false
	return true

func _in_deployment_zone(cell: Vector2i, owner: Piece.Owner) -> bool:
	if owner == Piece.Owner.BLUE:
		return cell.y >= 0 and cell.y <= 4
	return cell.y >= 11 and cell.y <= 15

func _handle_place_click(cell: Vector2i) -> void:
	var step := _current_step()
	var type: Piece.Type = step.get("piece_type", Piece.Type.A)
	var owner: Piece.Owner = step.get("owner", Piece.Owner.BLUE)
	var cells := _piece_cells_for_placement(type, cell)

	if not _can_place_in_croce(cells, owner):
		overlay.set_status(
			"Place the entire piece within the five-row Blue deployment zone, clear of other pieces."
		)
		_render_croce_ghost()
		return

	var key: String = step.get("designation", "Piece")
	var orientation := Piece.PieceOrientation.VERTICAL
	if type == Piece.Type.B:
		orientation = croce_b_orientation

	_create_piece(key, key, type, owner, cells, orientation)
	_refresh_piece_views()
	_clear_children(highlight_layer)
	_complete_action("Placed %s." % key)

func _toggle_pending_b_orientation() -> void:
	croce_b_orientation = (
		Piece.PieceOrientation.HORIZONTAL
		if croce_b_orientation == Piece.PieceOrientation.VERTICAL
		else Piece.PieceOrientation.VERTICAL
	)
	croce_hover_cell = _cell_from_mouse()
	_render_croce_ghost()
	overlay.set_status(
		"B1 placement is now %s. Move the pointer and click when the footprint is green."
		% ("horizontal" if croce_b_orientation == Piece.PieceOrientation.HORIZONTAL else "vertical")
	)

# -----------------------------------------------------------------------------
# Moves and captures
# -----------------------------------------------------------------------------

func _handle_move_click(cell: Vector2i) -> void:
	var step := _current_step()
	var expected_key: String = step.get("piece", "")

	if selected_piece_key.is_empty():
		var clicked := _piece_at_cell(cell)
		if clicked == null or _key_for_piece(clicked) != expected_key:
			overlay.set_status("Select %s first." % _display_key(expected_key))
			return

		selected_piece_key = expected_key
		_prepare_step_highlights()
		overlay.set_status(
			"Selected %s. Every green frame is a legal move."
			% _display_key(expected_key)
		)
		return

	if not pieces_by_key.has(selected_piece_key):
		_deselect_tutorial_piece()
		return

	var selected_piece: Piece = pieces_by_key[selected_piece_key]
	if selected_piece.cells.has(cell):
		_deselect_tutorial_piece()
		overlay.set_status("Selection cleared.")
		return

	# Illegal-move lessons deliberately ask the learner to click a destination
	# that normal highlighting excludes.
	if step.get("action", "") == "try_illegal" and _is_expected_destination(step, cell):
		_deselect_tutorial_piece()
		_complete_action(_illegal_message(step.get("id", "")), 0.9)
		return

	var option := _move_option_at_cell(cell)
	if option.is_empty():
		overlay.set_status("Choose one of the green legal destinations.")
		return

	if not step.get("accept_any_legal", false) and not _is_expected_destination(step, option.get("click_cell", cell)):
		overlay.set_status("That move is legal, but use the instructed destination for this example.")
		return

	_execute_staged_move(step, option)

func _deselect_tutorial_piece() -> void:
	selected_piece_key = ""
	legal_move_options.clear()
	_prepare_step_highlights()

func _is_expected_destination(step: Dictionary, cell: Vector2i) -> bool:
	if cell == step.get("destination_click", Vector2i(-99, -99)):
		return true
	for destination in step.get("new_cells", []):
		if destination == cell:
			return true
	return false

func _move_option_at_cell(cell: Vector2i) -> Dictionary:
	# Exact destination first, then any cell covered by a multi-cell footprint.
	for option in legal_move_options:
		if option.get("click_cell", Vector2i(-99, -99)) == cell:
			return option
	for option in legal_move_options:
		for covered in option.get("highlight_cells", option.get("new_cells", [])):
			if covered == cell:
				return option
	return {}

func _legal_move_options_for(piece: Piece) -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	match piece.type:
		Piece.Type.A:
			for direction in _orthogonal_directions():
				var destination := piece.cells[0] + direction
				var cells: Array[Vector2i] = []
				cells.append(destination)
				_append_legal_option(options, piece, destination, cells, piece.orientation, cells)

		Piece.Type.C:
			for direction in _orthogonal_directions():
				var shifted: Array[Vector2i] = []
				for old_cell in piece.cells:
					shifted.append(old_cell + direction)
				var destination := piece.cells[0] + direction
				_append_legal_option(options, piece, destination, shifted, piece.orientation, shifted)

		Piece.Type.GENERAL:
			for direction in _diagonal_directions():
				var destination := piece.cells[0] + direction
				if not _is_in_own_half(destination, piece.owner):
					continue
				var cells: Array[Vector2i] = []
				cells.append(destination)
				_append_legal_option(options, piece, destination, cells, piece.orientation, cells)

		Piece.Type.B:
			_append_b_move_options(options, piece)

	return options

func _append_b_move_options(options: Array[Dictionary], piece: Piece) -> void:
	if piece.cells.size() < 2:
		return

	var end_a: Vector2i = piece.cells[0]
	var end_b: Vector2i = piece.cells[1]
	var pivots: Array[Vector2i] = []
	pivots.append(end_a)
	pivots.append(end_b)

	var swing_steps: Array[Vector2i] = []
	if piece.orientation == Piece.PieceOrientation.HORIZONTAL:
		swing_steps.append(Vector2i.UP)
		swing_steps.append(Vector2i.DOWN)
	else:
		swing_steps.append(Vector2i.LEFT)
		swing_steps.append(Vector2i.RIGHT)

	var pivot_orientation := (
		Piece.PieceOrientation.VERTICAL
		if piece.orientation == Piece.PieceOrientation.HORIZONTAL
		else Piece.PieceOrientation.HORIZONTAL
	)

	for pivot in pivots:
		for swing_step in swing_steps:
			var swung_cell := pivot + swing_step
			var new_cells: Array[Vector2i] = []
			new_cells.append(pivot)
			new_cells.append(swung_cell)
			_append_legal_option(
				options,
				piece,
				swung_cell,
				new_cells,
				pivot_orientation,
				new_cells
			)

	var slide_directions: Array[Vector2i] = []
	if piece.orientation == Piece.PieceOrientation.HORIZONTAL:
		slide_directions.append(Vector2i.LEFT)
		slide_directions.append(Vector2i.RIGHT)
	else:
		slide_directions.append(Vector2i.UP)
		slide_directions.append(Vector2i.DOWN)

	for direction in slide_directions:
		var shifted: Array[Vector2i] = []
		for old_cell in piece.cells:
			shifted.append(old_cell + direction)

		var entering_cell := shifted[0]
		for candidate in shifted:
			if not piece.cells.has(candidate):
				entering_cell = candidate
				break

		var highlight_cells: Array[Vector2i] = []
		highlight_cells.append(entering_cell)
		_append_legal_option(
			options,
			piece,
			entering_cell,
			shifted,
			piece.orientation,
			highlight_cells
		)

func _append_legal_option(
	options: Array[Dictionary],
	piece: Piece,
	click_cell: Vector2i,
	new_cells: Array[Vector2i],
	orientation: Piece.PieceOrientation,
	highlight_cells: Array[Vector2i]
) -> void:
	for cell in new_cells:
		if not _is_on_board(cell):
			return

	var target_keys: Array[String] = []
	for other in pieces_by_uid.values():
		if other.uid == piece.uid:
			continue

		var overlaps := false
		for occupied in other.cells:
			if new_cells.has(occupied):
				overlaps = true
				break
		if not overlaps:
			continue

		if other.owner == piece.owner:
			return
		if RulesEngine.resolve_capture(piece, other) == RulesEngine.CaptureResult.ILLEGAL:
			return
		target_keys.append(_key_for_piece(other))

	options.append({
		"click_cell": click_cell,
		"new_cells": new_cells.duplicate(),
		"orientation": orientation,
		"highlight_cells": highlight_cells.duplicate(),
		"targets": target_keys,
	})

func _orthogonal_directions() -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	directions.append(Vector2i.UP)
	directions.append(Vector2i.DOWN)
	directions.append(Vector2i.LEFT)
	directions.append(Vector2i.RIGHT)
	return directions

func _diagonal_directions() -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	directions.append(Vector2i(-1, -1))
	directions.append(Vector2i(1, -1))
	directions.append(Vector2i(-1, 1))
	directions.append(Vector2i(1, 1))
	return directions

func _is_in_own_half(cell: Vector2i, owner: Piece.Owner) -> bool:
	if owner == Piece.Owner.BLUE:
		return cell.y < 8
	return cell.y >= 8

func _execute_staged_move(step: Dictionary, option: Dictionary) -> void:
	if not pieces_by_key.has(selected_piece_key):
		return

	var attacker: Piece = pieces_by_key[selected_piece_key]
	var outcome: String = step.get("outcome", "move")

	for target_key in step.get("targets", []):
		_remove_piece(target_key)

	if outcome == "mutual":
		_remove_piece(selected_piece_key)
	else:
		var new_cells: Array[Vector2i] = []
		for cell in option.get("new_cells", step.get("new_cells", [])):
			new_cells.append(cell)
		attacker.cells = new_cells
		attacker.orientation = option.get(
			"orientation",
			step.get("orientation", attacker.orientation)
		)

	selected_piece_key = ""
	legal_move_options.clear()
	_refresh_piece_views()
	_prepare_step_highlights()
	_complete_action(_success_message(step))

func _success_message(step: Dictionary) -> String:
	match step.get("id", ""):
		"objective_capture":
			return "Objective captured. A real match ends immediately."
		"double_c":
			return "Both B pieces were captured in one move."
		"mutual":
			return "Both A pieces were removed."
		"saboteur_capture":
			return "The Saboteur captured the otherwise immune General."
		"close_call_capture":
			return "Close Call preserved the attacking A."
		_:
			if step.get("outcome", "move") == "capture":
				return "Capture resolved."
			return "Move complete."

func _illegal_message(id: String) -> String:
	match id:
		"general_immunity":
			return "Illegal: an ordinary A cannot capture a General."
		"edge_c_blocked":
			return "Illegal: the enemy A blocks the entire C overlap."
		_:
			return "That move is illegal in normal play."

# -----------------------------------------------------------------------------
# Tutorial hand and cards
# -----------------------------------------------------------------------------

func _configure_hand(mode: String) -> void:
	_clear_hand()
	hand_mode = mode
	selected_cards.clear()
	card_panels.clear()

	if mode == "catalog":
		_show_card_catalog()
		call_deferred("_apply_focus")
		return

	hand_layer.visible = true

	var panel := PanelContainer.new()
	hand_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.97)
	panel_style.border_color = INK
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.25)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 3)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(card_scroll)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 7)
	card_scroll.add_child(cards_row)

	var specs := _card_specs(mode)
	var card_width := LIMIT_CARD_WIDTH if mode == "limit" else HAND_CARD_WIDTH
	for spec in specs:
		cards_row.add_child(_build_card(spec, card_width, _hand_is_interactive()))

	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(150, 0)
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)

	var hand_title := Label.new()
	hand_title.text = _hand_title(mode, specs.size())
	hand_title.add_theme_font_size_override("font_size", 15)
	hand_title.add_theme_color_override("font_color", INK)
	hand_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(hand_title)

	if _hand_is_interactive():
		deploy_button = Button.new()
		deploy_button.text = "Confirm Discard" if mode == "limit" else "Deploy"
		deploy_button.disabled = true
		deploy_button.custom_minimum_size = Vector2(0, 42)
		_style_hand_button(deploy_button)
		deploy_button.pressed.connect(_on_hand_confirmed)
		controls.add_child(deploy_button)

	call_deferred("_apply_focus")

func _clear_hand() -> void:
	hand_layer.visible = false
	hand_mode = ""
	selected_cards.clear()
	card_panels.clear()
	deploy_button = null
	_clear_children(hand_layer)
	if is_instance_valid(catalog_layer):
		catalog_layer.queue_free()
	catalog_layer = null
	call_deferred("_apply_focus")

func _show_card_catalog() -> void:
	hand_layer.visible = false

	var panel := PanelContainer.new()
	catalog_layer = panel
	panel.name = "CardCatalog"
	panel.z_index = 60
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	board_area.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 10
	panel.offset_top = TIMELINE_HEIGHT + 10
	panel.offset_right = -10
	panel.offset_bottom = -10

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.98)
	panel_style.border_color = Color("#c9c5bc")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.2)
	panel_style.shadow_size = 7
	panel_style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)

	for group in _catalog_groups():
		column.add_child(_build_catalog_group(
			group.get("title", "Cards"),
			group.get("cards", [])
		))

func _catalog_groups() -> Array[Dictionary]:
	return [
		{
			"title": "TYPE CARDS — examples",
			"cards": [
				_card("catalog_type_a", "res://assets/sprites/cards/type_A.png", "Type A"),
				_card("catalog_type_b", "res://assets/sprites/cards/type_B.png", "Type B"),
				_card("catalog_type_abc", "res://assets/sprites/cards/type_ABC.png", "Type ABC"),
			],
		},
		{
			"title": "CHART CARDS — examples",
			"cards": [
				_card("catalog_chart_01", "res://assets/sprites/cards/chart_01.png", "Chart 01"),
				_card("catalog_chart_03", "res://assets/sprites/cards/chart_03.png", "Chart 03"),
				_card("catalog_chart_07", "res://assets/sprites/cards/chart_07.png", "Chart 07"),
			],
		},
		{
			"title": "MINOR POWER CARDS — every effect",
			"cards": [
				_card("catalog_minor_jic", "res://assets/sprites/cards/minor_justincase.png", "Just In Case"),
				_card("catalog_minor_gmo", "res://assets/sprites/cards/minor_getmoveon_C.png", "Get Move On"),
				_card("catalog_minor_cc", "res://assets/sprites/cards/minor_closecall_A.png", "Close Call"),
				_card("catalog_minor_ityd", "res://assets/sprites/cards/minor_ityd_A.png", "I Thought You Were Dead"),
			],
		},
		{
			"title": "MAJOR POWER CARDS — every effect",
			"cards": [
				_card("catalog_major_blitz", "res://assets/sprites/cards/major_blitzkrieg.png", "Blitzkrieg"),
				_card("catalog_major_double", "res://assets/sprites/cards/major_doubleagent.png", "Double Agent"),
				_card("catalog_major_susp", "res://assets/sprites/cards/major_heseemedsusp.png", "He Seemed Suspicious"),
				_card("catalog_major_ontoyou", "res://assets/sprites/cards/major_imontoyou.png", "I'm On To You"),
				_card("catalog_major_ineffective", "res://assets/sprites/cards/major_ineffective.png", "Ineffective Leadership"),
				_card("catalog_major_jto", "res://assets/sprites/cards/major_justthisonce.png", "Just This Once"),
				_card("catalog_major_oma", "res://assets/sprites/cards/major_onemanArmy.png", "One Man Army"),
			],
		},
	]

func _build_catalog_group(title: String, specs: Array) -> Control:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 6)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", INK)
	group.add_child(heading)

	# FlowContainer lets the much larger catalogue cards wrap onto additional
	# rows at narrower resolutions instead of clipping off the right edge.
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 18)
	row.add_theme_constant_override("v_separation", 14)
	group.add_child(row)

	for spec in specs:
		var item := VBoxContainer.new()
		item.custom_minimum_size = Vector2(CATALOG_LABEL_WIDTH, 0)
		item.add_theme_constant_override("separation", 5)
		item.add_child(_build_card(spec, CATALOG_CARD_WIDTH, false))

		var label := Label.new()
		label.text = spec.get("label", "Card")
		label.custom_minimum_size = Vector2(CATALOG_LABEL_WIDTH, 0)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_child(label)
		row.add_child(item)

	return group

func _hand_is_interactive() -> bool:
	return hand_mode in ["saboteur", "close_call", "limit"]

func _hand_title(mode: String, count: int) -> String:
	match mode:
		"reward_two": return "Blue hand\n+2 cards"
		"saboteur": return "Select Type + Chart"
		"close_call": return "Select the power card"
		"limit": return "Hand: %d / 9" % count
		"timing": return "Timing examples"
		_: return "Private hand"

func _card_specs(mode: String) -> Array[Dictionary]:
	match mode:
		"reward_two":
			return [
				_card("reward_chart", "res://assets/sprites/cards/chart_03.png", "Chart"),
				_card("reward_power", "res://assets/sprites/cards/minor_justincase.png", "Just In Case"),
			]
		"timing":
			return [
				_card("timing_blitzkrieg", "res://assets/sprites/cards/major_blitzkrieg.png", "Blitzkrieg"),
				_card("timing_move_on", "res://assets/sprites/cards/minor_getmoveon_C.png", "Get Move On"),
				_card("timing_objective", "res://assets/sprites/cards/major_justthisonce.png", "Just This Once"),
				_card("timing_redeploy", "res://assets/sprites/cards/minor_ityd_A.png", "I Thought You Were Dead"),
				_card("timing_army", "res://assets/sprites/cards/major_onemanArmy.png", "One Man Army"),
			]
		"saboteur":
			return [
				_card("type_a", "res://assets/sprites/cards/type_A.png", "Type A"),
				_card("chart_07", "res://assets/sprites/cards/chart_07.png", "Chart 07"),
				_card("distractor", "res://assets/sprites/cards/minor_justincase.png", "Just In Case"),
			]
		"close_call":
			return [
				_card("close_call_a", "res://assets/sprites/cards/minor_closecall_A.png", "Close Call - A"),
			]
		"limit":
			return [
				_card("limit_1", "res://assets/sprites/cards/chart_01.png", "Chart 01"),
				_card("limit_2", "res://assets/sprites/cards/chart_03.png", "Chart 03"),
				_card("limit_3", "res://assets/sprites/cards/chart_07.png", "Chart 07"),
				_card("limit_4", "res://assets/sprites/cards/type_A.png", "Type A"),
				_card("limit_5", "res://assets/sprites/cards/type_B.png", "Type B"),
				_card("limit_6", "res://assets/sprites/cards/type_ABC.png", "Type ABC"),
				_card("limit_7", "res://assets/sprites/cards/minor_justincase.png", "Just In Case"),
				_card("limit_8", "res://assets/sprites/cards/minor_getmoveon_C.png", "Get Move On"),
				_card("limit_9", "res://assets/sprites/cards/major_justthisonce.png", "Just This Once"),
				_card("limit_10", "res://assets/sprites/cards/major_onemanArmy.png", "One Man Army"),
			]
		_:
			return []

func _card(id: String, path: String, label: String) -> Dictionary:
	return {"id": id, "path": path, "label": label}

func _build_card(spec: Dictionary, width: float, interactive: bool) -> Control:
	var height := width * (798.0 / 567.0)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(width, height)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", style)

	var texture := TextureRect.new()
	texture.texture = load(spec.get("path", ""))
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(texture)

	var id: String = spec.get("id", "card")
	card_panels[id] = frame
	if interactive:
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		frame.gui_input.connect(_on_card_gui_input.bind(id))
	return frame

func _on_card_gui_input(event: InputEvent, id: String) -> void:
	if input_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card(id)
		accept_event()

func _toggle_card(id: String) -> void:
	if selected_cards.has(id):
		selected_cards.erase(id)
	else:
		if hand_mode == "limit" or hand_mode == "close_call":
			selected_cards.clear()
		selected_cards.append(id)
	_update_card_frames()
	_update_deploy_button()

func _update_card_frames() -> void:
	for id in card_panels:
		var panel: PanelContainer = card_panels[id]
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = GOLD if selected_cards.has(id) else INK
			style.set_border_width_all(5 if selected_cards.has(id) else 2)

func _update_deploy_button() -> void:
	if deploy_button == null:
		return
	match hand_mode:
		"saboteur":
			deploy_button.disabled = not (selected_cards.has("type_a") and selected_cards.has("chart_07") and selected_cards.size() == 2)
		"close_call", "limit":
			deploy_button.disabled = selected_cards.size() != 1
		_:
			deploy_button.disabled = true

func _on_hand_confirmed() -> void:
	if input_locked or deploy_button == null or deploy_button.disabled:
		return
	match hand_mode:
		"saboteur":
			if not pieces_by_key.has("A7"):
				overlay.set_status("The staged A7 target is missing.")
				return
			var target: Piece = pieces_by_key["A7"]
			target.apply_saboteur_conversion(Piece.Owner.BLUE)
			_refresh_piece_views()
			_prepare_step_highlights()
			_complete_action("Type A plus Chart 07 converted Red A7 into Blue's Saboteur.", 0.8)
		"close_call":
			close_call_armed = true
			_complete_action("Close Call - A is armed for the next equal-A collision.", 0.7)
		"limit":
			_complete_action("One card returned to the bottom of the deck. The hand is back to nine.", 0.8)

func _style_hand_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = RED if hand_mode == "limit" else INK
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#c7c3bb")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", disabled)

# -----------------------------------------------------------------------------
# Completion utilities
# -----------------------------------------------------------------------------

func _complete_action(message: String, _delay: float = 0.0) -> void:
	if input_locked:
		return
	input_locked = true
	lesson_resolved = true
	completed_steps[step_index] = true
	overlay.set_status("")
	overlay.set_feedback(message)
	overlay.configure_buttons(true, "Continue")
	_update_timeline()

func _display_key(key: String) -> String:
	return key.replace("_RED", "")

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
