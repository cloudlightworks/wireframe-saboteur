extends CanvasLayer
class_name DebugHandBuilder

var game_state: GameState
var hand_panel: HandPanel
var templates: Array[Card] = []
var item_list: ItemList
var count_label: Label
var next_debug_uid := 9000

func setup(gs: GameState, hp: HandPanel) -> void:
	game_state = gs
	hand_panel = hp
	visible = false
	_build_templates()
	_build_ui()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_count()

func _build_templates() -> void:
	# Dedupe the real database so debug cards exactly match real archetypes
	var seen := {}
	for c in CardDatabase.build_full_deck():
		var key := _card_key(c)
		if not seen.has(key):
			seen[key] = true
			templates.append(c)

func _card_key(c: Card) -> String:
	match c.category:
		Card.Category.CHART:
			return "chart_%d" % c.chart_values.get(Piece.Type.A, 0)
		Card.Category.TYPE:
			var letters := ""
			for t in c.piece_types:
				letters += CardView._letter(t)
			return "type_%s" % letters
		Card.Category.MINOR_POWER:
			return "minor_%d_%d" % [c.minor_effect, c.effect_piece_type]
		Card.Category.MAJOR_POWER:
			return "major_%d" % c.major_effect
	return "?"

func _card_label(c: Card) -> String:
	match c.category:
		Card.Category.CHART:
			return "Chart  A:%d B:%d C:%d" % [
				c.chart_values.get(Piece.Type.A, 0),
				c.chart_values.get(Piece.Type.B, 0),
				c.chart_values.get(Piece.Type.C, 0)]
		Card.Category.TYPE:
			var letters := ""
			for t in c.piece_types:
				letters += CardView._letter(t)
			return "Type  %s" % letters
		Card.Category.MINOR_POWER:
			match c.minor_effect:
				Card.MinorEffect.GET_MOVE_ON:
					return "Get Move On! (%s)" % CardView._letter(c.effect_piece_type)
				Card.MinorEffect.CLOSE_CALL:
					return "Close Call! (%s)" % CardView._letter(c.effect_piece_type)
				Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
					return "I Thought You Were Dead! (%s)" % CardView._letter(c.effect_piece_type)
				Card.MinorEffect.JUST_IN_CASE:
					return "Just In Case..."
		Card.Category.MAJOR_POWER:
			match c.major_effect:
				Card.MajorEffect.INEFFECTIVE_LEADERSHIP: return "Ineffective Leadership"
				Card.MajorEffect.HE_SEEMED_SUSPICIOUS: return "He Seemed Suspicious"
				Card.MajorEffect.JUST_THIS_ONCE: return "Just This Once"
				Card.MajorEffect.BLITZKRIEG: return "Blitzkrieg"
				Card.MajorEffect.IM_ON_TO_YOU: return "I'm On To You"
				Card.MajorEffect.ONE_MAN_ARMY: return "One Man Army"
				Card.MajorEffect.DOUBLE_AGENT: return "Double Agent"
	return "?"

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(440, 60)
	panel.custom_minimum_size = Vector2(400, 600)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG: Build Hand (F4 to close)"
	vbox.add_child(title)

	count_label = Label.new()
	vbox.add_child(count_label)

	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(380, 480)
	for t in templates:
		item_list.add_item(_card_label(t))
	item_list.item_selected.connect(_on_item_selected)
	vbox.add_child(item_list)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	var clear_btn := Button.new()
	clear_btn.text = "Clear Hand"
	clear_btn.pressed.connect(_on_clear)
	hbox.add_child(clear_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(toggle)
	hbox.add_child(close_btn)

func _on_item_selected(index: int) -> void:
	if game_state.hands[game_state.current_player].size() >= 9:
		_refresh_count()
		return
	var t: Card = templates[index]
	var c := Card.new()
	c.uid = next_debug_uid; next_debug_uid += 1
	c.category = t.category
	c.piece_types = t.piece_types.duplicate()
	c.chart_values = t.chart_values.duplicate()
	c.minor_effect = t.minor_effect
	c.major_effect = t.major_effect
	c.effect_piece_type = t.effect_piece_type
	game_state.hands[game_state.current_player].append(c)
	hand_panel.refresh()
	_refresh_count()

func _on_clear() -> void:
	game_state.hands[game_state.current_player].clear()
	hand_panel.refresh()
	_refresh_count()

func _refresh_count() -> void:
	var who := "BLUE" if game_state.current_player == Piece.Owner.BLUE else "RED"
	count_label.text = "%s hand: %d / 9" % [who, game_state.hands[game_state.current_player].size()]
