extends Node
# ChatManager — non-authoritative player-to-player text channel for OnWS.
#
# Owns: chat message transport, shared cosmetic effect triggers.
# Owns nothing in GameState. Nothing here may mutate gameplay state, turn
# order, hands, deck, or pieces. If a feature needs to do that, it is not a
# chat feature and belongs in NetworkManager as a validated command.
#
# Transport follows the same request/apply pattern as NetworkManager:
#   client -> request_chat (host only) -> host sanitizes -> apply_chat (all)

signal message_received(side: int, text: String, seq: int)
signal effect_received(effect_id: String, side: int)
signal chat_rejected(reason: String)
signal typing_changed(is_typing: bool)
signal sticker_received(side: int, sticker_id: String)
signal placed_sticker_received(side: int, sticker_id: String, cell: Vector2i)

const MAX_LEN := 240
const RATE_WINDOW_MS := 4000   # sliding window for rate limiting
const RATE_LIMIT := 6          # messages allowed per window, per peer
const PLACE_COOLDOWN_MS := 4500  # placed stickers get their own, tighter budget

# Effect ids the host will relay. Anything not in here is dropped. Keep this
# list in sync with EasterEggs; the client-side table maps secret strings to
# these ids, and only the id ever crosses the wire.
const ALLOWED_SHARED_EFFECTS := [
	"confetti",
	"lightning",
	"static_burst",
	"eddystone",
]

var _seq: int = 0
var _stamps: Dictionary = {}   # peer_id -> Array[int] of ticks_msec
var _place_stamp: Dictionary = {}  # peer_id -> last placed-sticker tick
var muted: bool = false        # local-only: ignore incoming opponent messages

# ---------------------------------------------------------------- public API

func send_message(text: String) -> void:
	if not NetworkManager.is_networked():
		return
	var clean := _sanitize(text)
	if clean == "":
		return
	request_chat.rpc_id(1, clean)

func send_shared_effect(effect_id: String) -> void:
	if not NetworkManager.is_networked():
		return
	if not ALLOWED_SHARED_EFFECTS.has(effect_id):
		push_warning("ChatManager: unknown shared effect '%s'" % effect_id)
		return
	request_effect.rpc_id(1, effect_id)

func set_typing(is_typing: bool) -> void:
	if not NetworkManager.is_networked():
		return
	broadcast_typing.rpc(is_typing)

func reset() -> void:
	_seq = 0
	_stamps.clear()
	muted = false

# ------------------------------------------------------------------ messages

@rpc("any_peer", "call_local", "reliable")
func request_chat(text: String) -> void:
	if not NetworkManager.is_host():
		return
	var sender := _real_sender()
	if not _rate_ok(sender):
		if sender == multiplayer.get_unique_id():
			chat_rejected.emit("Slow down.")
		else:
			reject_chat.rpc_id(sender, "Slow down.")
		return
	var clean := _sanitize(text)
	if clean == "":
		return
	var side: int = Piece.Owner.BLUE if sender == 1 else Piece.Owner.RED
	_seq += 1
	apply_chat.rpc(side, clean, _seq)

@rpc("authority", "call_local", "reliable")
func apply_chat(side: int, text: String, seq: int) -> void:
	if muted and side != NetworkManager.my_side():
		return
	message_received.emit(side, text, seq)

@rpc("authority", "reliable")
func reject_chat(reason: String) -> void:
	chat_rejected.emit(reason)

# ------------------------------------------------------------- shared effects

@rpc("any_peer", "call_local", "reliable")
func request_effect(effect_id: String) -> void:
	if not NetworkManager.is_host():
		return
	var sender := _real_sender()
	if not ALLOWED_SHARED_EFFECTS.has(effect_id):
		return
	if not _rate_ok(sender):
		return
	var side: int = Piece.Owner.BLUE if sender == 1 else Piece.Owner.RED
	apply_effect.rpc(effect_id, side)

@rpc("authority", "call_local", "reliable")
func apply_effect(effect_id: String, side: int) -> void:
	if muted and side != NetworkManager.my_side():
		return
	effect_received.emit(effect_id, side)

# ------------------------------------------------------------------- stickers

func send_sticker(sticker_id: String) -> void:
	if not NetworkManager.is_networked():
		return
	if not StickerLibrary.is_valid(sticker_id):
		push_warning("ChatManager: unknown sticker '%s'" % sticker_id)
		return
	request_sticker.rpc_id(1, sticker_id)

func send_placed_sticker(sticker_id: String, cell: Vector2i) -> void:
	if not NetworkManager.is_networked():
		return
	if not StickerLibrary.is_valid(sticker_id):
		push_warning("ChatManager: unknown sticker '%s'" % sticker_id)
		return
	request_placed_sticker.rpc_id(1, sticker_id, cell)

@rpc("any_peer", "call_local", "reliable")
func request_sticker(sticker_id: String) -> void:
	if not NetworkManager.is_host():
		return
	var sender := _real_sender()
	if not StickerLibrary.is_valid(sticker_id):
		return
	if not _rate_ok(sender):
		return
	var side: int = Piece.Owner.BLUE if sender == 1 else Piece.Owner.RED
	apply_sticker.rpc(side, sticker_id)

@rpc("authority", "call_local", "reliable")
func apply_sticker(side: int, sticker_id: String) -> void:
	if muted and side != NetworkManager.my_side():
		return
	sticker_received.emit(side, sticker_id)

@rpc("any_peer", "call_local", "reliable")
func request_placed_sticker(sticker_id: String, cell: Vector2i) -> void:
	if not NetworkManager.is_host():
		return
	var sender := _real_sender()
	if not StickerLibrary.is_valid(sticker_id):
		return
	if not _place_ok(sender):
		return
	var side: int = Piece.Owner.BLUE if sender == 1 else Piece.Owner.RED
	apply_placed_sticker.rpc(side, sticker_id, cell)

@rpc("authority", "call_local", "reliable")
func apply_placed_sticker(side: int, sticker_id: String, cell: Vector2i) -> void:
	if muted and side != NetworkManager.my_side():
		return
	placed_sticker_received.emit(side, sticker_id, cell)

# ------------------------------------------------------------------- presence

@rpc("any_peer", "unreliable")
func broadcast_typing(is_typing: bool) -> void:
	# Cosmetic. Ignore the echo of our own call.
	if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
		return
	typing_changed.emit(is_typing)

# -------------------------------------------------------------------- helpers

func _real_sender() -> int:
	# Godot reports sender 0 when a peer RPCs itself. Same quirk NetworkManager
	# corrects for in submit_croce_placement.
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return sender

func _sanitize(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		var code := c.unicode_at(0)
		# Drop control characters, including newlines and tabs.
		if code < 32 or code == 127:
			continue
		out += c
	out = out.strip_edges()
	if out.length() > MAX_LEN:
		out = out.substr(0, MAX_LEN)
	return out

func _place_ok(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _place_stamp.get(peer_id, -PLACE_COOLDOWN_MS)
	if now - last < PLACE_COOLDOWN_MS:
		return false
	_place_stamp[peer_id] = now
	return true
	
func _rate_ok(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var list: Array = _stamps.get(peer_id, [])
	var kept: Array = []
	for t in list:
		if now - t < RATE_WINDOW_MS:
			kept.append(t)
	if kept.size() >= RATE_LIMIT:
		_stamps[peer_id] = kept
		return false
	kept.append(now)
	_stamps[peer_id] = kept
	return true
