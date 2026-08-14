extends Control
class_name MakeYourOwn

# "Make Your Own Saboteur Board" screen. Lets players export the print-and-play
# PDFs (board, pieces, cards, rulebook) via a native Save As dialog. Honor-system
# note up top: intended only for people who bought the physical game. Same visual
# language as the other menu screens. Emits `back`.

signal back

const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")
const BODY := Color("#33302b")
const HAIR := Color("#eceae4")

const TICK_SIZE := 26.0
const TICK_INSET := 14.0
const TICK_THICK := 2.0

# label, description, source path in res://, default save filename, section.
# Only entries whose source file exists are shown. Section headers only appear
# if at least one entry under them is present.
const PRINTABLES := [
	["The Board & Pieces", "Everything you need to make your own 18x16 board and all pieces. Includes a 2cm calibration square - check your print scale.",
		"res://assets/printables/saboteur_print_sheet.pdf", "saboteur_print_sheet.pdf", "PRINT AND PLAY"],
	["The Cards", "The full deck - charts, types, and power cards - double-sided layout for easy printing on card stock and cutting.",
		"res://assets/printables/saboteur_card_sheet.pdf", "saboteur_card_sheet.pdf", "PRINT AND PLAY"],
	["Make Your Own Theme", "How to build a theme pack: file names, image sizes, and the texture.json manifest. Read this before you start drawing.",
		"res://assets/printables/saboteur_theme_guide.pdf", "saboteur_theme_guide.pdf", "THEMES"],
	["Theme Starter Pack", "A working theme you can take apart. Unzip it, change some art, zip it back up, and import it from Options > Themes.",
		"res://assets/printables/saboteur_theme_template.zip", "saboteur_theme_template.zip", "THEMES"],
]

var _dialog: FileDialog
var _pending_src: String = ""

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_corner_ticks()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	col.add_child(_eyebrow("MAKE YOUR OWN"))
	col.add_child(_spacer(6))
	col.add_child(_title("Put together your own Saboteur board"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(20))

	# Honor-system note, in a soft panel so it reads as a request, not fine print.
	var note_panel := PanelContainer.new()
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color("#FAF6EE")
	nsb.set_corner_radius_all(10)
	nsb.set_border_width_all(1)
	nsb.border_color = HAIR
	nsb.content_margin_left = 16
	nsb.content_margin_right = 16
	nsb.content_margin_top = 12
	nsb.content_margin_bottom = 12
	note_panel.add_theme_stylebox_override("panel", nsb)
	var note := Label.new()
	note.text = "Please only print these if you or a close homey bought the game from us."
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", BODY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	note_panel.add_child(note)
	col.add_child(note_panel)
	col.add_child(_spacer(30))

	# One row per available printable, grouped by section. A header is only
	# emitted when a section actually has a file present, so a build missing
	# the theme files shows no empty THEMES heading.
	var any := false
	var current_section: String = ""
	for p in PRINTABLES:
		if not (ResourceLoader.exists(p[2]) or FileAccess.file_exists(p[2])):
			continue
		var section: String = p[4]
		if section != current_section:
			if current_section != "":
				col.add_child(_spacer(30))
			col.add_child(_section_label(section))
			col.add_child(_spacer(10))
			current_section = section
		col.add_child(_printable_row(p[0], p[1], p[2], p[3]))
		any = true
	if not any:
		var empty := Label.new()
		empty.text = "No printable files are bundled with this build yet."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", MUTED)
		col.add_child(empty)

	col.add_child(_spacer(38))
	col.add_child(_back_option())

	# Native Save As dialog, created once and reused.
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.add_filter("*.pdf", "PDF Document")
	_dialog.add_filter("*.zip", "Zip Archive")
	_dialog.file_selected.connect(_on_save_path_chosen)
	add_child(_dialog)

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l

func _printable_row(title: String, desc: String, src: String, default_name: String) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = HAIR
	sb.border_width_top = 1
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	row.add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", INK)
	left.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", BODY)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(400, 0)
	left.add_child(desc_lbl)

	# Save button (dark, like End Turn / Play Again).
	var btn := Button.new()
	btn.text = "Save file..."
	btn.custom_minimum_size = Vector2(120, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = INK
	bsb.set_corner_radius_all(8)
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	var bsb_hover := bsb.duplicate()
	bsb_hover.bg_color = Color("#2a2a2a")
	btn.add_theme_stylebox_override("normal", bsb)
	btn.add_theme_stylebox_override("hover", bsb_hover)
	btn.add_theme_stylebox_override("pressed", bsb_hover)
	btn.add_theme_color_override("font_color", PAPER)
	btn.pressed.connect(_on_save_pressed.bind(src, default_name))
	h.add_child(btn)
	return row

func _on_save_pressed(src: String, default_name: String) -> void:
	_pending_src = src
	_dialog.current_file = default_name
	_dialog.popup_centered_ratio(0.6)

func _on_save_path_chosen(dst_path: String) -> void:
	if _pending_src == "":
		return
	var src := FileAccess.open(_pending_src, FileAccess.READ)
	if src == null:
		_pending_src = ""
		return
	var data := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		_pending_src = ""
		return
	dst.store_buffer(data)
	dst.close()
	_pending_src = ""

# ---- Shared widget helpers ----
func _eyebrow(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", INK)
	return l

func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

func _rule_line(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _back_option() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.custom_minimum_size = Vector2(0, 44)

	var lb := Label.new()
	lb.text = "["
	lb.add_theme_font_size_override("font_size", 30)
	lb.add_theme_color_override("font_color", MUTED)
	row.add_child(lb)

	var mid := Label.new()
	mid.text = "back"
	mid.add_theme_font_size_override("font_size", 30)
	mid.add_theme_color_override("font_color", INK)
	row.add_child(mid)

	var rb := Label.new()
	rb.text = "]"
	rb.add_theme_font_size_override("font_size", 30)
	rb.add_theme_color_override("font_color", MUTED)
	row.add_child(rb)

	row.mouse_entered.connect(func():
		_tween_row_x(row, 6.0)
		lb.add_theme_color_override("font_color", ALIZARIN)
		mid.add_theme_color_override("font_color", ALIZARIN)
		rb.add_theme_color_override("font_color", ALIZARIN)
	)
	row.mouse_exited.connect(func():
		_tween_row_x(row, 0.0)
		lb.add_theme_color_override("font_color", MUTED)
		mid.add_theme_color_override("font_color", INK)
		rb.add_theme_color_override("font_color", MUTED)
	)
	row.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			back.emit()
	)
	return row

func _tween_row_x(row: Control, to_x: float) -> void:
	var t := create_tween()
	t.tween_property(row, "position:x", to_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_corner_ticks() -> void:
	for corner in ["tl", "tr", "bl", "br"]:
		add_child(_make_tick(corner))

func _make_tick(corner: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(TICK_SIZE, TICK_SIZE)
	c.size = Vector2(TICK_SIZE, TICK_SIZE)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match corner:
		"tl":
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2(TICK_INSET, TICK_INSET)
		"tr":
			c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			c.anchor_left = 1.0; c.anchor_right = 1.0
			c.position = Vector2(-TICK_INSET - TICK_SIZE, TICK_INSET)
		"bl":
			c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
			c.position = Vector2(TICK_INSET, -TICK_INSET - TICK_SIZE)
		"br":
			c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			c.anchor_left = 1.0; c.anchor_right = 1.0
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
			c.position = Vector2(-TICK_INSET - TICK_SIZE, -TICK_INSET - TICK_SIZE)
	c.draw.connect(_draw_tick.bind(c, corner))
	return c

func _draw_tick(c: Control, corner: String) -> void:
	var w := TICK_SIZE
	match corner:
		"tl":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)
		"tr":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)
		"bl":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)
		"br":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)
