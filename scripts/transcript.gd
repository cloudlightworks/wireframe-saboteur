extends Node
# Transcript — canonical serialization and hashing for the public half of a
# .wfs match record. Autoload as "Transcript".
#
# THE POINT: two machines that witnessed the same match must produce
# byte-identical transcript strings, so their hashes match and their
# signatures corroborate. Every rule in this file exists to kill one
# specific source of cross-machine variance. Do not "tidy" the
# serialization: whitespace, key order, and float formatting are exactly
# the things that break it.
#
# PUBLIC (hashed): match identity, player ids/keys, rules, board dims,
#   deck SIZE, both Croce placements, the event stream, per-turn board
#   hashes, result.
# PRIVATE (never hashed): hands, deck ORDER, display names. Deck order is
#   private for the same reason it was once a leak: only the host
#   legitimately holds it, so it cannot be part of what both sides hash.
#
# The human-readable .wfs stays JSON. The HASH is computed over the
# canonical string produced here — two representations, one canonical.
#
# Versioning: any change to serialization, field order, or which fields
# are included REQUIRES bumping ReplayRecorder.FORMAT_VERSION. A v2 hash
# can never be recomputed from a v3 serializer.

const SEP := "|"

# ---------------------------------------------------------------------------
# Board hash — the DEF-002 divergence detector.
# Called at each turn boundary. Pieces sorted by uid; captured pieces are
# EXCLUDED (they are not on the board, and including them would drag the
# private capture bookkeeping into the public hash).
# ---------------------------------------------------------------------------

static func board_hash(game_state) -> String:
	return canonical_pieces_string(game_state).sha256_text()

static func canonical_pieces_string(game_state) -> String:
	var uids: Array = game_state.pieces.keys()
	uids.sort()
	var parts: Array = []
	for uid in uids:
		parts.append(_piece_tuple(game_state.pieces[uid]))
	return SEP.join(parts)

# Fixed-order tuple. owner is CURRENT owner (a converted saboteur reads as
# its controller); original_owner is separate so conversion stays visible.
# Only the saboteur status enters the hash — it is the only piece-level
# status that changes public legality. Cells sorted (x,y) lexicographically
# so storage order can never differ between machines.
static func _piece_tuple(p) -> String:
	var cells: Array = []
	for c in p.cells:
		cells.append(Vector2i(c.x, c.y))
	cells.sort_custom(func(a, b):
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	var cell_strs: Array = []
	for c in cells:
		cell_strs.append("%d,%d" % [c.x, c.y])
	var sab := 1 if p.has_status("saboteur") else 0
	return "u%dt%do%dg%dr%ds%dc%s" % [
		p.uid, int(p.type), int(p.owner), int(p.original_owner),
		int(p.orientation), sab, ";".join(cell_strs)
	]

# ---------------------------------------------------------------------------
# Event canonicalization.
# Events are stored as JSON dictionaries in the .wfs for readability, but the
# hash is computed over this fixed-order string form. Field order per event
# type is pinned HERE, not by dictionary iteration order.
# ---------------------------------------------------------------------------

# Every event type and the exact field order that enters the hash.
# Adding a type or a field = FORMAT_VERSION bump.
const EVENT_FIELDS := {
	"move":         ["n", "by", "p", "from", "to"],
	"cap":          ["n", "owner", "p", "cells"],
	"draw":         ["n", "by"],            # card uid is PRIVATE — the draw is public, the card is not
	"disc":         ["n", "by", "card"],    # discards are face-up: card is public
	"end":          ["n", "by", "turn", "bh"],
	"sab":          ["n", "by", "target", "declared", "cards"],
	"ityd":         ["n", "by", "p", "cells", "orient"],
	"jto":          ["n", "by", "dest"],
	"gamo":         ["n", "by", "ptype"],
	"close_call":   ["n", "by", "ptype"],
	"oma":          ["n", "by", "ptype", "cards"],
	"blitzkrieg":   ["n", "by"],
	"just_in_case": ["n", "by"],
	"im_on_to_you": ["n", "by"],
	"he_seemed":    ["n", "by"],
	"double_agent": ["n", "by", "target"],
}

static func canonical_event(e: Dictionary) -> String:
	var t: String = e.get("t", "")
	if not EVENT_FIELDS.has(t):
		# Unknown event types are excluded from the hash rather than guessed
		# at. A reader that sees a hash mismatch AND an unknown type knows the
		# file came from a newer writer.
		return ""
	var parts: Array = ["t:" + t]
	for field in EVENT_FIELDS[t]:
		if not e.has(field):
			continue
		parts.append("%s:%s" % [field, _canon_value(e[field])])
	if e.get("d", false):
		parts.append("d:1")
	return ",".join(parts)

static func _canon_value(v) -> String:
	if v is Array:
		var inner: Array = []
		for item in v:
			inner.append(_canon_value(item))
		return "[" + ";".join(inner) + "]"
	if v is bool:
		return "1" if v else "0"
	return str(v)

# ---------------------------------------------------------------------------
# Full transcript.
# Field order is THE format. Everything here must be identical on both
# machines; anything that couldn't be goes in the private half instead.
# ---------------------------------------------------------------------------

static func build(header: Dictionary, events: Array) -> String:
	var parts: Array = []
	parts.append("v:%s" % str(header.get("format_version", 0)))
	parts.append("gv:%s" % str(header.get("game_version", "")))
	parts.append("m:%s" % str(header.get("match_id", "")))

	var players: Dictionary = header.get("players", {})
	for side in ["blue", "red"]:
		var pl: Dictionary = players.get(side, {})
		# id + pubkey only. Names are display text and MUST NOT enter the
		# hash: renaming yourself cannot be allowed to break corroboration.
		parts.append("p_%s:%s:%s" % [side, str(pl.get("id", "")), str(pl.get("pubkey", "")).sha256_text()])

	var rules: Dictionary = header.get("rules", {})
	var rule_parts: Array = []
	for k in RuleSettings.RULE_KEYS:   # list order IS the canonical order
		rule_parts.append("1" if rules.get(k, false) else "0")
	parts.append("r:" + "".join(rule_parts))

	var b: Dictionary = header.get("board", {})
	parts.append("b:%d,%d,%d" % [int(b.get("width", 0)), int(b.get("height", 0)), int(b.get("home_rows_per_side", 0))])

	parts.append("ds:%d" % int(header.get("deck_size", 0)))

	var croce: Dictionary = header.get("croce", {})
	for side in ["blue", "red"]:
		var placed: Array = croce.get(side, []).duplicate()
		placed.sort_custom(func(a, b): return int(a.get("uid", 0)) < int(b.get("uid", 0)))
		var pc: Array = []
		for entry in placed:
			var cells: Array = entry.get("cells", [])
			var cell_strs: Array = []
			for c in cells:
				cell_strs.append("%d,%d" % [int(c[0]), int(c[1])])
			cell_strs.sort()
			pc.append("u%dt%dr%dc%s" % [
				int(entry.get("uid", 0)), int(entry.get("type", 0)),
				int(entry.get("orientation", 0)), ";".join(cell_strs)
			])
		parts.append("c_%s:%s" % [side, SEP.join(pc)])

	var ev_parts: Array = []
	for e in events:
		var ce := canonical_event(e)
		if ce != "":
			ev_parts.append(ce)
	parts.append("e:" + SEP.join(ev_parts))

	var res: Dictionary = header.get("result", {})
	parts.append("res:%s,%s,%d" % [str(res.get("winner", "")), str(res.get("reason", "")), int(res.get("turns", 0))])

	return "\n".join(parts)

static func transcript_hash(header: Dictionary, events: Array) -> String:
	return build(header, events).sha256_text()
