extends Node
class_name StickerLibrary
# Registry of sendable images ("taunts"). Only the id crosses the network —
# never image bytes — so a client can't push arbitrary data at its opponent.
#
# To add one: drop a 256x256 PNG in res://assets/stickers/ and add a row below.
# Until the file exists, the chat falls back to drawing the label as text, so
# you can wire and test the whole flow before any art is finished.

const DIR := "res://assets/stickers/"

const STICKERS := {
	"stuck_general":     {"label": "stuck, general?",           "file": "stuck_general.png",    "cat": "taunt"},
	"jim":               {"label": "can't hide behind jim",     "file": "jim.png",              "cat": "taunt"},
	"suspicious_one":    {"label": "that's the suspicious one?", "file": "suspicious_one.png",   "cat": "taunt"},
	"sure_piece":        {"label": "sure about that piece?",     "file": "sure_piece.png",       "cat": "taunt"},
	"careful_now":       {"label": "careful, now…",              "file": "careful_now.png",      "cat": "taunt"},
	"sabotaged":         {"label": "sabotaged",                  "file": "sabotaged.png",        "cat": "taunt"},
	"too_slow":          {"label": "too slow",                   "file": "too_slow.png",         "cat": "taunt"},
	"boom":              {"label": "boom",                       "file": "boom.png",             "cat": "taunt"},
	"your_move":         {"label": "your move",                  "file": "your_move.png",        "cat": "taunt"},
	"uh_oh":             {"label": "uh oh…",                     "file": "uh_oh.png",            "cat": "taunt"},
	"oof":               {"label": "oof",                        "file": "oof.png",              "cat": "taunt"},
	"exclaim_question":  {"label": "!?",                         "file": "exclaim_question.png", "cat": "taunt"},
}

# Order the picker shows them in. Ids not listed here are appended after.
const ORDER := [
	"stuck_general", "jim", "suspicious_one", "sure_piece", "careful_now",
	"sabotaged", "too_slow", "boom", "your_move", "uh_oh", "oof", "exclaim_question",
]

static func is_valid(id: String) -> bool:
	return STICKERS.has(id)

static func label_for(id: String) -> String:
	var row: Dictionary = STICKERS.get(id, {})
	return row.get("label", id)

# Returns null when the art isn't there yet — callers fall back to the label.
static func texture_for(id: String) -> Texture2D:
	var row: Dictionary = STICKERS.get(id, {})
	if row.is_empty():
		return null
	var path: String = DIR + str(row.get("file", ""))
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res as Texture2D

static func ordered_ids() -> Array:
	var out: Array = []
	for id in ORDER:
		if STICKERS.has(id):
			out.append(id)
	for id in STICKERS.keys():
		if not out.has(id):
			out.append(id)
	return out
