extends Control
class_name OptionsMenu

# Audio-only for now (Master volume deferred; focus-loss mute is handled
# globally by settings_manager.gd, not a toggle here). Visual language matches
# house_rules.gd / main_menu.gd: corner crop-ticks, eyebrow, large light
# title, red-over-blue signature rule, bracketed [ back ] option, and the same
# pill toggle-switch used for House Rules. Sliders are functional Godot
# HSliders rather than a fully bespoke widget - fine for now, can be restyled
# to match the switches more closely later.

signal back

const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")
const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const TICK_COL := Color("#b9b3a7")
const BODY := Color("#33302b")
const HAIR := Color("#eceae4")
const COLORS := [
	["red", "Red", Color("#EA2B3D"), Color("#791F1F")],
	["blue", "Blue", Color("#3A5FEE"), Color("#0C447C")],
	["green", "Green", Color("#39FF14"), Color("#173404")],
	["yellow", "Yellow", Color("#FFCC00"), Color("#633806")],
	["magenta", "Magenta", Color("#FF00FF"), Color("#72243E")],
	["lavender", "Lavender", Color("#CB94F7"), Color("#3D2A5C")],
]

const TICK_SIZE := 26.0
const TICK_INSET := 14.0
const TICK_THICK := 2.0

var draw_own_background: bool = true
# Pause sets this false - colors are fixed at match start, changing them
# mid-match only ever affected pieces (not the board halves) and the
# section was pushing the embedded pause panel past its bounds anyway.
# Options reached from the main menu (before a match exists) keeps this true.
var show_player_colors: bool = true
var show_playlist_button: bool = true
var show_textures: bool = true

var _music_pct_label: Label
var _sfx_pct_label: Label
var _rs: Node  # RuleSettings autoload (may be null if unregistered)
var _main_view: Control
var _color_view: Control
var _texture_view: Control
var _soundtrack_view: Control
var _playlist_button: Button
var _track_pills: Dictionary = {}

func _ready() -> void:
	_rs = get_node_or_null("/root/RuleSettings")
	_build()


func _build() -> void:
	if draw_own_background:
		var bg := ColorRect.new()
		bg.color = PAPER
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		_build_corner_ticks()

	_main_view = _build_main_view()
	add_child(_main_view)
	if show_playlist_button:
		_build_playlist_button()

func _build_main_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	col.add_child(_eyebrow("OPTIONS"))
	col.add_child(_spacer(6))
	col.add_child(_title("Game Options"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(28))

	col.add_child(_section_label("MUSIC"))
	col.add_child(_spacer(10))
	col.add_child(_make_volume_row(
		"Volume", SettingsManager.music_volume,
		func(v):
			SettingsManager.set_music_volume_pref(v)
	))
	col.add_child(_spacer(8))
	col.add_child(_make_toggle_row(
		"Music enabled", SettingsManager.music_enabled,
		func(on):
			SettingsManager.set_music_enabled_pref(on)
	))

	col.add_child(_spacer(28))
	col.add_child(_section_label("SOUND EFFECTS"))
	col.add_child(_spacer(10))
	col.add_child(_make_volume_row(
		"Volume", SettingsManager.sfx_volume,
		func(v):
			SettingsManager.set_sfx_volume_pref(v)
	))
	col.add_child(_spacer(8))
	col.add_child(_make_toggle_row(
		"Sound effects enabled", SettingsManager.sfx_enabled,
		func(on):
			SettingsManager.set_sfx_enabled_pref(on)
	))
	
	col.add_child(_spacer(28))
	col.add_child(_section_label("REPLAYS"))
	col.add_child(_spacer(10))
	col.add_child(_make_toggle_row(
		"Record matches", SettingsManager.record_matches,
		func(on):
			SettingsManager.set_record_matches_pref(on)
	))
	col.add_child(_spacer(10))
	var replay_hint := Label.new()
	replay_hint.text = "Both players must record a game to produce a verifiable indenture for rankings."
	replay_hint.add_theme_font_size_override("font_size", 14)
	replay_hint.add_theme_color_override("font_color", MUTED)
	replay_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(replay_hint)

	col.add_child(_spacer(28))
	if show_player_colors or show_textures:
		var section_title := "Themes"
		if show_player_colors and show_textures:
			section_title = "Player Colors & Themes"
		elif show_player_colors:
			section_title = "Player Colors"
		col.add_child(_title(section_title))
		col.add_child(_spacer(10))
		col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
		col.add_child(_spacer(5))
		col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
		col.add_child(_spacer(28))
		if show_player_colors:
			col.add_child(_make_color_row())
		if show_textures:
			if show_player_colors:
				col.add_child(_spacer(20))
			col.add_child(_make_texture_row())
		col.add_child(_spacer(28))

	col.add_child(_spacer(38))
	col.add_child(_back_option(func(): back.emit()))

	return root

func _show_soundtrack_view() -> void:
	_main_view.visible = false
	if _playlist_button: _playlist_button.visible = false
	_soundtrack_view = _build_soundtrack_view()
	add_child(_soundtrack_view)

func _hide_soundtrack_view() -> void:
	MusicManager.stop_preview()
	if _soundtrack_view and is_instance_valid(_soundtrack_view):
		_soundtrack_view.queue_free()
	_soundtrack_view = null
	if _main_view and is_instance_valid(_main_view):
		_main_view.queue_free()
	_main_view = _build_main_view()
	add_child(_main_view)
	if _playlist_button:
		_playlist_button.visible = true
		_playlist_button.move_to_front()

func _refresh_soundtrack_view() -> void:
	if _soundtrack_view and is_instance_valid(_soundtrack_view):
		_soundtrack_view.queue_free()
	_soundtrack_view = _build_soundtrack_view()
	add_child(_soundtrack_view)


func _build_soundtrack_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	col.add_child(_eyebrow("OPTIONS  >  SOUNDTRACK"))
	col.add_child(_spacer(6))
	col.add_child(_title("Soundtrack"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(14))

	var intro := Label.new()
	intro.text = "Tap a title to hear it on loop. Switch a track off to keep it out of the gameplay rotation. At least one must stay on.)"
	intro.add_theme_font_size_override("font_size", 13)
	intro.add_theme_color_override("font_color", MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(560, 0)
	col.add_child(intro)
	col.add_child(_spacer(24))

	_track_pills.clear()
	for entry in MusicManager.get_gameplay_tracks():
		col.add_child(_make_track_row(entry))
		col.add_child(_spacer(8))

	col.add_child(_spacer(32))
	col.add_child(_back_option(func(): _hide_soundtrack_view()))
	return root

func _build_playlist_button() -> void:
	var btn := Button.new()
	btn.text = "Playlist"
	btn.add_theme_font_size_override("font_size", 17)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	# Sit just below the accent rules, inset from the right edge - same
	# floating treatment as the Gameplay Tutorial button on How to Play.
	btn.position = Vector2(-232.0, 150.0)
	btn.custom_minimum_size = Vector2(190, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROYAL_BLUE
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("#5A7AEE")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.pressed.connect(func(): _show_soundtrack_view())
	_playlist_button = btn
	add_child(btn)

func _make_track_row(entry: Dictionary) -> Control:
	var id: String = entry["id"]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var pill := Button.new()
	pill.text = entry["title"]
	pill.custom_minimum_size = Vector2(0, 44)
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_pill(pill, MusicManager.previewing_id == id)
	pill.pressed.connect(func():
		if MusicManager.previewing_id == id:
			MusicManager.stop_preview()
		else:
			MusicManager.preview_track(id)
		_refresh_pill_styles()
	)
	_track_pills[id] = pill
	row.add_child(pill)

	var sw := _make_switch(MusicManager.is_track_enabled(id), func(on):
		if not on and MusicManager.enabled_track_count() <= 1:
			_refresh_soundtrack_view()   # refuse: revert the switch visually
			return
		MusicManager.set_track_enabled(id, on)
		SettingsManager.set_disabled_tracks(MusicManager.get_disabled_ids())
	)
	row.add_child(sw)

	return row


func _style_pill(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ROYAL_BLUE.r, ROYAL_BLUE.g, ROYAL_BLUE.b, 0.10) if active else PAPER
	sb.border_color = ROYAL_BLUE if active else HAIR
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", ROYAL_BLUE if active else INK)
	btn.add_theme_font_size_override("font_size", 16)


func _refresh_pill_styles() -> void:
	for id in _track_pills:
		var btn: Button = _track_pills[id]
		if is_instance_valid(btn):
			_style_pill(btn, MusicManager.previewing_id == id)
			
func _make_color_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var desc := Label.new()
	desc.text = "Choose from alternative player colors."
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", BODY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc)

	var choose := Button.new()
	choose.text = "choose"
	choose.custom_minimum_size = Vector2(100, 36)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	choose.add_theme_stylebox_override("normal", sb)
	choose.add_theme_stylebox_override("hover", sb)
	choose.add_theme_color_override("font_color", INK)
	choose.pressed.connect(func(): _show_color_view())
	row.add_child(choose)
	return row


func _side_color(side: int) -> String:
	if _rs:
		return _rs.side_one_color if side == 1 else _rs.side_two_color
	return "blue" if side == 1 else "red"


func _set_side_color(side: int, key: String) -> void:
	if _rs:
		if side == 1:
			_rs.side_one_color = key
		else:
			_rs.side_two_color = key

func _make_texture_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var desc := Label.new()
	desc.text = "Change the look of the board and pieces."
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", BODY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc)

	var current := Label.new()
	current.text = "Current theme: %s" % TextureManager.label_for(TextureManager.active_id())
	current.add_theme_font_size_override("font_size", 16)
	current.add_theme_color_override("font_color", MUTED)
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(current)

	var choose := Button.new()
	choose.text = "choose"
	choose.custom_minimum_size = Vector2(100, 36)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	choose.add_theme_stylebox_override("normal", sb)
	choose.add_theme_stylebox_override("hover", sb)
	choose.add_theme_stylebox_override("pressed", sb)
	choose.add_theme_color_override("font_color", INK)
	choose.pressed.connect(_show_texture_view)
	row.add_child(choose)

	return row


func _show_texture_view() -> void:
	_main_view.visible = false
	if _playlist_button and is_instance_valid(_playlist_button):
		_playlist_button.visible = false
	_texture_view = _build_texture_view()
	add_child(_texture_view)


func _hide_texture_view() -> void:
	if _texture_view and is_instance_valid(_texture_view):
		_texture_view.queue_free()
	_texture_view = null
	if _main_view and is_instance_valid(_main_view):
		_main_view.queue_free()
	_main_view = _build_main_view()
	add_child(_main_view)
	if _playlist_button and is_instance_valid(_playlist_button):
		_playlist_button.visible = true
		_playlist_button.move_to_front()


func _refresh_texture_view() -> void:
	if _texture_view and is_instance_valid(_texture_view):
		_texture_view.queue_free()
	_texture_view = _build_texture_view()
	add_child(_texture_view)


func _build_texture_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	col.add_child(_eyebrow("OPTIONS  >  THEMES"))
	col.add_child(_spacer(6))
	col.add_child(_title("Themes"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(28))

	col.add_child(_section_label("INCLUDED"))
	col.add_child(_spacer(10))
	var active: String = TextureManager.active_id()
	for entry in TextureManager.all_packs():
		if entry["user"]:
			continue
		col.add_child(_texture_option(entry, entry["id"] == active))
		col.add_child(_spacer(6))

	col.add_child(_spacer(22))
	col.add_child(_section_label("YOUR THEMES"))
	col.add_child(_spacer(10))

	var any_user: bool = false
	for entry in TextureManager.all_packs():
		if not entry["user"]:
			continue
		any_user = true
		col.add_child(_texture_option(entry, entry["id"] == active))
		col.add_child(_spacer(6))

	if not any_user:
		var empty := Label.new()
		empty.text = "You have not added any themes yet."
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", MUTED)
		col.add_child(empty)

	col.add_child(_spacer(22))

	var add_btn := Button.new()
	add_btn.text = "add a theme pack (.zip)"
	add_btn.custom_minimum_size = Vector2(0, 40)
	var asb := StyleBoxFlat.new()
	asb.bg_color = PAPER
	asb.set_corner_radius_all(8)
	asb.set_border_width_all(1)
	asb.border_color = HAIR
	asb.border_color = INK
	asb.set_border_width_all(2)
	add_btn.add_theme_stylebox_override("normal", asb)
	add_btn.add_theme_stylebox_override("hover", asb)
	add_btn.add_theme_stylebox_override("pressed", asb)
	add_btn.add_theme_color_override("font_color", INK)
	add_btn.pressed.connect(_open_texture_import)
	col.add_child(add_btn)

	col.add_child(_spacer(10))
	var hint := Label.new()
	hint.text = "Theme packs are .zip files containing PNG images and a file called texture.json. You can save the theme guide and a starter pack from Make Your Own on the main menu."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	col.add_child(_spacer(38))
	col.add_child(_back_option(func(): _hide_texture_view()))

	return root


func _texture_option(entry: Dictionary, selected: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var btn := Button.new()
	btn.text = entry["label"]
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ROYAL_BLUE.r, ROYAL_BLUE.g, ROYAL_BLUE.b, 0.08) if selected else PAPER
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = INK if selected else HAIR
	sb.content_margin_left = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", INK)
	var pack_id: String = entry["id"]
	btn.pressed.connect(func():
		SettingsManager.set_texture_pack_pref(pack_id)
		_refresh_texture_view()
	)
	row.add_child(btn)

	if entry["user"]:
		var del := Button.new()
		del.text = "remove"
		del.custom_minimum_size = Vector2(90, 44)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = PAPER
		dsb.set_corner_radius_all(8)
		dsb.set_border_width_all(1)
		dsb.border_color = HAIR
		dsb.border_color = INK
		dsb.set_border_width_all(2)
		del.add_theme_stylebox_override("normal", dsb)
		del.add_theme_stylebox_override("hover", dsb)
		del.add_theme_stylebox_override("pressed", dsb)
		del.add_theme_color_override("font_color", INK)
		del.pressed.connect(func():
			TextureManager.remove_user_pack(pack_id)
			_refresh_texture_view()
		)
		row.add_child(del)

	return row


func _open_texture_import() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.zip ; Theme pack"])
	fd.title = "Choose a theme pack"
	fd.size = Vector2i(760, 520)
	add_child(fd)
	fd.file_selected.connect(func(p):
		var res: Dictionary = TextureManager.import_zip(p)
		fd.queue_free()
		_show_import_result(res)
	)
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered()


func _show_import_result(res: Dictionary) -> void:
	var dlg := AcceptDialog.new()
	if res["ok"]:
		var msg: String = "Added \"%s\"." % TextureManager.label_for(res["id"])
		var warns: Array = res["warnings"]
		if warns.size() > 0:
			msg += "\n\nSome files were skipped or look wrong:\n"
			var shown: int = 0
			for w in warns:
				if shown >= 8:
					msg += "\n(and %d more)" % (warns.size() - shown)
					break
				msg += "\n- " + str(w)
				shown += 1
		dlg.dialog_text = msg
	else:
		dlg.dialog_text = "Could not add that theme pack.\n\n" + str(res["error"])
	add_child(dlg)
	dlg.confirmed.connect(func():
		dlg.queue_free()
		_refresh_texture_view()
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
		_refresh_texture_view()
	)
	dlg.popup_centered()
	
func _show_color_view() -> void:
	_main_view.visible = false
	if _playlist_button and is_instance_valid(_playlist_button):
		_playlist_button.visible = false
	_color_view = _build_color_view()
	add_child(_color_view)


func _hide_color_view() -> void:
	if _color_view and is_instance_valid(_color_view):
		_color_view.queue_free()
	_color_view = null
	if _main_view and is_instance_valid(_main_view):
		_main_view.queue_free()
	_main_view = _build_main_view()
	add_child(_main_view)
	if _playlist_button and is_instance_valid(_playlist_button):
		_playlist_button.visible = true
		_playlist_button.move_to_front()


func _build_color_view() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 56)
	pad.add_theme_constant_override("margin_bottom", 72)
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	center.add_child(pad)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	pad.add_child(col)

	col.add_child(_eyebrow("OPTIONS  >  PLAYER COLORS"))
	col.add_child(_spacer(6))
	col.add_child(_title("Choose Sides"))
	col.add_child(_spacer(10))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_two_color]))
	col.add_child(_spacer(5))
	col.add_child(_rule_line(RuleSettings.COLOR_HEX[RuleSettings.side_one_color]))
	col.add_child(_spacer(14))

	var intro := Label.new()
	intro.text = "Pick a color for each side. The two sides can't share a color."
	intro.add_theme_font_size_override("font_size", 13)
	intro.add_theme_color_override("font_color", MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(520, 0)
	col.add_child(intro)
	col.add_child(_spacer(24))

	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 0)
	preview.custom_minimum_size = Vector2(560, 90)
	preview.add_child(_preview_half(1))
	preview.add_child(_preview_half(2))
	col.add_child(preview)
	col.add_child(_spacer(28))

	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 40)
	col.add_child(pickers)
	pickers.add_child(_build_side_picker(1))
	pickers.add_child(_build_side_picker(2))

	col.add_child(_spacer(34))
	col.add_child(_back_option(func(): _hide_color_view()))
	return root


func _preview_half(side: int) -> Control:
	var c = _color_hex(_side_color(side))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = "SIDE ONE" if side == 1 else "SIDE TWO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", PAPER)
	panel.add_child(lbl)
	return panel


func _build_side_picker(side: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := Label.new()
	head.text = "SIDE ONE" if side == 1 else "SIDE TWO"
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", MUTED)
	col.add_child(head)
	col.add_child(_spacer(6))

	var this_key := _side_color(side)
	var other_key := _side_color(2 if side == 1 else 1)
	for opt in COLORS:
		var key: String = opt[0]
		var selected := key == this_key
		var disabled := key == other_key
		col.add_child(_color_swatch(opt, selected, disabled, side))
	return col


func _color_swatch(opt: Array, selected: bool, disabled: bool, side: int) -> Control:
	var key: String = opt[0]
	var cname: String = opt[1]
	var hex: Color = RuleSettings.COLOR_HEX.get(key, opt[2])
	var ink: Color = opt[3]

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.disabled = disabled
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hex.r, hex.g, hex.b, 0.08) if selected else PAPER
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = ink if selected else HAIR
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	btn.add_child(h)

	var chip := ColorRect.new()
	chip.color = hex
	chip.custom_minimum_size = Vector2(24, 24)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(chip)

	var lbl := Label.new()
	lbl.text = cname
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", ink if selected else INK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lbl)

	btn.modulate = Color(1, 1, 1, 0.35) if disabled else Color.WHITE
	if not disabled:
		btn.pressed.connect(func():
			_set_side_color(side, key)
			_hide_color_view()
			_show_color_view()
		)
	return btn


func _color_hex(key: String) -> Color:
	if RuleSettings.COLOR_HEX.has(key):
		return RuleSettings.COLOR_HEX[key]
	return ROYAL_BLUE


func _color_name(key: String) -> String:
	for opt in COLORS:
		if opt[0] == key:
			return opt[1]
	return key
	
func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", MUTED)
	return l


func _make_volume_row(row_label: String, initial: float, on_change: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var head := HBoxContainer.new()
	col.add_child(head)

	var lbl := Label.new()
	lbl.text = row_label
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)

	var pct := Label.new()
	pct.text = "%d%%" % round(initial * 100)
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", MUTED)
	head.add_child(pct)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = round(initial * 100)
	slider.custom_minimum_size = Vector2(0, 24)

	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color("#eceae4")
	track_sb.set_corner_radius_all(4)
	track_sb.content_margin_top = 6
	track_sb.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = ROYAL_BLUE
	fill_sb.set_corner_radius_all(4)
	fill_sb.content_margin_top = 6
	fill_sb.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill_sb)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_sb)

	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % v
		on_change.call(v / 100.0)
	)
	col.add_child(slider)

	return col


func _make_toggle_row(row_label: String, on: bool, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text = row_label
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", BODY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	row.add_child(_make_switch(on, cb))

	return row


func _make_switch(on: bool, cb: Callable) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(52, 30)
	root.size = Vector2(52, 30)

	var sb_on := StyleBoxFlat.new()
	sb_on.bg_color = ROYAL_BLUE
	sb_on.set_corner_radius_all(15)
	var sb_off := StyleBoxFlat.new()
	sb_off.bg_color = Color("#c9c4b9")
	sb_off.set_corner_radius_all(15)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal", sb_on if on else sb_off)
	btn.add_theme_stylebox_override("hover", sb_on if on else sb_off)
	btn.add_theme_stylebox_override("pressed", sb_on if on else sb_off)
	root.add_child(btn)

	var kpanel := Panel.new()
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = PAPER
	ksb.set_corner_radius_all(12)
	kpanel.add_theme_stylebox_override("panel", ksb)
	kpanel.size = Vector2(24, 24)
	kpanel.position = Vector2(3 if on else 25, 3)
	kpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kpanel)

	var state := { "on": on }
	btn.pressed.connect(func():
		state.on = not state.on
		btn.add_theme_stylebox_override("normal", sb_on if state.on else sb_off)
		btn.add_theme_stylebox_override("hover", sb_on if state.on else sb_off)
		btn.add_theme_stylebox_override("pressed", sb_on if state.on else sb_off)
		var tw := root.create_tween()
		tw.tween_property(kpanel, "position:x", 3.0 if state.on else 25.0, 0.12)
		cb.call(state.on)
	)

	return root

func _eyebrow(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", INK)
	return l


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _rule_line(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _back_option(cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.custom_minimum_size = Vector2(0, 44)

	var lb := Label.new()
	lb.text = "["
	lb.add_theme_font_size_override("font_size", 30)
	lb.add_theme_color_override("font_color", MUTED)
	row.add_child(lb)

	var mid := Label.new()
	mid.text = "back"
	mid.add_theme_font_size_override("font_size", 30)
	mid.add_theme_color_override("font_color", INK)
	row.add_child(mid)

	var rb := Label.new()
	rb.text = "]"
	rb.add_theme_font_size_override("font_size", 30)
	rb.add_theme_color_override("font_color", MUTED)
	row.add_child(rb)

	row.mouse_entered.connect(func():
		_tween_row_x(row, 6.0)
		lb.add_theme_color_override("font_color", ALIZARIN)
		mid.add_theme_color_override("font_color", ALIZARIN)
		rb.add_theme_color_override("font_color", ALIZARIN)
	)
	row.mouse_exited.connect(func():
		_tween_row_x(row, 0.0)
		lb.add_theme_color_override("font_color", MUTED)
		mid.add_theme_color_override("font_color", INK)
		rb.add_theme_color_override("font_color", MUTED)
	)
	row.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
	)
	return row


func _tween_row_x(row: Control, to_x: float) -> void:
	var t := create_tween()
	t.tween_property(row, "position:x", to_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_corner_ticks() -> void:
	for corner in ["tl", "tr", "bl", "br"]:
		add_child(_make_tick(corner))


func _make_tick(corner: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(TICK_SIZE, TICK_SIZE)
	c.size = Vector2(TICK_SIZE, TICK_SIZE)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match corner:
		"tl":
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2(TICK_INSET, TICK_INSET)
		"tr":
			c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			c.anchor_left = 1.0; c.anchor_right = 1.0
			c.position = Vector2(-TICK_INSET - TICK_SIZE, TICK_INSET)
		"bl":
			c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
			c.position = Vector2(TICK_INSET, -TICK_INSET - TICK_SIZE)
		"br":
			c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			c.anchor_left = 1.0; c.anchor_right = 1.0
			c.anchor_top = 1.0; c.anchor_bottom = 1.0
			c.position = Vector2(-TICK_INSET - TICK_SIZE, -TICK_INSET - TICK_SIZE)
	c.draw.connect(_draw_tick.bind(c, corner))
	return c


func _draw_tick(c: Control, corner: String) -> void:
	var w := TICK_SIZE
	match corner:
		"tl":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)
		"tr":
			c.draw_line(Vector2(0, 0), Vector2(w, 0), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)
		"bl":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(0, 0), Vector2(0, w), TICK_COL, TICK_THICK)
		"br":
			c.draw_line(Vector2(0, w), Vector2(w, w), TICK_COL, TICK_THICK)
			c.draw_line(Vector2(w, 0), Vector2(w, w), TICK_COL, TICK_THICK)
