extends PanelContainer
signal next_pressed
signal exit_pressed
signal restart_pressed
signal action_pressed

const INK := Color("#141414")
const MUTED := Color("#6d6962")
const PAPER := Color("#fffefd")
const RED := Color("#E32636")
const BLUE := Color("#4169E1")
const GREEN := Color("#16834f")
const TIMELINE_INSET := 54.0

var progress_label: Label
var title_label: Label
var body_label: Label
var instruction_label: Label
var status_label: Label
var feedback_label: Label
var next_button: Button
var action_button: Button
var restart_button: Button
var exit_button: Button

func _ready() -> void:
	_build()

func _build() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PAPER
	panel_style.border_color = Color("#c9c5bc")
	panel_style.border_width_left = 1
	panel_style.shadow_color = Color(0, 0, 0, 0.22)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(-3, 0)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 22 + TIMELINE_INSET
	panel_style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", panel_style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	add_child(outer)

	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", MUTED)
	outer.add_child(progress_label)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", INK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(title_label)

	var rule := VBoxContainer.new()
	rule.add_theme_constant_override("separation", 4)
	var red_bar := ColorRect.new()
	red_bar.color = RED
	red_bar.custom_minimum_size = Vector2(0, 3)
	var blue_bar := ColorRect.new()
	blue_bar.color = BLUE
	blue_bar.custom_minimum_size = Vector2(0, 3)
	rule.add_child(red_bar)
	rule.add_child(blue_bar)
	outer.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 18)
	scroll.add_child(copy)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 17)
	body_label.add_theme_color_override("font_color", INK)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(body_label)

	instruction_label = Label.new()
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.add_theme_color_override("font_color", BLUE)
	instruction_label.add_theme_color_override("font_outline_color", Color.WHITE)
	instruction_label.add_theme_constant_override("outline_size", 2)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(instruction_label)

	status_label = Label.new()
	status_label.visible = false
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(status_label)

	feedback_label = Label.new()
	feedback_label.visible = false
	feedback_label.add_theme_font_size_override("font_size", 15)
	feedback_label.add_theme_color_override("font_color", BLUE)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(feedback_label)

	var button_column := VBoxContainer.new()
	button_column.add_theme_constant_override("separation", 8)
	outer.add_child(button_column)

	action_button = _button("Action", BLUE)
	action_button.visible = false
	action_button.pressed.connect(func(): action_pressed.emit())
	button_column.add_child(action_button)

	next_button = _button("Continue", INK)
	next_button.pressed.connect(func(): next_pressed.emit())
	button_column.add_child(next_button)

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	button_column.add_child(utility_row)

	restart_button = _button("Restart lesson", Color("#77736c"))
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(func(): restart_pressed.emit())
	utility_row.add_child(restart_button)

	exit_button = _button("Back to menu", Color("#77736c"))
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.pressed.connect(func(): exit_pressed.emit())
	utility_row.add_child(exit_button)

func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.custom_minimum_size = Vector2(0, 42)

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#c7c3bb")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", disabled)
	return button

func show_step(step: Dictionary, index: int, total: int) -> void:
	progress_label.text = "LESSON %02d / %02d" % [index + 1, total]
	title_label.text = step.get("title", "Tutorial")
	body_label.text = step.get("body", "")
	instruction_label.text = step.get("instruction", "")
	set_status("")
	set_feedback("")

func configure_buttons(
	show_next: bool,
	next_text: String = "Continue",
	show_action: bool = false,
	action_text: String = "Action"
) -> void:
	next_button.visible = show_next
	next_button.text = next_text
	action_button.visible = show_action
	action_button.text = action_text

func set_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()

func set_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
