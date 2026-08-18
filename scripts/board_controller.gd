extends Node2D

const REQUIRED_COUNTS := {
	Piece.Type.A: 12, Piece.Type.B: 6, Piece.Type.C: 3,
	Piece.Type.GENERAL: 1, Piece.Type.OBJECTIVE: 1,
}
const PIECE_ORDER := [
	Piece.Type.A, Piece.Type.B, Piece.Type.C,
	Piece.Type.GENERAL, Piece.Type.OBJECTIVE,
]
const TYPE_LABELS := {
	Piece.Type.A: "A", Piece.Type.B: "B", Piece.Type.C: "C",
	Piece.Type.GENERAL: "General", Piece.Type.OBJECTIVE: "Objective",
}
const OPP_BACK_W := 54.0
const OPP_BACK_H := OPP_BACK_W * (798.0 / 567.0)
const OPP_LABEL_GAP := 6.0

var opponent_count_root: Control
var opponent_count_label: Label
var opponent_hand_title: Label
var opponent_selected_view: PieceView = null

var game_state: GameState
var current_player: Piece.Owner = Piece.Owner.BLUE
var selected_type: Piece.Type = Piece.Type.A
var next_uid: int = 1
var ghost: PieceGhost
var piece_layer: Node2D
var ui_layer: CanvasLayer
var host_address_layer: CanvasLayer
var host_address_label: Label
var type_buttons: Dictionary = {}
var status_label: Label
var pass_screen: CanvasLayer
var pass_label: Label
var in_croce: bool = true
var _network_placement_done: bool = false
var _ready_finished: bool = false
var _card_lookup: Dictionary = {}
var debug_saboteur_armed: bool = false
var saboteur_targeting: bool = false
var saboteur_target_piece: Piece = null
var _sab_preview_views: Array = []   # PieceViews pulsing as declare-as candidates
var saboteur_type_card: Card = null
var saboteur_chart_card: Card = null
var saboteur_chosen_type: Piece.Type
var selected_piece: Piece = null
var selected_view: PieceView = null
var highlights: Array = []
var turn_label: Label
var turn_panel: PanelContainer
var end_turn_button: Button
var pause_button: Button
var rotate_button: Button
var _deployed_this_turn: bool = false
var hand_panel: HandPanel
var debug_hand_builder: DebugHandBuilder
var captured_tray: CapturedTray
var croce_panel: PanelContainer
var chat_overlay: ChatOverlay = null
var turn_timer_bar: ColorRect
var turn_timer_label: Label
var _turn_timer_active: bool = false
var _turn_timer_total: float = 30.0
var _turn_timer_left: float = 0.0
var _turn_timer_paused: bool = false   # true while a card is selected
var _pulse_t: float = 0.0
var turn_timer_ring: Panel
var _ring_sb_active: StyleBoxFlat    # yellow, current player
var _ring_sb_idle: StyleBoxFlat      # grey, waiting player
var _timer_ring_is_mine: bool = true
var _et_style_normal: StyleBox
var _et_style_pale: StyleBox
var move_ripple: RippleMarker = null
var _capture_ripples: Array = []   # RippleMarker splashes on this turn's capture squares

var ityd_selecting: bool = false      # waiting for player to click a captured piece
var ityd_placing: bool = false        # ghost placement phase
var ityd_piece: Piece = null          # the chosen captured piece
var ityd_card = null                  # the ITYD card, discarded on success
var ityd_ghost: PieceGhost = null
var ityd_required_type: Piece.Type
var _moved_piece: Piece = null
var jto_active: bool = false
var jto_card = null
var _game_over: bool = false

# --- CPU opponent (Tier 0) ---
var cpu: CpuPlayer = null        # null = human hotseat
var _cpu_pending: bool = false   # a CPU action is already scheduled

# Croce-period decorative portrait (draggable, rounded, drop-shadowed). Parented to
# ui_layer so it's torn down automatically whenever Croce setup ends.
var croce_portrait: Control
var _croce_drag: bool = false
var _croce_drag_offset: Vector2 = Vector2.ZERO

func _begin_networked_game_from_data(merged_pieces: Array) -> void:
	for child in piece_layer.get_children():
		child.queue_free()
	game_state.pieces.clear()
	next_uid = 1

	for d in merged_pieces:
		var p := Piece.new()
		p.uid = d["uid"]
		p.designation = d["designation"]
		p.type = d["type"]
		p.owner = d["owner"]
		p.original_owner = d["owner"]
		p._original_owner_set = true
		p.orientation = d["orientation"]
		var typed_cells: Array[Vector2i] = []
		for c in d["cells"]:
			typed_cells.append(c)
		CroceSetup.place_piece(p, typed_cells, game_state)
		next_uid = max(next_uid, p.uid + 1)
		var view := PieceView.new()
		piece_layer.add_child(view)
		view.setup(p)

	ghost.queue_free()
	ui_layer.queue_free()
	_teardown_croce_ui()
	game_state.initialize_deck()
	if not NetworkManager.is_host():
		game_state.deck.clear()
		game_state.deck_is_authoritative = false
		ReplayRecorder.start_match(game_state, "online", NetworkManager.my_side())
	in_croce = false
	piece_layer.visible = true
	_reveal_all_pieces()
	_build_turn_ui()
	MusicManager.begin_gameplay_rotation()
	print("Networked Croce merge complete — game begins for both players.")

func _ready() -> void:
	randomize()
	BoardView.flipped = false   # view flip is per-match; never inherited from the last one
	print("board_controller _ready called")
	MusicManager.play_track(MusicManager.Track.CROCE)
	game_state = GameState.new()
	game_state.board = Board.new()
	game_state.rules = GameRules.new()
	if NetworkManager.is_networked():
		current_player = NetworkManager.my_side()
		NetworkManager.network_croce_ready.connect(_begin_networked_game_from_data)
		NetworkManager.move_requested.connect(_on_move_requested)
		NetworkManager.move_applied.connect(_on_move_applied)
		NetworkManager.turn_end_requested.connect(_on_turn_end_requested)
		NetworkManager.turn_ended.connect(_on_turn_ended)
		NetworkManager.hand_state_received.connect(_on_hand_state_received)
		NetworkManager.deploy_requested.connect(_on_deploy_requested)
		NetworkManager.deploy_applied.connect(_on_deploy_applied)
		NetworkManager.jto_requested.connect(_on_jto_requested)
		NetworkManager.jto_applied.connect(_on_jto_applied)
		NetworkManager.ityd_requested.connect(_on_ityd_requested)
		NetworkManager.ityd_applied.connect(_on_ityd_applied)
		NetworkManager.discard_requested.connect(_on_discard_requested)
		NetworkManager.discard_applied.connect(_on_discard_applied)
		NetworkManager.saboteur_requested.connect(_on_saboteur_requested)
		NetworkManager.saboteur_applied.connect(_on_saboteur_applied)
		NetworkManager.oma_requested.connect(_on_oma_requested)
		NetworkManager.oma_applied.connect(_on_oma_applied)
		NetworkManager.selection_changed.connect(_on_opponent_selection_changed)
		NetworkManager.forfeit_requested.connect(_on_forfeit_requested)
		NetworkManager.match_ended.connect(_on_match_ended)
		NetworkManager.opponent_left.connect(_on_opponent_left)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.request_rejected.connect(_on_request_rejected)
		NetworkManager.deploy_mirror_changed.connect(_on_deploy_mirror_changed)
		if not NetworkManager.is_host():
			# We're the joining player. Don't build anything yet — ask the host
			# for its settings first, and wait for the answer.
			NetworkManager.rule_settings_received.connect(_on_rule_settings_received)
			if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				NetworkManager.request_rule_settings.rpc_id(1)
			else:
				NetworkManager.connected_to_host.connect(_on_connected_request_settings, CONNECT_ONE_SHOT)
			return
	_finish_ready()
	_cpu_from_menu()

func _card_in_hand(side: Piece.Owner, uid: int):
	for c in game_state.hands[side]:
		if c.uid == uid:
			return c
	return null
	
func _on_connected_request_settings() -> void:
	NetworkManager.request_rule_settings.rpc_id(1)

func _on_deploy_mirror_changed(is_visible: bool, pos: Vector2) -> void:
	if hand_panel:
		hand_panel.show_deploy_mirror(is_visible, pos)
		
func _on_rule_settings_received(_settings: Dictionary) -> void:
	_finish_ready()

func _reject(sender_id: int, reason: String) -> void:
	if not NetworkManager.is_host():
		return
	if sender_id == multiplayer.get_unique_id():
		_on_request_rejected(reason)          # host rejecting itself
	else:
		NetworkManager.reject_request.rpc_id(sender_id, reason)

func _on_request_rejected(reason: String) -> void:
	# Clear any half-finished local interaction so the player isn't stranded
	# mid-action with no way out.
	_deselect()
	if jto_active:
		jto_active = false
		jto_card = null
		_clear_highlights()
	if ityd_selecting or ityd_placing:
		_finish_ityd_local()
	if saboteur_targeting:
		_cancel_saboteur_targeting()
	SfxManager.play("illegal")
	if hand_panel:
		hand_panel.show_status(reason)
		hand_panel.refresh()
		
func _resolve_oma(side: Piece.Owner, type_uid: int, oma_uid: int, chosen_type: int, from_hand: bool) -> bool:
	var type_card = _card_in_hand(side, type_uid) if from_hand else _card_by_uid(type_uid)
	var oma_card = _card_in_hand(side, oma_uid) if from_hand else _card_by_uid(oma_uid)
	if type_card == null or oma_card == null:
		return false
	if not game_state.apply_one_man_army(side, type_card, chosen_type):
		return false
	game_state.discard_card(side, oma_card)
	SfxManager.play("play_major_card")
	_deployed_this_turn = true
	_update_turn_label()
	if hand_panel:
		hand_panel.refresh()
	return true

func _on_opponent_selection_changed(piece_uid: int) -> void:
	# Show the opponent's gold selection outline only. Never their legal moves —
	# that would telegraph exactly what they're considering.
	if opponent_selected_view and is_instance_valid(opponent_selected_view):
		opponent_selected_view.set_state(0)
		opponent_selected_view.set_selection_pulse(false)
	opponent_selected_view = null
	if piece_uid < 0 or not game_state.pieces.has(piece_uid):
		return
	var v := _find_view(game_state.pieces[piece_uid])
	if v:
		v.set_state(1)
		v.set_selection_pulse(true)
		opponent_selected_view = v
		
func _on_oma_requested(sender_id: int, type_uid: int, oma_uid: int, chosen_type: int) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != side:
		_reject(sender_id, "It isn't your turn.")
		return
	if not _resolve_oma(side, type_uid, oma_uid, chosen_type, true):
		_reject(sender_id, "One Man Army can't be played right now.")
		return
	NetworkManager.apply_oma.rpc(type_uid, oma_uid, chosen_type)
	_broadcast_hand_state()
	_announce_opponent_card(side, oma_uid, "One Man Army played.")

func _on_oma_applied(type_uid: int, oma_uid: int, chosen_type: int) -> void:
	if NetworkManager.is_host():
		return
	var side := game_state.current_player
	# Don't call apply_one_man_army() here — it validates against the playing
	# player's hand, and on this machine the opponent's hand is meaningless
	# (their cards are never transmitted). The host already validated.
	game_state.one_man_army_type = chosen_type
	game_state.one_man_army_active = true
	var type_card = _card_by_uid(type_uid)
	var oma_card = _card_by_uid(oma_uid)
	if type_card != null and game_state.hands[side].has(type_card):
		game_state.discard_card(side, type_card)
	if oma_card != null and game_state.hands[side].has(oma_card):
		game_state.discard_card(side, oma_card)
	SfxManager.play("play_major_card")
	_deployed_this_turn = true
	_update_turn_label()
	if hand_panel:
		hand_panel.refresh()
	_announce_opponent_card(side, oma_uid, "One Man Army played.")

func _on_saboteur_requested(sender_id: int, type_uid: int, chart_uid: int, chosen_type: int, target_uid: int) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != side:
		_reject(sender_id, "It isn't your turn.")
		return
	if not RulesEngine.can_declare_saboteur(side, game_state):
		_reject(sender_id, "You can't declare a Saboteur right now.")
		return
	if not _resolve_saboteur(side, type_uid, chart_uid, chosen_type, target_uid, true):
		_reject(sender_id, "That declaration doesn't match any piece.")
		return
	_finish_saboteur_local()
	NetworkManager.apply_saboteur.rpc(type_uid, chart_uid, chosen_type, target_uid)
	_broadcast_hand_state()
	_announce_card_play(side, "Saboteur declared!", "Opponent has declared a Saboteur!")

func _on_saboteur_applied(type_uid: int, chart_uid: int, chosen_type: int, target_uid: int) -> void:
	if NetworkManager.is_host():
		return
	var side := game_state.current_player
	# Do NOT call declare_saboteur() here. It validates against the declaring
	# player's hand, and on this machine the opponent's hand is meaningless —
	# their cards are never transmitted. The host already validated; just
	# apply the result it approved.
	if game_state.pieces.has(target_uid):
		saboteur_target_piece = game_state.pieces[target_uid]
		saboteur_target_piece.apply_saboteur_conversion(side)
	var type_card = _card_by_uid(type_uid)
	var chart_card = _card_by_uid(chart_uid)
	if type_card != null and game_state.hands[side].has(type_card):
		game_state.discard_card(side, type_card)
	if chart_card != null and game_state.hands[side].has(chart_card):
		game_state.discard_card(side, chart_card)
	_finish_saboteur_local()
	_announce_card_play(side, "Saboteur declared!", "Opponent has declared a Saboteur!")

func _finish_saboteur_local() -> void:
	if saboteur_target_piece:
		var v := _find_view(saboteur_target_piece)
		if v:
			v.set_saboteur_pulse(false)
	saboteur_targeting = false
	saboteur_target_piece = null
	saboteur_type_card = null
	saboteur_chart_card = null
	SfxManager.play("saboteur_transform")
	_refresh_all_piece_views()
	if captured_tray:
		captured_tray.refresh()
	if hand_panel:
		hand_panel.refresh()
	_deployed_this_turn = true
	_update_turn_label()
	
func _finish_ready() -> void:
	if Engine.has_singleton("RuleSettings") or get_node_or_null("/root/RuleSettings"):
		var rs = get_node_or_null("/root/RuleSettings")
		if rs:
			rs.apply_to(game_state.rules)
	piece_layer = get_node("PieceLayer")
	get_node("Board").refresh_colors()
	_build_ui()
	_build_pass_screen()
	_build_rotate_button()
	_spawn_ghost()
	_refresh_ui()
	if NetworkManager.is_networked() and NetworkManager.is_host():
		_build_host_address_label()
		NetworkManager.upnp_result.connect(func(_s, _ip, _m): _update_host_address_label(), CONNECT_ONE_SHOT)
	if NetworkManager.is_networked() and NetworkManager.is_host():
		if multiplayer.get_peers().is_empty():
			_build_waiting_notice()
			NetworkManager.player_connected.connect(_dismiss_waiting_notice, CONNECT_ONE_SHOT)
	if NetworkManager.is_networked():
		chat_overlay = ChatOverlay.new()
		add_child(chat_overlay)
		chat_overlay.effect_triggered.connect(_on_chat_effect)
		chat_overlay.placement_requested.connect(_on_sticker_placement_requested)
		ChatManager.placed_sticker_received.connect(_on_placed_sticker_received)
	if NetworkManager.is_networked():
		NetworkManager.turn_timer_started.connect(_on_turn_timer_started)
		NetworkManager.turn_timer_cancelled.connect(_on_turn_timer_cancelled)
		NetworkManager.turn_timer_pause_changed.connect(_apply_timer_pause)
	_ready_finished = true
	
func _on_chat_effect(effect_id: String, side: int) -> void:
	print("CHAT EFFECT: ", effect_id, " from side ", side)
	
func _build_host_address_label() -> void:
	host_address_layer = CanvasLayer.new()
	host_address_layer.layer = 60
	add_child(host_address_layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	host_address_layer.add_child(center)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.75, 0.3, 0.9)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)

	host_address_label = Label.new()
	host_address_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host_address_label.add_theme_font_size_override("font_size", 20)
	host_address_label.add_theme_color_override("font_outline_color", Color.BLACK)
	host_address_label.add_theme_constant_override("outline_size", 4)
	col.add_child(host_address_label)

	var btn := Button.new()
	btn.text = "Got it"
	btn.custom_minimum_size = Vector2(180, 46)
	btn.pressed.connect(_dismiss_host_address)
	col.add_child(btn)

	box.add_child(col)
	center.add_child(box)
	_update_host_address_label()

var _opp_count_pulse_tween: Tween
	
func _set_opponent_count_pulse(active: bool) -> void:
	if _opp_count_pulse_tween:
		_opp_count_pulse_tween.kill()
		_opp_count_pulse_tween = null
	if opponent_count_label == null or not is_instance_valid(opponent_count_label):
		return
	if active:
		_opp_count_pulse_tween = create_tween().set_loops()
		_opp_count_pulse_tween.tween_property(opponent_count_label, "modulate", Color(1.0, 0.72, 0.2), 0.5).set_trans(Tween.TRANS_SINE)
		_opp_count_pulse_tween.tween_property(opponent_count_label, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		opponent_count_label.modulate = Color.WHITE
		
func _dismiss_host_address() -> void:
	if host_address_layer and is_instance_valid(host_address_layer):
		host_address_layer.queue_free()
	host_address_layer = null
	host_address_label = null

func _update_host_address_label() -> void:
	if host_address_label == null or not is_instance_valid(host_address_label):
		return
	if NetworkManager.external_address != "":
		host_address_label.text = "Your address: %s\nShare this so a friend can join." % NetworkManager.external_address
	else:
		host_address_label.text = "Router: %s" % NetworkManager.upnp_status
		
func _on_ityd_requested(sender_id: int, card_uid: int, piece_uid: int, cells: Array, orientation: int) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != side:
		_reject(sender_id, "It isn't your turn.")
		return
	var card = _card_in_hand(side, card_uid)
	if card == null:
		_reject(sender_id, "You don't have that card.")
		return
	var typed_cells: Array[Vector2i] = []
	for c in cells:
		typed_cells.append(c)
	for cell in typed_cells:
		if not _in_ityd_zone(cell, side):
			_reject(sender_id, "That placement is outside your deployment zone.")
			return
	if not game_state.apply_i_thought_you_were_dead(side, piece_uid, typed_cells, orientation):
		_reject(sender_id, "That redeployment isn't legal.")
		return
	game_state.discard_card(side, card)
	SfxManager.play("croce_place")
	_finish_ityd_local()
	NetworkManager.apply_ityd.rpc(card_uid, piece_uid, cells, orientation)
	_broadcast_hand_state()
	_announce_opponent_card(side, card_uid, "Piece redeployed!")

func _on_discard_requested(sender_id: int, card_uids: Array) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	var limit: int = hand_panel.HAND_LIMIT if hand_panel else 9
	var hand: Array = game_state.hands[side]
	if hand.size() <= limit:
		_reject(sender_id, "You aren't over the hand limit.")
		return
	if card_uids.size() != hand.size() - limit:
		_reject(sender_id, "Wrong number of cards selected.")
		return
	var to_discard: Array = []
	for uid in card_uids:
		var c = _card_in_hand(side, uid)
		if c == null:
			_reject(sender_id, "You don't have that card.")
			return
		to_discard.append(c)
	for c in to_discard:
		game_state.discard_to_deck(side, c)
	SfxManager.play("discard")
	if hand_panel:
		hand_panel.refresh()
	NetworkManager.apply_discard.rpc(int(side), card_uids)
	_broadcast_hand_state()

func _on_discard_applied(side_int: int, card_uids: Array) -> void:
	if NetworkManager.is_host():
		return
	var side: Piece.Owner = side_int
	for uid in card_uids:
		var c = _card_in_hand(side, uid)
		if c != null:
			game_state.discard_to_deck(side, c)
	SfxManager.play("discard")
	if hand_panel:
		hand_panel.refresh()
		
func _on_ityd_applied(card_uid: int, piece_uid: int, cells: Array, orientation: int) -> void:
	if NetworkManager.is_host():
		return
	var side := game_state.current_player
	var card = _card_by_uid(card_uid)
	var typed_cells: Array[Vector2i] = []
	for c in cells:
		typed_cells.append(c)
	if game_state.apply_i_thought_you_were_dead(side, piece_uid, typed_cells, orientation):
		if card != null:
			game_state.discard_card(side, card)
		SfxManager.play("croce_place")
	_finish_ityd_local()
	_announce_opponent_card(side, card_uid, "Piece redeployed!")

func _finish_ityd_local() -> void:
	ityd_placing = false
	ityd_selecting = false
	ityd_piece = null
	ityd_card = null
	if ityd_ghost:
		ityd_ghost.queue_free()
		ityd_ghost = null
	if rotate_button:
		rotate_button.visible = false
	_refresh_all_piece_views()
	if captured_tray:
		captured_tray.refresh()
	if hand_panel:
		hand_panel.refresh()
	_update_turn_label()
	
func _on_move_requested(sender_id: int, piece_uid: int, destination: Vector2i) -> void:
	if not NetworkManager.is_host():
		return
	if not game_state.pieces.has(piece_uid):
		_reject(sender_id, "That piece no longer exists.")
		return
	var piece: Piece = game_state.pieces[piece_uid]
	var expected_side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if piece.owner != expected_side:
		_reject(sender_id, "That isn't your piece.")
		return
	if game_state.current_player != piece.owner:
		_reject(sender_id, "It isn't your turn.")
		return
	selected_piece = piece
	selected_view = _find_view(piece)
	_show_highlights(piece)
	var dest := _highlight_at(destination)
	if dest == Vector2i(-1, -1):
		_clear_highlights()
		selected_piece = null
		_reject(sender_id, "That move isn't legal.")
		return
	_execute_move(dest)
	NetworkManager.apply_move.rpc(piece_uid, dest)
	_broadcast_hand_state()

func _on_move_applied(piece_uid: int, destination: Vector2i) -> void:
	if NetworkManager.is_host():
		return
	if not game_state.pieces.has(piece_uid):
		return
	selected_piece = game_state.pieces[piece_uid]
	selected_view = _find_view(selected_piece)
	_execute_move(destination)

func _on_turn_end_requested(sender_id: int) -> void:
	if not NetworkManager.is_host():
		return
	var expected_side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != expected_side:
		_reject(sender_id, "It isn't your turn.")
		return
	NetworkManager.broadcast_end_turn.rpc()
	_broadcast_hand_state()

func _on_turn_ended() -> void:
	_on_turn_timer_cancelled()
	SfxManager.play("end_turn")
	var last_mover: Piece = _moved_piece
	_deselect()
	game_state.end_turn()
	_show_move_ripple(last_mover)
	_deployed_this_turn = false
	_update_turn_label()
	if hand_panel:
		hand_panel.refresh()
	if captured_tray:
		captured_tray.refresh()

func _show_move_ripple(piece: Piece) -> void:
	_dismiss_move_ripple()

	# Consume the capture record unconditionally, even if nothing is drawn
	# below, so a hidden turn's captures do not leak into the next ripple.
	var capture_cells: Array = game_state.capture_cells_this_turn.duplicate()
	game_state.capture_cells_this_turn.clear()
	var ityd_cells: Array = game_state.ityd_cells_this_turn.duplicate()
	game_state.ityd_cells_this_turn.clear()

	# Only for the player about to act. In hotseat there's one screen, so show.
	if NetworkManager.is_networked() and game_state.current_player != NetworkManager.my_side():
		return

	# Capture splashes first: little raindrops on each square something died on,
	# staggered so they land in a loose random series rather than all at once.
	var drop_key: String = RuleSettings.side_one_color if game_state.current_player == Piece.Owner.BLUE \
		else RuleSettings.side_two_color
	var drop_color: Color = RuleSettings.COLOR_HEX.get(drop_key, Color("#141414"))
	var delay: float = 0.0
	for cells in capture_cells:
		if cells.is_empty():
			continue
		var drop := RippleMarker.new()
		drop.make_raindrop()
		drop.position = _cells_center(cells)
		drop.color = drop_color
		drop.start_delay = delay
		add_child(drop)
		_capture_ripples.append(drop)
		delay += randf_range(0.12, 0.34)

	# A returned piece is an arrival rather than a death, so it gets a full
	# ripple instead of a raindrop — it should read as more significant than
	# a capture splash.
	for cells in ityd_cells:
		if cells.is_empty():
			continue
		var arrival := RippleMarker.new()
		arrival.position = _cells_center(cells)
		arrival.color = drop_color
		arrival.start_delay = delay
		add_child(arrival)
		_capture_ripples.append(arrival)
		delay += randf_range(0.12, 0.34)

	# Then the mover ripple, if the piece is still on the board.
	if piece == null or not game_state.pieces.has(piece.uid):
		return
	if piece.cells.is_empty():
		return

	move_ripple = RippleMarker.new()
	move_ripple.position = _cells_center(piece.cells)
	var key: String = RuleSettings.side_one_color if piece.owner == Piece.Owner.BLUE \
		else RuleSettings.side_two_color
	move_ripple.color = RuleSettings.COLOR_HEX.get(key, Color("#141414"))
	add_child(move_ripple)

func _cells_center(cells: Array) -> Vector2:
	var sum := Vector2.ZERO
	for cell in cells:
		sum += BoardView.grid_to_world_center(cell)
	return sum / float(cells.size())

func _dismiss_move_ripple() -> void:
	if move_ripple and is_instance_valid(move_ripple):
		move_ripple.dismiss()
	move_ripple = null
	for r in _capture_ripples:
		if r and is_instance_valid(r):
			r.dismiss()
	_capture_ripples.clear()
	
func _resolve_saboteur(side: Piece.Owner, type_uid: int, chart_uid: int, chosen_type: int, target_uid: int, from_hand: bool) -> bool:
	var type_card = _card_in_hand(side, type_uid) if from_hand else _card_by_uid(type_uid)
	var chart_card = _card_in_hand(side, chart_uid) if from_hand else _card_by_uid(chart_uid)
	if type_card == null or chart_card == null:
		return false
	# The host resolves the target from the card designation, the same way
	# begin_saboteur_targeting() does locally and the same way declare_saboteur()
	# will. The client-supplied target_uid is an assertion, not an instruction:
	# if it disagrees with the canonical piece, reject rather than apply.
	var designation := RulesEngine.designation_from_cards(type_card, chart_card, chosen_type)
	if designation == "":
		return false
	var opponent: Piece.Owner = Piece.Owner.RED if side == Piece.Owner.BLUE else Piece.Owner.BLUE
	var target := game_state._find_piece_by_designation(designation, opponent)
	if target == null:
		return false
	if target_uid != target.uid:
		return false
	saboteur_target_piece = target
	return game_state.declare_saboteur(side, type_card, chart_card, chosen_type)
	
# ---------------- turn countdown (host owns the clock) ----------------

const TURN_TIMER_SECONDS := 20.0

func _start_turn_timer() -> void:
	# Called after a piece MOVE completes. Host decides; in hotseat we're both.
	if NetworkManager.is_networked():
		if NetworkManager.is_host():
			NetworkManager.broadcast_turn_timer_start.rpc(TURN_TIMER_SECONDS)
	else:
		_on_turn_timer_started(TURN_TIMER_SECONDS)

func _tick_turn_timer(delta: float) -> void:
	if not _turn_timer_active or turn_timer_bar == null or end_turn_button == null:
		return
	if not _turn_timer_paused:
		_turn_timer_left = max(0.0, _turn_timer_left - delta)

	var frac: float = 1.0 - (_turn_timer_left / _turn_timer_total)
	turn_timer_bar.size.x = end_turn_button.size.x * frac
	turn_timer_bar.size.y = end_turn_button.size.y

	# Pulse the ring, faster and stronger as time runs down.
	var urgency: float = clamp(frac, 0.0, 1.0)
	_pulse_t += delta * (3.0 + urgency * 9.0)
	var glow: float = 0.5 + 0.5 * sin(_pulse_t)
	if turn_timer_ring and _timer_ring_is_mine:
		turn_timer_ring.modulate.a = 0.25 + 0.75 * glow * (0.35 + 0.65 * urgency)

	if _turn_timer_left <= 0.0:
		# Hold the bar full; only the host flips the turn, so a laggy client
		# shows a brief pause rather than a desync.
		_turn_timer_active = false
		if not NetworkManager.is_networked():
			_on_end_turn_pressed()
		elif NetworkManager.is_host():
			NetworkManager.broadcast_turn_timer_cancel.rpc()
			NetworkManager.broadcast_end_turn.rpc()
			
func _cancel_turn_timer() -> void:
	if NetworkManager.is_networked():
		if NetworkManager.is_host():
			NetworkManager.broadcast_turn_timer_cancel.rpc()
	else:
		_on_turn_timer_cancelled()

func _on_turn_timer_started(seconds: float) -> void:
	_turn_timer_total = seconds
	_turn_timer_left = seconds
	_turn_timer_active = true
	_turn_timer_paused = false
	_pulse_t = 0.0
	if turn_timer_bar:
		turn_timer_bar.visible = true
	var my_turn: bool = (not NetworkManager.is_networked()) \
		or game_state.current_player == NetworkManager.my_side()
	_timer_ring_is_mine = my_turn
	if turn_timer_ring:
		turn_timer_ring.visible = true
		turn_timer_ring.add_theme_stylebox_override("panel",
			_ring_sb_active if my_turn else _ring_sb_idle)
		# The waiting player's ring is steady; only the active one pulses.
		turn_timer_ring.modulate.a = 1.0 if not my_turn else turn_timer_ring.modulate.a
	if end_turn_button and _et_style_pale:
		end_turn_button.add_theme_stylebox_override("normal", _et_style_pale)
		end_turn_button.add_theme_stylebox_override("hover", _et_style_pale)
		end_turn_button.add_theme_stylebox_override("pressed", _et_style_pale)
	if hand_panel:
		hand_panel.show_status("Turn ends automatically — click End Turn when ready.")
	#	SfxManager.play("turn_warning")

func _on_turn_timer_cancelled() -> void:
	_turn_timer_active = false
	_turn_timer_paused = false
	if turn_timer_bar:
		turn_timer_bar.visible = false
		turn_timer_bar.size.x = 0
	if turn_timer_ring:
		turn_timer_ring.visible = false
	if end_turn_button and _et_style_normal:
		end_turn_button.add_theme_stylebox_override("normal", _et_style_normal)
		end_turn_button.add_theme_stylebox_override("hover", _et_style_normal)
		end_turn_button.add_theme_stylebox_override("pressed", _et_style_normal)

func set_turn_timer_paused(paused: bool) -> void:
	# A selected card or an in-progress deploy freezes the countdown. The
	# unpause is ignored while cards remain selected. Pause is authoritative:
	# the host owns the clock, so we route through it and both bars stay in sync
	# — and the acting player can't be timed out mid-card-selection.
	if not paused and hand_panel and not hand_panel.selected_cards.is_empty():
		return
	if NetworkManager.is_networked():
		NetworkManager.request_turn_timer_pause.rpc_id(1, paused)
	else:
		_turn_timer_paused = paused

func _apply_timer_pause(paused: bool) -> void:
	_turn_timer_paused = paused

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# --- Croce setup panel: rounded white window, drop shadow ---
	croce_panel = PanelContainer.new()
	var panel := croce_panel
	panel.position = Vector2(12, 20)
	panel.custom_minimum_size = Vector2(255, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color.WHITE
	panel_sb.set_corner_radius_all(12)
	panel_sb.shadow_color = Color(0, 0, 0, 0.35)
	panel_sb.shadow_size = 6
	panel_sb.shadow_offset = Vector2(0, 3)
	panel_sb.content_margin_left = 14
	panel_sb.content_margin_right = 14
	panel_sb.content_margin_top = 12
	panel_sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_sb)
	ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 7)
	vbox.custom_minimum_size = Vector2(227, 0)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Croce Menu"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("#141414"))
	vbox.add_child(title)

	# Signature rule: red over blue
	var rule := VBoxContainer.new()
	rule.add_theme_constant_override("separation", 4)
	var red_bar := ColorRect.new()
	red_bar.color = RuleSettings.COLOR_HEX[RuleSettings.side_two_color]
	red_bar.custom_minimum_size = Vector2(0, 2)
	var blue_bar := ColorRect.new()
	blue_bar.color = RuleSettings.COLOR_HEX[RuleSettings.side_one_color]
	blue_bar.custom_minimum_size = Vector2(0, 2)
	rule.add_child(red_bar)
	rule.add_child(blue_bar)
	vbox.add_child(rule)

	# "BLUE placing" status - outlined colored text
	status_label = Label.new()
	status_label.text = "%s's Pieces" % RuleSettings.display_name(Piece.Owner.BLUE)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", RuleSettings.COLOR_HEX[RuleSettings.side_one_color])
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(status_label)

	# Piece-count buttons (rounded)
	for type in PIECE_ORDER:
		var btn := Button.new()
		btn.text = _button_label(type)
		btn.add_theme_font_size_override("font_size", 15)
		var b_normal := StyleBoxFlat.new()
		b_normal.bg_color = Color("#f2efe9")
		b_normal.set_corner_radius_all(8)
		b_normal.content_margin_top = 6
		b_normal.content_margin_bottom = 6
		b_normal.content_margin_left = 10
		b_normal.content_margin_right = 10
		var b_hover := b_normal.duplicate()
		b_hover.bg_color = Color("#e6e1d8")
		var b_pressed := b_normal.duplicate()
		b_pressed.bg_color = Color("#d8d2c6")
		btn.add_theme_stylebox_override("normal", b_normal)
		btn.add_theme_stylebox_override("hover", b_hover)
		btn.add_theme_stylebox_override("pressed", b_pressed)
		btn.add_theme_stylebox_override("focus", b_normal)
		btn.add_theme_color_override("font_color", Color("#141414"))
		btn.pressed.connect(_on_type_selected.bind(type))
		vbox.add_child(btn)
		type_buttons[type] = btn

	_build_croce_portrait()

# The Croce-period portrait: rounded corners, drop shadow, draggable, spawned
# below the Croce Menu and sized a touch larger than it. Lives on ui_layer so it
# vanishes with the rest of the Croce UI when setup ends.
func _build_croce_portrait() -> void:
	var tex_path := "res://assets/ui/croce.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex = load(tex_path)
	if tex == null:
		return

	# Frame width slightly exceeds the Croce Menu (255) per "at least as large".
	var frame_w := 280.0
	var tex_size: Vector2 = tex.get_size()
	var frame_h: float = frame_w
	if tex_size.x > 0:
		frame_h = frame_w * (tex_size.y / tex_size.x)

	# Outer frame: white card, rounded, drop shadow (matches the app's panel look).
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(frame_w, frame_h)
	frame.size = Vector2(frame_w, frame_h)
	# Center the portrait on the OPPOSING half of the board: during Blue's Croce
	# setup it sits on the red (bottom) half, and when play hands off to Red it
	# respawns on the blue (top) half. The board is 18 cols x 16 rows at CELL px
	# from BOARD_ORIGIN; ui_layer is screen-space, so the selected board point is
	# converted through the viewport's active canvas transform below.
	# Blue half = rows 0-7 (center ~row 4), Red half = rows 8-15 (center ~row 12).
	# The portrait spawns on the half opposite the player setting up. A flipped
	# board swaps which half that is on screen, so pick from the flipped side.
	var portrait_side: Piece.Owner = current_player
	if BoardView.flipped:
		portrait_side = Piece.Owner.RED if current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	var center_col := 19.0 if portrait_side == Piece.Owner.BLUE else 9.0
	var opposing_row := 15.5 if portrait_side == Piece.Owner.BLUE else 4.0
	var board_pt := BoardView.BOARD_ORIGIN + Vector2(center_col * BoardView.CELL, opposing_row * BoardView.CELL)
	# Preserve the original hand-tuned opening placement for Blue's Croce. That
	# position was authored directly in this CanvasLayer's coordinate space.
	# Only the post-handoff portrait needs world-to-screen conversion, because its
	# blue-half board point has a negative world Y and would otherwise be offscreen.
	var portrait_pt: Vector2 = board_pt
	if portrait_side == Piece.Owner.RED:
		portrait_pt = get_viewport().get_canvas_transform() * board_pt
	frame.position = portrait_pt - Vector2(frame_w, frame_h) * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color.WHITE
	fsb.set_corner_radius_all(14)
	fsb.shadow_color = Color(0, 0, 0, 0.45)
	fsb.shadow_size = 10
	fsb.shadow_offset = Vector2(0, 5)
	fsb.content_margin_left = 5
	fsb.content_margin_right = 5
	fsb.content_margin_top = 5
	fsb.content_margin_bottom = 5
	frame.add_theme_stylebox_override("panel", fsb)

	# The image, clipped to rounded corners. A TextureRect inside a clip-enabled
	# panel gives the rounded-edge look without a shader.
	var clip := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color.WHITE
	csb.set_corner_radius_all(10)
	clip.add_theme_stylebox_override("panel", csb)
	clip.clip_contents = true
	# Let clicks fall through to the frame beneath so the WHOLE portrait is a drag
	# surface, not just the frame's thin margin. (Default STOP here was swallowing
	# every click over the image.)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(tr)

	frame.gui_input.connect(_on_croce_portrait_input)
	ui_layer.add_child(frame)
	croce_portrait = frame

func _on_jto_requested(sender_id: int, card_uid: int, destination: Vector2i) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != side:
		_reject(sender_id, "It isn't your turn.")
		return
	var card = _card_in_hand(side, card_uid)
	if card == null:
		_reject(sender_id, "You don't have that card.")
		return
	if game_state.objective_has_moved.get(side, false):
		_reject(sender_id, "The Objective has already moved this game.")
		return
	if not game_state.apply_just_this_once(side, destination):
		_reject(sender_id, "That destination isn't legal.")
		return
	game_state.discard_card(side, card)
	SfxManager.play("jto_objmove")
	jto_active = false
	jto_card = null
	_clear_highlights()
	_refresh_all_piece_views()
	_deployed_this_turn = true
	_update_turn_label()
	if hand_panel:
		hand_panel.refresh()
	NetworkManager.apply_jto.rpc(card_uid, destination)
	_broadcast_hand_state()
	_announce_opponent_card(side, card_uid, "Objective moved.")

func _on_jto_applied(card_uid: int, destination: Vector2i) -> void:
	if NetworkManager.is_host():
		return
	var side := game_state.current_player
	var card = _card_by_uid(card_uid)
	if game_state.apply_just_this_once(side, destination):
		if card != null:
			game_state.discard_card(side, card)
		SfxManager.play("jto_objmove")
	jto_active = false
	jto_card = null
	_clear_highlights()
	_refresh_all_piece_views()
	_deployed_this_turn = true
	_update_turn_label()
	_announce_opponent_card(side, card_uid, "Objective moved.")
	if hand_panel:
		hand_panel.refresh()
		
func _cards_from_uids(uids: Array) -> Array:
	if _card_lookup.is_empty():
		_build_card_lookup()
	var out: Array = []
	for uid in uids:
		if _card_lookup.has(uid):
			out.append(_card_lookup[uid])
	return out

func _on_deploy_requested(sender_id: int, card_uids: Array) -> void:
	if not NetworkManager.is_host():
		return
	var side := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	if game_state.current_player != side:
		_reject(sender_id, "It isn't your turn.")
		return
	var hand: Array = game_state.hands[side]
	var to_play: Array = []
	for uid in card_uids:
		for c in hand:
			if c.uid == uid:
				to_play.append(c)
				break
	if to_play.size() != card_uids.size():
		_reject(sender_id, "You don't have that card.")
		return
	var result := game_state.deploy_simple(side, to_play)
	if not result["ok"]:
		var msg: String = result["message"]
		_reject(sender_id, msg if msg != "" else "That card can't be played right now.")
		return
	_deployed_this_turn = true
	NetworkManager.apply_deploy_simple.rpc(card_uids)
	_update_turn_label()
	_refresh_all_piece_views()
	if hand_panel:
		hand_panel.refresh()
	_broadcast_hand_state()
	_announce_opponent_card(side, card_uids[0] if card_uids.size() > 0 else -1, "Deployed.")

func _on_deploy_applied(card_uids: Array) -> void:
	if NetworkManager.is_host():
		return
	var side := game_state.current_player
	if _card_lookup.is_empty():
		_build_card_lookup()
	var to_play: Array = []
	for uid in card_uids:
		# Look up from the canonical card database, NOT the local hand. A
		# hand-state correction can arrive first and remove the played card,
		# which would silently skip the effect and desync the two boards.
		if _card_lookup.has(uid):
			to_play.append(_card_lookup[uid])
	if to_play.size() == card_uids.size():
		game_state.deploy_simple(side, to_play)
	_deployed_this_turn = true
	_update_turn_label()
	_refresh_all_piece_views()
	_announce_opponent_card(side, card_uids[0] if card_uids.size() > 0 else -1, "Deployed.")
	if hand_panel:
		hand_panel.refresh()
		
func _respawn_croce_portrait() -> void:
	_croce_drag = false
	_croce_drag_offset = Vector2.ZERO
	if croce_portrait and is_instance_valid(croce_portrait):
		croce_portrait.free()
	croce_portrait = null
	_build_croce_portrait()

func _card_by_uid(uid: int):
	if _card_lookup.is_empty():
		_build_card_lookup()
	return _card_lookup.get(uid, null)
	
func _on_croce_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_croce_drag = true
			_croce_drag_offset = croce_portrait.global_position - event.global_position
		else:
			_croce_drag = false
	elif event is InputEventMouseMotion and _croce_drag:
		croce_portrait.global_position = event.global_position + _croce_drag_offset

func _button_label(type: Piece.Type) -> String:
	var placed := _placed_count(type)
	var total: int = REQUIRED_COUNTS[type]
	return "%s  %d/%d" % [TYPE_LABELS[type], placed, total]

func _placed_count(type: Piece.Type) -> int:
	var count := 0
	for piece in game_state.pieces.values():
		if piece.owner == current_player and piece.type == type:
			count += 1
	return count

func _build_pass_screen() -> void:
	pass_screen = CanvasLayer.new()
	pass_screen.visible = false
	add_child(pass_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_screen.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	pass_screen.add_child(vbox)

	# red-over-blue rule, centered, fixed width
	var rule := VBoxContainer.new()
	rule.add_theme_constant_override("separation", 4)
	rule.custom_minimum_size = Vector2(220, 0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rb := ColorRect.new(); rb.color = Color("#E32636"); rb.custom_minimum_size = Vector2(220, 2)
	var bb := ColorRect.new(); bb.color = Color("#4169E1"); bb.custom_minimum_size = Vector2(220, 2)
	rule.add_child(rb); rule.add_child(bb)
	vbox.add_child(rule)

	pass_label = Label.new()
	pass_label.add_theme_font_size_override("font_size", 30)
	pass_label.add_theme_color_override("font_color", Color.WHITE)
	pass_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pass_label.add_theme_constant_override("outline_size", 5)
	pass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pass_label)

	var sub := Label.new()
	sub.text = "Hand the device to the other player, then tap anywhere to begin."
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

func _show_pass_screen() -> void:
	pass_label.text = "%s's setup complete.\nPass to %s." % [RuleSettings.display_name(Piece.Owner.BLUE), RuleSettings.display_name(Piece.Owner.RED)] if current_player == Piece.Owner.BLUE \
		else "%s's setup complete.\nStarting game..." % RuleSettings.display_name(Piece.Owner.RED)
	pass_screen.visible = true

func _spawn_ghost() -> void:
	ghost = PieceGhost.new()
	ghost.piece_type = selected_type
	add_child(ghost)
	if ghost.piece_type == Piece.Type.B:
		_update_rotate_button(ghost)
	elif rotate_button:
		rotate_button.visible = false

func _on_type_selected(type: Piece.Type) -> void:
	if _placed_count(type) >= REQUIRED_COUNTS[type]:
		return
	selected_type = type
	ghost.piece_type = type
	ghost.orientation = Piece.PieceOrientation.VERTICAL
	if type == Piece.Type.B:
		_update_rotate_button(ghost)
	elif rotate_button:
		rotate_button.visible = false
	_refresh_ui()

func _broadcast_hand_state() -> void:
	if not NetworkManager.is_host():
		return
	var deck_count: int = game_state.deck.size()
	var red_uids: Array = []
	for c in game_state.hands[Piece.Owner.RED]:
		red_uids.append(c.uid)
	var blue_count: int = game_state.hands[Piece.Owner.BLUE].size()
	# Red receives its own cards plus only a COUNT of Blue's.
	for peer in multiplayer.get_peers():
		NetworkManager.receive_hand_state.rpc_id(peer, red_uids, blue_count, deck_count)
	# The host already knows everything; it just needs the count for display.
	NetworkManager.opponent_hand_count = game_state.hands[Piece.Owner.RED].size()
	_update_opponent_hand_counter()

func _on_hand_state_received(my_hand_uids: Array, opponent_count: int, deck_count: int) -> void:
	if NetworkManager.is_host():
		return
	if _card_lookup.is_empty():
		_build_card_lookup()
	var rebuilt: Array = []
	for uid in my_hand_uids:
		if _card_lookup.has(uid):
			rebuilt.append(_card_lookup[uid])
	game_state.hands[NetworkManager.my_side()] = rebuilt
	NetworkManager.opponent_hand_count = opponent_count
	if hand_panel:
		hand_panel.refresh()
		_update_opponent_hand_counter()

func _build_card_lookup() -> void:
	_card_lookup.clear()
	for c in CardDatabase.build_full_deck():
		_card_lookup[c.uid] = c

func _build_opponent_hand_counter(layer: CanvasLayer) -> void:
	if not NetworkManager.is_networked() and cpu == null:
		return
	var hidden_side: int = cpu.side if cpu != null else (1 - NetworkManager.my_side())
	var back_tex: Texture2D = TextureManager.card_back(hidden_side)
	if back_tex == null:
		return
	# Anchored at End Turn's own top-left (12, 76) so every child below is
	# positioned relative to the real button, not guessed absolute numbers.
	opponent_count_root = Control.new()
	opponent_count_root.position = Vector2(12, 76)
	opponent_count_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(opponent_count_root)

	var icon_x := 235.0 - OPP_BACK_W   # right edge of icon lands at 255 = button's own width
	var icon_y := 40.0 + OPP_LABEL_GAP # just below the button's 40px height

	var back := TextureRect.new()
	back.texture = back_tex
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.size = Vector2(OPP_BACK_W, OPP_BACK_H)
	back.position = Vector2(icon_x, icon_y)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opponent_count_root.add_child(back)

	opponent_count_label = Label.new()
	opponent_count_label.add_theme_font_size_override("font_size", 26)
	opponent_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	opponent_count_label.add_theme_constant_override("outline_size", 5)
	opponent_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opponent_count_label.position = Vector2(icon_x + OPP_BACK_W - 14.0, icon_y + OPP_BACK_H * 0.5 - 18.0)
	opponent_count_root.add_child(opponent_count_label)

	opponent_hand_title = Label.new()
	opponent_hand_title.text = "Opponent's\nCard Hand"
	opponent_hand_title.add_theme_font_size_override("font_size", 14)
	opponent_hand_title.add_theme_color_override("font_color", Color.WHITE)
	opponent_hand_title.add_theme_color_override("font_outline_color", Color("#141414") )
	opponent_hand_title.add_theme_constant_override("outline_size", 3)
	opponent_hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opponent_hand_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opponent_hand_title.position = Vector2(0, icon_y)
	opponent_hand_title.size = Vector2(icon_x - OPP_LABEL_GAP, OPP_BACK_H)
	opponent_count_root.add_child(opponent_hand_title)

	_update_opponent_hand_counter()

func _update_opponent_hand_counter() -> void:
	if opponent_count_label == null:
		return
	if cpu != null:
		NetworkManager.opponent_hand_count = game_state.hands[cpu.side].size()
	var opponent_is_blue: bool = (cpu.side == Piece.Owner.BLUE) if cpu != null \
		else (NetworkManager.my_side() != Piece.Owner.BLUE)
	var col: Color = RuleSettings.COLOR_HEX[
		RuleSettings.side_one_color if opponent_is_blue else RuleSettings.side_two_color]
	opponent_count_label.text = "×%d" % NetworkManager.opponent_hand_count
	opponent_count_label.add_theme_color_override("font_color", col)
	var limit: int = hand_panel.HAND_LIMIT if hand_panel else 9
	_set_opponent_count_pulse(NetworkManager.opponent_hand_count == limit)
	
func _in_deployment_zone(cell: Vector2i, owner: Piece.Owner) -> bool:
	if owner == Piece.Owner.BLUE:
		return cell.y >= 0 and cell.y <= 4
	else:
		return cell.y >= 11 and cell.y <= 15

# A player's whole half of the board: Blue owns the top 8 rows, Red the bottom 8.
func _in_own_half(cell: Vector2i, owner: Piece.Owner) -> bool:
	if owner == Piece.Owner.BLUE:
		return cell.y >= 0 and cell.y <= 7
	else:
		return cell.y >= 8 and cell.y <= 15

# Where an ITYD-returned piece may legally land. Base rule restricts it to the
# Croce deployment band; the house rule (ityd_deployment_zone_only == false)
# opens it up to the player's entire half. Reads the RuleSettings autoload;
# defaults to the base rule if the autoload isn't present.
func _in_ityd_zone(cell: Vector2i, owner: Piece.Owner) -> bool:
	var zone_only := true
	var rs = get_node_or_null("/root/RuleSettings")
	if rs and "ityd_deployment_zone_only" in rs:
		zone_only = rs.ityd_deployment_zone_only
	if zone_only:
		return _in_deployment_zone(cell, owner)
	return _in_own_half(cell, owner)

func _refresh_ui() -> void:
	var is_blue := current_player == Piece.Owner.BLUE
	status_label.text = "%s's Pieces" % (RuleSettings.display_name(Piece.Owner.BLUE) if is_blue else RuleSettings.display_name(Piece.Owner.RED))
	status_label.add_theme_color_override("font_color",
		RuleSettings.COLOR_HEX[RuleSettings.side_one_color] if is_blue else RuleSettings.COLOR_HEX[RuleSettings.side_two_color])
	for type in PIECE_ORDER:
		type_buttons[type].text = _button_label(type)
		type_buttons[type].disabled = _placed_count(type) >= REQUIRED_COUNTS[type]

func _b_new_cells_for_dest(piece: Piece, swung_cell: Vector2i) -> Array[Vector2i]:
	return RulesEngine.b_new_cells_for_dest(piece, swung_cell)
	
func _input(event: InputEvent) -> void:
	if not _ready_finished:
		return
	if event is InputEventMouseButton and event.pressed and (move_ripple or not _capture_ripples.is_empty()):
		_dismiss_move_ripple()
	if chat_overlay and chat_overlay.is_aiming():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				chat_overlay.consume_aim_click()  # cancel, discard
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				var id: String = chat_overlay.consume_aim_click()
				if id != "":
					_on_sticker_placement_requested(id)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			chat_overlay.consume_aim_click()
			get_viewport().set_input_as_handled()
			return
		return
	if chat_overlay and chat_overlay.is_capturing():
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			chat_overlay.set_open(false)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed \
				and not chat_overlay.contains_point(event.position):
			chat_overlay.unfocus()
			get_viewport().set_input_as_handled()
		return
	if chat_overlay and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_T:
		chat_overlay.toggle_open()
		get_viewport().set_input_as_handled()
		return
	if chat_overlay and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_MIDDLE:
		chat_overlay.toggle_open()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		return
	# Game's over - the win screen is up; ignore all board input.
	if _game_over:
		return
	# While the hand is over the limit, the player must discard down to 9 before
	# doing anything else. The hand panel handles its own card clicks; block board input.
	if hand_panel and hand_panel.is_discard_mode():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_debug_skip_croce()
			return
		if event.keycode == KEY_F2 and not in_croce:
			debug_saboteur_armed = true
			print("DEBUG: click an opponent piece to convert it to Saboteur")
			return
		if event.keycode == KEY_F3 and not in_croce:
			_debug_reverse_saboteur()
			return
		if event.keycode == KEY_F4 and not in_croce:
			debug_hand_builder.toggle()
			return
		if event.keycode == KEY_ENTER and not in_croce:
			if end_turn_button and not end_turn_button.disabled:
				_on_end_turn_pressed()
			return
		if event.keycode == KEY_F5 and not in_croce:
			_debug_stage_captures()
			return
		if event.keycode == KEY_F6 and not in_croce:
			_cpu_toggle()
			return
		if event.keycode == KEY_G and not in_croce:
			_debug_give_cpu_ityd()
			return
		if event.keycode == KEY_O and not in_croce:
			_debug_give_cpu_card(Card.Category.MAJOR_POWER, Card.MajorEffect.ONE_MAN_ARMY)
			return
		if event.keycode == KEY_J and not in_croce:
			_debug_give_cpu_card(Card.Category.MAJOR_POWER, Card.MajorEffect.JUST_THIS_ONCE)
			return
		if event.keycode == KEY_P and not in_croce:
			_debug_dump_pieces()
			return
	if in_croce:
		if pass_screen.visible:
			if event is InputEventMouseButton and event.pressed:
				_advance_player()
			return
		if _network_placement_done:
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				ghost.toggle_orientation()
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_try_place()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_try_undo_place()
	else:
		_handle_turn_input(event)
var _pause_menu: PauseMenu = null


func _toggle_pause_menu() -> void:
	if _pause_menu:
		return  # already open - Resume/buttons handle closing, ESC doesn't toggle-close
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(_close_pause_menu)
	_pause_menu.return_to_menu.connect(_on_pause_return_to_menu)
	_pause_menu.board_flip_requested.connect(_on_pause_flip_board)
	_pause_menu.quit_to_desktop.connect(_on_pause_quit)
	_pause_menu.forfeited.connect(_on_pause_forfeit)
	get_tree().paused = true
	MusicManager.suspend_rotation_for_menu()

func _side_has_legal_move(side: Piece.Owner) -> bool:
	for piece in game_state.pieces.values():
		if piece.owner != side:
			continue
		if game_state.piece_can_move(piece):
			return true
	return false
	
func _on_pause_forfeit() -> void:
	_close_pause_menu()
	if NetworkManager.is_networked():
		NetworkManager.request_forfeit.rpc_id(1)
		return
	var winner: Piece.Owner = Piece.Owner.RED if game_state.current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	_show_win_screen(winner)
	
func _on_pause_flip_board() -> void:
	BoardView.flipped = not BoardView.flipped
	_refresh_board_view()

func _refresh_board_view() -> void:
	get_node("Board").refresh_colors()
	for child in piece_layer.get_children():
		if child is PieceView:
			child.refresh_position()
	if selected_piece:
		_show_highlights(selected_piece)
		
func _close_pause_menu() -> void:
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null
		MusicManager.resume_rotation_after_menu()


func _on_pause_return_to_menu() -> void:
	get_tree().paused = false
	_leave_network_match()
	MusicManager.return_to_menu_music()
	get_tree().change_scene_to_file("res://scenes/menu_root.tscn")
	

func _on_forfeit_requested(sender_id: int) -> void:
	if not NetworkManager.is_host():
		return
	# The winner is the opponent of whoever forfeited — NOT the opponent of
	# current_player, since the passive player can forfeit on someone else's turn.
	var forfeiter := Piece.Owner.BLUE if sender_id == 1 else Piece.Owner.RED
	var winner := Piece.Owner.RED if forfeiter == Piece.Owner.BLUE else Piece.Owner.BLUE
	NetworkManager.broadcast_match_end.rpc(int(winner), "forfeit")

func _on_match_ended(winner: int, _reason: String) -> void:
	if _game_over:
		return
	_game_over = true
	_show_win_screen(winner)

func _on_opponent_left() -> void:
	if _game_over:
		return
	_game_over = true
	if NetworkManager.is_host():
		# The joining player left — host wins by default.
		_show_win_screen(NetworkManager.my_side())
	else:
		# The host ended the match. Not a victory, just an ending.
		_show_match_ended_notice("The host has ended the match.")

func _show_match_ended_notice(message: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)

	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	col.add_child(lbl)

	var btn := Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(280, 50)
	btn.pressed.connect(_on_return_to_main_menu_pressed)
	col.add_child(btn)

	box.add_child(col)
	center.add_child(box)
	
func _on_player_disconnected(_id: int) -> void:
	_on_opponent_left()
	
func _on_pause_quit() -> void:
	SfxManager.play("quit")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

func _try_place() -> void:
	var cells := ghost.get_cells()
	for cell in cells:
		if not _in_deployment_zone(cell, current_player):
			ghost.valid = false
			return
	var p := Piece.new()
	p.uid = next_uid
	p.type = selected_type
	p.owner = current_player
	p.cells = cells
	if selected_type == Piece.Type.B:
		p.orientation = ghost.orientation
	p.designation = _next_designation()
	if not CroceSetup.can_place_piece(p, cells, game_state):
		ghost.valid = false
		return
	CroceSetup.place_piece(p, cells, game_state)
	SfxManager.play("croce_place")
	next_uid += 1
	var view := PieceView.new()
	piece_layer.add_child(view)
	view.setup(p)
	_advance_selection()
	_sync_rotate_button()
	_refresh_ui()

func _next_designation() -> String:
	match selected_type:
		Piece.Type.GENERAL:
			return "General"
		Piece.Type.OBJECTIVE:
			return "Objective"
		_:
			var used: Dictionary = {}
			for piece in game_state.pieces.values():
				if piece.owner == current_player and piece.type == selected_type:
					used[piece.designation] = true
			var label: String = TYPE_LABELS[selected_type]
			var n: int = 1
			while used.has("%s%d" % [label, n]):
				n += 1
			return "%s%d" % [label, n]

func _try_undo_place() -> void:
	var grid: Vector2i = _mouse_to_grid()
	var target: Piece = null
	for piece in game_state.pieces.values():
		if piece.owner != current_player:
			continue
		if piece.cells.has(grid):
			target = piece
			break
	if target == null:
		return
	var freed_type: Piece.Type = target.type
	var freed_orientation: Piece.PieceOrientation = target.orientation
	_remove_piece_view(target)
	game_state.pieces.erase(target.uid)
	SfxManager.play("croce_place")
	selected_type = freed_type
	ghost.piece_type = freed_type
	if freed_type == Piece.Type.B:
		ghost.orientation = freed_orientation
		_update_rotate_button(ghost)
	elif rotate_button:
		rotate_button.visible = false
	_refresh_ui()

func _sync_rotate_button() -> void:
	# Show the rotate button whenever a B is the active selection during Croce,
	# hide it otherwise. Safe to call any time.
	if in_croce and selected_type == Piece.Type.B and ghost:
		_update_rotate_button(ghost)
	elif rotate_button:
		rotate_button.visible = false

func _advance_selection() -> void:
	if _placed_count(selected_type) >= REQUIRED_COUNTS[selected_type]:
		for type in PIECE_ORDER:
			if _placed_count(type) < REQUIRED_COUNTS[type]:
				_on_type_selected(type)
				return
		if NetworkManager.is_networked():
			status_label.text = "Waiting for the other player..."
			_network_placement_done = true
			NetworkManager.submit_croce_placement.rpc_id(1, _collect_my_croce_pieces())
		else:
			_show_pass_screen()

func _collect_my_croce_pieces() -> Array:
	var out: Array = []
	for piece in game_state.pieces.values():
		if piece.owner != current_player:
			continue
		out.append({
			"designation": piece.designation,
			"type": piece.type,
			"owner": piece.owner,
			"cells": piece.cells,
			"orientation": piece.orientation,
		})
	return out
	
func _advance_player() -> void:
	pass_screen.visible = false
	if current_player == Piece.Owner.BLUE:
		# Against the CPU there is no handoff: it places from the repertoire
		# and we go straight to the game.
		if cpu != null and cpu.side == Piece.Owner.RED:
			_cpu_place_croce(Piece.Owner.RED)
			_finish_croce()
			return
		current_player = Piece.Owner.RED
		selected_type = Piece.Type.A
		ghost.piece_type = Piece.Type.A
		ghost.orientation = Piece.PieceOrientation.VERTICAL
		_refresh_ui()
		_hide_pieces_owned_by(Piece.Owner.BLUE)
		# Respawn the Croce portrait on the blue half for Red's setup. Remove the
		# old (possibly dragged) instance immediately so its position cannot carry
		# across the handoff or overlap the replacement for one frame.
		_respawn_croce_portrait()
	else:
		_finish_croce()

func _finish_croce() -> void:
	if ghost:
		ghost.queue_free()
	if ui_layer:
		ui_layer.queue_free()
	_teardown_croce_ui()
	game_state.initialize_deck()
	ReplayRecorder.start_match(game_state, "cpu" if cpu != null else "hotseat", Piece.Owner.BLUE)
	in_croce = false
	piece_layer.visible = true
	_reveal_all_pieces()
	_build_turn_ui()
	MusicManager.begin_gameplay_rotation()
	print("Setup complete - game begins.")

# Places the CPU's army from Noah's repertoire, picking an opening at random.
func _cpu_place_croce(owner: Piece.Owner) -> void:
	var opening := CroceOpenings.random_name()
	var fault := CroceOpenings.validate(opening, owner)
	if fault != "":
		push_error("Croce opening '%s' invalid: %s — falling back." % [opening, fault])
		_auto_place_army(owner)
		return

	for e in CroceOpenings.entries_for(opening, owner):
		var designation: String = e[0]
		var p := Piece.new()
		p.uid = next_uid
		next_uid += 1
		p.type = CroceOpenings.type_for(designation)
		p.owner = owner
		p.designation = designation
		if p.type == Piece.Type.B:
			p.orientation = Piece.PieceOrientation.VERTICAL if e[3] == "V" else Piece.PieceOrientation.HORIZONTAL
		p.cells = CroceOpenings.cells_for(designation, e[1], e[2], e[3])
		game_state.pieces[p.uid] = p
		# _reveal_all_pieces() only unhides existing views — it doesn't build
		# them. During normal Croce _try_place() creates each view as it goes,
		# so pieces placed straight into game_state need one made here.
		var view := PieceView.new()
		piece_layer.add_child(view)
		view.setup(p)
	print("CPU Croce: %s" % opening)

func begin_saboteur_targeting(type_card: Card, chart_card: Card, chosen_type: Piece.Type) -> bool:
	var designation := RulesEngine.designation_from_cards(type_card, chart_card, chosen_type)
	if designation == "":
		return false
	if not RulesEngine.can_declare_saboteur(game_state.current_player, game_state):
		SfxManager.play("illegal")
		hand_panel.show_status("You already have an active Saboteur.")
		return false
	var opponent := Piece.Owner.RED if game_state.current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	var target := game_state._find_piece_by_designation(designation, opponent)
	if target == null:
		SfxManager.play("illegal")
		hand_panel.show_status("No opponent %s in play to convert." % designation)
		return false
	# Enter targeting mode
	_deselect()
	saboteur_targeting = true
	saboteur_target_piece = target
	saboteur_type_card = type_card
	saboteur_chart_card = chart_card
	saboteur_chosen_type = chosen_type
	# Pulse the target piece (green = state 2)
	var view := _find_view(target)
	print(">>> SABOTEUR TARGET ", target.designation, " view=", view)
	if view:
		view.set_outline_width(6.0)   # thicker outline so the target really stands out
		view.set_saboteur_pulse(true)
	hand_panel.show_status("Click the pulsing %s to convert it (right-click to cancel)." % designation)
	SfxManager.play("declare_saboteur_card")
	return true

func _cancel_saboteur_targeting() -> void:
	if saboteur_target_piece:
		var view := _find_view(saboteur_target_piece)
		if view:
			view.set_saboteur_pulse(false)
			view.set_state(0)
			view.set_outline_width(2.0)
	saboteur_targeting = false
	saboteur_target_piece = null
	saboteur_type_card = null
	saboteur_chart_card = null
	hand_panel.restore_deploy_card()
	set_turn_timer_paused(false)

# Pulses every piece the player could convert, one per selectable type on the
# card, while the "Declare as" picker is open. Presentation only — nothing is
# committed until a type is chosen. Types with no live target simply don't
# pulse, which is the point: you can see which choices are real.
func preview_saboteur_candidates(type_card: Card, chart_card: Card) -> void:
	clear_saboteur_preview()
	if type_card == null or chart_card == null:
		return
	var opponent := Piece.Owner.RED if game_state.current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	for t in type_card.piece_types:
		var designation := RulesEngine.designation_from_cards(type_card, chart_card, t)
		if designation == "":
			continue
		var target := game_state._find_piece_by_designation(designation, opponent)
		if target == null:
			continue
		var view := _find_view(target)
		if view:
			view.set_outline_width(5.0)
			view.set_saboteur_pulse(true)
			_sab_preview_views.append(view)

func clear_saboteur_preview() -> void:
	for v in _sab_preview_views:
		if v and is_instance_valid(v):
			v.set_saboteur_pulse(false)
			v.set_state(0)
			v.set_outline_width(2.0)
	_sab_preview_views.clear()
	
func _confirm_saboteur() -> void:
	if NetworkManager.is_networked():
		if saboteur_type_card == null or saboteur_chart_card == null or saboteur_target_piece == null:
			return
		NetworkManager.request_saboteur.rpc_id(1,
			saboteur_type_card.uid, saboteur_chart_card.uid,
			int(saboteur_chosen_type), saboteur_target_piece.uid)
		return
	var ok := game_state.declare_saboteur(
		game_state.current_player,
		saboteur_type_card,
		saboteur_chart_card,
		saboteur_chosen_type
	)
	var target := saboteur_target_piece
	# clear targeting state before refresh
	saboteur_targeting = false
	saboteur_target_piece = null
	saboteur_type_card = null
	saboteur_chart_card = null
	if ok:
		SfxManager.play("saboteur_transform")
		_refresh_all_piece_views()
		if captured_tray:
			captured_tray.refresh()
		hand_panel.refresh()
		hand_panel.show_status("Saboteur declared!")
		_deployed_this_turn = true
		_update_turn_label()
	else:
		SfxManager.play("illegal")
		var view := _find_view(target)
		if view:
			view.set_saboteur_pulse(false)
			view.set_state(0)
		hand_panel.restore_deploy_card()
		set_turn_timer_paused(false)
		hand_panel.show_status("Saboteur declaration failed.")

func begin_ityd(card) -> void:
	print(">>> begin_ityd called, required_type=", card.effect_piece_type)
	ityd_card = card
	ityd_required_type = card.effect_piece_type
	ityd_selecting = true
	ityd_placing = false
	ityd_piece = null
	hand_panel.show_status("Click one of your captured pieces to redeploy (right-click to cancel).")

func begin_just_this_once(card) -> void:
	if game_state.objective_has_moved.get(game_state.current_player, false):
		hand_panel.show_status("The Objective has already moved this game.")
		return
	jto_active = true
	jto_card = card
	_deselect()
	_show_jto_highlights()
	hand_panel.show_status("Click a destination for your Objective (right-click to cancel).")

func _show_jto_highlights() -> void:
	_clear_highlights()
	var objective := _find_own_objective()
	if objective == null:
		return
	var from: Vector2i = objective.cells[0]
	for to in _legal_jto_destinations(from):
		var h := MoveHighlight.new()
		h.dest_cell = to
		h.origin_cell = to
		h.highlight_color = RuleSettings.ghost_frame_color()
		h.dims = Vector2i(1, 1)
		h.position = BoardView.grid_to_world(to)
		piece_layer.add_child(h)
		highlights.append(h)

func _legal_jto_destinations(from: Vector2i) -> Array:
	var result: Array = []
	var player := game_state.current_player
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for dir in dirs:
		for dist in range(1, 4):
			var to: Vector2i = from + dir * dist
			if game_state._is_legal_objective_move(from, to, player):
				result.append(to)
	return result

func _find_own_objective() -> Piece:
	for piece in game_state.pieces.values():
		if piece.type == Piece.Type.OBJECTIVE and piece.owner == game_state.current_player:
			return piece
	return null

func _cancel_jto() -> void:
	jto_active = false
	jto_card = null
	_clear_highlights()
	hand_panel.restore_deploy_card()
	set_turn_timer_paused(false)
	hand_panel.show_status("Objective move cancelled.")

func _try_jto_place(grid: Vector2i) -> void:
	if NetworkManager.is_networked():
		if jto_card == null:
			return
		NetworkManager.request_jto.rpc_id(1, jto_card.uid, grid)
		return
	var ok := game_state.apply_just_this_once(game_state.current_player, grid)
	if not ok:
		SfxManager.play("illegal")
		return
	SfxManager.play("jto_objmove")
	game_state.discard_card(game_state.current_player, jto_card)
	jto_active = false
	jto_card = null
	_clear_highlights()
	_refresh_all_piece_views()
	_deployed_this_turn = true
	_update_turn_label()
	hand_panel.refresh()
	hand_panel.show_status("Objective moved.")
	
func _announce_card_play(acting_side: Piece.Owner, own_msg: String, opponent_msg: String) -> void:
	if hand_panel == null:
		return
	if not NetworkManager.is_networked() or acting_side == NetworkManager.my_side():
		hand_panel.announce(own_msg)
	else:
		hand_panel.announce(opponent_msg)
		
func _announce_opponent_card(acting_side: Piece.Owner, card_uid: int, own_msg: String) -> void:
	if hand_panel == null:
		return
	if not NetworkManager.is_networked() or acting_side == NetworkManager.my_side():
		hand_panel.announce(own_msg)
		return
	if _card_lookup.is_empty():
		_build_card_lookup()
	if _card_lookup.has(card_uid):
		hand_panel.reveal_opponent_card(_card_lookup[card_uid], "Opponent played a card.")
	else:
		hand_panel.announce("Opponent played a card.")
		
func _debug_try_convert_saboteur(grid: Vector2i) -> void:
	debug_saboteur_armed = false
	var opponent := Piece.Owner.RED if game_state.current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	for piece in game_state.pieces.values():
		if piece.owner != opponent:
			continue
		if piece.cells.has(grid):
			piece.apply_saboteur_conversion(game_state.current_player)
			_refresh_piece_view(piece)
			print("DEBUG: %s converted to Saboteur - now controlled by %s" % [
				piece.designation,
				"BLUE" if game_state.current_player == Piece.Owner.BLUE else "RED"
			])
			return
	print("DEBUG: no opponent piece at that cell - conversion cancelled")

func _debug_reverse_saboteur() -> void:
	var opponent := Piece.Owner.RED if game_state.current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	for piece in game_state.pieces.values():
		if piece.owner == opponent and piece.has_status("saboteur"):
			piece.reverse_saboteur_conversion(game_state.current_player)
			_refresh_piece_view(piece)
			print("DEBUG: %s Saboteur conversion reversed" % piece.designation)
			return
	print("DEBUG: no active Saboteur to reverse")

func _refresh_piece_view(piece: Piece) -> void:
	_remove_piece_view(piece)
	var view := PieceView.new()
	piece_layer.add_child(view)
	view.setup(piece)

func _hide_pieces_owned_by(owner: Piece.Owner) -> void:
	for child in piece_layer.get_children():
		if child is PieceView and child.piece.owner == owner:
			child.visible = false

func _reveal_all_pieces() -> void:
	for child in piece_layer.get_children():
		child.visible = true
		
func _handle_turn_input(event: InputEvent) -> void:
	if debug_hand_builder and debug_hand_builder.visible:
		return
	# Saboteur targeting mode intercepts all board input
	if saboteur_targeting:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_saboteur_targeting()
				hand_panel.show_status("Saboteur declaration cancelled.")
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				var grid := _mouse_to_grid()
				if saboteur_target_piece and saboteur_target_piece.cells.has(grid):
					_confirm_saboteur()
				# clicking elsewhere does nothing (stay in targeting)
		return	
	# Just This Once - click a highlighted Objective destination
	if jto_active:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_jto()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_try_jto_place(_mouse_to_grid())
		return
	# ITYD placement phase - ghost self-tracks the mouse; click to place
	if ityd_placing:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R and ityd_piece.type == Piece.Type.B:
				ityd_ghost.toggle_orientation()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_ityd()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_try_ityd_place()
		return
	# ITYD selecting phase - waiting for a tray click; right-click cancels
	if ityd_selecting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_ityd()
		return
	if event is InputEventMouseButton and event.pressed:
		var grid := _mouse_to_grid()
		if debug_saboteur_armed and event.button_index == MOUSE_BUTTON_LEFT:
			_debug_try_convert_saboteur(grid)
			return
		if debug_saboteur_armed and event.button_index == MOUSE_BUTTON_RIGHT:
			debug_saboteur_armed = false
			print("DEBUG: Saboteur conversion cancelled")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_deselect()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if selected_piece == null:
				_try_select(grid)
			else:
				# Clicking own piece's cells deselects rather than executing a move
				if selected_piece.cells.has(grid):
					_deselect()
					return
				var dest := _highlight_at(grid)
				if dest != Vector2i(-1, -1):
					if NetworkManager.is_networked():
						NetworkManager.request_move.rpc_id(1, selected_piece.uid, dest)
					else:
						_execute_move(dest)
				else:
					_deselect()
					_try_select(grid)

func _try_ityd_place() -> void:
	var cells := ityd_ghost.get_cells()
	for cell in cells:
		if not _in_ityd_zone(cell, game_state.current_player):
			ityd_ghost.valid = false
			return
	if NetworkManager.is_networked():
		if ityd_card == null or ityd_piece == null:
			return
		NetworkManager.request_ityd.rpc_id(1, ityd_card.uid, ityd_piece.uid, cells, ityd_ghost.orientation)
		return
	var ok := game_state.apply_i_thought_you_were_dead(
		game_state.current_player, ityd_piece.uid, cells, ityd_ghost.orientation
	)
	if not ok:
		ityd_ghost.valid = false
		return
	SfxManager.play("croce_place")
	game_state.discard_card(game_state.current_player, ityd_card)
	_finish_ityd_local()
	hand_panel.show_status("Piece redeployed!")
	_deployed_this_turn = true
	if rotate_button:
		rotate_button.visible = false
	_update_turn_label()
	
func _mouse_to_grid() -> Vector2i:
	return BoardView.world_to_grid(get_global_mouse_position())

# --- Placed-sticker (taunt-on-board) support. Purely cosmetic. ---

func _on_sticker_placement_requested(sticker_id: String) -> void:
	# The overlay has entered "click the board" mode. Snap the click to the
	# nearest cell and send that cell — never raw pixels, so it lands in the
	# same board spot on the opponent's differently-sized window.
	var cell := _mouse_to_grid()
	cell.x = clamp(cell.x, 0, 17)
	cell.y = clamp(cell.y, 0, 15)
	ChatManager.send_placed_sticker(sticker_id, cell)

func _on_placed_sticker_received(_side: int, sticker_id: String, cell: Vector2i) -> void:
	var world := BoardView.grid_to_world_center(cell)
	if sticker_id == "jim":
		_spawn_croce_wash()
	_spawn_board_sticker(sticker_id, world)

func _spawn_board_sticker(sticker_id: String, world_pos: Vector2) -> void:
	var tex: Texture2D = StickerLibrary.texture_for(sticker_id)
	var node: Node2D
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		var longest: float = max(tex.get_width(), tex.get_height())
		if longest > 0:
			s.scale = Vector2.ONE * (180.0 / longest)
		node = s
	else:
		var lbl := Label.new()
		lbl.text = StickerLibrary.label_for(sticker_id)
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color("#141414"))
		lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.position = -Vector2(60, 18)
		node = Node2D.new()
		node.add_child(lbl)
	node.position = world_pos
	node.z_index = 200
	add_child(node)

	node.modulate.a = 0.0
	node.scale *= 0.8
	var base_scale := node.scale
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.18)
	tw.tween_property(node, "scale", base_scale / 0.8, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(1.6)
	tw.tween_property(node, "modulate:a", 0.0, 0.5)
	tw.tween_callback(node.queue_free)

func _spawn_croce_wash() -> void:
	var tex_path := "res://assets/ui/croce.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex = load(tex_path)
	if tex == null:
		return

	var wash := Sprite2D.new()
	wash.texture = tex
	wash.centered = true
	# Center of the board. Invariant under a 180 degree flip, so no conversion
	# needed — but sourced from BoardView so a board-size change can't strand it.
	wash.position = BoardView.BOARD_ORIGIN + Vector2(
		BoardView.board_width * BoardView.CELL * 0.5,
		BoardView.board_height * BoardView.CELL * 0.5
	)
	# Blow it up to cover the whole board, comically oversized.
	var board_w := float(BoardView.board_width) * BoardView.CELL
	var longest: float = max(tex.get_width(), tex.get_height())
	if longest > 0:
		wash.scale = Vector2.ONE * (board_w * 1.25 / longest)
	# Behind the pieces (piece_layer sits above this Node2D's default children),
	# but the very faint alpha means it never fights the board anyway.
	wash.z_index = 1
	piece_layer.z_index = 5
	wash.modulate = Color(1, 1, 1, 0.0)
	add_child(wash)

	# Slow breathe: up to a barely-there peak, hold a moment, back down.
	var peak := 0.2
	var tw := create_tween()
	tw.tween_property(wash, "modulate:a", peak, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(wash, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(wash.queue_free)
	
func _try_select(grid: Vector2i) -> void:
	if NetworkManager.is_networked() and game_state.current_player != NetworkManager.my_side():
		return
	if cpu != null and game_state.current_player == cpu.side:
		return
	for piece in game_state.pieces.values():
		if piece.owner != game_state.current_player:
			continue
		if piece.cells.has(grid):
			var view := _find_view(piece)
			if view:
				_select_piece(piece, view)
			return

func _select_piece(piece: Piece, view: PieceView) -> void:
	selected_piece = piece
	selected_view = view
	view.set_state(1)
	view.set_selection_pulse(true)
	if game_state.piece_can_move(piece):
		_show_highlights(piece)
	if NetworkManager.is_networked():
		NetworkManager.broadcast_selection.rpc(piece.uid)

func _deselect() -> void:
	if selected_view:
		selected_view.set_state(0)
		selected_view.set_selection_pulse(false)
	selected_piece = null
	selected_view = null
	_clear_highlights()
	if NetworkManager.is_networked():
		NetworkManager.broadcast_selection.rpc(-1)

func _show_highlights(piece: Piece) -> void:
	_clear_highlights()
	# Legality now lives in RulesEngine.legal_destinations_for(). This function
	# is presentation only: it turns approved destinations into MoveHighlight nodes.
	for dest in RulesEngine.legal_destinations_for(piece, game_state):
		var h := MoveHighlight.new()
		h.dest_cell = dest
		h.highlight_color = RuleSettings.ghost_frame_color()
		if piece.type == Piece.Type.B:
			var dest_cells := _b_new_cells_for_dest(piece, dest)
			var new_cell := dest_cells[0]
			for dc in dest_cells:
				if not piece.cells.has(dc):
					new_cell = dc
					break
			h.dims = Vector2i(2, 1) if dest_cells[0].y == dest_cells[1].y else Vector2i(1, 2)
			h.origin_cell = Vector2i(
				mini(dest_cells[0].x, dest_cells[1].x),
				mini(dest_cells[0].y, dest_cells[1].y)
			)
			h.position = BoardView.cells_to_world(dest_cells)
			var is_slide := piece.cells.has(dest_cells[0]) or piece.cells.has(dest_cells[1])
			if is_slide:
				h.dims = Vector2i(1, 1)
				h.origin_cell = new_cell
				h.position = BoardView.grid_to_world(new_cell)
		else:
			h.dims = _piece_dims(piece)
			h.origin_cell = dest
			h.position = BoardView.cells_to_world(RulesEngine.cells_at(piece, dest))
		piece_layer.add_child(h)
		highlights.append(h)
		
func _clear_highlights() -> void:
	for h in highlights:
		h.queue_free()
	highlights.clear()

func _highlight_at(grid: Vector2i) -> Vector2i:
	# First pass: exact match on dest_cell - unambiguous for overlapping highlights
	for h in highlights:
		if h.dest_cell == grid:
			return h.dest_cell
	# Second pass: any overlap. Walks cell space from origin_cell rather than
	# converting position back to a cell, which would be wrong under a flip.
	for h in highlights:
		var dims: Vector2i = h.dims
		for r in range(dims.y):
			for c in range(dims.x):
				if h.origin_cell + Vector2i(c, r) == grid:
					return h.dest_cell
	return Vector2i(-1, -1)

func _execute_move(destination: Vector2i) -> void:
	_moved_piece = selected_piece
	var new_cells: Array[Vector2i]
	if selected_piece.type == Piece.Type.B:
		new_cells = _b_new_cells_for_dest(selected_piece, destination)
	else:
		new_cells = _cells_at(selected_piece, destination)
	# Recorded here rather than in _apply_movement, which runs after capture
	# resolution and is skipped entirely when the mover dies in a mutual
	# destroy — so capturing moves came out inverted and suicidal ones vanished.
	ReplayRecorder.record({
		"t": "move",
		"by": int(selected_piece.owner),
		"p": selected_piece.uid,
		"from": ReplayRecorder.cells_to_array(selected_piece.cells),
		"to": ReplayRecorder.cells_to_array(new_cells),
	})
	# Collect all overlapping opponent pieces
	var targets: Array = []
	for piece in game_state.pieces.values():
		if piece.uid == selected_piece.uid:
			continue
		if piece.owner == selected_piece.owner and not game_state.can_capture_own_piece:
			continue
		for cell in piece.cells:
			if new_cells.has(cell):
				targets.append(piece)
				break

	if targets.is_empty():
		match selected_piece.type:
			Piece.Type.A: SfxManager.play("move_a")
			Piece.Type.B: SfxManager.play("move_b")
			Piece.Type.C: SfxManager.play("move_c")
			Piece.Type.GENERAL: SfxManager.play("gen_move")
		_apply_movement(new_cells)
		_deselect()
		_check_win()
		_after_move()
		return

	if targets.size() == 1:
		var target: Piece = targets[0]
		var result := game_state.resolve_capture_with_effects(selected_piece, target)
		match result:
			RulesEngine.CaptureResult.ILLEGAL:
					SfxManager.play("illegal")
					_deselect()
					return
			RulesEngine.CaptureResult.CAPTURED:
					SfxManager.play_capture_full(selected_piece, target, game_state)
					_spawn_capture_burst(target)
					var was_objective: bool = target.type == Piece.Type.OBJECTIVE
					_remove_piece_view(target)
					game_state.capture_piece(target.uid)
					if not was_objective:
						game_state.resolve_capture_draws(result, selected_piece.owner, target.owner)
					_apply_movement(new_cells)
			RulesEngine.CaptureResult.MUTUAL_DESTROY:
					SfxManager.play_mutual()
					game_state.resolve_capture_draws(result, selected_piece.owner, target.owner)
					_spawn_capture_burst(target)
					_spawn_capture_burst(selected_piece)
					_remove_piece_view(target)
					game_state.capture_piece(target.uid)
					_remove_piece_view(selected_piece)
					game_state.capture_piece(selected_piece.uid)
					_deselect()
					_check_win()
					_after_move()
					return
		_deselect()
		_check_win()
		_after_move()
		return

	# Multi-target (C piece overlapping multiple opponents)
	var close_call_type := selected_piece.type
	var shield_all := game_state.close_call_active.has(close_call_type) and \
					  game_state.rules.close_call_shields_all_simultaneous_mutuals
	var attacker_destroyed := false
	var draw_already_resolved := false

	for target in targets:
		var base := RulesEngine.resolve_capture(selected_piece, target)
		var result := base

		if base == RulesEngine.CaptureResult.MUTUAL_DESTROY:
			if game_state.close_call_active.has(close_call_type):
				result = RulesEngine.CaptureResult.CAPTURED
				if not shield_all:
					game_state.close_call_active.erase(close_call_type)

		if result == RulesEngine.CaptureResult.ILLEGAL:
			continue

		if result == RulesEngine.CaptureResult.MUTUAL_DESTROY:
			SfxManager.play_mutual()
		else:
			SfxManager.play_capture_full(selected_piece, target, game_state)

		_spawn_capture_burst(target)
		_remove_piece_view(target)
		var target_was_objective: bool = target.type == Piece.Type.OBJECTIVE
		game_state.capture_piece(target.uid)

		if target_was_objective:
			SfxManager.play("victory")
			pass
		elif result == RulesEngine.CaptureResult.MUTUAL_DESTROY:
			attacker_destroyed = true
			if game_state.rules.c_captures_resolve_independently or not draw_already_resolved:
				game_state.resolve_capture_draws(result, selected_piece.owner, target.owner)
				draw_already_resolved = true
		else:
			if game_state.rules.c_captures_resolve_independently or not draw_already_resolved:
				game_state.resolve_capture_draws(RulesEngine.CaptureResult.CAPTURED, selected_piece.owner, target.owner)
				draw_already_resolved = true

	# Erase Close Call once after all simultaneous resolutions
	if shield_all and game_state.close_call_active.has(close_call_type):
		game_state.close_call_active.erase(close_call_type)

	if attacker_destroyed:
		_spawn_capture_burst(selected_piece)
		_remove_piece_view(selected_piece)
		game_state.capture_piece(selected_piece.uid)
		_deselect()
		_check_win()
		_after_move()
		return

	_apply_movement(new_cells)
	_deselect()
	_check_win()
	_after_move()
	
func _after_move() -> void:
	if _moved_piece:
		game_state.record_piece_moved(_moved_piece.uid)
	if game_state.moves_remaining > 0:
		game_state.spend_move()
	elif _moved_piece and game_state.piece_has_gamo_move(_moved_piece):
		game_state.spend_gamo_move(_moved_piece)
	_update_turn_label()
	_start_turn_timer()
	if hand_panel:
		hand_panel.refresh()
	if cpu != null:
		_update_opponent_hand_counter()
	if _moved_piece and game_state.piece_has_gamo_move(_moved_piece) and game_state.pieces.has(_moved_piece.uid):
		var view := _find_view(_moved_piece)
		if view:
			_select_piece(_moved_piece, view)
	_cpu_maybe_act()

func _on_end_turn_pressed() -> void:
	if hand_panel and hand_panel.is_discard_mode():
		return
	if game_state.rules.require_move_to_end_turn and not game_state.has_moved_this_turn \
			and _side_has_legal_move(game_state.current_player):
		hand_panel.show_status("You must move a piece before you can end your turn.")
		SfxManager.play("illegal")
		return
	_cancel_turn_timer()
	if NetworkManager.is_networked():
		NetworkManager.request_end_turn.rpc_id(1)
	else:
		_deselect()
		game_state.end_turn()
		_deployed_this_turn = false
		_update_turn_label()
		if hand_panel:
			hand_panel.refresh()
		if captured_tray:
			captured_tray.refresh()
	_cpu_maybe_act()

func _cells_at(piece: Piece, destination: Vector2i) -> Array[Vector2i]:
	return RulesEngine.cells_at(piece, destination)

func _b_orientation(cells: Array[Vector2i]) -> Piece.PieceOrientation:
	if cells[0].x == cells[1].x:
		return Piece.PieceOrientation.VERTICAL
	return Piece.PieceOrientation.HORIZONTAL
	
func _apply_movement(new_cells: Array[Vector2i]) -> void:
	selected_piece.cells = new_cells
	if selected_piece.type == Piece.Type.B:
		selected_piece.orientation = _b_orientation(new_cells)
		_remove_piece_view(selected_piece)
		var view := PieceView.new()
		piece_layer.add_child(view)
		view.setup(selected_piece)
	else:
		selected_view.refresh_position()
		
func _piece_dims(piece: Piece) -> Vector2i:
	return RulesEngine.piece_dims(piece)

func _find_view(piece: Piece) -> PieceView:
	for child in piece_layer.get_children():
		if child is PieceView and child.piece == piece:
			return child
	return null

func _remove_piece_view(piece: Piece) -> void:
	var view := _find_view(piece)
	if view:
		view.queue_free()

func _spawn_capture_burst(piece: Piece) -> void:
	var burst := CaptureBurst.new()
	add_child(burst)
	burst.play_at(piece.cells, piece.owner)

func _check_win() -> void:
	if _game_over:
		return
	var winner = RulesEngine.check_win(game_state)
	if winner != null:
		_game_over = true
		_show_win_screen(winner)

func _show_win_screen(winner: Piece.Owner) -> void:
	ReplayRecorder.finish_match(int(winner), "objective", game_state.turn_number)
	MusicManager.play_track(MusicManager.Track.MENU, 0.0)
	SfxManager.play("victory")
	var is_blue := winner == Piece.Owner.BLUE
	var win_color: Color = RuleSettings.COLOR_HEX[RuleSettings.side_one_color] if is_blue else RuleSettings.COLOR_HEX[RuleSettings.side_two_color]
	var win_name: String = RuleSettings.display_name(Piece.Owner.BLUE) if is_blue else RuleSettings.display_name(Piece.Owner.RED)

	var layer := CanvasLayer.new()
	layer.layer = 128   # above everything
	add_child(layer)

	# Dim backdrop that also swallows all clicks so the game underneath is frozen.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.06, 0.06, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	# Rounded white card with drop shadow - the app's signature panel look.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	# Red-over-blue signature rule.
	var rule := VBoxContainer.new()
	rule.add_theme_constant_override("separation", 4)
	rule.custom_minimum_size = Vector2(260, 0)
	var rb := ColorRect.new(); rb.color = Color("#E32636"); rb.custom_minimum_size = Vector2(260, 3)
	var bb := ColorRect.new(); bb.color = Color("#4169E1"); bb.custom_minimum_size = Vector2(260, 3)
	rule.add_child(rb); rule.add_child(bb)
	col.add_child(rule)

	# Winner headline - colored, outlined for punch.
	var headline := Label.new()
	headline.text = "%s Wins!" % win_name
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 46)
	headline.add_theme_color_override("font_color", win_color)
	headline.add_theme_color_override("font_outline_color", Color.BLACK)
	headline.add_theme_constant_override("outline_size", 6)
	col.add_child(headline)

	var sub := Label.new()
	sub.text = "The enemy Objective has been captured."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("#33302b"))
	col.add_child(sub)

	# Play Again button - styled dark like End Turn.
	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(200, 48)
	again.add_theme_font_size_override("font_size", 20)
	var ab := StyleBoxFlat.new()
	ab.bg_color = Color("#141414")
	ab.set_corner_radius_all(10)
	ab.content_margin_top = 8
	ab.content_margin_bottom = 8
	var ab_hover := ab.duplicate()
	ab_hover.bg_color = Color("#2a2a2a")
	again.add_theme_stylebox_override("normal", ab)
	again.add_theme_stylebox_override("hover", ab_hover)
	again.add_theme_stylebox_override("pressed", ab_hover)
	again.add_theme_color_override("font_color", Color.WHITE)
	again.pressed.connect(_on_play_again_pressed)
	col.add_child(again)

	# Return to Main Menu button - lighter outline variant so it reads as the
	# secondary action next to Play Again.
	var menu_btn := Button.new()
	menu_btn.text = "Return to Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 48)
	menu_btn.add_theme_font_size_override("font_size", 16)
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color("#ffffff")
	mb.border_color = Color("#141414")
	mb.set_border_width_all(2)
	mb.set_corner_radius_all(10)
	mb.content_margin_top = 8
	mb.content_margin_bottom = 8
	var mb_hover := mb.duplicate()
	mb_hover.bg_color = Color("#f0ede7")
	menu_btn.add_theme_stylebox_override("normal", mb)
	menu_btn.add_theme_stylebox_override("hover", mb_hover)
	menu_btn.add_theme_stylebox_override("pressed", mb_hover)
	menu_btn.add_theme_color_override("font_color", Color("#141414"))
	menu_btn.pressed.connect(_on_return_to_main_menu_pressed)
	col.add_child(menu_btn)

func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()

func _on_return_to_main_menu_pressed() -> void:
	_leave_network_match()
	get_tree().change_scene_to_file("res://scenes/menu_root.tscn")

func _leave_network_match() -> void:
	if not NetworkManager.is_networked():
		return
	# Only announce if the link is actually still up — after the host drops,
	# the peer object survives briefly but the connection doesn't.
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		NetworkManager.notify_leaving.rpc()
	NetworkManager.disconnect_network()
	
func _on_deployment_applied() -> void:
	_deployed_this_turn = true
	_refresh_all_piece_views()
	_update_turn_label()

func _refresh_all_piece_views() -> void:
	for child in piece_layer.get_children():
		if child is PieceView:
			child.queue_free()
	for piece in game_state.pieces.values():
		var view := PieceView.new()
		piece_layer.add_child(view)
		view.setup(piece)

func _build_turn_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# --- Turn indicator (styled) ---
	turn_panel = PanelContainer.new()
	turn_panel.position = Vector2(12, 20)
	turn_panel.custom_minimum_size = Vector2(255, 0)
	var ti_sb := StyleBoxFlat.new()
	ti_sb.bg_color = Color.WHITE
	ti_sb.set_corner_radius_all(12)
	ti_sb.shadow_color = Color(0, 0, 0, 0.35)
	ti_sb.shadow_size = 6
	ti_sb.shadow_offset = Vector2(0, 3)
	ti_sb.content_margin_left = 16
	ti_sb.content_margin_right = 16
	ti_sb.content_margin_top = 10
	ti_sb.content_margin_bottom = 10
	turn_panel.add_theme_stylebox_override("panel", ti_sb)
	layer.add_child(turn_panel)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 27)
	turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_label.add_theme_constant_override("outline_size", 4)
	turn_panel.add_child(turn_label)
	_update_turn_label()

	# --- End Turn button (styled) ---
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.position = Vector2(12, 76)
	end_turn_button.custom_minimum_size = Vector2(255, 40)
	end_turn_button.add_theme_font_size_override("font_size", 22)
	var et_normal := StyleBoxFlat.new()
	et_normal.bg_color = Color("#141414")
	et_normal.set_corner_radius_all(10)
	et_normal.content_margin_top = 8
	et_normal.content_margin_bottom = 8
	var et_hover := et_normal.duplicate()
	et_hover.bg_color = Color("#2a2a2a")
	var et_disabled := StyleBoxFlat.new()
	et_disabled.bg_color = Color("#cfcac1")
	et_disabled.set_corner_radius_all(10)
	et_disabled.content_margin_top = 8
	et_disabled.content_margin_bottom = 8
	end_turn_button.add_theme_stylebox_override("normal", et_normal)
	end_turn_button.add_theme_stylebox_override("hover", et_hover)
	end_turn_button.add_theme_stylebox_override("pressed", et_hover)
	end_turn_button.add_theme_stylebox_override("disabled", et_disabled)
	_et_style_normal = et_normal
	_et_style_pale = et_disabled
	end_turn_button.add_theme_color_override("font_color", Color.WHITE)
	end_turn_button.add_theme_color_override("font_outline_color", Color.BLACK)
	end_turn_button.add_theme_constant_override("outline_size", 4)
	end_turn_button.add_theme_color_override("font_disabled_color", Color("#8a857c"))
	end_turn_button.disabled = true
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	layer.add_child(end_turn_button)

	# Pulsing warning ring — sits behind/around the button, never tints it.
	turn_timer_ring = Panel.new()
	turn_timer_ring.position = end_turn_button.position - Vector2(7, 7)
	turn_timer_ring.size = end_turn_button.custom_minimum_size + Vector2(14, 14)
	turn_timer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0, 0, 0, 0)
	ring_sb.border_color = Color("#FFCC00")
	ring_sb.set_border_width_all(5)
	ring_sb.set_corner_radius_all(10)
	# Grey twin for the waiting player: same geometry, so the countdown bar's
	# corners are framed on both screens rather than left square on one.
	var ring_sb_idle := ring_sb.duplicate()
	ring_sb_idle.border_color = Color("#8a857c")
	_ring_sb_active = ring_sb
	_ring_sb_idle = ring_sb_idle
	turn_timer_ring.add_theme_stylebox_override("panel", ring_sb)
	turn_timer_ring.visible = false
	layer.add_child(turn_timer_ring)

	# Dark countdown bar, drawn over the pale button.
	turn_timer_bar = ColorRect.new()
	turn_timer_bar.color = Color(0.08, 0.08, 0.08, 0.72)
	turn_timer_bar.position = end_turn_button.position
	turn_timer_bar.size = Vector2(0, end_turn_button.custom_minimum_size.y)
	turn_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_timer_bar.visible = false
	layer.add_child(turn_timer_bar)

	# --- Mouse-accessible pause button, centered in the left UI margin ---
	pause_button = Button.new()
	pause_button.text = "[pause]"
	pause_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# The left-side UI column is 267 px wide (x = 12..267). A 125 px button
	# centered in that column begins at x = 77.
	pause_button.offset_left = 77.0
	pause_button.offset_right = 202.0
	pause_button.offset_top = -62.0
	pause_button.offset_bottom = -22.0
	pause_button.add_theme_font_size_override("font_size", 17)
	pause_button.focus_mode = Control.FOCUS_ALL
	pause_button.pressed.connect(_toggle_pause_menu)
	layer.add_child(pause_button)
	_update_pause_button_style()

	hand_panel = HandPanel.new()
	if cpu != null:
		# Keep the human's hand on screen through the CPU's turn.
		hand_panel.forced_side = Piece.Owner.BLUE if cpu.side == Piece.Owner.RED else Piece.Owner.RED
	add_child(hand_panel)
	hand_panel.setup(game_state)
	hand_panel.deployment_applied.connect(_on_deployment_applied)
	hand_panel.refresh()
	hand_panel.controller = self
	debug_hand_builder = DebugHandBuilder.new()
	add_child(debug_hand_builder)
	debug_hand_builder.setup(game_state, hand_panel)
	captured_tray = CapturedTray.new()
	add_child(captured_tray)
	captured_tray.setup(game_state)
	captured_tray.captured_piece_clicked.connect(_on_captured_piece_clicked)
	_build_opponent_hand_counter(layer)

func _build_rotate_button() -> void:
	# Own CanvasLayer so it always draws above the Croce portrait, even if the
	# player has dragged the portrait over the button's spawn spot.
	var rotate_layer := CanvasLayer.new()
	rotate_layer.layer = 64   # above ui_layer, below the win/pause layer (128)
	add_child(rotate_layer)

	rotate_button = Button.new()
	rotate_button.visible = false
	# Near-equilateral: squarish footprint, text wraps into rows inside it.
	rotate_button.custom_minimum_size = Vector2(150, 130)
	rotate_button.add_theme_font_size_override("font_size", 18)
	rotate_button.add_theme_constant_override("outline_size", 4)  # you have 3; heavier outline reads chunkier
	rotate_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotate_button.clip_text = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#000000")
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("#1c1c1c")
	rotate_button.add_theme_stylebox_override("normal", sb)
	rotate_button.add_theme_stylebox_override("hover", sb_hover)
	rotate_button.add_theme_stylebox_override("pressed", sb_hover)
	rotate_button.add_theme_color_override("font_color", Color.WHITE)
	rotate_button.add_theme_color_override("font_hover_color", Color.WHITE)
	rotate_button.add_theme_color_override("font_outline_color", Color.BLACK)
	rotate_button.add_theme_constant_override("outline_size", 3)

	rotate_button.pressed.connect(func():
		if in_croce and ghost:
			ghost.toggle_orientation()
			_update_rotate_button(ghost)
		elif ityd_placing and ityd_ghost:
			ityd_ghost.toggle_orientation()
			_update_rotate_button(ityd_ghost)
	)
	rotate_layer.add_child(rotate_button)
	
func _teardown_croce_ui() -> void:
	if rotate_button and is_instance_valid(rotate_button):
		rotate_button.get_parent().queue_free()  # frees the whole rotate_layer
		rotate_button = null
		
func _position_rotate_button() -> void:
	if not rotate_button or not rotate_button.visible:
		return

func _process(_delta: float) -> void:
	if not _ready_finished:
		return
	_position_rotate_button()
	_tick_turn_timer(_delta)
	
	# Pick the anchor by phase: Croce menu during setup, captured tray during ITYD.
	var anchor := Rect2()
	if in_croce and croce_panel:
		anchor = Rect2(croce_panel.global_position, croce_panel.size)
	elif ityd_placing and captured_tray:
		anchor = captured_tray.window_rect()

	if anchor.size == Vector2.ZERO:
		return
	if not rotate_button or not is_instance_valid(rotate_button):
		return

	const GAP := 12.0
	var btn_w := rotate_button.size.x
	var btn_h := rotate_button.size.y
	var vp := get_viewport().get_visible_rect().size

	var x: float = clamp(anchor.position.x, 8.0, vp.x - btn_w - 8.0)
	var below_y := anchor.position.y + anchor.size.y + GAP
	var y: float
	if below_y + btn_h <= vp.y - 8.0:
		y = below_y                          # room below the anchor
	else:
		y = anchor.position.y - GAP - btn_h  # flip above it
	rotate_button.position = Vector2(x, y)

func _update_rotate_button(g: PieceGhost) -> void:
	if not rotate_button:
		return
	if g.orientation == Piece.PieceOrientation.VERTICAL:
		rotate_button.text = "Click here or press R for horizontal placement"
	else:
		rotate_button.text = "Click here or press R for vertical placement"
	rotate_button.visible = true
	_position_rotate_button()

func _on_captured_piece_clicked(piece: Piece) -> void:
	if not ityd_selecting:
		return
	if piece.owner != game_state.current_player:
		SfxManager.play("illegal")
		hand_panel.show_status("You can only redeploy your own captured pieces.")
		return
	if piece.type != ityd_required_type:
		SfxManager.play("illegal")
		hand_panel.show_status("Wrong piece type for this card.")
		return
	ityd_selecting = false
	ityd_piece = piece
	_begin_ityd_placement(piece)

func _begin_ityd_placement(piece: Piece) -> void:
	ityd_placing = true
	hand_panel.hide_deploy_card()
	set_turn_timer_paused(true)
	ityd_ghost = PieceGhost.new()
	ityd_ghost.piece_type = piece.type
	ityd_ghost.orientation = piece.orientation
	add_child(ityd_ghost)
	if piece.type == Piece.Type.B:
		_update_rotate_button(ityd_ghost)
	elif rotate_button:
		rotate_button.visible = false
	var rs = get_node_or_null("/root/RuleSettings")
	var whole_side: bool = rs != null and "ityd_deployment_zone_only" in rs and not rs.ityd_deployment_zone_only
	var where := "anywhere on your side" if whole_side else "in your deployment zone"
	hand_panel.show_status("Place %s %s (right-click to cancel)." % [piece.designation, where])

func _cancel_ityd() -> void:
	ityd_selecting = false
	ityd_placing = false
	ityd_piece = null
	ityd_card = null
	if ityd_ghost:
		ityd_ghost.queue_free()
		ityd_ghost = null
	hand_panel.restore_deploy_card()
	set_turn_timer_paused(false)
	hand_panel.show_status("Redeploy cancelled.")

func _pause_button_color_key() -> String:
	# In network play the button keeps the local player's color. In local
	# pass-and-play it follows the player whose turn it is.
	var side := game_state.current_player
	if NetworkManager.is_networked():
		side = NetworkManager.my_side()
	return RuleSettings.side_one_color if side == Piece.Owner.BLUE else RuleSettings.side_two_color


func _update_pause_button_style() -> void:
	if pause_button == null:
		return
	var color_key := _pause_button_color_key()
	var bg: Color = RuleSettings.COLOR_HEX[color_key]
	var fg := Color.BLACK if color_key == "green" or color_key == "yellow" else Color.WHITE

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	normal.shadow_color = Color(0, 0, 0, 0.28)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.12)

	pause_button.add_theme_stylebox_override("normal", normal)
	pause_button.add_theme_stylebox_override("hover", hover)
	pause_button.add_theme_stylebox_override("pressed", pressed)
	pause_button.add_theme_stylebox_override("focus", hover)
	pause_button.add_theme_color_override("font_color", fg)
	pause_button.add_theme_color_override("font_hover_color", fg)
	pause_button.add_theme_color_override("font_pressed_color", fg)
	pause_button.add_theme_color_override("font_focus_color", fg)


func _update_turn_label() -> void:
	if turn_label == null:
		return
	var is_blue := game_state.current_player == Piece.Owner.BLUE
	turn_label.text = "%s's Move" % (RuleSettings.display_name(Piece.Owner.BLUE) if is_blue else RuleSettings.display_name(Piece.Owner.RED))
	turn_label.add_theme_color_override("font_color",
		RuleSettings.COLOR_HEX[RuleSettings.side_one_color] if is_blue else RuleSettings.COLOR_HEX[RuleSettings.side_two_color])
	turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_label.add_theme_constant_override("outline_size", 4)
	_update_pause_button_style()
	if hand_panel:
		hand_panel.refresh()
	if captured_tray:
		captured_tray.refresh()
	if end_turn_button:
		var it_is_my_turn := not NetworkManager.is_networked() or game_state.current_player == NetworkManager.my_side()
		var stuck := not _side_has_legal_move(game_state.current_player)
		end_turn_button.disabled = not it_is_my_turn or not (game_state.has_moved_this_turn or _deployed_this_turn or stuck)
		if hand_panel and it_is_my_turn and stuck and not game_state.has_moved_this_turn:
			hand_panel.show_status("No legal moves available — you may end your turn.")
	_update_opponent_hand_counter()

func _debug_skip_croce() -> void:
	if not in_croce:
		return

	# Clear anything placed so far
	for child in piece_layer.get_children():
		child.queue_free()
	game_state.pieces.clear()
	next_uid = 1

	# Blue layout - rows 0-4
	_auto_place_army(Piece.Owner.BLUE)
	# Red layout - rows 11-15
	_auto_place_army(Piece.Owner.RED)

	# Render all pieces
	for piece in game_state.pieces.values():
		var view := PieceView.new()
		piece_layer.add_child(view)
		view.setup(piece)

	# Skip to gameplay
	if ghost:
		ghost.queue_free()
	if ui_layer:
		ui_layer.queue_free()
	if pass_screen:
		pass_screen.queue_free()
	_teardown_croce_ui()
	piece_layer.visible = true
	game_state.initialize_deck()
	ReplayRecorder.start_match(game_state, "debug", Piece.Owner.BLUE)
	in_croce = false
	_build_turn_ui()
	print("DEBUG: Croce skipped - game begins.")

func _debug_stage_captures() -> void:
	# Move existing pieces to face off across the center line, matching the
	# C / A / B staging layout. Blue on rows 6-7, Red on rows 8-9.
	# [owner, designation, new_cells]
	var moves := [
		# A-vs-A mutual pairs (both draw) - pile up cards fast to test the 9-limit
		[Piece.Owner.BLUE, "A1", [Vector2i(0, 7)]],  [Piece.Owner.RED, "A1", [Vector2i(0, 8)]],
		[Piece.Owner.BLUE, "A2", [Vector2i(1, 7)]],  [Piece.Owner.RED, "A2", [Vector2i(1, 8)]],
		[Piece.Owner.BLUE, "A3", [Vector2i(2, 7)]],  [Piece.Owner.RED, "A3", [Vector2i(2, 8)]],
		[Piece.Owner.BLUE, "A4", [Vector2i(3, 7)]],  [Piece.Owner.RED, "A4", [Vector2i(3, 8)]],
		[Piece.Owner.BLUE, "A5", [Vector2i(4, 7)]],  [Piece.Owner.RED, "A5", [Vector2i(4, 8)]],
		[Piece.Owner.BLUE, "A6", [Vector2i(5, 7)]],  [Piece.Owner.RED, "A6", [Vector2i(5, 8)]],
		[Piece.Owner.BLUE, "A7", [Vector2i(6, 7)]],  [Piece.Owner.RED, "A7", [Vector2i(6, 8)]],
		[Piece.Owner.BLUE, "A8", [Vector2i(7, 7)]],  [Piece.Owner.RED, "A8", [Vector2i(7, 8)]],
		# C edge case: Blue C3 (cols 12-13, rows 6-7) drops one row to overlap
		#   - a corner of Red C3 (cols 11-12, rows 8-9)
		#   - the top cell of vertical Red B1 (col 13, rows 8-9)
		[Piece.Owner.RED,  "C3", [Vector2i(11, 8), Vector2i(12, 8), Vector2i(11, 9), Vector2i(12, 9)]],
		[Piece.Owner.RED,  "B1", [Vector2i(13, 8), Vector2i(13, 9)]],
		[Piece.Owner.BLUE, "C3", [Vector2i(12, 6), Vector2i(13, 6), Vector2i(12, 7), Vector2i(13, 7)]],
	]
	for m in moves:
		var target: Piece = null
		for piece in game_state.pieces.values():
			if piece.owner == m[0] and piece.designation == m[1]:
				target = piece
				break
		if target == null:
			print("DEBUG F5: no ", m[1], " found for ", m[0])
			continue
		var new_cells: Array[Vector2i] = []
		for c in m[2]:
			new_cells.append(Vector2i(c))
		target.cells = new_cells
		if target.type == Piece.Type.B:
			target.orientation = Piece.PieceOrientation.VERTICAL
		# refresh its view
		var view := _find_view(target)
		if view:
			view.queue_free()
		var new_view := PieceView.new()
		piece_layer.add_child(new_view)
		new_view.setup(target)
	print("DEBUG F5: staged existing C3/A7/B1 pieces across center line")

func _auto_place_army(owner: Piece.Owner) -> void:
	var row_offset := 0 if owner == Piece.Owner.BLUE else 11

	# A pieces - row 0/15, cols 0-11
	for i in range(12):
		var p := Piece.new()
		p.uid = next_uid; next_uid += 1
		p.type = Piece.Type.A
		p.owner = owner
		p.designation = "A%d" % (i + 1)
		p.cells = [Vector2i(i, row_offset if owner == Piece.Owner.BLUE else 15)]
		game_state.pieces[p.uid] = p

	# C pieces - rows 1-2/13-14, cols 0-5
	for i in range(3):
		var p := Piece.new()
		p.uid = next_uid; next_uid += 1
		p.type = Piece.Type.C
		p.owner = owner
		p.designation = "C%d" % (i + 1)
		var base_col := i * 2
		var base_row := (row_offset + 1) if owner == Piece.Owner.BLUE else 13
		p.cells = [
			Vector2i(base_col,     base_row),
			Vector2i(base_col + 1, base_row),
			Vector2i(base_col,     base_row + 1),
			Vector2i(base_col + 1, base_row + 1),
		]
		game_state.pieces[p.uid] = p

	# B pieces - rows 1-2/13-14, cols 6-11
	for i in range(6):
		var p := Piece.new()
		p.uid = next_uid; next_uid += 1
		p.type = Piece.Type.B
		p.owner = owner
		p.designation = "B%d" % (i + 1)
		p.orientation = Piece.PieceOrientation.VERTICAL
		var base_row := (row_offset + 1) if owner == Piece.Owner.BLUE else 13
		p.cells = [Vector2i(6 + i, base_row), Vector2i(6 + i, base_row + 1)]
		game_state.pieces[p.uid] = p

	# General
	var gen := Piece.new()
	gen.uid = next_uid; next_uid += 1
	gen.type = Piece.Type.GENERAL
	gen.owner = owner
	gen.designation = "General"
	gen.cells = [Vector2i(8, (row_offset + 3) if owner == Piece.Owner.BLUE else 12)]
	game_state.pieces[gen.uid] = gen

	# Objective
	var obj := Piece.new()
	obj.uid = next_uid; next_uid += 1
	obj.type = Piece.Type.OBJECTIVE
	obj.owner = owner
	obj.designation = "Objective"
	obj.cells = [Vector2i(9, (row_offset + 3) if owner == Piece.Owner.BLUE else 12)]
	game_state.pieces[obj.uid] = obj

var waiting_notice_layer: CanvasLayer

func _build_waiting_notice() -> void:
	waiting_notice_layer = CanvasLayer.new()
	waiting_notice_layer.layer = 55
	add_child(waiting_notice_layer)

	# Anchored bottom-centre so it stays clear of the Croce menu (top-left),
	# the hand counter (top-right), and the opponent's portrait.
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.add_theme_constant_override("margin_bottom", 28)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waiting_notice_layer.add_child(wrap)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(center)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.06, 0.82)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = "Waiting for a player to join…"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	center.add_child(box)

	# Slow breathing fade so it reads as "still waiting" without demanding attention.
	var tw := create_tween().set_loops()
	tw.tween_property(box, "modulate:a", 0.45, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(box, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)

func _dismiss_waiting_notice(_id: int = 0) -> void:
	if waiting_notice_layer and is_instance_valid(waiting_notice_layer):
		waiting_notice_layer.queue_free()
	waiting_notice_layer = null

# ============================================================
# CPU opponent driver
# ------------------------------------------------------------
# CpuPlayer decides; this section executes. Moves go through the same
# _execute_move() path a mouse click uses, so animation, SFX, capture bursts
# and win checking all happen exactly as they do for a human.
# ============================================================

func _cpu_toggle() -> void:
	if cpu == null:
		cpu = CpuPlayer.new(Piece.Owner.RED)
		print("CPU: enabled (RED)")
		_cpu_maybe_act()
	else:
		cpu = null
		_cpu_pending = false
		print("CPU: disabled")

func _cpu_maybe_act(delay: float = 0.6) -> void:
	if cpu == null or _cpu_pending:
		return
	if in_croce or _game_over:
		return
	if NetworkManager.is_networked():
		return
	if game_state.current_player != cpu.side:
		return
	_cpu_pending = true
	get_tree().create_timer(delay).timeout.connect(_cpu_act)

func _cpu_act() -> void:
	_cpu_pending = false
	if cpu == null or in_croce or _game_over:
		return
	if game_state.current_player != cpu.side:
		return

	_cpu_manage_hand()
	_cpu_try_deploy()

	cpu.note_hand(game_state.hands[cpu.side])
	var choice := cpu.choose_move(game_state)
	if choice.is_empty():
		if cpu.verbose:
			print("CPU: no legal moves (moves_remaining=%d, moved=%s) — ending turn"
				% [game_state.moves_remaining, game_state.pieces_moved_this_turn])
		_cpu_end_turn()
		return

	var piece: Piece = game_state.pieces.get(choice["piece_uid"])
	if piece == null:
		_cpu_end_turn()
		return
	var view := _find_view(piece)
	if view == null:
		push_warning("CPU: no PieceView for uid %d" % choice["piece_uid"])
		_cpu_end_turn()
		return

	_deselect()
	selected_piece = piece
	selected_view = view
	_execute_move(choice["dest"])   # calls _after_move(), which re-arms the CPU

# Deliberately NOT _on_end_turn_pressed(). That guard calls _side_has_legal_move(),
# which only checks the move BUDGET, not whether any destination is actually legal.
# A CPU with budget but no legal move would be refused and stall forever.
# This mirrors the body of _on_turn_ended() instead.
func _cpu_end_turn() -> void:
	_cancel_turn_timer()
	SfxManager.play("end_turn")
	var last_mover: Piece = _moved_piece
	_deselect()
	game_state.end_turn()
	_show_move_ripple(last_mover)
	_deployed_this_turn = false
	_update_turn_label()
	if hand_panel:
		hand_panel.refresh()
	if captured_tray:
		captured_tray.refresh()

# Discard down to the limit. The hand is read here and passed in, so
# CpuPlayer never touches game_state.hands itself.
func _cpu_manage_hand() -> void:
	var guard := 0
	while game_state.is_hand_over_limit(cpu.side) and guard < 20:
		guard += 1
		var card: Card = cpu.choose_discard(game_state, game_state.hands[cpu.side])
		if card == null:
			break
		game_state.discard_card(cpu.side, card)
		SfxManager.play("discard")
	if hand_panel:
		hand_panel.refresh()
	_update_opponent_hand_counter()

func _cpu_try_deploy() -> void:
	var hand: Array = game_state.hands[cpu.side]
	var names := []
	for c in hand:
		names.append(c.name if "name" in c else str(c.category))
	print("CPU deploy: hand=%d %s" % [hand.size(), names])
	var attempts := 0
	while attempts < 3:
		attempts += 1
		if _cpu_try_ityd():
			continue
		if _cpu_try_oma():
			continue
		if _cpu_try_jto():
			continue
		var plan: Dictionary = cpu.choose_deployment(game_state, game_state.hands[cpu.side])
		if plan.is_empty():
			return
		match plan["kind"]:
			"saboteur":
				var ok := game_state.declare_saboteur(
					cpu.side, plan["type_card"], plan["chart_card"], plan["chosen_type"])
				if not ok:
					return
				SfxManager.play("saboteur_transform")
				hand_panel.reveal_opponent_card(plan["type_card"], "CPU declared a Saboteur.")
				_refresh_all_piece_views()
				if captured_tray:
					captured_tray.refresh()
			"simple":
				var res := game_state.deploy_simple(cpu.side, plan["cards"])
				if not res["ok"]:
					return
				var c: Card = plan["cards"][0]
				SfxManager.play("play_major_card" if c.category == Card.Category.MAJOR_POWER else "play_minor_card")
				hand_panel.reveal_opponent_card(c, "CPU played a card.")
			_:
				return
		if hand_panel:
			hand_panel.refresh()
		_update_opponent_hand_counter()
		_update_turn_label()

# Called from _ready() so a menu selection takes effect without F6.
func _cpu_from_menu() -> void:
	if not GameSetup.vs_cpu:
		return
	cpu = CpuPlayer.new(GameSetup.cpu_side, GameSetup.cpu_tier)
	print("CPU: enabled from menu (side %d, tier %d)" % [GameSetup.cpu_side, GameSetup.cpu_tier])

func _debug_validate_openings() -> void:
	for name in CroceOpenings.names():
		for owner_val in [Piece.Owner.BLUE, Piece.Owner.RED]:
			var fault := CroceOpenings.validate(name, owner_val)
			var side_name := "blue" if owner_val == Piece.Owner.BLUE else "red"
			if fault == "":
				print("  OK   %s_%s" % [name, side_name])
			else:
				print("  FAIL %s_%s — %s" % [name, side_name, fault])

# DEBUG: hand the CPU a Get-a-Move-On for the first type it has a movable piece
# of, so the GaMO bonus-move path can be reproduced on demand. Throwaway.
func _debug_give_cpu_gamo() -> void:
	if cpu == null:
		print("DEBUG: no CPU active")
		return
	var gamo: Card = null
	for c in CardDatabase.build_full_deck():
		if c.category == Card.Category.MINOR_POWER and c.minor_effect == Card.MinorEffect.GET_MOVE_ON:
			gamo = c
			# Match the card's type to a piece the CPU can actually move.
			for piece in game_state.pieces.values():
				if piece.owner == cpu.side and piece.type == c.effect_piece_type:
					break
			break
	if gamo == null:
		print("DEBUG: no GaMO card in deck")
		return
	gamo.uid = 9500
	game_state.hands[cpu.side].append(gamo)
	print("DEBUG: gave CPU a GaMO-%s (hand now %d)" % [
		CardView._letter(gamo.effect_piece_type), game_state.hands[cpu.side].size()])
	if hand_panel:
		hand_panel.refresh()

# DEBUG: give the CPU an ITYD-A. Only fires the effect if the CPU has an A in
# its captured tray to redeploy. Throwaway.
func _debug_give_cpu_ityd() -> void:
	if cpu == null:
		print("DEBUG: no CPU active")
		return
	var ityd: Card = null
	for c in CardDatabase.build_full_deck():
		if c.category == Card.Category.MINOR_POWER \
		and c.minor_effect == Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD \
		and c.effect_piece_type == Piece.Type.A:
			ityd = c
			break
	if ityd == null:
		print("DEBUG: no ITYD-A in deck")
		return
	ityd.uid = 9600
	game_state.hands[cpu.side].append(ityd)
	var tray: int = game_state.captured_pieces[cpu.side].size()
	print("DEBUG: gave CPU an ITYD-A (hand %d, %d in tray)" % [
		game_state.hands[cpu.side].size(), tray])
	if hand_panel:
		hand_panel.refresh()

# Assembles the legal ITYD cells and hands them to the CPU to choose from,
# then applies the pick through the same headless applier the player uses.
# Returns true if an ITYD was played.
func _cpu_try_ityd() -> bool:
	if cpu == null:
		return false
	var captured: Array = game_state.captured_pieces[cpu.side]
	if captured.is_empty():
		return false
	var hand: Array = game_state.hands[cpu.side]

	# Which captured types could an ITYD in hand actually redeploy?
	var has_ityd := false
	for c in hand:
		if c.category == Card.Category.MINOR_POWER and c.minor_effect == Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
			has_ityd = true
			break
	if not has_ityd:
		return false

	# Build the set of legal single-cell placements. For a 1x1 (A) this is the
	# cell itself; multi-cell pieces need their footprint checked, but ITYD in
	# this build redeploys the piece at its own footprint anchored at the cell.
	var legal_cells: Array = []
	for y in range(16):
		for x in range(18):
			var cell := Vector2i(x, y)
			if not _in_ityd_zone(cell, cpu.side):
				continue
			if _cell_blocked(cell):
				continue
			legal_cells.append(cell)
	if legal_cells.is_empty():
		return false

	var anchor := _moved_piece.cells[0] if (_moved_piece != null and not _moved_piece.cells.is_empty()) else Vector2i(-1, -1)
	var plan: Dictionary = cpu.choose_ityd(game_state, hand, captured, legal_cells, anchor)
	if plan.is_empty():
		return false

	# Resolve the chosen piece to know its footprint at the target cell.
	var piece: Piece = null
	for cap in captured:
		if cap.uid == plan["piece_uid"]:
			piece = cap
			break
	if piece == null:
		return false

	var cells: Array[Vector2i] = CroceOpenings.cells_for(piece.designation, plan["cell"].x, plan["cell"].y,
		"V" if piece.orientation == Piece.PieceOrientation.VERTICAL else "H")
	# Every footprint cell must also be legal, not just the anchor.
	for cell in cells:
		if not _in_ityd_zone(cell, cpu.side) or _cell_blocked(cell):
			return false

	var ok := game_state.apply_i_thought_you_were_dead(cpu.side, plan["piece_uid"], cells, piece.orientation)
	if not ok:
		return false

	# Discard the ITYD card.
	for c in hand:
		if c.category == Card.Category.MINOR_POWER and c.minor_effect == Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
			game_state.discard_card(cpu.side, c)
			break

	# Build the view for the returned piece and announce it.
	var view := PieceView.new()
	piece_layer.add_child(view)
	view.setup(piece)
	SfxManager.play("play_minor_card")
	hand_panel.reveal_opponent_card(plan["card"], "CPU redeployed a piece.")
	if hand_panel:
		hand_panel.refresh()
	_update_opponent_hand_counter()
	if captured_tray:
		captured_tray.refresh()
	print("CPU ITYD: %s to %s" % [piece.designation, plan["cell"]])
	return true

# True if any piece already occupies this cell.
func _cell_blocked(cell: Vector2i) -> bool:
	for piece in game_state.pieces.values():
		if piece.cells.has(cell):
			return true
	return false

func _cpu_try_oma() -> bool:
	if cpu == null:
		return false
	var plan: Dictionary = cpu.choose_one_man_army(game_state, game_state.hands[cpu.side])
	if plan.is_empty():
		return false
	var ok := game_state.apply_one_man_army(cpu.side, plan["type_card"], plan["chosen_type"])
	if not ok:
		return false
	# apply_one_man_army() discards the TYPE card; the OMA major card must be
	# discarded separately, exactly as hand_panel._launch_one_man_army does.
	for c in game_state.hands[cpu.side]:
		if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.ONE_MAN_ARMY:
			game_state.discard_card(cpu.side, c)
			break
	SfxManager.play("play_major_card")
	hand_panel.reveal_opponent_card(plan["type_card"], "CPU declared One Man Army.")
	if hand_panel:
		hand_panel.refresh()
	_update_opponent_hand_counter()
	print("CPU OMA: type %d" % plan["chosen_type"])
	return true

func _cpu_try_jto() -> bool:
	if cpu == null:
		return false
	if game_state.objective_has_moved.get(cpu.side, false):
		return false
	var obj: Piece = null
	for p in game_state.pieces.values():
		if p.type == Piece.Type.OBJECTIVE and p.owner == cpu.side:
			obj = p
			break
	if obj == null or obj.cells.is_empty():
		return false

	# Enumerate legal Objective destinations: orthogonal, 1-3 cells, clear path,
	# own half, empty. Mirrors _is_legal_objective_move without duplicating it.
	var from: Vector2i = obj.cells[0]
	var legal_dests: Array = []
	for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		for dist in range(1, 4):
			var dest: Vector2i = from + dir * dist
			if game_state._is_legal_objective_move(from, dest, cpu.side):
				legal_dests.append(dest)

	var plan: Dictionary = cpu.choose_just_this_once(game_state, game_state.hands[cpu.side], legal_dests)
	if plan.is_empty():
		return false
	var ok := game_state.apply_just_this_once(cpu.side, plan["dest"])
	if not ok:
		return false
	# Discard the card (apply_just_this_once doesn't consume it).
	for c in game_state.hands[cpu.side]:
		if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.JUST_THIS_ONCE:
			game_state.discard_card(cpu.side, c)
			break
	_refresh_all_piece_views()
	SfxManager.play("jto_objmove")
	hand_panel.reveal_opponent_card(plan["card"], "CPU moved its Objective.")
	if hand_panel:
		hand_panel.refresh()
	_update_opponent_hand_counter()
	print("CPU JTO: objective to %s" % plan["dest"])
	return true

# DEBUG: drop a card matching (category, effect) into the CPU's hand. Throwaway.
func _debug_give_cpu_card(category: int, effect: int) -> void:
	if cpu == null:
		print("DEBUG: no CPU active")
		return
	var found: Card = null
	for c in CardDatabase.build_full_deck():
		if c.category != category:
			continue
		if category == Card.Category.MAJOR_POWER and c.major_effect == effect:
			found = c
			break
		if category == Card.Category.MINOR_POWER and c.minor_effect == effect:
			found = c
			break
	if found == null:
		print("DEBUG: no matching card in deck")
		return
	found.uid = 9700
	game_state.hands[cpu.side].append(found)
	print("DEBUG: gave CPU a card (hand now %d)" % game_state.hands[cpu.side].size())
	if hand_panel:
		hand_panel.refresh()

# DEBUG: print every Piece in state and every PieceView on screen, so orphaned
# views (rendered but not in game_state.pieces) show up immediately.
func _debug_dump_pieces() -> void:
	print("--- PIECES IN STATE ---")
	var state_uids := {}
	for p in game_state.pieces.values():
		state_uids[p.uid] = true
		var sab := " SABOTEUR" if p.has_status("saboteur") else ""
		print("  uid=%d %s owner=%d cells=%s%s" % [p.uid, p.designation, p.owner, p.cells, sab])
	print("--- PIECE VIEWS ON SCREEN ---")
	var view_uids := {}
	for child in piece_layer.get_children():
		if child is PieceView and child.piece != null:
			view_uids[child.piece.uid] = true
			var orphan := "" if state_uids.has(child.piece.uid) else "   <<< ORPHAN: not in state"
			print("  view uid=%d %s cells=%s%s" % [child.piece.uid, child.piece.designation, child.piece.cells, orphan])
	print("--- MISSING VIEWS ---")
	for uid in state_uids:
		if not view_uids.has(uid):
			print("  uid=%d in state but NO view" % uid)
	print("--- captured: blue=%d red=%d ---" % [
		game_state.captured_pieces[Piece.Owner.BLUE].size(),
		game_state.captured_pieces[Piece.Owner.RED].size()])
