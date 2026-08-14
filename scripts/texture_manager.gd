extends Node

# Resolves art for the active texture pack.
#
# Two kinds of pack:
#   built-in  - art under res://, loaded with load(), imported at build time
#   user      - art under user://textures/<id>/, loaded with Image.load()
#
# load() ONLY works on res:// paths. Files the player supplies at runtime were
# never imported by Godot, so they need Image.load() plus ImageTexture instead.
# That difference is the reason this file exists.
#
# Every lookup falls back: user file -> active built-in pack -> default pack.
# This is what makes partial packs possible. Someone can supply twelve A pieces
# and nothing else, and the rest of the game still renders.

const USER_ROOT := "user://textures/"
const MANIFEST_NAME := "texture.json"

# Bundled label face. Clear digits and unambiguous letterforms, which matters
# for designations drawn small over theme art.
const LABEL_FONT_PATH := "res://assets/fonts/LiberationSans-Regular.ttf"

var _label_font: Font = null

const BUILTIN := {
	"default": {
		"label": "Default",
		"pieces": "res://assets/sprites/pieces/",
		"board": "res://assets/board/",
		"cards": "res://assets/sprites/cards/",
		"palette": {
			"red":      Color("#EA2B3D"),
			"blue":     Color("#3A5FEE"),
			"green":    Color("#39FF14"),
			"yellow":   Color("#FFCC00"),
			"magenta":  Color("#FF00FF"),
			"lavender": Color("#CB94F7"),
			"orange":   Color("#FD6A00"),
			"black":    Color("#141414"),
		},
		"pulse": Color(0.3, 1.0, 0.4),
		"ityd": Color("#FFD400"),
		"plate": true,
		"labels": false,
		"label_color": Color("#141414"),
	},
	"rosecourt": {
		"label": "Rose Court",
		"pieces": "res://assets/textures/rosecourt/pieces/",
		"board": "res://assets/textures/rosecourt/board/",
		"cards": "res://assets/textures/rosecourt/cards/",
		"palette": {
			"red":      Color("#E0567F"),
			"blue":     Color("#7B99DC"),
			"green":    Color("#4E9B57"),
			"yellow":   Color("#E8B84B"),
			"magenta":  Color("#C96BB8"),
			"lavender": Color("#A98AD8"),
			"orange":   Color("#D9743F"),
			"black":    Color("#3A1F2B"),
		},
		"pulse": Color("#4E9B57"),
		"ityd": Color("#C79A3B"),
		"plate": false,
		"labels": false,
		"label_color": Color("#3A1F2B"),
	},
}

# Populated at startup by scanning USER_ROOT. Same shape as BUILTIN, plus
# "user": true and "dir": absolute path.
var user_packs: Dictionary = {}

var _cache: Dictionary = {}

signal packs_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(USER_ROOT)
	scan_user_packs()

# Card backs. A theme may ship one card_back.png, or two numbered ones so each
# player has their own. Falls back: numbered -> single -> default theme.
func card_back(side: int) -> Texture2D:
	var n: String = "card_back_1.png" if side == 0 else "card_back_2.png"
	return resolve("cards", [n, "card_back.png"])["texture"]

# ---------------------------------------------------------------- lookup ----

func active_id() -> String:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return "default"
	var v = sm.texture_pack
	if typeof(v) != TYPE_STRING:
		return "default"
	if BUILTIN.has(v) or user_packs.has(v):
		return v
	return "default"


func pack(id: String) -> Dictionary:
	if user_packs.has(id):
		return user_packs[id]
	if BUILTIN.has(id):
		return BUILTIN[id]
	return BUILTIN["default"]


func active() -> Dictionary:
	return pack(active_id())


func all_packs() -> Array:
	var out: Array = []
	for k in BUILTIN.keys():
		out.append({"id": k, "label": BUILTIN[k]["label"], "user": false})
	var user_ids: Array = user_packs.keys()
	user_ids.sort()
	for k in user_ids:
		out.append({"id": k, "label": user_packs[k]["label"], "user": true})
	return out


func label_for(id: String) -> String:
	return pack(id).get("label", id)


func palette() -> Dictionary:
	var p: Dictionary = active().get("palette", {})
	var base: Dictionary = BUILTIN["default"]["palette"]
	var out: Dictionary = base.duplicate()
	for k in p.keys():
		out[k] = p[k]
	return out


func pulse_color() -> Color:
	return active().get("pulse", BUILTIN["default"]["pulse"])


func ityd_color() -> Color:
	return active().get("ityd", BUILTIN["default"]["ityd"])

func labels_enabled() -> bool:
	return bool(active().get("labels", false))


func label_color() -> Color:
	return active().get("label_color", Color("#141414"))
	
func label_font() -> Font:
	if _label_font == null and ResourceLoader.exists(LABEL_FONT_PATH):
		_label_font = load(LABEL_FONT_PATH)
	return _label_font
	
# ---------------------------------------------------------------- textures --

# category is "pieces", "board" or "cards".
# rel is the filename, e.g. "blue_A7.png" or "tray/tray_blue_A7.png".
func get_texture(category: String, rel: String) -> Texture2D:
	var key: String = active_id() + "|" + category + "|" + rel
	if _cache.has(key):
		return _cache[key]

	var tex: Texture2D = null
	var p: Dictionary = active()

	if p.get("user", false):
		tex = _load_external(p["dir"].path_join(category).path_join(rel))
		if tex == null:
			tex = _load_builtin(BUILTIN["default"][category] + rel)
	else:
		tex = _load_builtin(p.get(category, "") + rel)
		if tex == null and active_id() != "default":
			tex = _load_builtin(BUILTIN["default"][category] + rel)

	_cache[key] = tex
	return tex

# Tries several filenames in order, within the active theme first and then the
# default theme. Returns { "texture": Texture2D, "rel": String, "own": bool }.
#
# "own" is true when the match came from the active theme rather than the
# default fallback. Callers use it to decide whether to draw a designation:
# a blank from the active theme needs one, the default theme's numbered art
# does not.
func resolve(category: String, rels: Array) -> Dictionary:
	var key: String = active_id() + "|" + category + "|" + "|".join(rels)
	if _cache.has(key):
		return _cache[key]

	var out: Dictionary = {"texture": null, "rel": "", "own": false}
	var p: Dictionary = active()

	for rel in rels:
		var tex: Texture2D = null
		if p.get("user", false):
			tex = _load_external(p["dir"].path_join(category).path_join(rel))
		else:
			tex = _load_builtin(p.get(category, "") + rel)
		if tex != null:
			out = {"texture": tex, "rel": rel, "own": true}
			break

	if out["texture"] == null:
		for rel in rels:
			var tex2: Texture2D = _load_builtin(BUILTIN["default"][category] + rel)
			if tex2 != null:
				out = {"texture": tex2, "rel": rel, "own": false}
				break

	_cache[key] = out
	return out

func _load_builtin(path: String) -> Texture2D:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var r = load(path)
	if r is Texture2D:
		return r
	return null


# Runtime load from a real file. Godot cannot rasterise SVG at runtime, so user
# packs are PNG only. That constraint belongs in the authoring guide.
func _load_external(abs_path: String) -> Texture2D:
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func clear_cache() -> void:
	_cache.clear()


# ------------------------------------------------------------ user packs ----

func scan_user_packs() -> void:
	user_packs.clear()
	var dir := DirAccess.open(USER_ROOT)
	if dir == null:
		packs_changed.emit()
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var parsed: Dictionary = _read_manifest(USER_ROOT + name)
			if not parsed.is_empty():
				user_packs[name] = parsed
		name = dir.get_next()
	dir.list_dir_end()
	packs_changed.emit()


func _read_manifest(pack_dir: String) -> Dictionary:
	var mpath: String = pack_dir.path_join(MANIFEST_NAME)
	if not FileAccess.file_exists(mpath):
		return {}
	var f := FileAccess.open(mpath, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(raw) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	var out: Dictionary = {}
	out["user"] = true
	out["dir"] = pack_dir
	out["label"] = str(data.get("name", pack_dir.get_file()))
	out["pulse"] = _hex_or(data.get("pulse", ""), BUILTIN["default"]["pulse"])
	out["ityd"] = _hex_or(data.get("ityd", ""), BUILTIN["default"]["ityd"])
	out["plate"] = bool(data.get("plate", false))
	# Imported themes default to engine-drawn designations. Supplying a numbered
	# file always wins over the blank, so a pack can mix the two.
	out["labels"] = bool(data.get("labels", true))
	out["label_color"] = _hex_or(data.get("label_color", ""), Color("#141414"))

	var pal: Dictionary = {}
	var raw_pal = data.get("palette", {})
	if typeof(raw_pal) == TYPE_DICTIONARY:
		for k in raw_pal.keys():
			var c: Color = _hex_or(str(raw_pal[k]), Color.BLACK)
			if c != Color.BLACK or str(raw_pal[k]).to_lower().contains("000000"):
				pal[str(k)] = c
	out["palette"] = pal
	return out


func _hex_or(s, fallback: Color) -> Color:
	var t: String = str(s).strip_edges()
	if t == "":
		return fallback
	if not t.begins_with("#"):
		t = "#" + t
	if not t.is_valid_html_color():
		return fallback
	return Color(t)


# ---------------------------------------------------------------- import ----

# Returns { "ok": bool, "id": String, "error": String, "warnings": Array }
func import_zip(zip_path: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "id": "", "error": "", "warnings": []}

	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		result["error"] = "Could not open that file. Is it a .zip?"
		return result

	var files: PackedStringArray = reader.get_files()

	# The manifest may sit at the root or one folder down, depending on how the
	# player zipped it. Find it and treat its folder as the pack root.
	var prefix: String = ""
	var found: bool = false
	for f in files:
		if f.get_file() == MANIFEST_NAME:
			prefix = f.substr(0, f.length() - MANIFEST_NAME.length())
			found = true
			break
	if not found:
		reader.close()
		result["error"] = "No %s found inside the zip. Every theme pack needs one." % MANIFEST_NAME
		return result

	var raw: String = reader.read_file(prefix + MANIFEST_NAME).get_string_from_utf8()
	var json := JSON.new()
	if json.parse(raw) != OK or typeof(json.data) != TYPE_DICTIONARY:
		reader.close()
		result["error"] = "%s is not valid JSON." % MANIFEST_NAME
		return result

	var data: Dictionary = json.data
	var id: String = str(data.get("id", "")).strip_edges()
	if id == "":
		reader.close()
		result["error"] = "Manifest has no \"id\"."
		return result
	if not id.is_valid_filename():
		reader.close()
		result["error"] = "The \"id\" contains characters not allowed in a folder name."
		return result
	if BUILTIN.has(id):
		reader.close()
		result["error"] = "\"%s\" is a built-in theme name. Choose another id." % id
		return result

	var dest: String = USER_ROOT + id
	DirAccess.make_dir_recursive_absolute(dest)

	var warnings: Array = []
	var copied: int = 0

	for f in files:
		if not f.begins_with(prefix):
			continue
		var rel: String = f.substr(prefix.length())
		if rel == "" or rel.ends_with("/"):
			continue
		if rel.contains(".."):
			continue
		var ext: String = rel.get_extension().to_lower()
		if rel != MANIFEST_NAME and ext != "png":
			if ext == "svg":
				warnings.append("Skipped %s -- SVG is not supported in imported themes. Use PNG." % rel)
			continue

		var bytes: PackedByteArray = reader.read_file(f)
		var out_path: String = dest.path_join(rel)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var w := FileAccess.open(out_path, FileAccess.WRITE)
		if w == null:
			warnings.append("Could not write %s" % rel)
			continue
		w.store_buffer(bytes)
		w.close()
		copied += 1

		if ext == "png":
			var sz: Vector2i = _png_size(out_path)
			var want: Vector2i = _expected_size(rel)
			if want != Vector2i.ZERO and sz != Vector2i.ZERO and sz != want:
				warnings.append("%s is %dx%d, expected %dx%d." % [rel, sz.x, sz.y, want.x, want.y])

	reader.close()

	if copied <= 1:
		result["error"] = "The zip contained no usable PNG files."
		return result

	scan_user_packs()
	result["ok"] = true
	result["id"] = id
	result["warnings"] = warnings
	return result


func remove_user_pack(id: String) -> void:
	if not user_packs.has(id):
		return
	if active_id() == id:
		var sm: Node = get_node_or_null("/root/SettingsManager")
		if sm != null:
			sm.set_texture_pack_pref("default")
	_rm_rf(USER_ROOT + id)
	clear_cache()
	scan_user_packs()


func _rm_rf(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		var child: String = path.path_join(n)
		if dir.current_is_dir():
			_rm_rf(child)
		else:
			DirAccess.remove_absolute(child)
		n = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _png_size(abs_path: String) -> Vector2i:
	var img := Image.new()
	if img.load(abs_path) != OK:
		return Vector2i.ZERO
	return Vector2i(img.get_width(), img.get_height())


# Expected pixel size from the filename. Returns ZERO for anything unrecognised
# (cards, board art), which means "do not check".
func _expected_size(rel: String) -> Vector2i:
	var f: String = rel.get_file()
	if not f.ends_with(".png"):
		return Vector2i.ZERO
	if not (rel.begins_with("pieces/") or rel.begins_with("tray/") or rel.begins_with("pieces/tray/")):
		return Vector2i.ZERO

	var stem: String = f.get_basename()
	var tall: bool = stem.ends_with("_vertical")
	var wide: bool = stem.ends_with("_horizontal")
	var is_tray: bool = rel.contains("tray/")

	# Tray tiles use STRETCH_KEEP_ASPECT_CENTERED, so any aspect ratio fits.
	# Nothing to validate.
	if is_tray:
		return Vector2i.ZERO

	# Board-tier type blanks: blue_A.png, blue_B_vertical.png, blue_C.png
	if stem.ends_with("_C"):
		return Vector2i(256, 256)
	if stem.ends_with("_A"):
		return Vector2i(128, 128)
	if stem.contains("_C") or stem.begins_with("back_") and stem.ends_with("_C"):
		return Vector2i(256, 256)
	if wide:
		return Vector2i(256, 128)
	if tall:
		return Vector2i(128, 256)
	return Vector2i(128, 128)
