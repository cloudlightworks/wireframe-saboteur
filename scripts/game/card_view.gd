extends Control
class_name CardView

signal card_clicked(card_view: CardView)

const CARD_TEX := Vector2(567, 798)

# Small grid thumbnail size (fixed hitbox — never resizes, so hover never flickers).
const THUMB_W := 88.0
const THUMB_H := THUMB_W * (798.0 / 567.0)   # keep card aspect ratio (~124)

# Pop-up (readable) version: rendered on a separate layer, ignores the mouse.
const POP_SCALE := 2.0
const POP_LEFT_OFFSET := 26.0                 # slight leftward nudge so it clears the margin edge
const ANIM_TIME := 0.10

var card: Card
var is_selected: bool = false
var _discard_pulse: bool = false
var hover_locked: bool = false

var thumb_sprite: TextureRect
var _popup_parent: Control          # the high layer in HandPanel where pop-ups render
var _popup: Control                 # the enlarged floating copy (created lazily)
var _popup_frame: Panel
var _pulse_tween: Tween

# tex_path resolution is unchanged from before
func setup(c: Card, popup_parent: Control) -> void:
	card = c
	_popup_parent = popup_parent
	custom_minimum_size = Vector2(THUMB_W, THUMB_H)
	size = Vector2(THUMB_W, THUMB_H)
	mouse_filter = Control.MOUSE_FILTER_STOP

	thumb_sprite = TextureRect.new()
	thumb_sprite.texture = TextureManager.get_texture("cards", _sprite_path())
	thumb_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	thumb_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thumb_sprite)
	var border := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.draw_center = false
	bsb.set_border_width_all(2)
	bsb.border_color = Color.BLACK
	bsb.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", bsb)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)
		accept_event()

func _on_mouse_entered() -> void:
	if hover_locked:
		return
	_show_popup()

func _on_mouse_exited() -> void:
	# Keep the pop-up visible if this card is selected; otherwise hide it.
	if not is_selected:
		_hide_popup()

# Called by HandPanel whenever the current selection changes. When locked, this
# card can't usefully be added to the selection right now, so it's taken out of
# the input chain entirely (mouse_filter IGNORE) — clicks fall through it rather
# than being caught and no-op'd, and its pop-up is suppressed too. Selected cards
# are never locked (their pop-up stays pinned and stays clickable to deselect).
func set_hover_locked(locked: bool) -> void:
	hover_locked = locked
	mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	_apply_popup_mouse_filter()
	if locked and not is_selected:
		_hide_popup()

# The pop-up is only ever a click target (STOP) while this card is genuinely
# selected/pinned — that's the one state where it's guaranteed to stay put
# instead of appearing/disappearing under the cursor as the mouse travels
# across the hand. Every other state (plain hover, or locked-out) leaves it
# as IGNORE so it can never intercept motion/hover meant for a neighbor.
func _apply_popup_mouse_filter() -> void:
	if not _popup:
		return
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP if (is_selected and not hover_locked) else Control.MOUSE_FILTER_IGNORE

# ---- Pop-up management (separate layer, MOUSE_FILTER_IGNORE => no flicker) ----
func _show_popup() -> void:
	if _popup == null:
		_build_popup()
	_popup.visible = true
	_position_popup()
	_popup_parent.move_child(_popup, _popup_parent.get_child_count() - 1)  # bring to front

func _hide_popup() -> void:
	if _popup:
		_popup.visible = false

func _build_popup() -> void:
	var pw := THUMB_W * POP_SCALE
	var ph := THUMB_H * POP_SCALE
	_popup = Control.new()
	_popup.custom_minimum_size = Vector2(pw, ph)
	_popup.size = Vector2(pw, ph)
	# The zoomed pop-up starts as a hover-only preview (IGNORE, matching the
	# original design) so it never steals hover/motion events from neighboring
	# thumbnails while just browsing. It only becomes a real click target once
	# this card is actually selected/pinned — see _apply_popup_mouse_filter().
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.gui_input.connect(_on_gui_input)

	var spr := TextureRect.new()
	spr.texture = thumb_sprite.texture
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	spr.set_anchors_preset(Control.PRESET_FULL_RECT)
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(spr)
	var pborder := Panel.new()
	var pbsb := StyleBoxFlat.new()
	pbsb.draw_center = false
	pbsb.set_border_width_all(2)
	pbsb.border_color = Color.BLACK
	pbsb.set_corner_radius_all(6)
	pborder.add_theme_stylebox_override("panel", pbsb)
	pborder.set_anchors_preset(Control.PRESET_FULL_RECT)
	pborder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(pborder)

	# Yellow selection / red discard frame (hidden unless selected or discard-pulsing)
	_popup_frame = Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.draw_center = false
	fsb.border_color = Color(1.0, 0.84, 0.1)   # gold by default
	fsb.set_border_width_all(4)
	fsb.set_corner_radius_all(12)
	_popup_frame.add_theme_stylebox_override("panel", fsb)
	_popup_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_frame.visible = false
	_popup.add_child(_popup_frame)

	_popup_parent.add_child(_popup)

func _position_popup() -> void:
	# Center the pop-up on the thumbnail, nudged left, clamped to the screen.
	var pw := THUMB_W * POP_SCALE
	var ph := THUMB_H * POP_SCALE
	var center := global_position + Vector2(THUMB_W, THUMB_H) * 0.5
	var pos := center - Vector2(pw, ph) * 0.5 - Vector2(POP_LEFT_OFFSET, 0)
	# clamp vertically so it doesn't run off top/bottom
	var vp := get_viewport_rect().size
	pos.y = clampf(pos.y, 8.0, vp.y - ph - 8.0)
	pos.x = maxf(pos.x, 8.0)
	_popup.position = pos

func set_selected(value: bool) -> void:
	is_selected = value
	if value:
		_show_popup()
		if _popup_frame:
			_popup_frame.visible = true
			_set_frame_color(Color(1.0, 0.84, 0.1))   # gold
	else:
		if _popup_frame:
			_popup_frame.visible = false
		if not get_global_rect().has_point(get_global_mouse_position()):
			_hide_popup()
	_apply_popup_mouse_filter()

# Discard mode: pulse the thumbnail red to signal "over limit, must discard".
func set_discard_pulse(value: bool) -> void:
	_discard_pulse = value
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if value:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(thumb_sprite, "modulate", Color(1.0, 0.5, 0.5), 0.5)
		_pulse_tween.tween_property(thumb_sprite, "modulate", Color.WHITE, 0.5)
	else:
		thumb_sprite.modulate = Color.WHITE

# When selected FOR DISCARD, show a red frame instead of gold.
func set_discard_selected(value: bool) -> void:
	is_selected = value
	if value:
		_show_popup()
		if _popup_frame:
			_popup_frame.visible = true
			_set_frame_color(Color(0.9, 0.2, 0.2))     # red
	else:
		if _popup_frame:
			_popup_frame.visible = false
		if not get_global_rect().has_point(get_global_mouse_position()):
			_hide_popup()
	_apply_popup_mouse_filter()

func _set_frame_color(c: Color) -> void:
	var sb := _popup_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = c

func free_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null

func _exit_tree() -> void:
	free_popup()

static func _letter(t: Piece.Type) -> String:
	match t:
		Piece.Type.A: return "A"
		Piece.Type.B: return "B"
		Piece.Type.C: return "C"
		_: return "?"

func _sprite_path() -> String:
	return sprite_name_for(card)

# Returns a filename only, not a full path. TextureManager resolves it against
# the active theme and falls back to the default card art for anything a theme
# does not supply.
static func sprite_name_for(card: Card) -> String:
	match card.category:
		Card.Category.CHART:
			return "chart_%02d.png" % card.chart_values.get(Piece.Type.A, 1)
		Card.Category.TYPE:
			var letters := ""
			for t in card.piece_types:
				letters += _letter(t)
			return "type_%s.png" % letters
		Card.Category.MINOR_POWER:
			match card.minor_effect:
				Card.MinorEffect.JUST_IN_CASE:
					return "minor_justincase.png"
				Card.MinorEffect.GET_MOVE_ON:
					return "minor_getmoveon_%s.png" % _letter(card.effect_piece_type)
				Card.MinorEffect.CLOSE_CALL:
					return "minor_closecall_%s.png" % _letter(card.effect_piece_type)
				Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
					return "minor_ityd_%s.png" % _letter(card.effect_piece_type)
		Card.Category.MAJOR_POWER:
			match card.major_effect:
				Card.MajorEffect.BLITZKRIEG:
					return "major_blitzkrieg.png"
				Card.MajorEffect.DOUBLE_AGENT:
					return "major_doubleagent.png"
				Card.MajorEffect.HE_SEEMED_SUSPICIOUS:
					return "major_heseemedsusp.png"
				Card.MajorEffect.IM_ON_TO_YOU:
					return "major_imontoyou.png"
				Card.MajorEffect.INEFFECTIVE_LEADERSHIP:
					return "major_ineffective.png"
				Card.MajorEffect.JUST_THIS_ONCE:
					return "major_justthisonce.png"
				Card.MajorEffect.ONE_MAN_ARMY:
					return "major_onemanArmy.png"
	return ""
