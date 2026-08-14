extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connected_to_host()
signal connection_failed()

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 2

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("host_game failed, error code: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: hosting on port ", port)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("join_game failed, error code: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: joining ", address, ":", port)
	return OK

func disconnect_network() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	print("NetworkManager: disconnected")
	received_croce.clear()
	opponent_hand_count = 0
	NetworkManager.upnp_cleanup()

func is_host() -> bool:
	return multiplayer.is_server()

func my_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: peer connected, id=", id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: peer disconnected, id=", id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("NetworkManager: connected to host, my id=", my_id())
	submit_version.rpc_id(1, GAME_VERSION)
	connected_to_host.emit()

func _on_connection_failed() -> void:
	print("NetworkManager: connection failed")
	connection_failed.emit()

@rpc("any_peer", "call_local", "reliable")
func report_move(piece_uid: int, destination: Vector2i) -> void:
	print("NetworkManager: peer ", multiplayer.get_remote_sender_id(),
		" reports a move — piece uid ", piece_uid, " to ", destination)

func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null

func my_side() -> Piece.Owner:
	return Piece.Owner.BLUE if is_host() else Piece.Owner.RED

signal network_croce_ready(merged_pieces: Array)

var received_croce: Dictionary = {}
const EXPECTED_PLAYERS := 2

@rpc("any_peer", "call_local", "reliable")
func submit_croce_placement(pieces_data: Array) -> void:
	if not is_host():
		return
	# When a peer sends an RPC to itself, Godot reports the sender as 0 instead
	# of the peer's real id (this is the same quirk report_move ran into
	# earlier). Correct for it here so the host always attributes its own
	# submission to its own real id.
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var real_owner: Piece.Owner = Piece.Owner.BLUE if sender == 1 else Piece.Owner.RED
	var corrected: Array = []
	for piece_data in pieces_data:
		var d: Dictionary = piece_data.duplicate()
		d["owner"] = real_owner
		corrected.append(d)
	received_croce[sender] = corrected
	print("NetworkManager: host received Croce placement from peer ", sender,
		" — ", pieces_data.size(), " pieces")
	print("NetworkManager: host now has placements from ", received_croce.keys())
	if received_croce.size() >= EXPECTED_PLAYERS:
		_broadcast_merged_croce()

func _broadcast_merged_croce() -> void:
	# Give every piece one shared id, unique across both sides, replacing each
	# side's own private numbering.
	var merged: Array = []
	var uid := 1
	for peer_id in received_croce.keys():
		for piece_data in received_croce[peer_id]:
			var d: Dictionary = piece_data.duplicate()
			d["uid"] = uid
			uid += 1
			merged.append(d)
	print("NetworkManager: host merged ", merged.size(), " pieces, starting the game")
	receive_merged_croce.rpc(merged)

@rpc("authority", "call_local", "reliable")
func receive_merged_croce(merged_pieces: Array) -> void:
	print("NetworkManager: received merged board — ", merged_pieces.size(), " pieces")
	network_croce_ready.emit(merged_pieces)

signal move_requested(sender_id: int, piece_uid: int, destination: Vector2i)
signal move_applied(piece_uid: int, destination: Vector2i)

@rpc("any_peer", "call_local", "reliable")
func request_move(piece_uid: int, destination: Vector2i) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	move_requested.emit(sender, piece_uid, destination)

@rpc("authority", "reliable")
func apply_move(piece_uid: int, destination: Vector2i) -> void:
	move_applied.emit(piece_uid, destination)

signal turn_end_requested(sender_id: int)
signal turn_ended()

@rpc("any_peer", "call_local", "reliable")
func request_end_turn() -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	turn_end_requested.emit(sender)

@rpc("authority", "call_local", "reliable")
func broadcast_end_turn() -> void:
	turn_ended.emit()
signal turn_timer_started(seconds: float)
signal turn_timer_cancelled()
signal turn_timer_pause_changed(paused: bool)

# Host tells both clients to start/stop showing the countdown. The host owns
# the real clock; the client bar is a visual estimate of it.
@rpc("authority", "call_local", "reliable")
func broadcast_turn_timer_start(seconds: float) -> void:
	turn_timer_started.emit(seconds)

func broadcast_turn_timer_cancel() -> void:
	turn_timer_cancelled.emit()
	
# The acting player asks the host to pause; the host mirrors it to both bars,
# so the host's authoritative clock stops too and nobody is timed out mid-card.
@rpc("any_peer", "call_local", "reliable")
func request_turn_timer_pause(paused: bool) -> void:
	if not is_host():
		return
	broadcast_turn_timer_pause.rpc(paused)

@rpc("authority", "call_local", "reliable")
func broadcast_turn_timer_pause(paused: bool) -> void:
	turn_timer_pause_changed.emit(paused)

signal rule_settings_received(settings: Dictionary)

@rpc("any_peer", "reliable")
func request_rule_settings() -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var rs = get_node_or_null("/root/RuleSettings")
	if rs == null:
		return
	var snapshot := {
		"close_call_shields_all_simultaneous_mutuals": rs.close_call_shields_all_simultaneous_mutuals,
		"c_captures_resolve_independently": rs.c_captures_resolve_independently,
		"general_can_capture_cycle_pieces": rs.general_can_capture_cycle_pieces,
		"mutual_destruction_both_draw": rs.mutual_destruction_both_draw,
		"blitzkrieg_old_different_piece": rs.blitzkrieg_old_different_piece,
		"require_move_to_end_turn": rs.require_move_to_end_turn,
		"objective_saboteurs_only": rs.objective_saboteurs_only,
		"ityd_deployment_zone_only": rs.ityd_deployment_zone_only,
		"side_one_color": rs.side_one_color,
		"side_two_color": rs.side_two_color,
	}
	send_rule_settings.rpc_id(sender, snapshot)

@rpc("authority", "reliable")
func send_rule_settings(settings: Dictionary) -> void:
	var rs = get_node_or_null("/root/RuleSettings")
	if rs:
		rs.close_call_shields_all_simultaneous_mutuals = settings["close_call_shields_all_simultaneous_mutuals"]
		rs.c_captures_resolve_independently = settings["c_captures_resolve_independently"]
		rs.general_can_capture_cycle_pieces = settings["general_can_capture_cycle_pieces"]
		rs.mutual_destruction_both_draw = settings["mutual_destruction_both_draw"]
		rs.blitzkrieg_old_different_piece = settings["blitzkrieg_old_different_piece"]
		rs.require_move_to_end_turn = settings["require_move_to_end_turn"]
		rs.objective_saboteurs_only = settings["objective_saboteurs_only"]
		rs.ityd_deployment_zone_only = settings["ityd_deployment_zone_only"]
		rs.side_one_color = settings["side_one_color"]
		rs.side_two_color = settings["side_two_color"]
	rule_settings_received.emit(settings)

signal hand_state_received(my_hand_uids: Array, opponent_count: int, deck_count: int)

@rpc("authority", "reliable")
func receive_hand_state(my_hand_uids: Array, opponent_count: int, deck_count: int) -> void:
	hand_state_received.emit(my_hand_uids, opponent_count, deck_count)
	
var opponent_hand_count: int = 0

signal deck_synced(deck_uids: Array)

@rpc("authority", "reliable")
func sync_deck(deck_uids: Array) -> void:
	deck_synced.emit(deck_uids)
	
signal deploy_requested(sender_id: int, card_uids: Array)
signal deploy_applied(card_uids: Array)

@rpc("any_peer", "call_local", "reliable")
func request_deploy_simple(card_uids: Array) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	deploy_requested.emit(sender, card_uids)

@rpc("authority", "reliable")
func apply_deploy_simple(card_uids: Array) -> void:
	deploy_applied.emit(card_uids)
	
signal jto_requested(sender_id: int, card_uid: int, destination: Vector2i)
signal jto_applied(card_uid: int, destination: Vector2i)

@rpc("any_peer", "call_local", "reliable")
func request_jto(card_uid: int, destination: Vector2i) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	jto_requested.emit(sender, card_uid, destination)

@rpc("authority", "reliable")
func apply_jto(card_uid: int, destination: Vector2i) -> void:
	jto_applied.emit(card_uid, destination)

signal ityd_requested(sender_id: int, card_uid: int, piece_uid: int, cells: Array, orientation: int)
signal ityd_applied(card_uid: int, piece_uid: int, cells: Array, orientation: int)

@rpc("any_peer", "call_local", "reliable")
func request_ityd(card_uid: int, piece_uid: int, cells: Array, orientation: int) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	ityd_requested.emit(sender, card_uid, piece_uid, cells, orientation)

@rpc("authority", "reliable")
func apply_ityd(card_uid: int, piece_uid: int, cells: Array, orientation: int) -> void:
	ityd_applied.emit(card_uid, piece_uid, cells, orientation)

signal discard_requested(sender_id: int, card_uids: Array)
signal discard_applied(side: int, card_uids: Array)

@rpc("any_peer", "call_local", "reliable")
func request_discard(card_uids: Array) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	discard_requested.emit(sender, card_uids)

@rpc("authority", "reliable")
func apply_discard(side: int, card_uids: Array) -> void:
	discard_applied.emit(side, card_uids)

signal saboteur_requested(sender_id: int, type_uid: int, chart_uid: int, chosen_type: int, target_uid: int)
signal saboteur_applied(type_uid: int, chart_uid: int, chosen_type: int, target_uid: int)

@rpc("any_peer", "call_local", "reliable")
func request_saboteur(type_uid: int, chart_uid: int, chosen_type: int, target_uid: int) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	saboteur_requested.emit(sender, type_uid, chart_uid, chosen_type, target_uid)

@rpc("authority", "reliable")
func apply_saboteur(type_uid: int, chart_uid: int, chosen_type: int, target_uid: int) -> void:
	saboteur_applied.emit(type_uid, chart_uid, chosen_type, target_uid)
	
signal oma_requested(sender_id: int, type_uid: int, oma_uid: int, chosen_type: int)
signal oma_applied(type_uid: int, oma_uid: int, chosen_type: int)

@rpc("any_peer", "call_local", "reliable")
func request_oma(type_uid: int, oma_uid: int, chosen_type: int) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	oma_requested.emit(sender, type_uid, oma_uid, chosen_type)

@rpc("authority", "reliable")
func apply_oma(type_uid: int, oma_uid: int, chosen_type: int) -> void:
	oma_applied.emit(type_uid, oma_uid, chosen_type)

signal selection_changed(piece_uid: int)

@rpc("any_peer", "call_local", "reliable")
func broadcast_selection(piece_uid: int) -> void:
	# Purely cosmetic: tells the other window which piece is highlighted.
	# -1 means "nothing selected".
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	selection_changed.emit(piece_uid)

signal forfeit_requested(sender_id: int)
signal match_ended(winner: int, reason: String)
signal opponent_left()

@rpc("any_peer", "call_local", "reliable")
func request_forfeit() -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	forfeit_requested.emit(sender)

@rpc("authority", "call_local", "reliable")
func broadcast_match_end(winner: int, reason: String) -> void:
	match_ended.emit(winner, reason)

@rpc("any_peer", "reliable")
func notify_leaving() -> void:
	opponent_left.emit()

signal upnp_result(success: bool, external_ip: String, message: String)

var _upnp: UPNP = null
var _upnp_thread: Thread = null
var _upnp_mapped_port: int = 0

func host_game_upnp(port: int = DEFAULT_PORT) -> Error:
	var err := host_game(port)
	if err != OK:
		return err
	# Router discovery blocks for a couple of seconds, so it runs off-thread.
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))
	return OK

func _upnp_worker(port: int) -> void:
	var upnp := UPNP.new()
	if upnp.discover() != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_upnp_done", false, "", "No UPnP router found.")
		return
	var gw := upnp.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		call_deferred("_upnp_done", false, "", "Router found but not usable.")
		return
	# ENet is UDP.
	if upnp.add_port_mapping(port, port, "WireframeSaboteur", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_upnp_done", false, "", "Router refused to open the port.")
		return
	var ip := upnp.query_external_address()
	_upnp = upnp
	_upnp_mapped_port = port
	if ip == "":
		call_deferred("_upnp_done", false, "", "Port opened, but couldn't read the public address.")
		return
	call_deferred("_upnp_done", true, ip, "")

func _upnp_done(success: bool, ip: String, message: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
		external_address = ip
	upnp_status = message if not success else "Ready"
	upnp_result.emit(success, ip, message)

func upnp_cleanup() -> void:
	if _upnp and _upnp_mapped_port != 0:
		_upnp.delete_port_mapping(_upnp_mapped_port, "UDP")
	_upnp = null
	_upnp_mapped_port = 0

var external_address: String = ""
var upnp_status: String = "Checking router…"

signal request_rejected(reason: String)

@rpc("authority", "reliable")
func reject_request(reason: String) -> void:
	request_rejected.emit(reason)

const GAME_VERSION := "0.1.0"

signal join_succeeded()
signal join_failed(reason: String)

@rpc("any_peer", "reliable")
func submit_version(v: String) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if v != GAME_VERSION:
		version_rejected.rpc_id(sender, GAME_VERSION)
		# Let the message flush before dropping them.
		await get_tree().create_timer(0.5).timeout
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	version_accepted.rpc_id(sender)

@rpc("authority", "reliable")
func version_rejected(host_version: String) -> void:
	join_failed.emit("Version mismatch.\n\nHost is running %s\nYou are running %s\n\nBoth players need the same build." % [host_version, GAME_VERSION])

@rpc("authority", "reliable")
func version_accepted() -> void:
	join_succeeded.emit()
	
signal deploy_mirror_changed(visible: bool, pos: Vector2)

@rpc("any_peer", "unreliable_ordered")
func broadcast_deploy_mirror(is_visible: bool, pos: Vector2) -> void:
	# Cosmetic only. Unreliable — a dropped drag frame doesn't matter, and this
	# fires on every mouse move, which shouldn't clog the reliable channel.
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	deploy_mirror_changed.emit(is_visible, pos)
