extends Node

const SAVE_PATH := "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var music_enabled: bool = true
var sfx_enabled: bool = true

# Placeholder for later - once Jamie's alt soundtrack lands, this becomes a
# real choice (e.g. "default" / "sax") with its own row in Options, and
# music_manager.gd gets a second TRACKS_ALT dict to preload from.
var soundtrack_variant: String = "default"
var disabled_tracks: Array = []

# ---- Textures ----
# Id of the active texture pack. May be a built-in ("default", "rosecourt") or
# the folder name of a pack the player imported. Validated on load.
var texture_pack: String = "default"

# ---- Replays ----
# Opt-in. When on, each completed match writes a .wfs record to user://replays/.
# Recording is local and per-player: each side keeps its own copy of a match.
var record_matches: bool = false

signal texture_pack_changed(id: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			MusicManager.set_music_volume(0.0)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			MusicManager.set_music_volume(music_volume if music_enabled else 0.0)


func set_music_volume_pref(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_music_enabled_pref(enabled: bool) -> void:
	music_enabled = enabled
	_apply()
	_save()


func set_sfx_volume_pref(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_sfx_enabled_pref(enabled: bool) -> void:
	sfx_enabled = enabled
	_apply()
	_save()


func _apply() -> void:
	MusicManager.set_music_volume(music_volume if music_enabled else 0.0)
	SfxManager.set_sfx_volume(sfx_volume if sfx_enabled else 0.0)
	MusicManager.set_disabled_ids(disabled_tracks)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "soundtrack_variant", soundtrack_variant)
	cfg.set_value("audio", "disabled_tracks", disabled_tracks)
	cfg.set_value("display", "texture_pack", texture_pack)
	cfg.set_value("replays", "record_matches", record_matches)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # no save yet - defaults stand
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	music_enabled = cfg.get_value("audio", "music_enabled", music_enabled)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	sfx_enabled = cfg.get_value("audio", "sfx_enabled", sfx_enabled)
	soundtrack_variant = cfg.get_value("audio", "soundtrack_variant", soundtrack_variant)
	disabled_tracks = cfg.get_value("audio", "disabled_tracks", disabled_tracks)
	texture_pack = cfg.get_value("display", "texture_pack", "default")
	record_matches = cfg.get_value("replays", "record_matches", false)

func set_record_matches_pref(enabled: bool) -> void:
	record_matches = enabled
	_save()
	
func set_texture_pack_pref(id: String) -> void:
	var chosen: String = id
	var tm: Node = get_node_or_null("/root/TextureManager")
	if tm != null and not (tm.BUILTIN.has(chosen) or tm.user_packs.has(chosen)):
		chosen = "default"
	if chosen == texture_pack:
		return
	texture_pack = chosen
	_save()
	if tm != null:
		tm.clear_cache()
	texture_pack_changed.emit(texture_pack)


func set_disabled_tracks(ids: Array) -> void:
	disabled_tracks = ids
	_apply()
	_save()
