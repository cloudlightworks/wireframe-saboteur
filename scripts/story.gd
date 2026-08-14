extends Control
class_name Story

# The Story screen, in the shared menu visual language (corner ticks, eyebrow,
# large light title, red-over-blue signature rule, bracketed [ back ]). Presents
# the origin narrative as flowing prose, then a placeholder index of deeper
# sections (The Board, The Pieces, etc.) to be filled in later. The Cards
# row opens cardspage.gd. Emits `back`.
#
# Narrative text is verbatim from No's story mockup. Ampersands/apostrophes kept
# ASCII. The section index rows are inert placeholders for now.

signal back

var _photo_overlay: Control
var _photo_back_overlay: Control
var _scroll: ScrollContainer

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

# Margin photo rails: fixed-width columns on either side of the text where
# story_01..08.jpg are placed in numerical order, alternating left/right as
# you scroll down (odd numbers left, even numbers right).
const RAIL_WIDTH := 40.0
const PHOTO_WIDTH := 255.0
const PHOTO_GAP := 190.0
const RAIL_STAGGER := 95.0
const PHOTO_RADIUS := 14.0

# Screen-space anchor points for the eight floating photos (left column x, right
# column x), spaced down the page. They start here and can be dragged anywhere.
const PHOTO_LEFT_X := 60.0
const PHOTO_RIGHT_X := 1180.0
const PHOTO_TOP := 40.0
const PHOTO_STEP := 300.0

# The later archive images sit on a separate lower visual layer, scattered so
# that the original 01-08 photographs partly cover them. Both layers are tied
# to the story scroll and every photograph remains independently draggable.
const BACK_PHOTO_WIDTH := 215.0

const PARAGRAPHS := [
	"The story of the game of Saboteur begins on the graveyard shift in a little gas station outside of Philadelphia. In a mysterious creative fugue, local ginger bricoleur Noah Matuszewski conceived of a board game wherein pieces captured one another via a rock/paper/scissors-style system, and wherein any one of a player's own pieces might be turned to the other side as a saboteur.",
	"Using foamcore board, index cards, markers, and tape, he brought forth the world's first Saboteur board, and he rested.",
	"Over the following days and weeks Noah invited others to play his creation. These included his co-workers at the gas station: Jamie, an intense jazz musician with a dashing ponytail; Amber, a brilliant and hilarious young volleyball player; Andrew, motorcycling poet and secret husband of Amber; as well as a host of local kids and suspected weirdos who spent entirely too much time in the gas station.",
	"With input from this crack team of playtesters, Matuszewski refined his game, shaping and finessing it into a more consistent and perfect form. Unending onion layers of complexity emerged spontaneously from regular gameplay, revealing clever, sophisticated tactics and distinct play styles taking very different strategic approaches. An incredibly ambitious 4-player version of the gameboard was created by Noah and tested. Eventually, there were enough serious players to organize the first of a series of annual Sabotournaments, where players gathered each year to determine a champion.",
]

# Deeper-dive sections. The Cards is active; the others remain placeholders.
const SECTIONS := [
	"The Board",
	"The Pieces",
	"The Cards",
	"The Croce",
	"The Players",
	"West Coast Saboteur Club and the Computer Version",
]

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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	_scroll = scroll

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	# Keep enough scrollable height for the final photo pair, even when the
	# prose/index happens to measure slightly shorter on a particular viewport.
	pad.custom_minimum_size = Vector2(0, 1150)
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	# Slim side margins keep the text column readable and give the floating photos
	# some room to sit at the page edges without covering text by default.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	pad.add_child(row)

	var left_margin := Control.new()
	left_margin.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	left_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left_margin)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	var right_margin := Control.new()
	right_margin.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right_margin)

	col.add_child(_eyebrow("THE STORY"))
	col.add_child(_spacer(6))
	col.add_child(_title("Graveyard Shift"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(30))

	for p in PARAGRAPHS:
		col.add_child(_body(p))
		col.add_child(_spacer(20))

	col.add_child(_spacer(40))
	col.add_child(_back_option())

	# Floating draggable photo overlays. The 09-14 layer is added first so it
	# remains behind the original 01-08 layer. Empty overlay space ignores input,
	# allowing ordinary story scrolling; only the photographs intercept clicks.
	var back_overlay := Control.new()
	back_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back_overlay)
	_photo_back_overlay = back_overlay
	_build_background_photos(back_overlay)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_photo_overlay = overlay
	_build_floating_photos(overlay)

	# Follow vertical scroll.
	var vbar := _scroll.get_v_scroll_bar()
	if vbar:
		vbar.value_changed.connect(_on_scroll)

func _on_scroll(value: float) -> void:
	if _photo_back_overlay:
		_photo_back_overlay.position.y = -value
	if _photo_overlay:
		_photo_overlay.position.y = -value

func _body(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	l.add_theme_constant_override("line_spacing", 5)
	return l

# Places the eight story photos as free-floating, draggable children of the
# overlay. They alternate left/right columns descending the page, starting near
# the margins so they don't cover text by default -- but any that overlap can be
# dragged clear (or onto the text, if you like).
func _build_floating_photos(overlay: Control) -> void:
	# Explicit arrangement matching the approved Story-page composition.
	# Order, read left-to-right and top-to-bottom:
	# 01, 08, 03, 04, 05, 06, 12, 10, 02, 07.
	#
	# The right rail is calculated from the actual logical viewport width.
	# This keeps it on-screen when the project stretches a 1280-wide viewport
	# into a wider desktop window.
	var viewport_w := get_viewport_rect().size.x
	var left_x := 68.0
	var right_x := viewport_w - PHOTO_WIDTH - 28.0

	# Tighter row spacing than the previous pass.
	var row_y := [
		48.0,
		258.0,
		468.0,
		678.0,
		888.0,
	]

	var layout := [
		{"number": 1,  "position": Vector2(left_x,  row_y[0])},
		{"number": 8,  "position": Vector2(right_x, row_y[0] - 18.0)},
		{"number": 3,  "position": Vector2(20.0,    row_y[1])},
		{"number": 4,  "position": Vector2(right_x, row_y[1])},
		{"number": 5,  "position": Vector2(54.0,    row_y[2])},
		{"number": 6,  "position": Vector2(right_x - 18.0, row_y[2])},
		{"number": 12, "position": Vector2(28.0,    row_y[3])},
		{"number": 10, "position": Vector2(right_x, row_y[3])},
	]

	for item in layout:
		var n: int = item["number"]
		var photo := _photo("res://assets/menu/story_%02d.jpg" % n, PHOTO_WIDTH, 0.0)
		photo.position = item["position"]
		_make_photo_draggable(photo)
		overlay.add_child(photo)

		var center_x := viewport_w / 2.0
		var bottom_y := 820.0
		var gap := 24.0
		var left_photo := _photo("res://assets/menu/story_02.jpg", PHOTO_WIDTH, 0.0)
		left_photo.position = Vector2(center_x - PHOTO_WIDTH - gap / 2.0, bottom_y)
		_make_photo_draggable(left_photo)
		overlay.add_child(left_photo)

		var right_photo := _photo("res://assets/menu/story_07.jpg", PHOTO_WIDTH, 0.0)
		right_photo.position = Vector2(center_x + gap / 2.0, bottom_y)
		_make_photo_draggable(right_photo)
		overlay.add_child(right_photo)
# Places story_09..14 on a separate layer beneath 01..08. Their coordinates
# deliberately overlap the front set so portions remain tucked behind it until
# the player drags either photograph aside.
func _build_background_photos(_overlay: Control) -> void:
	# The approved composition uses one unified photo layer. Intentionally empty.
	pass

# Makes a floating photo draggable with a small click-vs-nothing threshold, the
# same pattern as the deploy card / tray / Croce portrait. Brings the grabbed
# photo to the front so it lifts above its neighbours while being moved.
func _make_photo_draggable(photo: Control) -> void:
	photo.mouse_filter = Control.MOUSE_FILTER_STOP
	# Per-photo drag state stored on the node via metadata so one handler serves all.
	photo.set_meta("dragging", false)
	photo.set_meta("offset", Vector2.ZERO)
	photo.gui_input.connect(_on_photo_input.bind(photo))

func _on_photo_input(event: InputEvent, photo: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			photo.set_meta("dragging", true)
			photo.set_meta("offset", photo.global_position - event.global_position)
			photo.move_to_front()
		else:
			photo.set_meta("dragging", false)
	elif event is InputEventMouseMotion and photo.get_meta("dragging"):
		photo.global_position = event.global_position + photo.get_meta("offset")

# A photo mounted like a real print: a white matte border framing the image,
# rounded outer corners, and a warm layered drop shadow, gently rotated for a
# scattered, pinned-up feel. The inner image itself keeps square-ish corners
# (only a tiny round) so it reads as a photo inside a mount, not a sticker.
func _photo(path: String, width: float, rot_deg: float) -> Control:
	var tex: Texture2D = load(path)
	var img_size := tex.get_size()
	var mat_border := 9.0                       # white photo-matte thickness
	var img_w := width - mat_border * 2.0
	var img_h := img_w * (img_size.y / img_size.x)

	# Outer mount: white card, rounded, warm shadow.
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(PHOTO_RADIUS)
	sb.shadow_color = Color(0.15, 0.11, 0.07, 0.28)   # warm, not neutral grey
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = mat_border
	sb.content_margin_right = mat_border
	sb.content_margin_top = mat_border
	sb.content_margin_bottom = mat_border + 4.0        # slightly deeper bottom lip, like a print
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(width, img_h + mat_border * 2.0 + 4.0)
	frame.size = Vector2(width, img_h + mat_border * 2.0 + 4.0)

	# Inner image, only lightly rounded so it sits as a photo within the matte.
	var inner_radius := 3.0
	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.custom_minimum_size = Vector2(img_w, img_h)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.material = _rounded_material(Vector2(img_w, img_h), inner_radius)
	frame.add_child(tex_rect)

	# Rotate around the frame's own center rather than its top-left corner.
	var full_h := img_h + mat_border * 2.0 + 4.0
	frame.pivot_offset = Vector2(width, full_h) / 2.0
	frame.rotation_degrees = rot_deg
	return frame

# Builds a small canvas-item shader that discards the texture's corners
# outside a rounded rect, so the photo's corners visually match the frame's.
func _rounded_material(size: Vector2, radius: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(150.0, 100.0);
uniform float radius = 14.0;

void fragment() {
	vec2 pos = UV * rect_size;
	vec2 center = rect_size * 0.5;
	vec2 q = abs(pos - center) - (center - vec2(radius));
	float dist = length(max(q, 0.0)) - radius;
	vec4 tex_color = texture(TEXTURE, UV);
	tex_color.a *= 1.0 - smoothstep(-1.0, 1.0, dist);
	COLOR = tex_color;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("radius", radius)
	return mat

# Builds an Explore Further row. "The Cards" is active and opens the sibling
# cardspage.gd script; the remaining chapter rows retain their placeholder state.
func _section_row(title: String) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = HAIR
	sb.border_width_top = 1
	if title == SECTIONS[SECTIONS.size() - 1]:
		sb.border_width_bottom = 1
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", INK if title == "The Cards" else MUTED)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lbl)

	var tag := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("#F1EFE8")
	tsb.set_corner_radius_all(3)
	tsb.content_margin_left = 6
	tsb.content_margin_right = 6
	tsb.content_margin_top = 1
	tsb.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", tsb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tag_lbl := Label.new()
	tag_lbl.text = "OPEN" if title == "The Cards" else "SOON"
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", ALIZARIN if title == "The Cards" else MUTED)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(tag_lbl)
	h.add_child(tag)

	if title == "The Cards":
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(func():
			lbl.add_theme_color_override("font_color", ALIZARIN)
			_tween_row_x(row, 6.0)
		)
		row.mouse_exited.connect(func():
			lbl.add_theme_color_override("font_color", INK)
			_tween_row_x(row, 0.0)
		)
		row.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_cards_page()
		)
	else:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return row

# Loads cardspage.gd from the same directory as this script, so the link remains
# valid regardless of where the menu scripts are stored in the project.
func _open_cards_page() -> void:
	var own_script := get_script() as Script
	if own_script == null:
		push_error("Story: could not resolve its own script path.")
		return

	var cards_path := own_script.resource_path.get_base_dir().path_join("cardspage.gd")
	var cards_script := load(cards_path) as Script
	if cards_script == null:
		push_error("Story: could not load %s" % cards_path)
		return

	var cards_page := cards_script.new() as Control
	if cards_page == null:
		push_error("Story: cardspage.gd did not instantiate as a Control.")
		return

	var host := get_parent()
	if host == null:
		push_error("Story: no parent available to host the Cards page.")
		cards_page.queue_free()
		return

	hide()
	host.add_child(cards_page)
	cards_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_page.back.connect(func():
		cards_page.queue_free()
		show()
	)

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
