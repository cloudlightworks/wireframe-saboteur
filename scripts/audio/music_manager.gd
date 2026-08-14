extends Node

enum Track {
	NONE,
	MENU,
	CROCE,
	GAMEPLAY_ROTATION_MEMBER,
}

# ---- Fixed, non-rotation tracks ----
const MENU_STREAM := preload("res://assets/audio/music/music_01.wav")
const CROCE_STREAM := preload("res://assets/audio/music/music_02.wav")

# ---- Gameplay rotation registry ----
# Order here IS the rotation order: themes alternating with the remaining
# music_/vari_ files (ordinal within each family), themes closing the cycle.
# Titles are placeholders for the future Soundtrack/Playlist submenu.
const GAMEPLAY_TRACKS: Array[Dictionary] = [
	{ "id": "theme_01", "title": "Wireframe Waltz",        "stream": preload("res://assets/audio/music/theme_01.wav") },
	{ "id": "music_03", "title": "Pump Island Nocturne",   "stream": preload("res://assets/audio/music/music_03.wav") },
	{ "id": "theme_02", "title": "Foamcore Fortress",      "stream": preload("res://assets/audio/music/theme_02.wav") },
	{ "id": "music_04", "title": "Fluorescent Hum",        "stream": preload("res://assets/audio/music/music_04.wav") },
	{ "id": "theme_03", "title": "Index Card Shuffle",     "stream": preload("res://assets/audio/music/theme_03.wav") },
	{ "id": "music_05", "title": "Last Customer",          "stream": preload("res://assets/audio/music/music_05.wav") },
	{ "id": "theme_04", "title": "Saboteur's Creep",       "stream": preload("res://assets/audio/music/theme_04.wav") },
	{ "id": "vari_01",  "title": "Coffee at 3 A.M.",       "stream": preload("res://assets/audio/music/vari_01.wav") },
	{ "id": "theme_05", "title": "Rock Paper Soldier",     "stream": preload("res://assets/audio/music/theme_05.wav") },
	{ "id": "vari_02",  "title": "Highway Shimmer",        "stream": preload("res://assets/audio/music/vari_02.wav") },
	{ "id": "theme_06", "title": "Designation Drift",      "stream": preload("res://assets/audio/music/theme_06.wav") },
	{ "id": "vari_03",  "title": "Neon Reprise",           "stream": preload("res://assets/audio/music/vari_03.wav") },
	{ "id": "theme_07", "title": "Objective in Sight",     "stream": preload("res://assets/audio/music/theme_07.wav") },
	{ "id": "vari_04",  "title": "Closing Time",           "stream": preload("res://assets/audio/music/vari_04.wav") },
	{ "id": "theme_08", "title": "Mutual Destruction",     "stream": preload("res://assets/audio/music/theme_08.wav") },
	{ "id": "theme_09", "title": "Sabotournament",         "stream": preload("res://assets/audio/music/theme_09.wav") },
]

# Every track plays this many full cycles of its own length, looping
# seamlessly (no fade, no gap) between cycles, before crossfading out.
const CYCLES_PER_TRACK := 2

# Long, gentle hand-off between rotation tracks.
const CROSSFADE_SECONDS := 5.0
# Fade for one-off entrances (menu, Croce) where nothing overlaps.
const ENTRANCE_FADE_SECONDS := 2.0

const SILENT_DB := -80.0

var current_track: Track = Track.NONE
var current_rotation_id: String = ""

var _in_gameplay_rotation: bool = false
var _rotation_index: int = 0
var _elapsed_in_track: float = 0.0
var _track_duration_target: float = 0.0

# Per-track enable flags for the future Playlist submenu. All enabled by
# default; the submenu will call set_track_enabled(). Persistence will land
# in SettingsManager alongside the submenu itself.
var _disabled_ids: Dictionary = {}

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_is_a: bool = true
var _fade_tween: Tween

# ---- Preview (Soundtrack submenu) ----
var previewing_id: String = ""
var _suspended_rotation: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = _make_player("MusicPlayerA")
	_player_b = _make_player("MusicPlayerB")


func _make_player(player_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.bus = &"Music"
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _active_player() -> AudioStreamPlayer:
	return _player_a if _active_is_a else _player_b


# Forces a WAV stream to loop seamlessly at the mixer level. This is what
# keeps a track's own cycle-to-cycle seam gapless and fade-free; the
# finished signal never fires on a looping stream, so rotation advancement
# is clocked in _process() instead.
func _ensure_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _process(delta: float) -> void:
	if not _in_gameplay_rotation:
		return
	_elapsed_in_track += delta
	if _elapsed_in_track >= _track_duration_target:
		_advance_rotation()


# ---- Public API ----

# One-off tracks: menu and Croce. Turns rotation OFF.
func play_track(track: Track, fade_seconds: float = ENTRANCE_FADE_SECONDS) -> void:
	if track == current_track and _active_player().playing:
		return
	var stream: AudioStream = null
	match track:
		Track.MENU: stream = MENU_STREAM
		Track.CROCE: stream = CROCE_STREAM
		_:
			push_warning("MusicManager: play_track only handles MENU/CROCE")
			return
	_in_gameplay_rotation = false
	current_track = track
	current_rotation_id = ""
	_ensure_looping(stream)
	_start_crossfade(stream, fade_seconds)


# Kicks off the self-sustaining gameplay rotation from the top of the
# registry. Each track loops seamlessly for CYCLES_PER_TRACK full lengths,
# then crossfades into the next enabled track. No further calls needed.
func begin_gameplay_rotation() -> void:
	_in_gameplay_rotation = true
	current_track = Track.GAMEPLAY_ROTATION_MEMBER
	_rotation_index = -1
	_advance_rotation(ENTRANCE_FADE_SECONDS)


func return_to_menu_music() -> void:
	play_track(Track.MENU)


func stop_music(fade_seconds: float = 0.5) -> void:
	current_track = Track.NONE
	current_rotation_id = ""
	_in_gameplay_rotation = false
	var p := _active_player()
	if not p.playing:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade_seconds <= 0.0:
		_player_a.stop()
		_player_b.stop()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(p, "volume_db", SILENT_DB, fade_seconds)
	await _fade_tween.finished
	_player_a.stop()
	_player_b.stop()
	p.volume_db = 0.0

# ---- Preview API (Soundtrack submenu) ----

func preview_track(id: String) -> void:
	for entry in GAMEPLAY_TRACKS:
		if entry["id"] == id:
			_in_gameplay_rotation = false
			current_track = Track.NONE
			current_rotation_id = ""
			previewing_id = id
			var stream: AudioStream = entry["stream"]
			_ensure_looping(stream)
			_start_crossfade(stream, 0.8)
			return
	push_warning("MusicManager: unknown track id '%s'" % id)


func stop_preview() -> void:
	if previewing_id == "":
		return
	previewing_id = ""
	current_track = Track.NONE   # so play_track doesn't early-return
	play_track(Track.MENU, 0.8)


# ---- Menu suspend/restore (pause screen) ----
# Swaps to menu music while a menu is open, remembering that gameplay
# rotation was running so it can pick back up on the same track afterwards
# rather than restarting the whole rotation from the top.

func suspend_rotation_for_menu() -> void:
	_suspended_rotation = _in_gameplay_rotation
	if _suspended_rotation:
		play_track(Track.MENU)


func resume_rotation_after_menu() -> void:
	if not _suspended_rotation:
		return
	_suspended_rotation = false
	previewing_id = ""
	_in_gameplay_rotation = true
	current_track = Track.GAMEPLAY_ROTATION_MEMBER
	_rotation_index -= 1          # so _advance_rotation lands on the same track
	_advance_rotation()


# ---- Playlist state ----

func get_disabled_ids() -> Array:
	return _disabled_ids.keys()


func set_disabled_ids(ids: Array) -> void:
	_disabled_ids.clear()
	for id in ids:
		_disabled_ids[id] = true


func enabled_track_count() -> int:
	return GAMEPLAY_TRACKS.size() - _disabled_ids.size()
	
func set_music_volume(linear_volume: float) -> void:
	var safe_volume := clampf(linear_volume, 0.0, 1.0)
	if safe_volume <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	else:
		var bus_index := AudioServer.get_bus_index(&"Music")
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))


# ---- Playlist submenu API (UI not built yet; this is its foundation) ----

# Returns the full registry (id, title, stream) for the Soundtrack screen.
func get_gameplay_tracks() -> Array[Dictionary]:
	return GAMEPLAY_TRACKS


func set_track_enabled(id: String, enabled: bool) -> void:
	if enabled:
		_disabled_ids.erase(id)
	else:
		_disabled_ids[id] = true


func is_track_enabled(id: String) -> bool:
	return not _disabled_ids.has(id)


# ---- Internals ----

func _advance_rotation(fade_seconds: float = CROSSFADE_SECONDS) -> void:
	var count := GAMEPLAY_TRACKS.size()
	# Find the next enabled track, scanning at most one full cycle.
	for i in count:
		var idx := (_rotation_index + 1 + i) % count
		var entry: Dictionary = GAMEPLAY_TRACKS[idx]
		if _disabled_ids.has(entry["id"]):
			continue
		_rotation_index = idx
		current_rotation_id = entry["id"]
		var stream: AudioStream = entry["stream"]
		_ensure_looping(stream)
		_elapsed_in_track = 0.0
		_track_duration_target = stream.get_length() * CYCLES_PER_TRACK
		_start_crossfade(stream, fade_seconds)
		return
	# Every rotation track is disabled: keep whatever is playing, check
	# again after a short delay rather than every frame.
	_elapsed_in_track = 0.0
	_track_duration_target = 5.0


func _start_crossfade(stream: AudioStream, fade_seconds: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var outgoing := _active_player()
	var was_playing := outgoing.playing

	_active_is_a = not _active_is_a
	var incoming := _active_player()

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_seconds)
	if was_playing:
		_fade_tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_seconds)
		_fade_tween.chain().tween_callback(outgoing.stop)
