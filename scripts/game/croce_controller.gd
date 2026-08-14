extends Node2D
class_name CroceController

const CELL = 64
const BOARD_ORIGIN = Vector2(-576, -512)

const REQUIRED_COUNTS := {
	Piece.Type.A: 12, Piece.Type.B: 6, Piece.Type.C: 3,
	Piece.Type.GENERAL: 1, Piece.Type.OBJECTIVE: 1,
}
const PIECE_ORDER := [
	Piece.Type.A, Piece.Type.B, Piece.Type.C,
	Piece.Type.GENERAL, Piece.Type.OBJECTIVE,
]
const TYPE_LABELS := {
	Piece.Type.A: "A", Piece.Type.B: "B", Piece.Type.C: "C",
	Piece.Type.GENERAL: "General", Piece.Type.OBJECTIVE: "Objective",
}

var game_state: GameState
var current_player: Piece.Owner = Piece.Owner.BLUE
var selected_type: Piece.Type = Piece.Type.A
var next_uid: int = 1
var ghost: PieceGhost
var piece_layer: Node2D
var ui_layer: CanvasLayer
var type_buttons: Dictionary = {}
var rotate_hint: Label
var status_label: Label
var pass_screen: CanvasLayer
var pass_label: Label

signal setup_finished(gs: GameState)

func initialize(gs: GameState, pl: Node2D) -> void:
	game_state = gs
	piece_layer = pl
	_build_ui()
	_build_pass_screen()
	_spawn_ghost()
	_refresh_ui()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.custom_minimum_size = Vector2(140, 0)
	panel.add_child(vbox)

	status_label = Label.new()
	status_label.text = "BLUE placing"
	status_label.add_theme_color_override("font_color", Color(0.25, 0.45, 0.9))
	vbox.add_child(status_label)

	rotate_hint = Label.new()
	rotate_hint.text = "Press R to rotate"
	rotate_hint.add_theme_font_size_override("font_size", 13)
	rotate_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	rotate_hint.visible = false
	vbox.add_child(rotate_hint)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for type in PIECE_ORDER:
		var btn := Button.new()
		btn.text = _button_label(type)
		btn.pressed.connect(_on_type_selected.bind(type))
		vbox.add_child(btn)
		type_buttons[type] = btn

func _button_label(type: Piece.Type) -> String:
	var placed := _placed_count(type)
	var total: int = REQUIRED_COUNTS[type]
	return "%s  %d/%d" % [TYPE_LABELS[type], placed, total]

func _placed_count(type: Piece.Type) -> int:
	var count := 0
	for piece in game_state.pieces.values():
		if piece.owner == current_player and piece.type == type:
			count += 1
	return count

func _build_pass_screen() -> void:
	pass_screen = CanvasLayer.new()
	pass_screen.visible = false
	add_child(pass_screen)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_screen.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pass_screen.add_child(vbox)

	var lbl := Label.new()
	lbl.name = "PassLabel"
	pass_label = lbl
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var sub := Label.new()
	sub.text = "Hand the device to the other player, then tap anywhere to begin."
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

func _show_pass_screen() -> void:
	pass_label.text = "BLUE setup complete.\nPass to RED." if current_player == Piece.Owner.BLUE \
		else "RED setup complete.\nStarting game..."
	pass_screen.visible = true

func _spawn_ghost() -> void:
	ghost = PieceGhost.new()
	ghost.piece_type = selected_type
	add_child(ghost)

func _on_type_selected(type: Piece.Type) -> void:
	if _placed_count(type) >= REQUIRED_COUNTS[type]:
		return
	selected_type = type
	ghost.piece_type = type
	ghost.orientation = Piece.PieceOrientation.VERTICAL
	_refresh_ui()

func _in_deployment_zone(cell: Vector2i, owner: Piece.Owner) -> bool:
	if owner == Piece.Owner.BLUE:
		return cell.y >= 0 and cell.y <= 4
	else:
		return cell.y >= 11 and cell.y <= 15
		
func _refresh_ui() -> void:
	var is_blue := current_player == Piece.Owner.BLUE
	status_label.text = "Blue Pieces" if is_blue else "Red Pieces"
	status_label.add_theme_color_override("font_color",
		Color("#4169E1") if is_blue else Color("#E32636"))
	rotate_hint.visible = (selected_type == Piece.Type.B)
	for type in PIECE_ORDER:
		type_buttons[type].text = _button_label(type)
		type_buttons[type].disabled = _placed_count(type) >= REQUIRED_COUNTS[type]

func handle_input(event: InputEvent) -> void:
	if pass_screen.visible:
		if event is InputEventMouseButton and event.pressed:
			_advance_player()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			ghost.toggle_orientation()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place()

func _try_place() -> void:
	var cells := ghost.get_cells()
	for cell in cells:
		if not _in_deployment_zone(cell, current_player):
			ghost.valid = false
			return
	var p := Piece.new()
	p.uid = next_uid
	p.type = selected_type
	p.owner = current_player
	p.cells = cells
	if selected_type == Piece.Type.B:
		p.orientation = ghost.orientation
	p.designation = _next_designation()

	if not CroceSetup.can_place_piece(p, cells, game_state):
		ghost.valid = false
		return

	CroceSetup.place_piece(p, cells, game_state)
	next_uid += 1

	var view := PieceView.new()
	piece_layer.add_child(view)
	view.setup(p)

	_advance_selection()
	_refresh_ui()

func _next_designation() -> String:
	match selected_type:
		Piece.Type.GENERAL:
			return "General"
		Piece.Type.OBJECTIVE:
			return "Objective"
		_:
			var n := _placed_count(selected_type) + 1
			return "%s%d" % [TYPE_LABELS[selected_type], n]

func _advance_selection() -> void:
	# If this type is now full, auto-select the next incomplete type
	if _placed_count(selected_type) >= REQUIRED_COUNTS[selected_type]:
		for type in PIECE_ORDER:
			if _placed_count(type) < REQUIRED_COUNTS[type]:
				_on_type_selected(type)
				return
		# All types complete — show pass screen
		_show_pass_screen()

func _advance_player() -> void:
	pass_screen.visible = false
	if current_player == Piece.Owner.BLUE:
		current_player = Piece.Owner.RED
		selected_type = Piece.Type.A
		ghost.piece_type = Piece.Type.A
		ghost.orientation = Piece.PieceOrientation.VERTICAL
		_refresh_ui()
	else:
		# Both players done
		ghost.queue_free()
		ui_layer.queue_free()
		emit_signal("setup_finished", game_state)
