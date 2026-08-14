extends Control
class_name HouseRules

# Native port of the House Rules mockup, in the same visual language as
# main_menu.gd / how_to_play.gd: corner crop-ticks, eyebrow, large light title,
# red-over-blue signature rule, bracketed [ back ] option. Lists all rule toggles
# with a build-status tag each (WORKING / NOT WIRED / NOT BUILT), so the screen is
# honest about which choices actually affect play. Wired rules read/write the
# RuleSettings autoload (which survives the menu->game change). If that autoload
# isn't registered, toggles still flip and remember via a local fallback dict, so
# the switch is never a dead placeholder. The "Player colors" row opens a picker.

signal back

# ---- Palette (shared with the other menu screens) ----
const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")
const BODY := Color("#33302b")
const HAIR := Color("#eceae4")

# Status tag colors (fg, bg).
const ST_LIVE := [Color("#3B6D11"), Color("#EAF3DE")]
const ST_INERT := [Color("#854F0B"), Color("#FAEEDA")]
const ST_UNBUILT := [Color("#7a7368"), Color("#F1EFE8")]

const TICK_SIZE := 26.0
const TICK_INSET := 14.0
const TICK_THICK := 2.0

# Rule rows. Each: settings_field (on RuleSettings, "" if none), name, status,
# base description, house description. Status: "live" / "inert" / "unbuilt".
# Working rules first. "on" (blue/STANDARD) always stores the base value; the
# field polarity is chosen so true == standard for every rule.
var _rules := [
	["ityd_deployment_zone_only", "I Thought You Were Dead: placement", "live",
		"A returned piece must go in your Croce deployment zone.",
		"A returned piece may be placed anywhere on your own half of the board."],
	["close_call_shields_all_simultaneous_mutuals", "Close Call! coverage", "live",
		"Shields C from ALL simultaneous mutual annihilations in one move.",
		"Converts only the FIRST mutual; later mutuals in the same move still apply."],
	["c_captures_resolve_independently", "C-capture card draws", "live",
		"Each piece a C overlaps resolves its card draw independently.",
		"Only the primary target resolves a draw."],
	["mutual_destruction_both_draw", "Mutual destruction draws", "live",
		"Both players draw a card on a mutual annihilation.",
		"Neither player draws."],
	["blitzkrieg_old_different_piece", "Old Blitzkrieg", "live",
		"Blitzkrieg grants +1 move; the same piece may move twice.",
		"The second move must be a DIFFERENT piece."],
	["require_move_to_end_turn", "Require a move to end turn", "live",
		"Deploying a card alone may end your turn (deploy-and-pass).",
		"You must move a piece before you can end your turn."],
	["objective_saboteurs_only", "Objective Capture: Who's Allowed", "live",
	"Any piece may capture the Objective.",
	"Only a Saboteur-status piece may capture it."],
]

var _rs: Node   # RuleSettings autoload (may be null if unregistered)
var _rows_host: VBoxContainer
var _main_view: Control
var _color_view: Control

# Fallback state used when the RuleSettings autoload isn't registered, so the
# toggles still flip visibly and remember within this screen session.
var _local_state := {}

func _ready() -> void:
	_rs = get_node_or_null("/root/RuleSettings")
	_build()

func _rule_value(field: String, default_val: bool) -> bool:
	if _rs and field != "" and field in _rs:
		return _rs.get(field)
	if _local_state.has(field):
		return _local_state[field]
	return default_val

func _set_rule(field: String, value: bool) -> void:
	if _rs and field != "" and field in _rs:
		_rs.set(field, value)
	_local_state[field] = value

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_corner_ticks()

	_main_view = _build_main_view()
	add_child(_main_view)

func _build_main_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

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

	col.add_child(_eyebrow("HOUSE RULES"))
	col.add_child(_spacer(6))
	col.add_child(_title("Bend the Rules"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(14))

	var intro := Label.new()
	intro.text = "Toggle any rule to its variant. Blue is the standard game; red marks a house rule in effect."
	intro.add_theme_font_size_override("font_size", 13)
	intro.add_theme_color_override("font_color", MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(520, 0)
	col.add_child(intro)
	col.add_child(_spacer(28))

	_rows_host = VBoxContainer.new()
	_rows_host.add_theme_constant_override("separation", 0)
	col.add_child(_rows_host)
	_rebuild_rows()

	col.add_child(_spacer(38))
	col.add_child(_back_option(func(): back.emit()))
	return root

func _rebuild_rows() -> void:
	for c in _rows_host.get_children():
		c.queue_free()
	# Standard rule rows.
	for i in range(_rules.size()):
		var r = _rules[i]
		_rows_host.add_child(_make_rule_row(r[0], r[1], r[2], r[3], r[4], i == 0))
	# Player-colors row (opens sub-view).

# One rule row: name + STANDARD/HOUSE tag + status tag, description, and a pill
# toggle. on == true means base/standard (blue); false means house rule (red).
func _make_rule_row(field: String, rname: String, status: String, base_desc: String, house_desc: String, first: bool) -> Control:
	var on := _rule_value(field, true)
	var accent := ROYAL_BLUE if on else ALIZARIN

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = HAIR
	sb.border_width_top = 1
	if _is_last_rule_row(field):
		sb.border_width_bottom = 1
	sb.content_margin_top = 15
	sb.content_margin_bottom = 15
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	row.add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	left.add_child(head)

	var name_lbl := Label.new()
	name_lbl.text = rname
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", INK)
	head.add_child(name_lbl)

	head.add_child(_pill("STANDARD" if on else "HOUSE RULE", accent, Color(0, 0, 0, 0), true))

	var desc := Label.new()
	desc.text = base_desc if on else house_desc
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", BODY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(430, 0)
	left.add_child(desc)

	var sw := _make_switch(on, func(new_on):
		_set_rule(field, new_on)
		_rebuild_rows()
	)
	h.add_child(sw)
	return row

func _is_last_rule_row(field: String) -> bool:
	return field == _rules[_rules.size() - 1][0]
	
# ---- Shared widget helpers (match main_menu.gd / how_to_play.gd) ----
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

# Small rounded tag. If outline_only, transparent fill with colored border+text;
# else filled bg with colored text.
func _pill(text: String, fg: Color, bg: Color, outline_only: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	if outline_only:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = fg
	else:
		sb.bg_color = bg
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	return p

func _status_label(status: String) -> String:
	match status:
		"live": return "WORKING"
		"inert": return "NOT WIRED"
		_: return "NOT BUILT"

func _status_colors(status: String) -> Array:
	match status:
		"live": return ST_LIVE
		"inert": return ST_INERT
		_: return ST_UNBUILT

# Pill on/off toggle. Calls cb(new_on) when clicked. The knob lives in a plain
# Control wrapper (NOT directly in the Button) because a Button re-lays-out its
# direct children and would override the knob's manual position, freezing it in
# place. With the plain wrapper the knob sits left when on, right when off.
func _make_switch(on: bool, cb: Callable) -> Control:
	var accent := ROYAL_BLUE if on else ALIZARIN

	var root := Control.new()
	root.custom_minimum_size = Vector2(52, 30)
	root.size = Vector2(52, 30)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(15)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.pressed.connect(func(): cb.call(not on))
	root.add_child(btn)

	# Circular knob, manually positioned inside the plain Control (sticks here).
	var kpanel := Panel.new()
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = PAPER
	ksb.set_corner_radius_all(12)
	kpanel.add_theme_stylebox_override("panel", ksb)
	kpanel.size = Vector2(24, 24)
	kpanel.position = Vector2(3 if on else 25, 3)
	kpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kpanel)

	return root

# Bracketed [ label ] text button that recolors/slides on hover, emits on click.
func _bracket_button(label: String, cb: Callable) -> Control:
	# No slide: this sits inline at the right of a row, so shifting it would
	# overlap the description text. Hover just recolors.
	return _make_bracket_row(label, ROYAL_BLUE, cb, false)

func _back_option(cb: Callable) -> Control:
	return _make_bracket_row("back", ALIZARIN, cb, true)

func _make_bracket_row(label: String, accent: Color, cb: Callable, slide: bool) -> Control:
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
	mid.text = label
	mid.add_theme_font_size_override("font_size", 30)
	mid.add_theme_color_override("font_color", INK)
	row.add_child(mid)

	var rb := Label.new()
	rb.text = "]"
	rb.add_theme_font_size_override("font_size", 30)
	rb.add_theme_color_override("font_color", MUTED)
	row.add_child(rb)

	row.mouse_entered.connect(func():
		if slide:
			_tween_row_x(row, 6.0)
		lb.add_theme_color_override("font_color", accent)
		mid.add_theme_color_override("font_color", accent)
		rb.add_theme_color_override("font_color", accent)
	)
	row.mouse_exited.connect(func():
		if slide:
			_tween_row_x(row, 0.0)
		lb.add_theme_color_override("font_color", MUTED)
		mid.add_theme_color_override("font_color", INK)
		rb.add_theme_color_override("font_color", MUTED)
	)
	row.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
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
