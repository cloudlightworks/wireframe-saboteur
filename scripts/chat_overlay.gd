extends CanvasLayer
class_name ChatOverlay
# Persistent chat panel for OnWS. Presentation only — it sends through
# ChatManager and renders what comes back. It knows nothing about GameState.
#
# Interaction:
#   - T (or middle-click) opens. Stays open until closed with [ x ].
#   - Drag anywhere on the panel body to move it.
#   - Hover a corner: a right-angle tick appears; drag to resize.
#   - While the input box has focus, board_controller gates board input.
#   - Esc, or a click outside the panel, releases focus without closing.

signal effect_triggered(effect_id: String, side: int)
signal placement_requested(sticker_id: String)

const PANEL_W := 340.0
const PANEL_H := 260.0
const MARGIN := 16.0
const MAX_LINES := 120
const CORNER := 20.0        # hit zone for corner resize
const MIN_SIZE := Vector2(260, 170)
const MAX_SIZE := Vector2(760, 680)
const INK := Color("#141414")

var panel: PanelContainer
var log_scroll: ScrollContainer
var log_box: VBoxContainer
var input_box: LineEdit
var badge: Panel
var badge_label: Label
var typing_label: Label
var hint: Control            # draws the corner right-angle
var sticker_btn: Button
var sticker_popup: PopupPanel
var sticker_view: Control    # transient overlay for an incoming taunt
var _aiming_sticker: String = ""   # non-empty = waiting for a board click

var _open: bool = false
var _unread: int = 0
var _typing_sent: bool = false

var _hover_corner: int = -1  # 0=TL 1=TR 2=BL 3=BR, -1 none
var _drag_mode: int = 0      # 0 none, 1 move, 2 resize
var _drag_corner: int = -1
var _anchor: Vector2 = Vector2.ZERO   # fixed opposite corner while resizing
var _move_grab: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 130
	_build()
	set_open(false)
	ChatManager.message_received.connect(_on_message_received)
	ChatManager.effect_received.connect(_on_effect_received)
	ChatManager.chat_rejected.connect(_on_chat_rejected)
	ChatManager.typing_changed.connect(_on_typing_changed)
	ChatManager.sticker_received.connect(_on_sticker_received)

# ------------------------------------------------------------------ interface

func is_capturing() -> bool:
	return _open and input_box != null and input_box.has_focus()

func contains_point(p: Vector2) -> bool:
	if not _open or panel == null:
		return false
	return panel.get_global_rect().has_point(p)

func unfocus() -> void:
	if input_box:
		input_box.release_focus()
	_send_typing(false)

func toggle_open() -> void:
	if _open and not is_capturing():
		focus_input()
		return
	set_open(not _open)

func set_open(value: bool) -> void:
	_open = value
	panel.visible = value
	hint.visible = value
	if value:
		_unread = 0
		_refresh_badge()
		focus_input()
	else:
		unfocus()
		_hover_corner = -1
		hint.queue_redraw()
		_refresh_badge()

func focus_input() -> void:
	if input_box:
		input_box.grab_focus()
		input_box.caret_column = input_box.text.length()

# ------------------------------------------------------- move / resize handling

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _drag_mode == 0:
		var c := _corner_at(event.position)
		if c != _hover_corner:
			_hover_corner = c
			panel.mouse_default_cursor_shape = _cursor_for(c)
			hint.queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			focus_input()
			var c := _corner_at(event.position)
			if c != -1:
				_drag_mode = 2
				_drag_corner = c
				_anchor = _opposite_corner_global(c)
			else:
				_drag_mode = 1
				_move_grab = event.position
		else:
			_drag_mode = 0
			_drag_corner = -1
		return

	if event is InputEventMouseMotion and _drag_mode != 0:
		if _drag_mode == 1:
			panel.position += event.relative
			_clamp_to_screen()
		else:
			_resize_from(get_viewport().get_mouse_position())
		hint.queue_redraw()

func _corner_at(local: Vector2) -> int:
	var s := panel.size
	var left := local.x <= CORNER
	var right := local.x >= s.x - CORNER
	var top := local.y <= CORNER
	var bottom := local.y >= s.y - CORNER
	if left and top:
		return 0
	if right and top:
		return 1
	if left and bottom:
		return 2
	if right and bottom:
		return 3
	return -1

func _cursor_for(c: int) -> int:
	match c:
		0, 3:
			return Control.CURSOR_FDIAGSIZE
		1, 2:
			return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_MOVE

func _corner_global(c: int) -> Vector2:
	var r := panel.get_global_rect()
	match c:
		0:
			return r.position
		1:
			return Vector2(r.end.x, r.position.y)
		2:
			return Vector2(r.position.x, r.end.y)
	return r.end

func _opposite_corner_global(c: int) -> Vector2:
	var opposite: int = [3, 2, 1, 0][c]
	return _corner_global(opposite)

func _resize_from(mouse: Vector2) -> void:
	var raw_min := Vector2(min(_anchor.x, mouse.x), min(_anchor.y, mouse.y))
	var raw_max := Vector2(max(_anchor.x, mouse.x), max(_anchor.y, mouse.y))
	var s := (raw_max - raw_min).clamp(MIN_SIZE, MAX_SIZE)
	# Keep the anchor corner pinned while the dragged corner follows the mouse.
	var pos := Vector2(
		_anchor.x if mouse.x >= _anchor.x else _anchor.x - s.x,
		_anchor.y if mouse.y >= _anchor.y else _anchor.y - s.y
	)
	panel.size = s
	panel.custom_minimum_size = s
	panel.position = pos

func _clamp_to_screen() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.position.x = clamp(panel.position.x, -panel.size.x + 60.0, vp.x - 60.0)
	panel.position.y = clamp(panel.position.y, 0.0, vp.y - 40.0)

func _draw_hint() -> void:
	if not _open or _hover_corner == -1 or panel == null:
		return
	var r := panel.get_global_rect()
	var c := _corner_global(_hover_corner)
	var arm := 15.0
	var inset := 5.0
	var dx := 1.0 if c.x <= r.position.x + 1.0 else -1.0
	var dy := 1.0 if c.y <= r.position.y + 1.0 else -1.0
	var o := c + Vector2(inset * dx, inset * dy)
	hint.draw_line(o, o + Vector2(arm * dx, 0), INK, 2.0)
	hint.draw_line(o, o + Vector2(0, arm * dy), INK, 2.0)

# --------------------------------------------------------------------- events

func _on_submit(text: String) -> void:
	var code := EasterEggs.extract_code(text)
	if code != "":
		input_box.text = ""
		_send_typing(false)
		var entry: Dictionary = EasterEggs.lookup(code)
		if entry.is_empty():
			_add_system_line("nothing there.")
		elif entry["scope"] == "shared":
			ChatManager.send_shared_effect(entry["effect"])
		else:
			var me: int = NetworkManager.my_side() if NetworkManager.is_networked() else 0
			_on_effect_received(entry["effect"], me)
		return
	ChatManager.send_message(text)
	input_box.text = ""
	_send_typing(false)

func _on_text_changed(new_text: String) -> void:
	_send_typing(new_text.strip_edges() != "")

func _send_typing(active: bool) -> void:
	if active == _typing_sent:
		return
	_typing_sent = active
	ChatManager.set_typing(active)

func _on_message_received(side: int, text: String, _seq: int) -> void:
	var is_me: bool = NetworkManager.is_networked() and side == NetworkManager.my_side()
	_add_line(_side_name(side), _side_color(side), text)
	if not is_me and not _open:
		_unread += 1
		_refresh_badge()

func _on_effect_received(effect_id: String, side: int) -> void:
	effect_triggered.emit(effect_id, side)

func _on_chat_rejected(reason: String) -> void:
	_add_system_line(reason)

func _on_typing_changed(is_typing: bool) -> void:
	if typing_label:
		typing_label.visible = is_typing

# ------------------------------------------------------------------- log lines

func _add_line(who: String, who_color: Color, text: String) -> void:
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override("normal_font_size", 14)
	row.add_theme_font_size_override("bold_font_size", 14)
	row.add_theme_color_override("default_color", INK)
	row.text = "[b][color=#%s]%s[/color][/b]  %s" % [
		who_color.to_html(false), who, text.xml_escape()
	]
	log_box.add_child(row)
	_trim_and_scroll()

func _add_system_line(text: String) -> void:
	var row := Label.new()
	row.text = text
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override("font_size", 13)
	row.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	log_box.add_child(row)
	_trim_and_scroll()

func _trim_and_scroll() -> void:
	while log_box.get_child_count() > MAX_LINES:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func _side_name(side: int) -> String:
	if not NetworkManager.is_networked():
		return "you"
	return "you" if side == NetworkManager.my_side() else "them"

func _side_color(side: int) -> Color:
	var key: String = RuleSettings.side_one_color if side == Piece.Owner.BLUE \
		else RuleSettings.side_two_color
	return RuleSettings.COLOR_HEX.get(key, INK)

# ----------------------------------------------------------------- construction

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(vp.x - PANEL_W - MARGIN, vp.y - PANEL_H - MARGIN)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	panel.mouse_exited.connect(_on_panel_exited)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffffff")
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	# --- header
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)

	var title := Label.new()
	title.text = "TRUST NOTHING THEY SAY"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	typing_label = Label.new()
	typing_label.text = "typing…"
	typing_label.visible = false
	typing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typing_label.add_theme_font_size_override("font_size", 12)
	typing_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	header.add_child(typing_label)

	var close_btn := Button.new()
	close_btn.text = "[ x ]"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", INK)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# --- log
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(log_scroll)

	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_box)

	# --- input
	input_box = LineEdit.new()
	input_box.placeholder_text = "say something…"
	input_box.max_length = ChatManager.MAX_LEN
	input_box.mouse_filter = Control.MOUSE_FILTER_STOP
	input_box.add_theme_font_size_override("font_size", 14)
	input_box.add_theme_color_override("font_color", INK)
	input_box.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.55))
	input_box.add_theme_color_override("caret_color", INK)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("#f6f4ef")
	isb.border_color = INK
	isb.set_border_width_all(1)
	isb.set_corner_radius_all(6)
	isb.set_content_margin_all(6)
	input_box.add_theme_stylebox_override("normal", isb)
	input_box.add_theme_stylebox_override("focus", isb)
	input_box.text_submitted.connect(_on_submit)
	input_box.text_changed.connect(_on_text_changed)
	input_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var input_row := HBoxContainer.new()
	input_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_row.add_theme_constant_override("separation", 6)
	input_row.add_child(input_box)

	sticker_btn = Button.new()
	sticker_btn.text = "[ ☺ ]"
	sticker_btn.flat = true
	sticker_btn.focus_mode = Control.FOCUS_NONE
	sticker_btn.tooltip_text = "Taunts"
	sticker_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sticker_btn.add_theme_font_size_override("font_size", 15)
	sticker_btn.add_theme_color_override("font_color", INK)
	sticker_btn.pressed.connect(_on_sticker_button)
	input_row.add_child(sticker_btn)

	col.add_child(input_row)

	sticker_popup = PopupPanel.new()
	add_child(sticker_popup)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in StickerLibrary.ordered_ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		var tex := StickerLibrary.texture_for(id)
		if tex:
			b.icon = tex
		else:
			b.text = StickerLibrary.label_for(id)
			b.add_theme_font_size_override("font_size", 12)
		b.gui_input.connect(_on_picker_input.bind(id))
		grid.add_child(b)
	sticker_popup.add_child(grid)

	# --- corner hint (own full-screen canvas, drawn above the panel)
	hint = Control.new()
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.draw.connect(_draw_hint)
	add_child(hint)

	# --- unread badge (shown only while closed)
	badge = Panel.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.custom_minimum_size = Vector2(26, 26)
	badge.size = Vector2(26, 26)
	badge.offset_left = -(26 + MARGIN)
	badge.offset_top = -(26 + MARGIN)
	badge.offset_right = -MARGIN
	badge.offset_bottom = -MARGIN
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#EA2B3D")
	bsb.set_corner_radius_all(13)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.gui_input.connect(_on_badge_input)
	badge.visible = false
	add_child(badge)

	badge_label = Label.new()
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)

func _on_sticker_button() -> void:
	var r := sticker_btn.get_global_rect()
	sticker_popup.popup(Rect2i(
		Vector2i(int(r.position.x) - 200, int(r.position.y) - 200),
		Vector2i(280, 190)
	))

func _on_picker_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			# Double-click: drop it straight into the chat window.
			sticker_popup.hide()
			ChatManager.send_sticker(id)
			focus_input()
		else:
			# Single click: arm placement mode, wait for a board click.
			sticker_popup.hide()
			_begin_aim(id)

func _begin_aim(id: String) -> void:
	_aiming_sticker = id
	unfocus()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func _cancel_aim() -> void:
	_aiming_sticker = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func is_aiming() -> bool:
	return _aiming_sticker != ""

# Called by board_controller when a board click lands during aim mode.
func consume_aim_click() -> String:
	var id := _aiming_sticker
	_cancel_aim()
	return id

func _on_sticker_received(side: int, sticker_id: String) -> void:
	if not _open:
		var is_me: bool = NetworkManager.is_networked() and side == NetworkManager.my_side()
		if not is_me:
			_unread += 1
			_refresh_badge()
		return
	_show_sticker(sticker_id)

func _show_sticker(sticker_id: String) -> void:
	if sticker_view and is_instance_valid(sticker_view):
		sticker_view.queue_free()

	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)
	sticker_view = holder

	var tex := StickerLibrary.texture_for(sticker_id)
	var art: Control
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(170, 170)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art = tr
	else:
		var lbl := Label.new()
		lbl.text = StickerLibrary.label_for(sticker_id)
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", INK)
		lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art = lbl
	holder.add_child(art)

	holder.modulate.a = 0.0
	holder.scale = Vector2(0.8, 0.8)
	holder.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(1.6)
	tw.tween_property(holder, "modulate:a", 0.0, 0.5)
	tw.tween_callback(holder.queue_free)

func _on_close_pressed() -> void:
	set_open(false)

func _on_badge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		set_open(true)
		badge.accept_event()

func _on_panel_exited() -> void:
	if _drag_mode == 0:
		_hover_corner = -1
		hint.queue_redraw()

func _refresh_badge() -> void:
	if badge == null:
		return
	badge.visible = (not _open) and _unread > 0
	badge_label.text = str(_unread) if _unread < 10 else "9+"
	if badge.visible:
		badge.scale = Vector2(0.6, 0.6)
		badge.pivot_offset = badge.size * 0.5
		var tw := create_tween()
		tw.tween_property(badge, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
