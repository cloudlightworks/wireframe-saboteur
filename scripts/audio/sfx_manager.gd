extends Node

const SFX: Dictionary = {
	"move_a": preload("res://assets/audio/sfx/sfx_amove.ogg"),
	"move_b": preload("res://assets/audio/sfx/sfx_bmove.ogg"),
	"move_c": preload("res://assets/audio/sfx/sfx_cmove.ogg"),
	"cap_a_c": preload("res://assets/audio/sfx/sfx_a_cap_c.ogg"),
	"cap_b_a": preload("res://assets/audio/sfx/sfx_b_cap_a.ogg"),
	"cap_c_b": preload("res://assets/audio/sfx/sfx_c_cap_b.ogg"),
	"close_call_save": preload("res://assets/audio/sfx/sfx_cc_cap.ogg"),
	"cap_general": preload("res://assets/audio/sfx/sfx_cap_gen.ogg"),
	"mutual_01": preload("res://assets/audio/sfx/sfx_mutual_01.ogg"),
	"mutual_02": preload("res://assets/audio/sfx/sfx_mutual_02.ogg"),
	"croce_place": preload("res://assets/audio/sfx/sfx_croce_place.ogg"),
	"declare_saboteur_card": preload("res://assets/audio/sfx/sfx_declaresabo_card.ogg"),
	"saboteur_transform": preload("res://assets/audio/sfx/sfx_sabo_transform.ogg"),
	"discard": preload("res://assets/audio/sfx/sfx_discard.ogg"),
	"illegal": preload("res://assets/audio/sfx/sfx_no_can_do.ogg"),
	"play_major_card": preload("res://assets/audio/sfx/sfx_play_major_card.ogg"),
	"play_minor_card": preload("res://assets/audio/sfx/sfx_play_minor_card.ogg"),
	"jto_objmove": preload("res://assets/audio/sfx/sfx_jto_objmove.ogg"),
	"victory": preload("res://assets/audio/sfx/sfx_winner_screen_victory.ogg"),
	"gen_move": preload("res://assets/audio/sfx/sfx_gen_move.ogg"),
	"gen_caps": preload("res://assets/audio/sfx/sfx_gen_caps.ogg"),
	"iotu_cap": preload("res://assets/audio/sfx/sfx_iotu_cap.ogg"),
	"aoo_cap": preload("res://assets/audio/sfx/sfx_oma_cap.ogg"),
	"sel_card": preload("res://assets/audio/sfx/sfx_sel_card.ogg"),
	"quit": preload("res://assets/audio/sfx/sfx_quit.ogg"),
	"end_turn": preload("res://assets/audio/sfx/sfx_end_turn.ogg"),
	"menu_hover_1": preload("res://assets/audio/sfx/menu_hover_1.ogg"),
	"menu_hover_2": preload("res://assets/audio/sfx/menu_hover_2.ogg"),
	"menu_click": preload("res://assets/audio/sfx/menu_click.ogg"),
}

const POOL_SIZE := 8

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)


func play(key: String) -> void:
	if not SFX.has(key):
		push_warning("SfxManager: unknown sfx key '%s'" % key)
		return
	var p := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	p.stream = SFX[key]
	p.play()


# Menu hovers strictly alternate rather than picking at random, so running
# down a list of options gives an even back-and-forth.
var _menu_hover_toggle: bool = false

func play_menu_hover() -> void:
	_menu_hover_toggle = not _menu_hover_toggle
	play("menu_hover_1" if _menu_hover_toggle else "menu_hover_2")

func play_mutual() -> void:
	play("mutual_01" if randi() % 2 == 0 else "mutual_02")

func play_capture(attacker_type: Piece.Type, defender_type: Piece.Type) -> void:
	if defender_type == Piece.Type.GENERAL:
		play("cap_general")
		return
	if attacker_type == Piece.Type.A and defender_type == Piece.Type.C:
		play("cap_a_c")
	elif attacker_type == Piece.Type.B and defender_type == Piece.Type.A:
		play("cap_b_a")
	elif attacker_type == Piece.Type.C and defender_type == Piece.Type.B:
		play("cap_c_b")
	elif attacker_type == defender_type:
		play("close_call_save")

func play_capture_full(attacker: Piece, defender: Piece, game_state) -> void:
	if defender.type == Piece.Type.GENERAL:
		if attacker.has_status("saboteur"):
			play("cap_general")
		elif game_state.one_man_army_active and attacker.type == game_state.one_man_army_type:
			play("aoo_cap")
		return
	if attacker.type == Piece.Type.GENERAL:
		if defender.has_status("saboteur"):
			play("iotu_cap")
		else:
			play("gen_caps")
		return
	play_capture(attacker.type, defender.type)
	
func set_sfx_volume(linear_volume: float) -> void:
	var safe_volume := clampf(linear_volume, 0.0, 1.0)

	if safe_volume <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), true)
	else:
		var bus_index := AudioServer.get_bus_index(&"SFX")
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))
