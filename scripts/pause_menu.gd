extends CanvasLayer
class_name PauseMenu

signal resumed
signal return_to_menu
signal quit_to_desktop
signal forfeited

const INK := Color("#141414")
const MUTED := Color("#7a7368")
const PAPER := Color("#ffffff")
const ROYAL_BLUE := Color("#4169E1")
const ALIZARIN := Color("#E32636")

var _content_host: Control
var _options_instance: OptionsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_content_host = VBoxContainer.new()
	_content_host.custom_minimum_size = Vector2(480, 0)
	center.add_child(_content_host)

	_show_buttons()


func _clear_content() -> void:
	for c in _content_host.get_children():
		c.queue_free()


func _show_buttons() -> void:
	_clear_content()

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	_content_host.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var rule := ColorRect.new()
	rule.color = RuleSettings.COLOR_HEX[RuleSettings.side_one_color]
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)

	col.add_child(_spacer(6))
	col.add_child(_make_button("Resume", true, func(): resumed.emit()))
	col.add_child(_make_button("Sound Options", false, func(): _show_options()))
	col.add_child(_make_button("Return to Main Menu", false, func(): return_to_menu.emit()))
	col.add_child(_make_button("Forfeit Match", false, func(): _show_forfeit_confirm()))
	col.add_child(_make_button("Quit Game", false, func(): quit_to_desktop.emit()))


func _show_options() -> void:
	_clear_content()

	_options_instance = OptionsMenu.new()
	_options_instance.draw_own_background = false
	_options_instance.show_player_colors = false
	_options_instance.show_playlist_button = false
	_options_instance.show_textures = false
	_options_instance.custom_minimum_size = Vector2(600, 420)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	_content_host.add_child(panel)
	panel.add_child(_options_instance)

	_options_instance.back.connect(_show_buttons)

func _show_forfeit_confirm() -> void:
	_clear_content()

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	_content_host.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Forfeit the match?"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := Label.new()
	body.text = "This ends the game immediately. Your opponent wins. This can't be undone."
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(body)

	col.add_child(_spacer(6))
	col.add_child(_make_button("Yes, forfeit", false, func(): forfeited.emit()))
	col.add_child(_make_button("Cancel", true, func(): _show_buttons()))

func _make_button(text: String, primary: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 18)

	var sb := StyleBoxFlat.new()
	sb.bg_color = ROYAL_BLUE if primary else PAPER
	sb.border_color = INK
	sb.set_border_width_all(2 if not primary else 0)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("#5a7ae6") if primary else Color("#f0ede7")

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", PAPER if primary else INK)
	btn.pressed.connect(cb)
	return btn


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
