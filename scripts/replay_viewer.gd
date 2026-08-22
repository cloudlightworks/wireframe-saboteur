extends Control
# Replay viewer — draws its own wireframe board, matching the approved mockup.
#
# No dependency on board.tscn, PieceView, or the live render stack. Two tinted
# halves, thin grid lines, outlined piece rectangles, designation text. It
# reads a ReplayRecord and never touches GameState or a live match.
#
# Host is blue (top), client is red (bottom), always — structural, not personal.
# No player names are shown.

const PAPER := Color("#ffffff")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const TICK := Color("#b9b3a7")
const FOOT := Color("#b3ada2")
const ROYAL := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const BLUE_FILL := Color("#eff3fd")
const RED_FILL := Color("#fdeff1")
const BLUE_PIECE := Color("#dde5fb")
const RED_PIECE := Color("#fbdde0")
const OBJ := Color("#F0A500")

var record: ReplayRecord = null
var other_record: ReplayRecord = null

var _event_index: int = 0

var _board: Control
var _turn_label: Label
var _of_label: Label
var _host_label: Label
var _client_label: Label
var _lines_label: Label
var _indenture: Control
var _indenture_note: Label
var _scrub: Control

signal closed

# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func open(rec: ReplayRecord, other: ReplayRecord = null) -> void:
	record = rec
	other_record = other
	_event_index = -1
	_refresh()

# ---------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for corner in ["tl", "tr", "bl", "br"]:
		add_child(_make_tick(corner))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	body.add_child(_build_rail())

	_board = Control.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.draw.connect(_draw_board)
	body.add_child(_board)

	col.add_child(_build_transport())
	col.add_child(_build_footer())

func _build_rail() -> Control:
	var rail := VBoxContainer.new()
	rail.custom_minimum_size = Vector2(196, 0)
	rail.add_theme_constant_override("separation", 4)

	rail.add_child(_small("T U R N", MUTED, 11))
	_turn_label = _big("1")
	rail.add_child(_turn_label)
	_of_label = _small("of 1", MUTED, 15)
	rail.add_child(_of_label)

	rail.add_child(_spacer(10))
	rail.add_child(_rule(ALIZARIN))
	rail.add_child(_rule(ROYAL))
	rail.add_child(_spacer(14))

	_host_label = _small("host", ROYAL, 15)
	rail.add_child(_host_label)
	_client_label = _small("client", ALIZARIN, 15)
	rail.add_child(_client_label)
	rail.add_child(_spacer(16))

	rail.add_child(_small("T H I S   T U R N", MUTED, 11))
	_lines_label = Label.new()
	_lines_label.add_theme_font_size_override("font_size", 13)
	_lines_label.add_theme_color_override("font_color", INK)
	_lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines_label.custom_minimum_size = Vector2(190, 0)
	rail.add_child(_lines_label)
	rail.add_child(_spacer(18))

	var mark_row := HBoxContainer.new()
	mark_row.add_theme_constant_override("separation", 10)
	_indenture = Control.new()
	_indenture.custom_minimum_size = Vector2(34, 34)
	_indenture.draw.connect(_draw_indenture)
	mark_row.add_child(_indenture)
	_indenture_note = Label.new()
	_indenture_note.add_theme_font_size_override("font_size", 11)
	_indenture_note.add_theme_color_override("font_color", MUTED)
	_indenture_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_indenture_note.custom_minimum_size = Vector2(140, 0)
	mark_row.add_child(_indenture_note)
	rail.add_child(mark_row)
	return rail

func _build_transport() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.add_child(_bracket("|<", func(): _seek(-1)))
	btns.add_child(_bracket("<", func(): _step_turn(-1)))
	btns.add_child(_bracket(">", func(): _step_turn(1)))
	btns.add_child(_bracket(">|", func(): _seek((record.events.size() - 1) if record else 0)))
	row.add_child(btns)

	_scrub = Control.new()
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.custom_minimum_size = Vector2(0, 18)
	_scrub.draw.connect(_draw_scrub)
	_scrub.gui_input.connect(_on_scrub_input)
	row.add_child(_scrub)

	return row

func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.add_child(_bracket("load records", func(): _open_load_panel()))
	row.add_child(_bracket("back", func(): _leave()))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)
	row.add_child(_small("W I R E F R A M E   S A B O T E U R", FOOT, 10))
	return row

# ---------------------------------------------------------------------------
func _step(dir: int) -> void:
	if record:
		_seek(clampi(_event_index + dir, 0, record.events.size() - 1))

func _step_turn(dir: int) -> void:
	if record == null or record.turn_ends.is_empty():
		return
	if dir > 0:
		for idx in record.turn_ends:
			if idx > _event_index:
				_seek(idx)
				return
		_seek(record.events.size() - 1)
	else:
		var prev := -1
		for idx in record.turn_ends:
			if idx < _event_index:
				prev = idx
			else:
				break
		_seek(prev)
		
func _seek(index: int) -> void:
	if record == null:
		return
	_event_index = clampi(index, -1, maxi(record.events.size() - 1, 0))
	_refresh()

func _leave() -> void:
	MusicManager.return_to_menu_music()
	get_tree().change_scene_to_file("res://scenes/menu_root.tscn")

var _slot_paths := ["", ""]

func _open_load_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.size = get_viewport().get_visible_rect().size
	layer.add_child(shade)

	var center := CenterContainer.new()
	center.size = get_viewport().get_visible_rect().size
	layer.add_child(center)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(30)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)

	col.add_child(_small("F I T   A   R E C O R D", MUTED, 11))
	var title := Label.new()
	title.text = "open a match"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	col.add_child(title)
	col.add_child(_rule(ALIZARIN))
	col.add_child(_rule(ROYAL))
	col.add_child(_spacer(8))

	_slot_paths = ["", ""]
	var slot_labels := []
	for i in range(2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = "no file chosen" if i == 0 else "second half (optional)"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", MUTED)
		lbl.custom_minimum_size = Vector2(320, 0)
		var idx := i
		row.add_child(_bracket("choose", func(): _pick_slot(idx, lbl)))
		row.add_child(lbl)
		slot_labels.append(lbl)
		col.add_child(row)

	col.add_child(_spacer(10))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	actions.add_child(_bracket("watch it", func():
		_apply_slots()
		layer.queue_free()
	))
	actions.add_child(_bracket("cancel", func(): layer.queue_free()))
	col.add_child(actions)

	box.add_child(col)
	center.add_child(box)

func _pick_slot(index: int, label: Label) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.wfs ; Match record"])
	fd.current_dir = ProjectSettings.globalize_path("user://replays/")
	fd.size = Vector2i(760, 520)
	add_child(fd)
	fd.file_selected.connect(func(p: String):
		_slot_paths[index] = p
		var probe := ReplayRecord.new()
		if probe.load_from(p):
			label.text = "%s  —  %s" % [p.get_file(), "host" if probe.recorded_by == "blue" else "client"]
			label.add_theme_color_override("font_color", ROYAL if probe.recorded_by == "blue" else ALIZARIN)
		else:
			label.text = probe.error
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered()

func _apply_slots() -> void:
	if _slot_paths[0] == "":
		return
	var a := ReplayRecord.new()
	if not a.load_from(_slot_paths[0]):
		_lines_label.text = a.error
		return
	record = a
	other_record = null
	if _slot_paths[1] != "":
		var b := ReplayRecord.new()
		if b.load_from(_slot_paths[1]):
			other_record = b
	_event_index = -1
	_refresh()
	
func _refresh() -> void:
	if record == null:
		return
	var st := record.state_at(_event_index)
	_board.set_meta("state", st)
	_turn_label.text = "0" if _event_index < 0 else str(st["turn"])
	_of_label.text = "of %d" % record.turn_count()
	_host_label.text = "host   %d pieces" % _count(st["pieces"], Piece.Owner.BLUE)
	_client_label.text = "client   %d pieces" % _count(st["pieces"], Piece.Owner.RED)
	_lines_label.text = "\n".join(st["lines"]) if not st["lines"].is_empty() else "—"

	var fit := record.fit_against(other_record)
	_indenture.set_meta("state", fit["state"])
	_indenture.queue_redraw()
	_indenture_note.text = fit["note"] if fit["note"] != "" else _fit_word(fit["state"])

	_board.queue_redraw()
	_scrub.queue_redraw()

func _count(pieces: Dictionary, side: int) -> int:
	var n := 0
	for uid in pieces:
		if int(pieces[uid].owner) == side:
			n += 1
	return n

# ---------------------------------------------------------------------------
# Board drawing — thin wireframe, matching the mockup.
# ---------------------------------------------------------------------------

func _draw_board() -> void:
	var bw := BoardView.board_width
	var bh := BoardView.board_height
	var avail := _board.size
	var cell := minf(avail.x / bw, avail.y / bh) * 0.98
	var ox := (avail.x - cell * bw) * 0.5
	var oy := (avail.y - cell * bh) * 0.5
	var home := bh / 2

	_board.draw_rect(Rect2(ox, oy, cell * bw, cell * home), BLUE_FILL)
	_board.draw_rect(Rect2(ox, oy + cell * home, cell * bw, cell * home), RED_FILL)

	for x in range(bw + 1):
		_board.draw_line(Vector2(ox + x * cell, oy), Vector2(ox + x * cell, oy + cell * home), Color(ROYAL, 0.45), 1.0)
		_board.draw_line(Vector2(ox + x * cell, oy + cell * home), Vector2(ox + x * cell, oy + cell * bh), Color(ALIZARIN, 0.45), 1.0)
	for y in range(home + 1):
		_board.draw_line(Vector2(ox, oy + y * cell), Vector2(ox + cell * bw, oy + y * cell), Color(ROYAL, 0.45), 1.0)
	for y in range(home, bh + 1):
		_board.draw_line(Vector2(ox, oy + y * cell), Vector2(ox + cell * bw, oy + y * cell), Color(ALIZARIN, 0.45), 1.0)
	_board.draw_line(Vector2(ox, oy + cell * home), Vector2(ox + cell * bw, oy + cell * home), INK, 0.9)

	var st = _board.get_meta("state", null)
	if st == null:
		return

	for c in st["capture_cells"]:
		var cx: float = ox + (c.x + 0.5) * cell
		var cy: float = oy + (c.y + 0.5) * cell
		_board.draw_arc(Vector2(cx, cy), cell * 0.35, 0, TAU, 24, Color(INK, 0.3), 0.8)

	for uid in st["pieces"]:
		_draw_piece(st["pieces"][uid], ox, oy, cell)
	var tray_x: float = ox + cell * bw + 14.0
	_draw_tray(st["hands"].get(Piece.Owner.BLUE, []), tray_x, oy + 4.0, ROYAL)
	_draw_tray(st["hands"].get(Piece.Owner.RED, []), tray_x, oy + cell * float(home) + 8.0, ALIZARIN)

func _draw_tray(uids: Array, x: float, y: float, edge: Color) -> void:
	var font := ThemeDB.fallback_font
	var w: float = 52.0
	var h: float = 22.0
	var gap: float = 4.0
	for i in range(uids.size()):
		var r := Rect2(x, y + i * (h + gap), w, h)
		_board.draw_rect(r, PAPER)
		_board.draw_rect(r, edge, false, 1.0)
		var label: String = ReplayRecord.card_label(int(uids[i]))
		var fs: int = 11
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		_board.draw_string(font, Vector2(r.position.x + w * 0.5 - tw * 0.5, r.position.y + h * 0.5 + 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, edge)

func _draw_piece(p, ox: float, oy: float, cell: float) -> void:
	var minx := 999
	var miny := 999
	var maxx := -999
	var maxy := -999
	for c in p.cells:
		minx = mini(minx, c.x); miny = mini(miny, c.y)
		maxx = maxi(maxx, c.x); maxy = maxi(maxy, c.y)
	if minx == 999:
		return
	var r := Rect2(ox + minx * cell + 1, oy + miny * cell + 1,
		(maxx - minx + 1) * cell - 2, (maxy - miny + 1) * cell - 2)

	var edge: Color
	var fill: Color
	if int(p.type) == Piece.Type.OBJECTIVE or int(p.type) == Piece.Type.GENERAL:
		edge = INK
		fill = OBJ
	elif int(p.owner) == Piece.Owner.BLUE:
		edge = ROYAL
		fill = BLUE_PIECE
	else:
		edge = ALIZARIN
		fill = RED_PIECE

	_board.draw_rect(r, fill)
	_board.draw_rect(r, edge, false, 1.1)
	if p.has_status("saboteur"):
		_board.draw_rect(r.grow(-2.0), edge, false, 0.8)

	var font := ThemeDB.fallback_font
	var fs := int(cell * 0.4)
	var label := str(p.designation)
	if int(p.type) == Piece.Type.GENERAL:
		label = "G"
	elif int(p.type) == Piece.Type.OBJECTIVE:
		label = "O"
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	_board.draw_string(font, Vector2(r.position.x + r.size.x * 0.5 - tw * 0.5, r.position.y + r.size.y * 0.5 + fs * 0.35),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, edge)

# ---------------------------------------------------------------------------

func _draw_scrub() -> void:
	var w := _scrub.size.x
	var y := 8.0
	_scrub.draw_line(Vector2(0, y), Vector2(w, y), TICK, 1.0)
	if record == null or record.events.is_empty():
		return
	var frac := float(_event_index) / float(maxi(record.events.size() - 1, 1))
	_scrub.draw_line(Vector2(0, y), Vector2(w * frac, y), ALIZARIN, 1.0)
	_scrub.draw_line(Vector2(w * frac, 1), Vector2(w * frac, 15), INK, 2.0)

func _on_scrub_input(event: InputEvent) -> void:
	if record == null:
		return
	var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var dragged: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if pressed or dragged:
		var frac: float = clampf(event.position.x / maxf(_scrub.size.x, 1.0), 0.0, 1.0)
		_seek(int(frac * float(record.events.size() - 1)))

func _draw_indenture() -> void:
	var state := str(_indenture.get_meta("state", "single"))
	var k := _indenture.size.x / 100.0
	_indenture.draw_rect(Rect2(Vector2(3, 3) * k, Vector2(94, 94) * k), INK, false, 2.0)

	if state == "local":
		_indenture.draw_rect(Rect2(Vector2(24, 28) * k, Vector2(52, 46) * k), TICK, false, 2.0)
		return

	var blue := PackedVector2Array([Vector2(22,26),Vector2(52,26),Vector2(34,50),Vector2(52,62),Vector2(30,74),Vector2(52,76),Vector2(22,76)])
	var red := PackedVector2Array([Vector2(78,26),Vector2(52,26),Vector2(34,50),Vector2(52,62),Vector2(30,74),Vector2(52,76),Vector2(78,76)])
	var offset := Vector2(7, -4) if state in ["mismatch", "boards_agree"] else Vector2.ZERO

	_poly(blue, k, Vector2.ZERO, ROYAL)
	if state in ["fitted", "mismatch", "boards_agree", "same_side"]:
		var c := ROYAL if state == "same_side" else ALIZARIN
		_poly(red, k, offset, c)

func _poly(pts: PackedVector2Array, k: float, off: Vector2, c: Color) -> void:
	var s := PackedVector2Array()
	for p in pts:
		s.append((p + off) * k)
	s.append(s[0])
	_indenture.draw_polyline(s, c, 2.0)

func _fit_word(state: String) -> String:
	match state:
		"fitted": return "both halves fitted"
		"single": return "one half only"
		"local": return "local match"
		"same_side": return "same side twice"
		"boards_agree": return "boards agree, records don't"
	return "records disagree"

# ---------------------------------------------------------------------------

func _bracket(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "[ %s ]" % text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", ROYAL)
	b.add_theme_color_override("font_pressed_color", ALIZARIN)
	b.pressed.connect(cb)
	return b

func _small(text: String, c: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _big(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", INK)
	return l

func _rule(c: Color) -> Control:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(0, 2)
	return r

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _make_tick(corner: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(14, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match corner:
		"tl": c.set_anchors_preset(Control.PRESET_TOP_LEFT); c.position = Vector2(14, 14)
		"tr": c.set_anchors_preset(Control.PRESET_TOP_RIGHT); c.position = Vector2(-28, 14)
		"bl": c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); c.position = Vector2(14, -28)
		"br": c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); c.position = Vector2(-28, -28)
	c.draw.connect(func():
		var h := corner.begins_with("t")
		var l := corner.ends_with("l")
		var y := 0.0 if h else 14.0
		var x := 0.0 if l else 14.0
		c.draw_line(Vector2(0, y), Vector2(14, y), TICK, 1.0)
		c.draw_line(Vector2(x, 0), Vector2(x, 14), TICK, 1.0)
	)
	return c
