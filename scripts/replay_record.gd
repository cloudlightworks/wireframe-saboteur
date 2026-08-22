extends RefCounted
class_name ReplayRecord
# Parses a .wfs match record and reconstructs the board at any turn.
#
# Standalone by design: it never touches GameState, RulesEngine, or the live
# match. It rebuilds real Piece resources from the file so PieceView can render
# them exactly as in play, but nothing here can mutate a game in progress.
#
# No rules engine is needed. The record contains both the opening position and
# every board-changing event, so stepping forward is applying recorded facts,
# not deriving them. That is what makes the viewer independent of the
# RulesEngine consolidation work.

var ok: bool = false
var error: String = ""

var header: Dictionary = {}
var events: Array = []

# Turn boundaries: index into `events` where each turn ends. Built once so the
# scrubber can jump without replaying from the start every frame.
var turn_ends: Array = []          # event index of each "end" event
var final_turn: int = 0

var recorded_by: String = ""       # "blue" (host) or "red" (client)
var transcript_hash: String = ""
var is_local: bool = false         # hotseat / cpu / debug — nothing to corroborate


static func card_for(uid: int) -> Card:
	for c in CardDatabase.build_full_deck():
		if c.uid == uid:
			return c
	return null

static func card_label(uid: int) -> String:
	var c := card_for(uid)
	if c == null:
		return "?"
	match c.category:
		Card.Category.CHART:
			return "%d/%d/%d" % [c.chart_values.get(Piece.Type.A, 0), c.chart_values.get(Piece.Type.B, 0), c.chart_values.get(Piece.Type.C, 0)]
		Card.Category.TYPE:
			var s := ""
			for t in c.piece_types:
				s += ["A", "B", "C"][int(t)]
			return s
		Card.Category.MINOR_POWER:
			var suffix: String = ["A", "B", "C"][int(c.effect_piece_type)] if int(c.effect_piece_type) < 3 else ""
			match c.minor_effect:
				Card.MinorEffect.GET_MOVE_ON: return "GMO-" + suffix
				Card.MinorEffect.CLOSE_CALL: return "CC-" + suffix
				Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD: return "ITYD-" + suffix
				Card.MinorEffect.JUST_IN_CASE: return "JIC"
		Card.Category.MAJOR_POWER:
			match c.major_effect:
				Card.MajorEffect.INEFFECTIVE_LEADERSHIP: return "IL"
				Card.MajorEffect.HE_SEEMED_SUSPICIOUS: return "HSS"
				Card.MajorEffect.JUST_THIS_ONCE: return "JTO"
				Card.MajorEffect.BLITZKRIEG: return "BK"
				Card.MajorEffect.IM_ON_TO_YOU: return "IOTY"
				Card.MajorEffect.ONE_MAN_ARMY: return "OMA"
				Card.MajorEffect.DOUBLE_AGENT: return "DA"
	return "?"
	
# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

func load_from(path: String) -> bool:
	ok = false
	error = ""
	if not FileAccess.file_exists(path):
		error = "That file isn't there any more."
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		error = "Couldn't open that file."
		return false
	var raw := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "That doesn't look like a match record."
		return false
	if parsed.get("magic", "") != "WFSREC":
		error = "That isn't a Wireframe Saboteur record."
		return false

	header = parsed
	events = parsed.get("events", [])
	recorded_by = parsed.get("recorded_by", "")
	transcript_hash = parsed.get("transcript_hash", "")
	var mode: String = parsed.get("mode", "")
	is_local = mode != "online"

	if not header.has("croce"):
		error = "This record has no opening position."
		return false

	_index_turns()
	ok = true
	return true

func _index_turns() -> void:
	turn_ends.clear()
	for i in range(events.size()):
		if events[i].get("t", "") == "end":
			turn_ends.append(i)
	final_turn = int(header.get("result", {}).get("turns", turn_ends.size()))

# ---------------------------------------------------------------------------
# Board reconstruction
# ---------------------------------------------------------------------------

# Rebuild the opening position as real Piece resources, keyed by uid.
func opening_pieces() -> Dictionary:
	var out: Dictionary = {}
	var croce: Dictionary = header.get("croce", {})
	for side_key in ["blue", "red"]:
		var owner: int = Piece.Owner.BLUE if side_key == "blue" else Piece.Owner.RED
		for entry in croce.get(side_key, []):
			var p := Piece.new()
			p.uid = int(entry.get("uid", 0))
			p.designation = str(entry.get("designation", ""))
			p.type = int(entry.get("type", 0)) as Piece.Type
			p.owner = owner
			p.original_owner = owner
			p.orientation = int(entry.get("orientation", 0)) as Piece.PieceOrientation
			var cells: Array[Vector2i] = []
			for c in entry.get("cells", []):
				cells.append(Vector2i(int(c[0]), int(c[1])))
			p.cells = cells
			out[p.uid] = p
	return out

# State at a given event index: pieces plus a plain-language account of the
# turn that just finished. Rebuilt from the opening each time — a match is a
# few hundred events, so this is cheap and avoids any incremental-state bugs.
func state_at(event_index: int) -> Dictionary:
	var pieces := opening_pieces()
	var captured_blue: int = 0
	var captured_red: int = 0
	var last_move_cells: Array = []
	var capture_cells: Array = []
	var lines: Array = []
	var turn_no: int = 1
	var hands := {Piece.Owner.BLUE: [], Piece.Owner.RED: []}

	var limit: int = mini(event_index, events.size() - 1)
	for i in range(limit + 1):
		var e: Dictionary = events[i]
		var t: String = e.get("t", "")
		match t:
			"move":
				var uid: int = int(e.get("p", -1))
				if pieces.has(uid):
					var cells: Array[Vector2i] = []
					for c in e.get("to", []):
						cells.append(Vector2i(int(c[0]), int(c[1])))
					pieces[uid].cells = cells
					last_move_cells = cells
					capture_cells = []
					lines = ["%s moves %s" % [_side_word(e.get("by", 0)), pieces[uid].designation]]
			"cap":
				var cuid: int = int(e.get("p", -1))
				if pieces.has(cuid):
					var victim: Piece = pieces[cuid]
					if victim.owner == Piece.Owner.BLUE:
						captured_blue += 1
					else:
						captured_red += 1
					var cc: Array = []
					for c in e.get("cells", []):
						cc.append(Vector2i(int(c[0]), int(c[1])))
					capture_cells.append_array(cc)
					lines.append("takes %s %s" % [_side_word(int(victim.owner)), victim.designation])
					pieces.erase(cuid)
			"sab":
				var tuid: int = int(e.get("target", -1))
				if pieces.has(tuid):
					pieces[tuid].apply_saboteur_conversion(int(e.get("by", 0)) as Piece.Owner)
					lines.append("%s turns %s" % [_side_word(e.get("by", 0)), pieces[tuid].designation])
			"double_agent":
				var duid: int = int(e.get("target", -1))
				if pieces.has(duid):
					pieces[duid].reverse_saboteur_conversion(int(e.get("by", 0)) as Piece.Owner)
					lines.append("%s recovers %s" % [_side_word(e.get("by", 0)), pieces[duid].designation])
			"ityd":
				var iuid: int = int(e.get("p", -1))
				var icells: Array[Vector2i] = []
				for c in e.get("cells", []):
					icells.append(Vector2i(int(c[0]), int(c[1])))
				# A returned piece is absent from the live set; rebuild a stub
				# from the opening roster so it renders with its real identity.
				var roster := opening_pieces()
				if roster.has(iuid):
					var rp: Piece = roster[iuid]
					rp.cells = icells
					rp.orientation = int(e.get("orient", 0)) as Piece.PieceOrientation
					pieces[iuid] = rp
					lines.append("%s returns %s" % [_side_word(e.get("by", 0)), rp.designation])
			"jto":
				var d = e.get("dest", [0, 0])
				lines.append("%s moves the objective" % _side_word(e.get("by", 0)))
			"draw":
				var dby: int = int(e.get("by", 0))
				if e.has("card"):
					hands[dby].append(int(e["card"]))
				lines.append("%s draws" % _side_word(dby))
			"disc":
				var qby: int = int(e.get("by", 0))
				if e.has("card"):
					hands[qby].erase(int(e["card"]))
			"gamo":
				lines.append("%s plays Get Move On" % _side_word(e.get("by", 0)))
			"close_call":
				lines.append("%s plays Close Call" % _side_word(e.get("by", 0)))
			"blitzkrieg":
				lines.append("%s plays Blitzkrieg" % _side_word(e.get("by", 0)))
			"oma":
				lines.append("%s plays One Man Army" % _side_word(e.get("by", 0)))
			"just_in_case":
				lines.append("%s plays Just In Case" % _side_word(e.get("by", 0)))
			"im_on_to_you":
				lines.append("%s plays I'm On To You" % _side_word(e.get("by", 0)))
			"he_seemed":
				lines.append("%s plays He Seemed Suspicious" % _side_word(e.get("by", 0)))
			"end":
				turn_no = int(e.get("turn", turn_no)) + 1

	return {
		"pieces": pieces,
		"lines": lines,
		"turn": turn_no,
		"move_cells": last_move_cells,
		"capture_cells": capture_cells,
		"captured_blue": captured_blue,
		"captured_red": captured_red,
		"hands": hands,
	}

# Event index at the END of a given turn number, for the scrubber.
func event_index_for_turn(turn: int) -> int:
	if turn_ends.is_empty():
		return events.size() - 1
	var idx: int = clampi(turn - 1, 0, turn_ends.size() - 1)
	return turn_ends[idx]

func turn_count() -> int:
	return maxi(turn_ends.size(), 1)

# ---------------------------------------------------------------------------
# Corroboration — the indenture check
# ---------------------------------------------------------------------------

# Compare against the other player's copy. Returns a dictionary describing the
# fit, in the vocabulary the viewer displays.
func fit_against(other: ReplayRecord) -> Dictionary:
	if other == null or not other.ok:
		return {"state": "single", "note": ""}
	if recorded_by == other.recorded_by:
		return {"state": "same_side", "note": "Both of these are the %s's copy." % _role_word(recorded_by)}
	if is_local or other.is_local:
		return {"state": "local", "note": "Local matches have only one witness."}
	if transcript_hash != "" and transcript_hash == other.transcript_hash:
		return {"state": "fitted", "note": ""}

	# They disagree. Find the first turn whose board hash differs — that is the
	# turn the two accounts part company, and the only useful thing to report.
	var mine := _board_hashes()
	var theirs := other._board_hashes()
	for turn in mine.keys():
		if theirs.has(turn) and theirs[turn] != mine[turn]:
			return {"state": "mismatch", "note": "Records disagree from turn %d." % turn}
		# Boards agree at every turn but the transcripts still differ — the two
	# copies witnessed the same game and recorded it differently. That is a
	# gap in what each side logs, not a disputed match.
	return {"state": "boards_agree", "note": "The boards match, but the records don't fit."}

func _board_hashes() -> Dictionary:
	var out: Dictionary = {}
	for e in events:
		if e.get("t", "") == "end" and e.has("bh"):
			out[int(e.get("turn", 0))] = str(e["bh"])
	return out

# ---------------------------------------------------------------------------

func _side_word(side) -> String:
	return "host" if int(side) == Piece.Owner.BLUE else "client"

func _role_word(key: String) -> String:
	return "host" if key == "blue" else "client"
