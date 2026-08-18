extends Node
# Opt-in local match recorder.
#
# Writes one .wfs file per completed match to user://replays/. Recording is
# per-player and local: each side keeps its own copy. A file is one player's
# account of a match, not a neutral record — see "recorded_by".
#
# Records commands (what a player did) AND derived effects (what followed).
# Commands alone would be replayable only once a headless engine exists;
# recording effects alongside means a future replayer can compare its own
# derivation against what actually happened, which is divergence detection
# rather than just playback.
#
# Nothing here is authoritative. No rule reads it, and failure to record must
# never affect play — every entry point no-ops when inactive.

const FORMAT_VERSION := 1
const DIR := "user://replays/"

var active: bool = false

var _header: Dictionary = {}
var _events: Array = []
var _seq: int = 0
var _started_ms: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

# Called once the deck is shuffled and both Croce placements are on the board.
func start_match(game_state, mode: String, my_side: int) -> void:
	active = false
	_events.clear()
	_seq = 0
	if not SettingsManager.record_matches:
		return
	if game_state == null:
		return

	_started_ms = Time.get_ticks_msec()
	var nm := get_node_or_null("/root/NetworkManager")
	var gs_setup := get_node_or_null("/root/GameSetup")

	var networked: bool = nm != null and nm.is_networked()
	var vs_cpu: bool = gs_setup != null and gs_setup.vs_cpu
	# Only a networked two-human match can ever support a verified result.
	var rankable: bool = networked and not vs_cpu

	_header = {
		"magic": "WFSREC",
		"format_version": FORMAT_VERSION,
		"game_version": nm.GAME_VERSION if nm != null else "unknown",
		"match_id": _match_id(nm),
		"started_at": Time.get_datetime_string_from_system(true),
		"mode": mode,
		"rankable": rankable,
		"corroborable": false,   # set true when the opponent reports recording
		"recorded_by": "blue" if my_side == Piece.Owner.BLUE else "red",
		"players": _players(nm, gs_setup, vs_cpu),
		"rules": RuleSettings.rules_snapshot(),
		"board": {
			"width": BoardView.board_width,
			"height": BoardView.board_height,
			"home_rows_per_side": game_state.board.home_rows_per_side,
		},
		"deck": _deck_uids(game_state),
		"croce": _croce(game_state),
	}
	active = true

func finish_match(winner: int, reason: String, turns: int) -> void:
	if not active:
		return
	_header["ended_at"] = Time.get_datetime_string_from_system(true)
	_header["duration_ms"] = Time.get_ticks_msec() - _started_ms
	_header["result"] = {
		"winner": _side_key(winner),
		"reason": reason,
		"turns": turns,
	}
	_write()
	active = false

# A match that ended without a result — quit to menu, crash recovery, etc.
func abandon() -> void:
	if not active:
		return
	finish_match(-1, "abandoned", _events.size())

# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------

# `derived` marks an effect that followed from a command rather than a player
# input. A replayer should be able to reproduce these; it must be given the rest.
func record(event: Dictionary, derived: bool = false) -> void:
	if not active:
		return
	_seq += 1
	event["n"] = _seq
	if derived:
		event["d"] = true
	_events.append(event)

func note_opponent_recording(is_recording: bool) -> void:
	if not active:
		return
	_header["corroborable"] = is_recording and _header.get("rankable", false)

# ---------------------------------------------------------------------------
# Header assembly
# ---------------------------------------------------------------------------

func _match_id(nm) -> String:
	# Host-supplied in networked play so both sides agree. Until that protocol
	# field lands, fall back to a local id — usable for solo review, but two
	# files from the same match will not yet be linkable.
	if nm != null and nm.get("match_id") != null and nm.match_id != "":
		return nm.match_id
	return Crypto.new().generate_random_bytes(12).hex_encode()

func _players(nm, gs_setup, vs_cpu: bool) -> Dictionary:
	var out := {}
	for side in [Piece.Owner.BLUE, Piece.Owner.RED]:
		var key := _side_key(side)
		var is_cpu: bool = vs_cpu and gs_setup != null and side == gs_setup.cpu_side
		var entry := {
			"name": RuleSettings.display_name(side),
			"color": RuleSettings.side_one_color if side == Piece.Owner.BLUE else RuleSettings.side_two_color,
			"is_cpu": is_cpu,
			"id": "",
			"pubkey": "",
		}
		# Only this machine's own identity is known for certain. The opponent's
		# arrives over the wire once the handshake carries it.
		if nm != null and nm.is_networked() and side == nm.my_side():
			entry["id"] = PlayerIdentity.player_id
			entry["pubkey"] = PlayerIdentity.public_key_pem()
		elif nm == null or not nm.is_networked():
			if not is_cpu:
				entry["id"] = PlayerIdentity.player_id
		out[key] = entry
	return out

func _deck_uids(game_state) -> Array:
	var out := []
	for c in game_state.deck:
		out.append(c.uid)
	return out

func _croce(game_state) -> Dictionary:
	var out := {"blue": [], "red": []}
	for uid in game_state.pieces:
		var p = game_state.pieces[uid]
		out[_side_key(p.owner)].append({
			"uid": p.uid,
			"designation": p.designation,
			"type": int(p.type),
			"orientation": int(p.orientation),
			"cells": cells_to_array(p.cells),
		})
	return out

# ---------------------------------------------------------------------------
# Encoding helpers — network and file representations must never carry engine
# objects, only explicit serializable data.
# ---------------------------------------------------------------------------

static func cell_to_array(c: Vector2i) -> Array:
	return [c.x, c.y]

static func cells_to_array(cells) -> Array:
	var out := []
	for c in cells:
		out.append([c.x, c.y])
	return out

func _side_key(side: int) -> String:
	if side == Piece.Owner.BLUE:
		return "blue"
	if side == Piece.Owner.RED:
		return "red"
	return "null"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

func _write() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var doc := _header.duplicate(true)
	doc["events"] = _events
	var text := JSON.stringify(doc, "  ")
	# Sign the body so a record is bound to the identity that produced it.
	doc["signature"] = PlayerIdentity.sign_text(text)
	doc["content_hash"] = text.sha256_text()
	var final_text := JSON.stringify(doc, "  ")

	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
	var path := "%s%s_%s.wfs" % [DIR, stamp, str(_header.get("match_id", "x")).substr(0, 8)]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("ReplayRecorder: could not write %s" % path)
		return
	f.store_string(final_text)
	print("Replay written: ", path)
