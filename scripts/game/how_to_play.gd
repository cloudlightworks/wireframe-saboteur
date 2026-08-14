extends Control
class_name HowToPlay

# How-to-play screen sharing MainMenu's visual language (corner ticks, eyebrow,
# red-over-blue signature rule, muted ink palette), with scrollable rules content
# and real in-game piece + card thumbnails. Emits `back` when the player leaves.

signal back
signal tutorial_requested

# ---- Palette (shared with MainMenu / the card+tray system) ----
const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")

const TICK_SIZE := 26.0
const TICK_INSET := 14.0
const TICK_THICK := 2.0

const PIECE_DIR := "res://assets/sprites/pieces/"
const CARD_DIR := "res://assets/sprites/cards/"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_corner_ticks()

	# Scroll container so dense rules content never clips.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 0
	scroll.offset_top = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	# Centered content column.
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(720, 0)
	col.add_theme_constant_override("separation", 0)
	# top/bottom breathing room inside the scroll
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_child(col)
	center.add_child(pad)

	# ---- Header ----
	col.add_child(_eyebrow("HOW TO PLAY"))
	col.add_child(_spacer(6))
	col.add_child(_title("Feints & Conversions"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(30))

	# ---- Goal ----
	col.add_child(_section("The Goal"))
	col.add_child(_body("Capture your opponent's Objective. The moment a player's Objective is taken, the game ends and the capturer wins. Everything else on the board exists to protect your own Objective and open a lane to theirs."))
	col.add_child(_spacer(26))

	# ---- The Army ----
	col.add_child(_section("The Army"))
	col.add_child(_body("Each side commands the same forces: twelve A pieces, six B pieces, three C pieces, one General, and one Objective. A, B, and C are the fighting pieces; they capture one another in a cycle."))
	col.add_child(_spacer(14))
	col.add_child(_piece_gallery())
	col.add_child(_spacer(26))

	# ---- Capture cycle ----
	col.add_child(_section("The Capture Cycle"))
	col.add_child(_body("The three fighting types beat each other in a ring: A captures C, C captures B, B captures A. When a piece meets an enemy it beats, that enemy is captured. When two pieces of the SAME type meet, they mutually annihilate \u2014 both are removed."))
	col.add_child(_spacer(14))
	col.add_child(_cycle_row())
	col.add_child(_spacer(26))

	# ---- Setup & turns ----
	col.add_child(_section("Setup & Turns"))
	col.add_child(_body("During Croce setup each player secretly places their army in their home rows. On your turn you may move one piece, and you may also play power cards from your hand. A movement or a successful card deployment enables the End Turn button."))
	col.add_child(_spacer(26))

	# ---- Controls ----
	col.add_child(_section("Controls"))
	col.add_child(_body("Almost everything is done by clicking, but a few keys speed things up:"))
	col.add_child(_spacer(14))
	col.add_child(_controls_table())
	col.add_child(_spacer(26))
	
	# ---- The General ----
	col.add_child(_section("The General"))
	col.add_child(_body("The General moves diagonally within its own half and captures A, B, or C freely \u2014 but it cannot be captured by ordinary pieces, and it cannot take an enemy Objective or General. Only a declared Saboteur (or special power cards) can bring a General down."))
	col.add_child(_spacer(14))
	col.add_child(_general_color_table())
	col.add_child(_spacer(26))
	
	# ---- Saboteurs ----
	col.add_child(_section("Declaring a Saboteur"))
	col.add_child(_body("Play a Type card together with a Chart card to name one specific enemy piece by its designation (for example, A7). That piece becomes YOUR Saboteur: it flips to your control and can strike where your own pieces cannot \u2014 including at an enemy General. You may only have one active Saboteur at a time."))
	col.add_child(_spacer(26))

	# ---- Power cards ----
	col.add_child(_section("Power Cards"))
	col.add_child(_body("Minor and Major powers bend the rules for a turn: extra moves, protection from mutual annihilation, redeploying a fallen piece, freezing an enemy General, and more. Each card explains its own effect."))
	col.add_child(_spacer(14))
	col.add_child(_card_gallery())
	col.add_child(_spacer(26))

	# ---- Chat & taunts ----
	col.add_child(_section("Chat & Taunts"))
	col.add_child(_body("In an online match you can talk to your opponent \u2014 and needle them. Press T to open the chat box; it stays where you put it until you close it with [ x ]."))
	col.add_child(_spacer(14))
	col.add_child(_chat_note())
	col.add_child(_spacer(40))

	# ---- Back ----
	col.add_child(_back_option())

	# Gameplay Tutorial button: pinned top-right, floating above the scroll content
	# (added after scroll so it draws on top and catches clicks). Emits
	# tutorial_requested -- not wired to an actual tutorial yet.
	_build_tutorial_button()

func _build_tutorial_button() -> void:
	var btn := Button.new()
	btn.text = "Gameplay Tutorial"
	btn.add_theme_font_size_override("font_size", 17)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	# Sit just below the top-right corner tick, inset from the right edge.
	btn.position = Vector2(-232.0, 150.0)
	btn.custom_minimum_size = Vector2(190, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1FA83A")            # green, like the mockup
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("#25C445")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.pressed.connect(func(): tutorial_requested.emit())
	add_child(btn)

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

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", INK)
	return l

func _body(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color("#33302b"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(680, 0)
	# a hair of top padding so section header + body read as a unit
	l.add_theme_constant_override("line_spacing", 4)
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

# A small key-reference. Each row is a rendered keycap plus what it does.
# Only real player-facing bindings are listed - debug keys are omitted.
func _controls_table() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 12)

	var rows := [
		["Click", "Select a piece, then click a highlighted square to move. Click a card to pick it up; click again to select it."],
		["R", "During setup and redeployment, rotate a B piece between upright and sideways before placing it."],
		["Enter", "End your turn (same as the End Turn button)."],
		["T", "In an online match, open the chat box \u2014 see Chat & Taunts below."],
		["Esc", "Pause the game \u2014 open sound options, return to the menu, or quit."],
	]

	for entry in rows:
		var key_text: String = entry[0]
		var desc_text: String = entry[1]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Keycap
		var cap := PanelContainer.new()
		cap.custom_minimum_size = Vector2(74, 38)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color("#f4f2ec")
		csb.border_color = Color("#141414")
		csb.set_border_width_all(2)
		csb.set_corner_radius_all(7)
		csb.shadow_color = Color(0, 0, 0, 0.18)
		csb.shadow_size = 0
		csb.shadow_offset = Vector2(0, 2)
		csb.content_margin_left = 12
		csb.content_margin_right = 12
		csb.content_margin_top = 6
		csb.content_margin_bottom = 6
		cap.add_theme_stylebox_override("panel", csb)
		var cap_lbl := Label.new()
		cap_lbl.text = key_text
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 16)
		cap_lbl.add_theme_color_override("font_color", INK)
		cap.add_child(cap_lbl)
		row.add_child(cap)

		# Description
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", 15)
		desc.add_theme_color_override("font_color", INK)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.custom_minimum_size = Vector2(560, 0)
		row.add_child(desc)

		wrap.add_child(row)

	return wrap

# A framed callout covering the in-match chat box and taunt stickers. Kept in
# the same paper-and-ink language as the rest of the page: hairline border,
# muted eyebrow, short tag on the left, plain description on the right.
func _chat_note() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(680, 0)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#faf8f3")
	fsb.border_color = Color("#d8d2c6")
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(8)
	fsb.content_margin_left = 20
	fsb.content_margin_right = 20
	fsb.content_margin_top = 18
	fsb.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", fsb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	box.add_child(_eyebrow("ONLINE MATCHES ONLY"))

	var rows := [
		["T", "Open the chat box. Middle-clicking does the same. While the text field has focus the board ignores your clicks."],
		["Esc", "Step back out to the board without closing the box. Clicking anywhere off the panel does the same."],
		["[ \u263a ]", "Open the taunt stickers. Double-click one to post it in the chat box; single-click one to pick it up, then click a square on the board to plant it there."],
		["Drag", "Move the box by dragging its body. Hover a corner until the tick appears, then drag to resize."],
	]
	for entry in rows:
		box.add_child(_chat_row(entry[0], entry[1]))

	box.add_child(_spacer(2))

	var foot := Label.new()
	foot.text = "Messages hold up to 240 characters, and sending too fast earns a \u201cSlow down.\u201d While the box is closed, a red counter marks unread messages \u2014 click it to reopen. Nothing said or stuck to the board changes the game: chat cannot move a piece, play a card, or end a turn."
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", MUTED)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(628, 0)
	foot.add_theme_constant_override("line_spacing", 3)
	box.add_child(foot)

	return frame

func _chat_row(tag: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.add_theme_font_size_override("font_size", 15)
	tag_lbl.add_theme_color_override("font_color", INK)
	tag_lbl.custom_minimum_size = Vector2(74, 0)
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(tag_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color("#33302b"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(540, 0)
	row.add_child(desc_lbl)

	return row

# A row of blue-side piece thumbnails with captions. Uses real in-game sprites;
# any that fail to load are simply skipped so a missing asset never crashes.
func _piece_gallery() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var items := [
		["@tex:blue_A1.png|blue_A.png", "A"],
		["@tex:blue_B1_vertical.png|blue_B_vertical.png", "B"],
		["@tex:blue_C1.png|blue_C.png", "C"],
		["@tex:general_yellow.png", "General"],
		["@tex:objective_blue.png", "Objective"],
	]
	for it in items:
		var cell := _thumb_cell(it[0], it[1], 64.0)
		if cell:
			row.add_child(cell)
	return row

# The A -> C -> B -> A capture ring, shown as labeled swatches with arrows.
func _cycle_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var seq := ["A", "C", "B", "A"]
	for i in range(seq.size()):
		row.add_child(_cycle_chip(seq[i]))
		if i < seq.size() - 1:
			var arrow := Label.new()
			arrow.text = "\u2192"
			arrow.add_theme_font_size_override("font_size", 24)
			arrow.add_theme_color_override("font_color", MUTED)
			row.add_child(arrow)
	return row

func _cycle_chip(letter: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_border_width_all(2)
	sb.border_color = INK
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = letter
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", INK)
	p.add_child(l)
	return p

# A sampling of power cards as thumbnails.
func _card_gallery() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cards := [
		CARD_DIR + "major_blitzkrieg.png",
		CARD_DIR + "minor_closecall_A.png",
		CARD_DIR + "major_doubleagent.png",
		CARD_DIR + "minor_ityd_A.png",
	]
	for path in cards:
		var cell := _thumb_cell(path, "", 132.0)
		if cell:
			row.add_child(cell)
	return row

# Shows each selectable side color and the two-tone treatment its General
# takes. Swatches pull live from RuleSettings so they always match the
# actual in-game colors rather than hardcoded copies.
func _general_color_table() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)

	var note := Label.new()
	note.text = "Different Generals for each player color:"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", MUTED)
	wrap.add_child(note)
	wrap.add_child(_spacer(4))

	# side color -> {bg, fg} as color-name keys, matching RuleSettings.GENERAL_SCHEME
	var scheme := [
		["blue",     "Blue",     "yellow",   "black"],
		["red",      "Red",      "black",    "yellow"],
		["yellow",   "Yellow",   "magenta",  "black"],
		["magenta",  "Magenta",  "black",    "lavender"],
		["green",    "Green",    "lavender", "black"],
		["lavender", "Lavender", "black",    "magenta"],
	]

	for entry in scheme:
		var side_key: String = entry[0]
		var side_name: String = entry[1]
		var bg_key: String = entry[2]
		var fg_key: String = entry[3]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)

		# Side color chip + name
		var chip := ColorRect.new()
		chip.color = RuleSettings.COLOR_HEX[side_key]
		chip.custom_minimum_size = Vector2(22, 22)
		row.add_child(chip)

		var name_lbl := Label.new()
		name_lbl.text = side_name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", INK)
		name_lbl.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_lbl)

		var arrow := Label.new()
		arrow.text = "\u2192"
		arrow.add_theme_font_size_override("font_size", 16)
		arrow.add_theme_color_override("font_color", MUTED)
		row.add_child(arrow)

		# A tiny General preview: bg-colored square with a fg-colored "G"
		var gen := Panel.new()
		gen.custom_minimum_size = Vector2(30, 30)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = RuleSettings.COLOR_HEX[bg_key]
		gsb.set_corner_radius_all(4)
		gen.add_theme_stylebox_override("panel", gsb)
		var g_lbl := Label.new()
		g_lbl.text = "G"
		g_lbl.add_theme_font_size_override("font_size", 18)
		g_lbl.add_theme_color_override("font_color", RuleSettings.COLOR_HEX[fg_key])
		g_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		g_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gen.add_child(g_lbl)
		row.add_child(gen)

		wrap.add_child(row)

	wrap.add_child(_spacer(6))
	var fallback := Label.new()
	fallback.text = "If either player picks Green, Saboteur reveals and move highlights switch from green to orange."
	fallback.add_theme_font_size_override("font_size", 13)
	fallback.add_theme_color_override("font_color", MUTED)
	fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback.custom_minimum_size = Vector2(680, 0)
	wrap.add_child(fallback)

	return wrap
	
# One thumbnail: image scaled to target width (aspect preserved) + optional caption.
# Returns null if the texture can't be loaded, so callers can skip it.
func _thumb_cell(path: String, caption: String, target_w: float) -> Control:
	var tex: Texture2D = null
	if path.begins_with("@tex:"):
		# "@tex:blue_A1.png|blue_A.png" -- candidates separated by a pipe.
		var cands: Array = path.substr(5).split("|")
		tex = TextureManager.resolve("pieces", cands)["texture"]
	elif ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		return null
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER

	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_size: Vector2 = tex.get_size()
	var h: float = target_w
	if tex_size.x > 0:
		h = target_w * (tex_size.y / tex_size.x)
	tr.custom_minimum_size = Vector2(target_w, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(tr)

	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", MUTED)
		cell.add_child(cap)
	return cell

func _back_option() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 44)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var lb := Label.new(); lb.text = "["
	lb.add_theme_font_size_override("font_size", 28)
	lb.add_theme_color_override("font_color", MUTED)
	row.add_child(lb)
	var mid := Label.new(); mid.text = "back to menu"
	mid.add_theme_font_size_override("font_size", 28)
	mid.add_theme_color_override("font_color", INK)
	row.add_child(mid)
	var rb := Label.new(); rb.text = "]"
	rb.add_theme_font_size_override("font_size", 28)
	rb.add_theme_color_override("font_color", MUTED)
	row.add_child(rb)

	row.mouse_entered.connect(func():
		_tween_row_x(row, 6.0)
		lb.add_theme_color_override("font_color", ROYAL_BLUE)
		mid.add_theme_color_override("font_color", ROYAL_BLUE)
		rb.add_theme_color_override("font_color", ROYAL_BLUE)
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
