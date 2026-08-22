extends Control
class_name MainMenu

# Native Godot port of menu_mockup.html. Matches its visual language exactly:
# crop-mark corner ticks, an uppercase letterspaced eyebrow, a large LIGHT-weight
# two-word title, the signature red-over-blue double rule, an italic muted
# attribution line, and bracketed [ option ] rows that slide right on hover with
# an alternating royal-blue / alizarin accent. Built entirely in code to match the
# rest of this project (no .tscn dependency).
#
# 2026-08-03: whole screen scaled down and pulled in behind a page margin, since
# the list reads long rather than tight. "start game" is now a parent row that
# reveals a borderless flyout to its right - bare text, no panel chrome, dithered
# in pixel by pixel. "local game" reuses the existing start_game id, so
# menu_root.gd needs no changes.

# ---- Palette (from the mockup's :root) ----
const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")
const FOOT_COL := Color("#b3ada2")

# Emitted when a menu option is chosen; the host (e.g. an outer Main scene) decides
# what each does. Kept as a signal so this screen stays decoupled from game/scene
# loading specifics.
signal option_selected(id: String)

# id, label. "start_game" is now a parent that opens SUBMENU_START rather than
# firing directly; host_game / join_game moved into that flyout.
const OPTIONS := [
	["start_game", "start game"],
	["how_to_play", "how to play"],
	["house_rules", "house rules"],
	["options", "options"],
	["replay", "replay"],
	["make_your_own", "make your own board"],
	["credits", "credits"],
	["story", "lore"],
	["quit", "quit"],
]

# The id that opens a flyout instead of emitting.
const PARENT_ID := "start_game"

# Flyout contents. "local game" emits start_game, which menu_root.gd already
# handles as a plain offline launch.
const SUBMENU_START := [
	["host_game", "host game"],
	["join_game", "join game"],
	["local_game", "local game"],
]

# "local game" is itself a parent, opening a second flyout to its right.
const LOCAL_PARENT_ID := "local_game"

const SUBMENU_LOCAL := [
	["start_cpu_game", "player vs CPU"],
	["start_game", "player vs player"],
]

const TICK_SIZE := 22.0
const TICK_INSET := 12.0
const TICK_THICK := 2.0

# ---- Layout tuning ----
const PAGE_MARGIN := 56          # breathing room from the viewport edges
const COLUMN_WIDTH := 560
const TITLE_FONT := 60
const ROW_FONT := 24
const ROW_HEIGHT := 38.0
const ROW_SEPARATION := 2        # as it was
const BRACKET_GAP := 9           # space between [ , label , ]
const SUBMENU_X_GAP := 26.0      # horizontal offset from the start-game row
const SUBMENU_Y_DROP := 2.0      # top flyout item sits 2px below the parent line
const SUBMENU_CLOSE_DELAY := 0.30
const REVEAL_TIME := 0.32
const REVEAL_PIXEL := 3.0        # dither cell size, in screen pixels

# Dither-in shader: each screen-space cell gets a stable pseudo-random threshold,
# and cells above the current reveal value are discarded. Tweening `reveal` from
# 0 to 1 makes the glyphs materialize pixel by pixel rather than fading as a
# whole. Note this is a plain canvas_item shader - no MODULATE builtin exists in
# Godot 4, and none is needed here since we only gate alpha via discard.
const REVEAL_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float cell_px = 3.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	if (reveal < 0.999) {
		vec2 cell = floor(FRAGCOORD.xy / max(cell_px, 1.0));
		if (hash21(cell) > reveal) {
			discard;
		}
	}
}
"""

var _submenu: VBoxContainer = null
var _start_row: Control = null
var _close_timer: Timer = null
var _reveal_mat: ShaderMaterial = null
var _reveal_tween: Tween = null

# Second-level flyout hanging off "local game".
var _submenu2: VBoxContainer = null
var _local_row: Control = null
var _reveal_mat2: ShaderMaterial = null
var _reveal_tween2: Tween = null
var _local_row_clear: Callable = Callable()
# Restores the parent row's ink/muted colors; held so the row can stay accented
# for as long as the flyout is open.
var _start_row_clear: Callable = Callable()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	print("MainMenu _ready - requesting menu music")
	MusicManager.play_track(MusicManager.Track.MENU, 0.0)
	_build()

func _build() -> void:
	# Opaque paper background covering the whole viewport.
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_corner_ticks()

	# ---- Page margin, then the centered screen column ----
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", PAGE_MARGIN)
	margin.add_theme_constant_override("margin_right", PAGE_MARGIN)
	margin.add_theme_constant_override("margin_top", PAGE_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PAGE_MARGIN)
	add_child(margin)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var screen := VBoxContainer.new()
	screen.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	screen.add_theme_constant_override("separation", 0)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(screen)

	# ---- Title block ----
	var eyebrow := Label.new()
	eyebrow.text = "A TWO-PLAYER GAME OF FEINTS & CONVERSIONS"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", MUTED)
	# letterspacing/uppercase are baked into the string; Godot has no CSS tracking,
	# so we approximate the .32em tracking with spaced caps only where it reads well.
	eyebrow.add_theme_constant_override("line_spacing", 0)
	screen.add_child(eyebrow)

	screen.add_child(_spacer(4))

	# Big light-weight title. DejaVu Sans (Godot default) has no dedicated Light
	# weight, so we lean on size + generous tracking to echo the mockup's
	# regular-not-bold feel rather than faking weight.
	var title := Label.new()
	title.text = "Wireframe Saboteur"
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.add_theme_color_override("font_color", INK)
	screen.add_child(title)

	screen.add_child(_spacer(7))

	# ---- Signature double rule: red over blue ----
	screen.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	screen.add_child(_spacer(4))
	screen.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))

	screen.add_child(_spacer(10))

	var attrib := Label.new()
	attrib.text = "A computer game totally derivative of The Saboteurs by Noah Matuszewski."
	attrib.add_theme_font_size_override("font_size", 12)
	attrib.add_theme_color_override("font_color", MUTED)
	attrib.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attrib.custom_minimum_size = Vector2(440, 0)
	screen.add_child(attrib)

	screen.add_child(_spacer(20))

	# ---- Menu options ----
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", ROW_SEPARATION)
	screen.add_child(menu)

	for i in range(OPTIONS.size()):
		var id: String = OPTIONS[i][0]
		var label: String = OPTIONS[i][1]
		# Even-indexed rows (0-based) accent blue; odd accent red - the mockup uses
		# :nth-child(even) for the red accent (1-based even = our odd index).
		var accent: Color = ALIZARIN if (i % 2 == 1) else ROYAL_BLUE
		var row := _build_option(id, label, accent, 1 if id == PARENT_ID else 0, false)
		menu.add_child(row)
		if id == PARENT_ID:
			_start_row = row

	# ---- Footer ----
	var foot := Label.new()
	foot.text = "WIREFRAME SABOTEUR"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 10)
	foot.add_theme_color_override("font_color", FOOT_COL)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -34
	foot.offset_bottom = -22
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)

	_build_submenu()

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

# ---------------------------------------------------------------------------
# Flyout: no panel, no border, no background. Just the rows.
# ---------------------------------------------------------------------------

func _build_submenu() -> void:
	# A single deferred close timer. Its timeout re-checks where the pointer
	# actually is, which is more reliable than mouse_exited: a Control fires
	# mouse_exited when the pointer moves onto one of its own children, so
	# exit-driven closing would fight the rows inside the flyout.
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.wait_time = SUBMENU_CLOSE_DELAY
	_close_timer.timeout.connect(_on_close_timeout)
	add_child(_close_timer)

	var sh := Shader.new()
	sh.code = REVEAL_SHADER
	_reveal_mat = ShaderMaterial.new()
	_reveal_mat.shader = sh
	_reveal_mat.set_shader_parameter("reveal", 1.0)
	_reveal_mat.set_shader_parameter("cell_px", REVEAL_PIXEL)

	_submenu = VBoxContainer.new()
	_submenu.visible = false
	_submenu.z_index = 20
	_submenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submenu.add_theme_constant_override("separation", ROW_SEPARATION)

	for i in range(SUBMENU_START.size()):
		var id: String = SUBMENU_START[i][0]
		var label: String = SUBMENU_START[i][1]
		var accent: Color = ALIZARIN if (i % 2 == 1) else ROYAL_BLUE
		var row := _build_option(id, label, accent, 2 if id == LOCAL_PARENT_ID else 0, true)
		_submenu.add_child(row)
		if id == LOCAL_PARENT_ID:
			_local_row = row

	add_child(_submenu)

	# --- second level: its own material so its dither tween runs independently ---
	var sh2 := Shader.new()
	sh2.code = REVEAL_SHADER
	_reveal_mat2 = ShaderMaterial.new()
	_reveal_mat2.shader = sh2
	_reveal_mat2.set_shader_parameter("reveal", 1.0)
	_reveal_mat2.set_shader_parameter("cell_px", REVEAL_PIXEL)

	_submenu2 = VBoxContainer.new()
	_submenu2.visible = false
	_submenu2.z_index = 21
	_submenu2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submenu2.add_theme_constant_override("separation", ROW_SEPARATION)

	for i in range(SUBMENU_LOCAL.size()):
		var id2: String = SUBMENU_LOCAL[i][0]
		var label2: String = SUBMENU_LOCAL[i][1]
		var accent2: Color = ALIZARIN if (i % 2 == 1) else ROYAL_BLUE
		_submenu2.add_child(_build_option(id2, label2, accent2, 0, true, _reveal_mat2))

	add_child(_submenu2)

func _open_submenu() -> void:
	if _submenu == null or _start_row == null:
		return
	_close_timer.stop()
	if _submenu.visible:
		return
	_submenu.visible = true
	_submenu.size = _submenu.get_combined_minimum_size()
	_place_submenu()
	# Re-place once layout has settled, in case font metrics changed the width.
	call_deferred("_place_submenu")

	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_mat.set_shader_parameter("reveal", 0.0)
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_reveal_mat, "shader_parameter/reveal", 1.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_LINEAR)

func _place_submenu() -> void:
	if _submenu == null or not _submenu.visible or _start_row == null:
		return
	var r := _start_row.get_global_rect()
	# The parent row slides 6px right on hover; anchor to its resting edge so the
	# flyout does not jitter with it.
	var x := r.position.x + r.size.x + SUBMENU_X_GAP
	var y := r.position.y + SUBMENU_Y_DROP
	var vp := get_viewport_rect().size
	x = min(x, vp.x - _submenu.size.x - float(PAGE_MARGIN))
	y = clamp(y, float(PAGE_MARGIN), max(float(PAGE_MARGIN), vp.y - _submenu.size.y - float(PAGE_MARGIN)))
	_submenu.global_position = Vector2(x, y)

func _open_submenu2() -> void:
	_open_submenu()   # hovering the local row must keep its parent flyout up
	if _submenu2 == null or _local_row == null:
		return
	_close_timer.stop()
	if _submenu2.visible:
		return
	_submenu2.visible = true
	_submenu2.size = _submenu2.get_combined_minimum_size()
	_place_submenu2()
	call_deferred("_place_submenu2")

	if _reveal_tween2 != null and _reveal_tween2.is_valid():
		_reveal_tween2.kill()
	_reveal_mat2.set_shader_parameter("reveal", 0.0)
	_reveal_tween2 = create_tween()
	_reveal_tween2.tween_property(_reveal_mat2, "shader_parameter/reveal", 1.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_LINEAR)

func _place_submenu2() -> void:
	if _submenu2 == null or not _submenu2.visible or _local_row == null:
		return
	var r := _local_row.get_global_rect()
	var x := r.position.x + r.size.x + SUBMENU_X_GAP
	var y := r.position.y + SUBMENU_Y_DROP
	var vp := get_viewport_rect().size
	x = min(x, vp.x - _submenu2.size.x - float(PAGE_MARGIN))
	y = clamp(y, float(PAGE_MARGIN), max(float(PAGE_MARGIN), vp.y - _submenu2.size.y - float(PAGE_MARGIN)))
	_submenu2.global_position = Vector2(x, y)

func _request_close_submenu() -> void:
	if _submenu != null and _submenu.visible:
		_close_timer.start()

func _on_close_timeout() -> void:
	if _submenu == null or not _submenu.visible:
		return
	# Stay open while the pointer is anywhere in the row, either gap, or either flyout.
	var mp := get_global_mouse_position()
	var bridge := _start_row.get_global_rect().merge(_submenu.get_global_rect())
	if _submenu2 != null and _submenu2.visible:
		bridge = bridge.merge(_submenu2.get_global_rect())
	if bridge.grow(8.0).has_point(mp):
		_close_timer.start()
		return
	_hide_submenu()

func _hide_submenu2() -> void:
	if _submenu2 == null or not _submenu2.visible:
		return
	if _reveal_tween2 != null and _reveal_tween2.is_valid():
		_reveal_tween2.kill()
	_reveal_mat2.set_shader_parameter("reveal", 1.0)
	_submenu2.visible = false
	if _local_row != null and _local_row_clear.is_valid():
		if not _local_row.get_global_rect().has_point(get_global_mouse_position()):
			_tween_row_x(_local_row, 0.0)
			_local_row_clear.call()

func _hide_submenu() -> void:
	if _submenu == null:
		return
	_hide_submenu2()
	_close_timer.stop()
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_mat.set_shader_parameter("reveal", 1.0)
	_submenu.visible = false
	if _start_row != null and _start_row_clear.is_valid():
		if not _start_row.get_global_rect().has_point(get_global_mouse_position()):
			_tween_row_x(_start_row, 0.0)
			_start_row_clear.call()

# ---------------------------------------------------------------------------
# Option rows
# ---------------------------------------------------------------------------

# One [ label ] row: baseline-aligned brackets + label, slides right on hover and
# recolors to its accent, mirroring the mockup's transform + color transition.
# `is_parent` rows open the flyout instead of emitting, and stay accented while
# it is open.
# `parent_of`: 0 = plain row, 1 = opens the start flyout, 2 = opens the local flyout.
func _build_option(id: String, label: String, accent: Color, parent_of: int, dither: bool, mat: ShaderMaterial = null) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", BRACKET_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var lb := _row_label("[", MUTED, dither, mat)
	row.add_child(lb)
	var mid := _row_label(label, INK, dither, mat)
	row.add_child(mid)
	var rb := _row_label("]", MUTED, dither, mat)
	row.add_child(rb)

	# A trailing chevron marks the row that opens a flyout.
	if parent_of > 0:
		row.add_child(_row_label(">", TICK_COL, dither, mat))

	var set_accent := func() -> void:
		lb.add_theme_color_override("font_color", accent)
		mid.add_theme_color_override("font_color", accent)
		rb.add_theme_color_override("font_color", accent)
	var clear_accent := func() -> void:
		lb.add_theme_color_override("font_color", MUTED)
		mid.add_theme_color_override("font_color", INK)
		rb.add_theme_color_override("font_color", MUTED)

	if parent_of == 1:
		_start_row_clear = clear_accent
	elif parent_of == 2:
		_local_row_clear = clear_accent

	row.mouse_entered.connect(func() -> void:
		#SfxManager.play_menu_hover()
		_tween_row_x(row, 6.0)
		set_accent.call()
		if parent_of == 1:
			_open_submenu()
		elif parent_of == 2:
			_open_submenu2()
		elif _is_submenu2_row(row):
			pass                     # already deepest level
		elif _is_submenu_row(row):
			_hide_submenu2()         # sibling of "local game" — collapse its flyout
		else:
			_hide_submenu()          # a plain top-level row dismisses everything
	)
	row.mouse_exited.connect(func() -> void:
		if parent_of == 1 and _submenu != null and _submenu.visible:
			return   # keep the parent lit while its flyout is up
		if parent_of == 2 and _submenu2 != null and _submenu2.visible:
			return
		_tween_row_x(row, 0.0)
		clear_accent.call()
		if _is_submenu_row(row) or _is_submenu2_row(row):
			_request_close_submenu()
	)
	row.gui_input.connect(func(event) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			#SfxManager.play("menu_click")
			if parent_of == 1:
				_open_submenu()
				return
			if parent_of == 2:
				_open_submenu2()
				return
			if _is_submenu_row(row) or _is_submenu2_row(row):
				_hide_submenu()
			option_selected.emit(id)
	)
	return row

# Flyout labels share one ShaderMaterial per level, so a single uniform tween
# dithers every glyph on that level in at once.
func _row_label(text: String, col: Color, dither: bool, mat: ShaderMaterial = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ROW_FONT)
	l.add_theme_color_override("font_color", col)
	if dither:
		var m: ShaderMaterial = mat if mat != null else _reveal_mat
		if m != null:
			l.material = m
	return l

# True if this row lives inside the flyout rather than the main column.
func _is_submenu_row(row: Control) -> bool:
	if _submenu == null:
		return false
	return _submenu.is_ancestor_of(row)

func _is_submenu2_row(row: Control) -> bool:
	if _submenu2 == null:
		return false
	return _submenu2.is_ancestor_of(row)

func _tween_row_x(row: Control, to_x: float) -> void:
	var t := create_tween()
	t.tween_property(row, "position:x", to_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_corner_ticks() -> void:
	# Four L-shaped crop marks in the viewport corners, matching .tick.tl/tr/bl/br.
	# Each is a Control drawn with two lines via a small draw callback.
	for corner in ["tl", "tr", "bl", "br"]:
		var tick := _make_tick(corner)
		add_child(tick)

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
			c.position = Vector2(-TICK_INSET - TICK_SIZE, TICK_INSET)
			c.anchor_left = 1.0; c.anchor_right = 1.0
		"bl":
			c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			c.position = Vector2(TICK_INSET, -TICK_INSET - TICK_SIZE)
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
		"br":
			c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			c.anchor_left = 1.0; c.anchor_right = 1.0
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
			c.position = Vector2(-TICK_INSET - TICK_SIZE, -TICK_INSET - TICK_SIZE)
	c.draw.connect(_draw_tick.bind(c, corner))
	return c

func _draw_tick(c: Control, corner: String) -> void:
	var w := TICK_SIZE
	# Which two edges form the L depends on the corner.
	match corner:
		"tl":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)   # top
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)   # left
		"tr":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)   # top
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)   # right
		"bl":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)   # bottom
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)   # left
		"br":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)   # bottom
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)   # right
