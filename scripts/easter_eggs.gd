extends Node
class_name EasterEggs
# Secret-code table for the chat box.
#
# A code is typed into chat as /code, *code, or *code*. On a match the text is
# CONSUMED — it never reaches the network and the opponent never sees it.
#
# Scope rules:
#   "local"  — only the typing player sees the result. Nothing on the wire.
#   "shared" — both players see it. The effect id (never the code) is sent to
#              the host, which checks it against ChatManager.ALLOWED_SHARED_EFFECTS.
#
# Effects are COSMETIC ONLY. Nothing here may touch GameState, hands, deck,
# turn order, or pieces. If you want a code to change the game, it stops being
# an easter egg and has to become a validated command in NetworkManager.

const CODES := {
	# code (lowercase, no punctuation) : { scope, effect }
	"eddystone":  {"scope": "shared", "effect": "eddystone"},
	"lighthouse": {"scope": "shared", "effect": "eddystone"},
	"confetti":   {"scope": "shared", "effect": "confetti"},
	"storm":      {"scope": "shared", "effect": "lightning"},
	"static":     {"scope": "local",  "effect": "static_burst"},
}

# Strips the /, *, or *…* wrapper and normalizes. Returns "" if the text isn't
# in code form at all (so ordinary messages fall straight through).
static func extract_code(raw: String) -> String:
	var t := raw.strip_edges()
	if t == "":
		return ""
	if not (t.begins_with("/") or t.begins_with("*")):
		return ""
	while t.begins_with("/") or t.begins_with("*"):
		t = t.substr(1)
	while t.ends_with("*") or t.ends_with("/"):
		t = t.substr(0, t.length() - 1)
	return t.strip_edges().to_lower()

static func lookup(code: String) -> Dictionary:
	return CODES.get(code, {})
