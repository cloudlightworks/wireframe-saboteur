extends Node
class_name MenuRoot

# Entry-point router. Shows the main menu; on selection either swaps in the
# how-to-play screen (returnable via `back`) or loads the game scene (main.tscn).
# The game scene itself is untouched - this simply launches it instead of the
# game being the project's main scene directly.
#
# To make this the entry point: set this scene as the project's main scene
# (Project > Project Settings > Application > Run > Main Scene). The old main.tscn
# stays exactly as-is and is loaded on "start game".

const GAME_SCENE := "res://scenes/main.tscn"
const TUTORIAL_SCENE := preload("res://scenes/tutorial.tscn")

var _current: Control = null

func _ready() -> void:
	_show_menu()

func _clear() -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_current = null

# A plain Node parent gives Control children no rect to anchor against, so a
# child's own PRESET_FULL_RECT collapses to size zero (which is why the paper
# background wasn't filling the window). Force the child to the viewport size and
# keep it in sync on resize.
func _fit_to_viewport(c: Control) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	c.position = Vector2.ZERO
	c.size = vp_size
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	if _current and is_instance_valid(_current):
		_current.size = get_viewport().get_visible_rect().size

func _show_menu() -> void:
	_clear()
	var menu := MainMenu.new()
	menu.option_selected.connect(_on_option_selected)
	add_child(menu)
	_fit_to_viewport(menu)
	_current = menu

func _show_how_to_play() -> void:
	_clear()
	var htp := HowToPlay.new()
	htp.back.connect(_show_menu)
	htp.tutorial_requested.connect(_on_tutorial_requested)
	add_child(htp)
	_fit_to_viewport(htp)
	_current = htp

func _on_tutorial_requested() -> void:
	_clear()
	var tutorial := TUTORIAL_SCENE.instantiate()
	tutorial.connect("finished", Callable(self, "_show_menu"))
	add_child(tutorial)
	_fit_to_viewport(tutorial as Control)
	_current = tutorial as Control

func _show_house_rules() -> void:
	_clear()
	var hr := HouseRules.new()
	hr.back.connect(_show_menu)
	add_child(hr)
	_fit_to_viewport(hr)
	_current = hr

func _show_options() -> void:
	var options := OptionsMenu.new()
	options.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(options)
	options.back.connect(func():
		options.queue_free()
		_show_menu()
	)

func _show_make_your_own() -> void:
	_clear()
	var myo := MakeYourOwn.new()
	myo.back.connect(_show_menu)
	add_child(myo)
	_fit_to_viewport(myo)
	_current = myo

func _show_credits() -> void:
	_clear()
	var cr := Credits.new()
	cr.back.connect(_show_menu)
	add_child(cr)
	_fit_to_viewport(cr)
	_current = cr

func _show_story() -> void:
	_clear()
	var st := Story.new()
	st.back.connect(_show_menu)
	add_child(st)
	_fit_to_viewport(st)
	_current = st

func _on_option_selected(id: String) -> void:
	match id:
		"start_game":
			NetworkManager.disconnect_network()
			GameSetup.vs_cpu = false
			get_tree().change_scene_to_file(GAME_SCENE)
		"start_cpu_game":
			NetworkManager.disconnect_network()
			GameSetup.vs_cpu = true
			GameSetup.cpu_side = Piece.Owner.RED
			get_tree().change_scene_to_file(GAME_SCENE)
		"host_game":
			_show_host_prompt()
		"join_game":
			_show_join_prompt()
		"how_to_play":
			_show_how_to_play()
		"house_rules":
			_show_house_rules()
		"options":
			_show_options()
		"make_your_own":
			_show_make_your_own()
		"credits":
			_show_credits()
		"story":
			_show_story()
		"quit":
			SfxManager.play("quit")
			await get_tree().create_timer(2.0).timeout
			get_tree().quit()


const JOIN_ADDRESS_PATH := "user://last_join_address.txt"
const PLAYER_NAME_PATH := "user://player_name.txt"

func _show_join_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.position = Vector2.ZERO
	shade.size = get_viewport().get_visible_rect().size
	layer.add_child(shade)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = get_viewport().get_visible_rect().size
	layer.add_child(center)
	
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Join Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Enter the host's address.\n127.0.0.1 = same computer."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.custom_minimum_size = Vector2(320, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	
	var name_field := LineEdit.new()
	name_field.text = _load_player_name()
	name_field.placeholder_text = "Your name (optional)"
	name_field.max_length = 16
	name_field.custom_minimum_size = Vector2(320, 44)
	name_field.add_theme_font_size_override("font_size", 20)
	col.add_child(name_field)

	var field := LineEdit.new()
	field.text = _load_last_address()
	field.placeholder_text = "127.0.0.1"
	field.custom_minimum_size = Vector2(320, 44)
	field.add_theme_font_size_override("font_size", 20)
	col.add_child(field)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 46)
	cancel.pressed.connect(func(): layer.queue_free())
	row.add_child(cancel)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.custom_minimum_size = Vector2(150, 46)
	var do_join := func():
		var addr := field.text.strip_edges()
		if addr == "":
			addr = "127.0.0.1"
		_save_last_address(addr)
		var pname := name_field.text.strip_edges()
		_save_player_name(pname)
		GameSetup.vs_cpu = false
		NetworkManager.local_player_name = pname
		status.text = "Connecting to %s…" % addr
		connect_btn.disabled = true
		field.editable = false
		NetworkManager.disconnect_network()
		var err: int = NetworkManager.join_game(addr)
		if err != OK:
			status.text = "Couldn't start a connection.\nCheck the address."
			connect_btn.disabled = false
			field.editable = true
			return
		_await_join(layer, status, connect_btn, field)
	connect_btn.pressed.connect(do_join)
	field.text_submitted.connect(func(_t): do_join.call())
	row.add_child(connect_btn)

	col.add_child(row)
	box.add_child(col)
	center.add_child(box)
	field.grab_focus()
	field.select_all()

func _await_join(layer: CanvasLayer, status: Label, connect_btn: Button, field: LineEdit) -> void:
	# A dictionary, not a bool — GDScript lambdas capture locals by value, so a
	# plain bool wouldn't be shared between these callbacks.
	var state := {"done": false}

	var fail := func(msg: String) -> void:
		if state["done"]:
			return
		state["done"] = true
		NetworkManager.disconnect_network()
		status.text = msg
		connect_btn.disabled = false
		field.editable = true

	var succeed := func() -> void:
		if state["done"]:
			return
		state["done"] = true
		layer.queue_free()
		get_tree().change_scene_to_file(GAME_SCENE)

	NetworkManager.join_succeeded.connect(succeed, CONNECT_ONE_SHOT)
	NetworkManager.join_failed.connect(fail, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(
		func(): fail.call("Couldn't reach that host.\n\nCheck the address, and that they're hosting."),
		CONNECT_ONE_SHOT)

	await get_tree().create_timer(10.0).timeout
	fail.call("No response from that address.\n\nCheck the address, and that the host's firewall allows the game.")
	
func _on_upnp_result(success: bool, external_ip: String, message: String) -> void:
	if success:
		print("UPnP OK — friends can join at: ", external_ip)
	else:
		print("UPnP unavailable: ", message)
		
func _load_last_address() -> String:
	if FileAccess.file_exists(JOIN_ADDRESS_PATH):
		var f := FileAccess.open(JOIN_ADDRESS_PATH, FileAccess.READ)
		if f:
			var s := f.get_as_text().strip_edges()
			if s != "":
				return s
	return "127.0.0.1"

func _save_last_address(addr: String) -> void:
	var f := FileAccess.open(JOIN_ADDRESS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(addr)

func _load_player_name() -> String:
	if FileAccess.file_exists(PLAYER_NAME_PATH):
		var f := FileAccess.open(PLAYER_NAME_PATH, FileAccess.READ)
		if f:
			return f.get_as_text().strip_edges()
	return ""

func _save_player_name(n: String) -> void:
	var f := FileAccess.open(PLAYER_NAME_PATH, FileAccess.WRITE)
	if f:
		f.store_string(n)

func _show_host_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.position = Vector2.ZERO
	shade.size = get_viewport().get_visible_rect().size
	layer.add_child(shade)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = get_viewport().get_visible_rect().size
	layer.add_child(center)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Host Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Leave blank to be called by your side color."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)

	var name_field := LineEdit.new()
	name_field.text = _load_player_name()
	name_field.placeholder_text = "Your name (optional)"
	name_field.max_length = 16
	name_field.custom_minimum_size = Vector2(320, 44)
	name_field.add_theme_font_size_override("font_size", 20)
	col.add_child(name_field)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 46)
	cancel.pressed.connect(func(): layer.queue_free())
	row.add_child(cancel)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(150, 46)
	var do_host := func():
		var pname := name_field.text.strip_edges()
		_save_player_name(pname)
		GameSetup.vs_cpu = false
		NetworkManager.disconnect_network()
		NetworkManager.local_player_name = pname
		NetworkManager.player_names[Piece.Owner.BLUE] = RuleSettings.sanitize_name(pname)
		NetworkManager.upnp_result.connect(_on_upnp_result, CONNECT_ONE_SHOT)
		var err: int = NetworkManager.host_game_upnp()
		if err != OK:
			push_error("host_game failed: %s" % err)
			layer.queue_free()
			return
		get_tree().change_scene_to_file(GAME_SCENE)
	start_btn.pressed.connect(do_host)
	name_field.text_submitted.connect(func(_t): do_host.call())
	row.add_child(start_btn)

	col.add_child(row)
	box.add_child(col)
	center.add_child(box)
	name_field.grab_focus()
	name_field.select_all()
