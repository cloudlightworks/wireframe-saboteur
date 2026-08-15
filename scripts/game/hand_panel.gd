extends CanvasLayer
class_name HandPanel
signal deployment_applied

# When >= 0, always show this side's hand regardless of whose turn it is.
# Set by board_controller in CPU mode so the CPU's cards stay hidden.
var forced_side: int = -1

const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const HAND_LIMIT := 9
const REVEAL_W := 300.0
const REVEAL_H := REVEAL_W * (798.0 / 567.0)

# ---- Two-column grid geometry (right margin) ----
const THUMB_W := 72.0
const THUMB_H := THUMB_W * (798.0 / 567.0)   # ~101
const COL_GAP := 10.0
const ROW_GAP := 6.0
const GRID_TOP := 52.0                        # below the count indicator
const GRID_RIGHT_MARGIN := 40.0
const DEPLOY_DRAG_THRESHOLD := 6.0            # px of movement before a press counts as a drag, not a click

const BACK_W := 44.0
const BACK_H := BACK_W * (798.0 / 567.0)
const BACK_OVERLAP := 16.0
const BACK_X := 60.0
const BACK_Y := 600.0

var game_state: GameState
var card_views: Array[CardView] = []
var selected_cards: Array[Card] = []          # deployment selection
var discard_selection: Array[Card] = []       # discard-mode selection
var discard_mode: bool = false

var status_label: Label
var status_box: PanelContainer
var _status_timer: SceneTreeTimer
var _status_active: bool = false
var _status_persistent: bool = false
var announce_box: PanelContainer
var announce_label: Label
var _announce_timer: SceneTreeTimer = null
var deploy_card: Button
var deploy_frame: Control          # outer wrapper: rainbow rings + shadow, mirrors deploy_card.visible
var deploy_rings: Control          # just the colored ring layers, so the pulse tween never tints the text
var _deploy_pulse_tween: Tween
var _count_pulse_tween: Tween
var _deploy_dragging: bool = false
var _deploy_drag_offset: Vector2 = Vector2.ZERO
var _deploy_press_pos: Vector2 = Vector2.ZERO
var _deploy_moved: bool = false
var _deploy_home_pos: Vector2 = Vector2.ZERO
var discard_button: Button
var count_label: Label
var popup_layer: Control                       # high layer for card pop-ups
var controller  # board_controller reference, set after creation
var _mirror_last_sent: Vector2 = Vector2(-99999, -99999)
var mirror_back: TextureRect
var _mirror_size: Vector2 = Vector2.ZERO

func setup(gs: GameState) -> void:
	game_state = gs
	_build_controls()

func is_discard_mode() -> bool:
	return discard_mode

func announce(text: String) -> void:
	if announce_box == null or text == "":
		return
	announce_label.text = text
	announce_box.modulate.a = 1.0
	announce_box.visible = true
	await get_tree().process_frame
	announce_box.position = Vector2(SCREEN_W * 0.5 - announce_box.size.x * 0.5, 96)
	var t := get_tree().create_timer(4.5)
	_announce_timer = t
	await t.timeout
	if _announce_timer == t:
		var tw := create_tween()
		tw.tween_property(announce_box, "modulate:a", 0.0, 1.0)
		await tw.finished
		if _announce_timer == t:
			announce_box.visible = false
			announce_box.modulate.a = 1.0
			_announce_timer = null

func show_status(text: String) -> void:
	_show_status(text)

func _send_deploy_mirror() -> void:
	if not NetworkManager.is_networked():
		return
	var vis := deploy_frame != null and deploy_frame.visible
	var pos := deploy_frame.global_position if vis else Vector2.ZERO
	if vis and pos.distance_to(_mirror_last_sent) < 2.0:
		return
	_mirror_last_sent = pos if vis else Vector2(-99999, -99999)
	NetworkManager.broadcast_deploy_mirror.rpc(vis, pos)
	
func _set_count_pulse(active: bool) -> void:
	if _count_pulse_tween:
		_count_pulse_tween.kill()
		_count_pulse_tween = null
	if count_label == null:
		return
	if active:
		_count_pulse_tween = create_tween().set_loops()
		_count_pulse_tween.tween_property(count_label, "modulate", Color(1.0, 0.72, 0.2), 0.5).set_trans(Tween.TRANS_SINE)
		_count_pulse_tween.tween_property(count_label, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		count_label.modulate = Color.WHITE
		
func _show_status(text: String) -> void:
	if text == "":
		status_box.visible = false
		_status_active = false
		_status_persistent = false
		_status_timer = null
		return
	status_label.text = text
	status_box.modulate.a = 1.0
	status_box.visible = true
	_status_active = true          # set BEFORE any await — this is the fix
	await get_tree().process_frame
	status_box.position = Vector2(SCREEN_W * 0.5 - status_box.size.x * 0.5, 24)
	if discard_mode:
		# Discard prompts persist with no timer; remember that so refresh()
		# can clear them once discard mode ends.
		_status_persistent = true
		return
	var this_timer := get_tree().create_timer(4.0)
	_status_timer = this_timer
	await this_timer.timeout
	if _status_timer == this_timer:
		var tw := create_tween()
		tw.tween_property(status_box, "modulate:a", 0.0, 0.8)
		await tw.finished
		if _status_timer == this_timer:
			status_box.visible = false
			status_box.modulate.a = 1.0
			_status_active = false
			_status_persistent = false
			_status_timer = null

func _build_controls() -> void:
	# Status toast
	status_box = PanelContainer.new()
	var status_sb := StyleBoxFlat.new()
	status_sb.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	status_sb.set_corner_radius_all(8)
	status_sb.set_content_margin_all(10)
	status_box.add_theme_stylebox_override("panel", status_sb)
	status_box.visible = false
	add_child(status_box)

	# Opponent-action announcements live in their OWN toast. status_box is
	# shared with deploy hints and gets cleared by refresh()/_update_deploy_state(),
	# which was silently killing announcements.
	announce_box = PanelContainer.new()
	var ann_sb := StyleBoxFlat.new()
	ann_sb.bg_color = Color(0.06, 0.06, 0.06, 0.93)
	ann_sb.set_corner_radius_all(10)
	ann_sb.set_content_margin_all(16)
	announce_box.add_theme_stylebox_override("panel", ann_sb)
	announce_box.visible = false
	announce_label = Label.new()
	announce_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announce_label.custom_minimum_size = Vector2(300, 0)
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announce_label.add_theme_font_size_override("font_size", 20)
	announce_box.add_child(announce_label)
	add_child(announce_box)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	status_box.add_child(status_label)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(320, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(320, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)

	# Card-count indicator (top of hand column)
	var count_box := PanelContainer.new()
	var cb_sb := StyleBoxFlat.new()
	cb_sb.bg_color = Color.WHITE
	cb_sb.set_corner_radius_all(8)
	cb_sb.shadow_color = Color(0, 0, 0, 0.3)
	cb_sb.shadow_size = 4
	cb_sb.set_content_margin_all(6)
	count_box.add_theme_stylebox_override("panel", cb_sb)
	var col_x := SCREEN_W - (THUMB_W * 2 + COL_GAP) - GRID_RIGHT_MARGIN
	count_box.position = Vector2(col_x, 20)
	count_box.custom_minimum_size = Vector2(THUMB_W * 2 + COL_GAP, 0)
	add_child(count_box)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 19)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 4)
	count_box.add_child(count_label)

	# Deploy card — superimposed over the hand-column centerline (not board-center,
	# so it never covers Saboteur-target pieces on the board). Same footprint as the
	# zoomed hand-card pop-up, with a nested red/blue/green/yellow ring border inside
	# an overall black border + drop shadow, and a looping color-cycle pulse.
	var pop_w: float = CardView.THUMB_W * CardView.POP_SCALE
	var pop_h: float = CardView.THUMB_H * CardView.POP_SCALE
	# Positioned immediately to the LEFT of the hand grid — not centered on top
	# of it. z_index alone does not give a Control input priority over a sibling
	# geometrically underneath it in this setup; confirmed by trace logs showing
	# every click on this card was actually landing on and deselecting whatever
	# hand card sat underneath. Zero overlap removes the ambiguity entirely
	# instead of fighting Godot's input hit-testing over it.
	var grid_left_x := SCREEN_W - (THUMB_W * 2 + COL_GAP) - GRID_RIGHT_MARGIN
	var deploy_margin := 24.0

	deploy_frame = Control.new()
	deploy_frame.custom_minimum_size = Vector2(pop_w, pop_h)
	deploy_frame.size = Vector2(pop_w, pop_h)
	deploy_frame.position = Vector2(grid_left_x - deploy_margin - pop_w, SCREEN_H * 0.5 - pop_h * 0.5)
	_deploy_home_pos = deploy_frame.position
	_mirror_size = Vector2(pop_w, pop_h)
	deploy_frame.visible = false
	deploy_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# z_index (not tree order) decides draw order within a CanvasLayer, and this
	# needs to sit above everything else in the hand — thumbnails, and even the
	# topmost popup_layer (100) that zoomed/selected cards render on — since the
	# deploy card only appears once a selection is already made and should never
	# be visually buried under it.
	deploy_frame.z_index = 150
	add_child(deploy_frame)

	deploy_rings = Control.new()
	deploy_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	deploy_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deploy_frame.add_child(deploy_rings)

	# Outer -> inner: overall black border (+ shadow), then red, blue, green, yellow rings.
	var ring_specs := [
		{ "inset": 0.0,  "color": Color("#141414"), "width": 3.0, "shadow": true  },
		{ "inset": 4.0,  "color": Color("#E32636"), "width": 4.0, "shadow": false },
		{ "inset": 9.0,  "color": Color("#4169E1"), "width": 4.0, "shadow": false },
		{ "inset": 14.0, "color": Color("#2E8B57"), "width": 4.0, "shadow": false },
		{ "inset": 19.0, "color": Color("#FFD400"), "width": 4.0, "shadow": false },
	]
	for i in range(ring_specs.size()):
		var spec = ring_specs[i]
		var ring := PanelContainer.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.offset_left = spec["inset"]
		ring.offset_top = spec["inset"]
		ring.offset_right = -spec["inset"]
		ring.offset_bottom = -spec["inset"]
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color.WHITE if i == 0 else Color(0, 0, 0, 0)
		rsb.set_border_width_all(spec["width"])
		rsb.border_color = spec["color"]
		rsb.set_corner_radius_all(maxi(4, 14 - i * 2))
		if spec["shadow"]:
			rsb.shadow_color = Color(0, 0, 0, 0.45)
			rsb.shadow_size = 10
			rsb.shadow_offset = Vector2(0, 5)
		ring.add_theme_stylebox_override("panel", rsb)
		deploy_rings.add_child(ring)

	deploy_card = Button.new()
	deploy_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	deploy_card.offset_left = 24
	deploy_card.offset_top = 24
	deploy_card.offset_right = -24
	deploy_card.offset_bottom = -24
	deploy_card.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.01)   # transparent but still a clickable normal state
	sb.set_corner_radius_all(6)
	deploy_card.add_theme_stylebox_override("normal", sb)
	deploy_card.add_theme_stylebox_override("hover", sb)
	deploy_card.add_theme_stylebox_override("pressed", sb)
	deploy_card.add_theme_font_size_override("font_size", 20)
	# Drag-vs-click handling lives in _on_deploy_input: a press+release that stays
	# under DEPLOY_DRAG_THRESHOLD px fires the deploy; anything past that repositions
	# the card so it can be dragged clear of a piece it's covering. We do NOT use the
	# Button's `pressed` signal, since that can't tell a click from a drag.
	deploy_card.gui_input.connect(_on_deploy_input)
	# deploy_card stays the one true visibility toggle everywhere else in this file;
	# the frame just mirrors it so no other call site needs to change. Also
	# re-assert popup locks on every visibility change — this is the safety net
	# for the SABOTEUR/JTO/ITYD paths, which hide deploy_card mid-selection (before
	# targeting completes) rather than clearing selected_cards outright. Without
	# this, any stray hover event right as deploy_card disappears could expose a
	# popup that should still be locked.
	deploy_card.visibility_changed.connect(func():
		deploy_frame.visible = deploy_card.visible
		_send_deploy_mirror()
	)
	deploy_frame.add_child(deploy_card)

	_start_deploy_pulse()

	# Confirm Discard button (styled like the deploy card, red)
	discard_button = Button.new()
	discard_button.custom_minimum_size = Vector2(180, 54)
	discard_button.position = Vector2(SCREEN_W * 0.5 - 90, 720 * 0.5 + 120)
	discard_button.text = "Confirm Discard"
	discard_button.visible = false
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.85, 0.15, 0.15)
	dsb.set_corner_radius_all(10)
	var dsb_dis := StyleBoxFlat.new()
	dsb_dis.bg_color = Color("#cfcac1")
	dsb_dis.set_corner_radius_all(10)
	discard_button.add_theme_stylebox_override("normal", dsb)
	discard_button.add_theme_stylebox_override("hover", dsb)
	discard_button.add_theme_stylebox_override("pressed", dsb)
	discard_button.add_theme_stylebox_override("disabled", dsb_dis)
	discard_button.add_theme_color_override("font_color", Color.WHITE)
	discard_button.add_theme_font_size_override("font_size", 18)
	discard_button.pressed.connect(_confirm_discard)
	add_child(discard_button)

	# High layer for card pop-ups (added last => on top of thumbnails)
	popup_layer = Control.new()
	popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.z_index = 100
	add_child(popup_layer)
		
# Loops the deploy card's ring layer through blue -> red -> yellow -> green,
# the same tween-loop technique the hand uses for the discard-mode red pulse.
# Only the ring layer is tweened, never deploy_card itself, so the DEPLOY /
# DECLARE SABOTEUR label text stays fully legible throughout.
func _start_deploy_pulse() -> void:
	var colors := [Color("#4169E1"), Color("#E32636"), Color("#FFD400"), Color("#2E8B57")]
	_deploy_pulse_tween = create_tween().set_loops()
	for c in colors:
		_deploy_pulse_tween.tween_property(deploy_rings, "modulate", c, 0.45)

func show_deploy_mirror(is_visible: bool, pos: Vector2) -> void:
	if not is_visible:
		if mirror_back and is_instance_valid(mirror_back):
			mirror_back.queue_free()
		mirror_back = null
		return
	if mirror_back == null or not is_instance_valid(mirror_back):
		mirror_back = TextureRect.new()
		mirror_back.texture = card_back_tex(_display_side())
		mirror_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mirror_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mirror_back.size = _mirror_size
		mirror_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mirror_back.z_index = 150
		add_child(mirror_back)
	mirror_back.global_position = pos
	
# Click vs drag on the deploy card. Left-press starts tracking; motion past the
# threshold turns it into a drag that repositions deploy_frame (so it can be
# pulled off a piece it's covering); release fires the deploy only if it never
# passed the threshold. deploy_card is anchored full-rect inside deploy_frame, so
# we move the FRAME and let the button follow.
func _on_deploy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_deploy_dragging = true
			_deploy_moved = false
			_deploy_press_pos = event.global_position
			_deploy_drag_offset = deploy_frame.global_position - event.global_position
		else:
			# release
			var was_drag := _deploy_moved
			_deploy_dragging = false
			_deploy_moved = false
			if not was_drag:
				_try_deploy()
				if _deploy_moved:
					deploy_frame.global_position = event.global_position + _deploy_drag_offset
			_send_deploy_mirror()
	elif event is InputEventMouseMotion and _deploy_dragging:
		if not _deploy_moved and event.global_position.distance_to(_deploy_press_pos) > DEPLOY_DRAG_THRESHOLD:
			_deploy_moved = true
		if _deploy_moved:
			deploy_frame.global_position = event.global_position + _deploy_drag_offset

func refresh() -> void:
	for v in card_views:
		v.free_popup()
		v.queue_free()
	card_views.clear()
	selected_cards.clear()
	discard_selection.clear()

	var hand: Array = game_state.hands[_display_side()]

	# Enter/exit discard mode automatically based on the current player's hand.
	discard_mode = hand.size() > HAND_LIMIT

	# Lay out thumbnails in two columns, right margin.
	var col_x := SCREEN_W - (THUMB_W * 2 + COL_GAP) - GRID_RIGHT_MARGIN
	for i in range(hand.size()):
		var cv := CardView.new()
		add_child(cv)
		cv.setup(hand[i], popup_layer)
		var col := i % 2
		var row := i / 2
		var x := col_x + col * (THUMB_W + COL_GAP)
		var y := GRID_TOP + row * (THUMB_H + ROW_GAP)
		cv.position = Vector2(x, y)
		cv.card_clicked.connect(_on_card_clicked)
		card_views.append(cv)

	_update_popup_locks()
	_update_count_label()

	if discard_mode:
		_enter_discard_visuals()
		deploy_card.visible = false
	else:
		discard_button.visible = false
		# A discard prompt persists with no timer; clear it now that discard
		# mode is over, or it hangs on screen indefinitely.
		if _status_persistent:
			_show_status("")
		# Don't clobber an announcement toast that is still showing.
		elif status_box and not _status_active:
			status_box.visible = false
		_update_deploy_state()
		move_child(popup_layer, get_child_count() - 1)

func _update_count_label() -> void:
	if count_label == null:
		return
	var n: int = game_state.hands[_display_side()].size()
	count_label.text = "Hand: %d / %d" % [n, HAND_LIMIT]
	count_label.add_theme_color_override("font_color",
		Color(0.85, 0.15, 0.15) if n > HAND_LIMIT else Color.WHITE)
	_set_count_pulse(n == HAND_LIMIT)

# ---------------- Discard mode ----------------
func _enter_discard_visuals() -> void:
	var excess: int = game_state.hands[_display_side()].size() - HAND_LIMIT
	for v in card_views:
		v.set_discard_pulse(true)
	_show_status("Hand over limit \u2014 select %d card(s) to discard, then Confirm." % excess)
	discard_button.visible = true
	_update_discard_button()

func _update_discard_button() -> void:
	var excess: int = game_state.hands[_display_side()].size() - HAND_LIMIT
	discard_button.disabled = (discard_selection.size() != excess)

func _confirm_discard() -> void:
	var excess: int = game_state.hands[_display_side()].size() - HAND_LIMIT
	if discard_selection.size() != excess:
		return
	if NetworkManager.is_networked():
		var uids: Array = []
		for c in discard_selection:
			uids.append(c.uid)
		NetworkManager.request_discard.rpc_id(1, uids)
		discard_selection.clear()
		return
	SfxManager.play("discard")
	for c in discard_selection:
		game_state.discard_to_deck(_display_side(), c)
	discard_selection.clear()
	refresh()

# ---------------- Card click ----------------
func _on_card_clicked(cv: CardView) -> void:
	# Discard mode can legitimately trigger on the passive player's turn
	# (defenders draw on some captures), so it must stay clickable.
	if not discard_mode and NetworkManager.is_networked() and game_state.current_player != NetworkManager.my_side():
		return
	if discard_mode:
		if discard_selection.has(cv.card):
			discard_selection.erase(cv.card)
			cv.set_discard_selected(false)
		else:
			discard_selection.append(cv.card)
			cv.set_discard_selected(true)
		_update_discard_button()
		return
	# Normal deployment selection
	if selected_cards.has(cv.card):
		selected_cards.erase(cv.card)
		cv.set_selected(false)
		if controller:
			if cv.card == controller.ityd_card:
				controller._cancel_ityd()
			elif cv.card == controller.jto_card:
				controller._cancel_jto()
			elif cv.card == controller.saboteur_type_card or cv.card == controller.saboteur_chart_card:
				controller._cancel_saboteur_targeting()
	else:
		# Belt-and-suspenders: mouse_filter already keeps ineligible cards from
		# generating this click at all, but guard the logic too in case a click
		# was already in flight the instant eligibility changed.
		if not _card_popup_allowed(cv):
			return
		SfxManager.play("sel_card")
		selected_cards.append(cv.card)
		cv.set_selected(true)
	_update_deploy_state()
	_update_popup_locks()
	if controller:
		controller.set_turn_timer_paused(not selected_cards.is_empty())

# Decide, for every card currently in hand, whether hovering it should still
# pop it up given what's already selected:
#  - Nothing selected -> everything's poppable.
#  - Selection already resolves to a deployable effect (a simple one-card power,
#    or a completed Type+Chart / Type+OneManArmy pair) -> the effect is "achieved",
#    so freeze every other card's pop-up until this is deployed or deselected.
#  - Exactly one Type, Chart, or One Man Army card selected (still waiting on its
#    partner) -> only cards that could complete that pairing stay poppable.
#  - Anything else unresolved -> freeze, to avoid implying a pairing that isn't real.
func _update_popup_locks() -> void:
	for cv in card_views:
		cv.set_hover_locked(not _card_popup_allowed(cv))

func _card_popup_allowed(cv: CardView) -> bool:
	if selected_cards.is_empty():
		return true
	if selected_cards.has(cv.card):
		return true
	var info := game_state.classify_deployment(selected_cards)
	if info["kind"] != GameState.DeployKind.NONE:
		return false
	if selected_cards.size() == 1:
		var c = selected_cards[0]
		if c.category == Card.Category.TYPE:
			return cv.card.category == Card.Category.CHART \
				or (cv.card.category == Card.Category.MAJOR_POWER and cv.card.major_effect == Card.MajorEffect.ONE_MAN_ARMY)
		elif c.category == Card.Category.CHART:
			return cv.card.category == Card.Category.TYPE
		elif c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.ONE_MAN_ARMY:
			return cv.card.category == Card.Category.TYPE
	return false


func _update_deploy_state() -> void:
	var info := game_state.classify_deployment(selected_cards)
	var kind = info["kind"]
	var player_color := Color(0.25, 0.45, 0.9) if game_state.current_player == Piece.Owner.BLUE else Color(0.9, 0.25, 0.25)

	if kind == GameState.DeployKind.NONE:
		deploy_card.visible = false
		_show_status(info["reason"] if not selected_cards.is_empty() else "")
		return

	# Snap back to home each time the card newly appears, so a drag from a prior
	# deployment doesn't leave it stranded somewhere off to the side.
	if not deploy_card.visible:
		deploy_frame.position = _deploy_home_pos
	deploy_card.visible = true
	deploy_card.add_theme_color_override("font_color", player_color)
	deploy_card.add_theme_color_override("font_hover_color", player_color)
	deploy_card.add_theme_color_override("font_pressed_color", player_color)

	match kind:
		GameState.DeployKind.SIMPLE:
			deploy_card.text = "DEPLOY"
			_show_status("")
		GameState.DeployKind.SABOTEUR:
			deploy_card.text = "DECLARE\nSABOTEUR"
			_show_status("")
		GameState.DeployKind.ONE_MAN_ARMY:
			deploy_card.text = "ONE MAN\nARMY"
			_show_status("")
		GameState.DeployKind.JUST_THIS_ONCE:
			deploy_card.text = "JUST THIS\nONCE"
			_show_status("")
		GameState.DeployKind.I_THOUGHT_YOU_WERE_DEAD:
			deploy_card.text = "DEPLOY\nI THOUGHT\nYOU WERE\nDEAD"
			_show_status("")

func _try_deploy() -> void:
	var info := game_state.classify_deployment(selected_cards)
	match info["kind"]:
		GameState.DeployKind.SIMPLE:
			if NetworkManager.is_networked():
				var uids: Array = []
				for c in selected_cards:
					uids.append(c.uid)
				NetworkManager.request_deploy_simple.rpc_id(1, uids)
				selected_cards.clear()
				refresh()
			else:
				var result := game_state.deploy_simple(game_state.current_player, selected_cards)
				if result["message"] != "":
					_show_status(result["message"])
				else:
					_show_status("Deployed." if result["ok"] else "Couldn't deploy.")
				if result["ok"]:
					var is_major := false
					for c in selected_cards:
						if c.category == Card.Category.MAJOR_POWER:
							is_major = true
							break
					SfxManager.play("play_major_card" if is_major else "play_minor_card")
					deployment_applied.emit()
				refresh()
		GameState.DeployKind.SABOTEUR:
			deploy_card.visible = false
			_begin_saboteur_deploy()
		GameState.DeployKind.ONE_MAN_ARMY:
			_begin_one_man_army_deploy()
		GameState.DeployKind.JUST_THIS_ONCE:
			deploy_card.visible = false
			SfxManager.play("play_major_card")
			if controller:
				controller.begin_just_this_once(selected_cards[0])
		GameState.DeployKind.I_THOUGHT_YOU_WERE_DEAD:
			deploy_card.visible = false
			SfxManager.play("play_minor_card")
			if controller:
				controller.begin_ityd(selected_cards[0])
		_:
			pass

# Called by board_controller when a targeting phase (Saboteur, Just This Once,
# ITYD) is cancelled without completing — re-evaluates the current selection so
# the deploy card reappears correctly rather than being stuck hidden with no
# way to retry or deselect.
func restore_deploy_card() -> void:
	_update_deploy_state()

# Positions a type-choice picker (Saboteur B/C, One Man Army B/C, etc.) next to
# wherever the deploy card actually is right now, instead of a stale hardcoded
# board-center coordinate. total_height is the picker's expected content height,
# used to vertically center it against the deploy card.
func _picker_anchor_position(total_height: float) -> Vector2:
	var picker_w := 140.0
	var margin := 18.0
	var x := deploy_frame.position.x - picker_w - margin
	var y := deploy_frame.position.y + (deploy_frame.size.y - total_height) * 0.5
	return Vector2(x, y)

# Styled panel + buttons so the choice is obviously visible/clickable, matching
# the app's rounded/shadowed/black-border look rather than bare default buttons.
func _style_picker_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(140, 44)
	b.add_theme_font_size_override("font_size", 18)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color.WHITE
	bsb.set_corner_radius_all(8)
	bsb.set_border_width_all(2)
	bsb.border_color = Color("#141414")
	bsb.shadow_color = Color(0, 0, 0, 0.35)
	bsb.shadow_size = 4
	var bsb_hover := bsb.duplicate()
	bsb_hover.bg_color = Color("#f2efe9")
	b.add_theme_stylebox_override("normal", bsb)
	b.add_theme_stylebox_override("hover", bsb_hover)
	b.add_theme_stylebox_override("pressed", bsb_hover)
	b.add_theme_color_override("font_color", Color("#141414"))

func _begin_saboteur_deploy() -> void:
	var type_card: Card = null
	var chart_card: Card = null
	for c in selected_cards:
		if c.category == Card.Category.TYPE:
			type_card = c
		elif c.category == Card.Category.CHART:
			chart_card = c
	if type_card == null or chart_card == null:
		return
	if type_card.piece_types.size() > 1:
		_show_type_picker(type_card, chart_card)
	else:
		var chosen: Piece.Type = type_card.piece_types[0]
		_launch_saboteur(type_card, chart_card, chosen)

func _begin_one_man_army_deploy() -> void:
	var type_card: Card = null
	for c in selected_cards:
		if c.category == Card.Category.TYPE:
			type_card = c
	if type_card == null:
		return
	if type_card.piece_types.size() > 1:
		_show_oma_type_picker(type_card)
	else:
		_launch_one_man_army(type_card, type_card.piece_types[0])

func _launch_one_man_army(type_card: Card, chosen: Piece.Type) -> void:
	if NetworkManager.is_networked():
		var oma_card: Card = null
		for c in selected_cards:
			if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.ONE_MAN_ARMY:
				oma_card = c
				break
		if oma_card == null:
			return
		NetworkManager.request_oma.rpc_id(1, type_card.uid, oma_card.uid, int(chosen))
		selected_cards.clear()
		refresh()
		return
	var ok := game_state.apply_one_man_army(game_state.current_player, type_card, chosen)
	if ok:
		SfxManager.play("play_major_card")
		for c in selected_cards:
			if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.ONE_MAN_ARMY:
				game_state.discard_card(game_state.current_player, c)
		_show_status("One Man Army: %s can capture the General this turn." % _type_letter(chosen))
		if controller:
			controller._deployed_this_turn = true
			controller._update_turn_label()
		deployment_applied.emit()
		refresh()
	else:
		_show_status("Couldn't play One Man Army.")

func _show_oma_type_picker(type_card: Card) -> void:
	var picker := VBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	var count := type_card.piece_types.size()
	picker.position = _picker_anchor_position(count * 44.0 + (count - 1) * 8.0)
	for t in type_card.piece_types:
		var b := Button.new()
		b.text = "Arm %s" % _type_letter(t)
		_style_picker_button(b)
		b.pressed.connect(func():
			picker.queue_free()
			_launch_one_man_army(type_card, t)
		)
		picker.add_child(b)
	add_child(picker)

func _launch_saboteur(type_card: Card, chart_card: Card, chosen: Piece.Type) -> void:
	if controller and controller.begin_saboteur_targeting(type_card, chart_card, chosen):
		pass

func _show_type_picker(type_card: Card, chart_card: Card) -> void:
	var picker := VBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	var count := type_card.piece_types.size()
	picker.position = _picker_anchor_position(count * 44.0 + (count - 1) * 8.0)
	for t in type_card.piece_types:
		var b := Button.new()
		b.text = "Declare as %s" % _type_letter(t)
		_style_picker_button(b)
		b.pressed.connect(func():
			picker.queue_free()
			_launch_saboteur(type_card, chart_card, t)
		)
		picker.add_child(b)
	add_child(picker)

func _type_letter(t: Piece.Type) -> String:
	match t:
		Piece.Type.A: return "A"
		Piece.Type.B: return "B"
		Piece.Type.C: return "C"
		_: return "?"

func hide_deploy_card() -> void:
	if deploy_card:
		deploy_card.visible = false

func _display_side() -> Piece.Owner:
	if NetworkManager.is_networked():
		return NetworkManager.my_side()
	if forced_side >= 0:
		return forced_side
	return game_state.current_player
	

var reveal_root: Control
var _reveal_timer: SceneTreeTimer = null

func reveal_opponent_card(card: Card, text: String) -> void:
	if reveal_root:
		reveal_root.queue_free()
	reveal_root = Control.new()
	reveal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reveal_root)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(REVEAL_W, REVEAL_H)
	art.position = Vector2(SCREEN_W * 0.5 - REVEAL_W * 0.5, 90)
	art.pivot_offset = Vector2(REVEAL_W * 0.5, REVEAL_H * 0.5)
	art.texture = card_back_tex(_display_side())
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_root.add_child(art)

	var cap := Label.new()
	cap.text = text
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 20)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", 5)
	cap.size = Vector2(REVEAL_W, 30)
	cap.position = Vector2(SCREEN_W * 0.5 - REVEAL_W * 0.5, 90 + REVEAL_H + 10)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_root.add_child(cap)

	var this_root := reveal_root
	# Squash to edge-on, swap the texture at the midpoint, then open out again.
	var tw := create_tween()
	tw.tween_property(art, "scale:x", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_instance_valid(art):
		return
	art.texture = _face_texture(card)
	var tw2 := create_tween()
	tw2.tween_property(art, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished

	var t := get_tree().create_timer(2.6)
	_reveal_timer = t
	await t.timeout
	if _reveal_timer != t or not is_instance_valid(this_root):
		return
	var tw3 := create_tween()
	tw3.tween_property(this_root, "modulate:a", 0.0, 0.7)
	await tw3.finished
	if is_instance_valid(this_root):
		this_root.queue_free()
	if reveal_root == this_root:
		reveal_root = null
		
# Resolved at runtime, not preloaded, so the active theme can supply its own.
# A theme may ship one card_back.png, or card_back_1/2.png so each player has
# their own. TextureManager falls back numbered -> single -> default theme.
static func card_back_tex(side: int) -> Texture2D:
	return TextureManager.card_back(side)
var _face_cache: Dictionary = {}

func _face_texture(card: Card) -> Texture2D:
	if not _face_cache.has(card.uid):
		_face_cache[card.uid] = TextureManager.get_texture("cards", CardView.sprite_name_for(card))
	return _face_cache[card.uid]
