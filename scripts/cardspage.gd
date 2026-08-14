extends Control
class_name CardsPage

# The Cards page, using the shared menu visual language from story.gd:
# corner ticks, restrained typography, red-over-blue signature rule, a
# bracketed [ back ] link, and a draggable mounted photograph.

signal back

var _photo_overlay: Control
var _scroll: ScrollContainer

const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")
const BODY := Color("#141414")

const TICK_SIZE := 26.0
const TICK_INSET := 14.0
const TICK_THICK := 2.0

const PHOTO_WIDTH := 420.0
const PHOTO_RADIUS := 14.0
const PHOTO_X := 650.0
const PHOTO_Y := 255.0

const INTRO_TEXT := "Cards were originally scrawled in Noah's spidery hand! Here's how he came up with them:"

func _ready() -> void:
	# This page is instantiated dynamically. Give the root its final full-screen
	# geometry before building children that anchor themselves to it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_build")

func _build() -> void:
	if get_child_count() > 0:
		return

	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_corner_ticks()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	pad.add_child(row)

	var left_margin := Control.new()
	left_margin.custom_minimum_size = Vector2(40, 0)
	left_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left_margin)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 720)
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	var right_margin := Control.new()
	right_margin.custom_minimum_size = Vector2(40, 0)
	right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right_margin)

	col.add_child(_eyebrow("THE CARDS"))
	col.add_child(_spacer(6))
	col.add_child(_title("The Cards"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(ALIZARIN))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(ROYAL_BLUE))
	col.add_child(_spacer(30))
	col.add_child(_body(INTRO_TEXT))
	col.add_child(_spacer(470))
	col.add_child(_back_option())

	# Added last so the mounted photograph appears above the page content. The
	# overlay ignores mouse input except where the photo itself catches it.
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_photo_overlay = overlay

	var photo := _photo("res://assets/menu/cards_01.jpg", PHOTO_WIDTH)
	photo.position = Vector2(PHOTO_X, PHOTO_Y)
	_make_photo_draggable(photo)
	overlay.add_child(photo)

	var vbar := _scroll.get_v_scroll_bar()
	if vbar:
		vbar.value_changed.connect(_on_scroll)

func _on_scroll(value: float) -> void:
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

func _make_photo_draggable(photo: Control) -> void:
	photo.mouse_filter = Control.MOUSE_FILTER_STOP
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

func _photo(path: String, width: float) -> Control:
	var tex: Texture2D = load(path)
	var img_size := tex.get_size()
	var mat_border := 9.0
	var img_w := width - mat_border * 2.0
	var img_h := img_w * (img_size.y / img_size.x)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(PHOTO_RADIUS)
	sb.shadow_color = Color(0.15, 0.11, 0.07, 0.28)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = mat_border
	sb.content_margin_right = mat_border
	sb.content_margin_top = mat_border
	sb.content_margin_bottom = mat_border + 4.0
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(width, img_h + mat_border * 2.0 + 4.0)
	frame.size = Vector2(width, img_h + mat_border * 2.0 + 4.0)

	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.custom_minimum_size = Vector2(img_w, img_h)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.material = _rounded_material(Vector2(img_w, img_h), 3.0)
	frame.add_child(tex_rect)

	# Straight orientation keeps the thin matte edge clean and avoids rotated
	# raster resampling along the frame.
	frame.rotation_degrees = 0.0
	return frame

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
