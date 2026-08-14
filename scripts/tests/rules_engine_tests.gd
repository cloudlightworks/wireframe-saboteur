extends SceneTree

func _initialize():
	test_a_vs_c()
	test_b_vs_a()
	test_c_vs_b()
	test_equal_trade()
	test_general_immunity()
	test_objective_capture()
	test_saboteur_conversion()
	test_saboteur_general_kill()
	test_only_one_active_saboteur()
	test_c_movement()
	test_c_movement_edge_of_board()
	test_b_movement()
	test_b_movement_edge_of_board()
	test_b_movement_vertical()
	test_general_diagonal_constraint()
	test_general_half_constraint()
	test_designation_from_cards()
	test_draw_card()
	test_draw_card_empty_deck()
	test_discard_card()
	test_discard_card_not_in_hand()
	test_capture_draws_card()
	test_mutual_destruction_draws_both()
	test_hand_limit_discard()
	test_hand_exactly_at_limit()
	test_end_to_end_saboteur_declaration()
	test_draw_triggers_reshuffle()
	test_end_turn()
	test_double_agent()
	test_he_seemed_suspicious()
	test_just_this_once()
	test_just_this_once_blocked_path()
	test_get_move_on()
	test_close_call()
	test_im_on_to_you()
	test_one_man_army()
	test_blitzkrieg()
	test_just_in_case()
	test_ineffective_leadership()
	test_i_thought_you_were_dead()
	test_capture_piece()
	test_croce_valid_placement()
	test_croce_invalid_placement()
	test_croce_setup_complete()
	test_general_captures_piece()
	test_general_cannot_capture_saboteur()
	test_b_slide_moves()
	test_legal_destinations_filter()
	test_objective_capture()
	test_objective_capture_by_normal_piece()
	test_objective_capture_by_saboteur()
	test_general_cannot_capture_objective()
	test_captured_saboteur_reverts_to_original_owner()
	print("All rules_engine tests passed.")
	quit()

func test_a_vs_c():
	var a := Piece.new(); a.type = Piece.Type.A
	var c := Piece.new(); c.type = Piece.Type.C
	assert(RulesEngine.resolve_capture(a, c) == RulesEngine.CaptureResult.CAPTURED)

func test_b_vs_a():
	var b := Piece.new(); b.type = Piece.Type.B
	var a := Piece.new(); a.type = Piece.Type.A
	assert(RulesEngine.resolve_capture(b, a) == RulesEngine.CaptureResult.CAPTURED)

func test_c_vs_b():
	var c := Piece.new(); c.type = Piece.Type.C
	var b := Piece.new(); b.type = Piece.Type.B
	assert(RulesEngine.resolve_capture(c, b) == RulesEngine.CaptureResult.CAPTURED)

func test_equal_trade():
	var a1 := Piece.new(); a1.type = Piece.Type.A
	var a2 := Piece.new(); a2.type = Piece.Type.A
	assert(RulesEngine.resolve_capture(a1, a2) == RulesEngine.CaptureResult.MUTUAL_DESTROY)

func test_general_immunity():
	var a := Piece.new(); a.type = Piece.Type.A
	var general := Piece.new(); general.type = Piece.Type.GENERAL
	assert(RulesEngine.resolve_capture(a, general) == RulesEngine.CaptureResult.ILLEGAL)

func test_objective_capture_by_normal_piece():
	var a := Piece.new(); a.type = Piece.Type.A
	var objective := Piece.new(); objective.type = Piece.Type.OBJECTIVE
	assert(RulesEngine.resolve_capture(a, objective) == RulesEngine.CaptureResult.CAPTURED)

func test_objective_capture_by_saboteur():
	var a := Piece.new(); a.type = Piece.Type.A; a.status_effects["saboteur"] = true
	var objective := Piece.new(); objective.type = Piece.Type.OBJECTIVE
	assert(RulesEngine.resolve_capture(a, objective) == RulesEngine.CaptureResult.CAPTURED)

func test_general_cannot_capture_objective():
	var general := Piece.new(); general.type = Piece.Type.GENERAL
	var objective := Piece.new(); objective.type = Piece.Type.OBJECTIVE
	assert(RulesEngine.resolve_capture(general, objective) == RulesEngine.CaptureResult.ILLEGAL)

func test_objective_capture():
	var game_state := GameState.new()

	var blue_objective := Piece.new()
	blue_objective.uid = 1
	blue_objective.type = Piece.Type.OBJECTIVE
	blue_objective.owner = Piece.Owner.BLUE

	var red_objective := Piece.new()
	red_objective.uid = 2
	red_objective.type = Piece.Type.OBJECTIVE
	red_objective.owner = Piece.Owner.RED

	game_state.pieces[blue_objective.uid] = blue_objective
	game_state.pieces[red_objective.uid] = red_objective

	assert(RulesEngine.check_win(game_state) == null)

	game_state.pieces.erase(red_objective.uid)

	assert(RulesEngine.check_win(game_state) == Piece.Owner.BLUE)
	
	assert(RulesEngine.check_win(game_state) == Piece.Owner.BLUE)
	game_state.free()
	
func test_saboteur_conversion():
	var piece := Piece.new()
	piece.owner = Piece.Owner.BLUE
	piece.apply_saboteur_conversion(Piece.Owner.RED)
	assert(piece.owner == Piece.Owner.RED)
	assert(piece.has_status("saboteur"))

func test_saboteur_general_kill():
	var saboteur_piece := Piece.new()
	saboteur_piece.type = Piece.Type.A
	saboteur_piece.apply_saboteur_conversion(Piece.Owner.RED)

	var general := Piece.new()
	general.type = Piece.Type.GENERAL

	assert(RulesEngine.resolve_capture(saboteur_piece, general) == RulesEngine.CaptureResult.CAPTURED)	
	
func test_only_one_active_saboteur():
	var game_state := GameState.new()

	var converted_piece := Piece.new()
	converted_piece.uid = 1
	converted_piece.apply_saboteur_conversion(Piece.Owner.RED)
	game_state.pieces[converted_piece.uid] = converted_piece

	assert(RulesEngine.can_declare_saboteur(Piece.Owner.RED, game_state) == false)
	assert(RulesEngine.can_declare_saboteur(Piece.Owner.BLUE, game_state) == true)	
	assert(RulesEngine.can_declare_saboteur(Piece.Owner.BLUE, game_state) == true)
	game_state.free()
	
func test_c_movement():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.C
	piece.cells = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	assert(moves.has(Vector2i(5, 4)))
	assert(moves.has(Vector2i(5, 6)))
	assert(moves.has(Vector2i(4, 5)))
	assert(moves.has(Vector2i(6, 5)))
	assert(moves.size() == 4)

	game_state.free()

func test_c_movement_edge_of_board():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.C
	piece.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	assert(not moves.has(Vector2i(-1, 0)))
	assert(not moves.has(Vector2i(0, -1)))
	assert(moves.has(Vector2i(1, 0)))
	assert(moves.has(Vector2i(0, 1)))
	assert(moves.size() == 2)

	game_state.free()	
	
func test_b_movement():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.B
	piece.orientation = Piece.PieceOrientation.HORIZONTAL
	piece.cells = [Vector2i(5, 5), Vector2i(6, 5)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	assert(moves.has(Vector2i(5, 4)))
	assert(moves.has(Vector2i(5, 6)))
	assert(moves.has(Vector2i(6, 4)))
	assert(moves.has(Vector2i(6, 6)))
	assert(moves.has(Vector2i(4, 5)))
	assert(moves.has(Vector2i(7, 5)))
	assert(moves.size() == 6)

	game_state.free()

func test_b_movement_edge_of_board():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.B
	piece.orientation = Piece.PieceOrientation.HORIZONTAL
	piece.cells = [Vector2i(0, 0), Vector2i(1, 0)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	assert(not moves.has(Vector2i(0, -1)))
	assert(not moves.has(Vector2i(1, -1)))
	assert(moves.has(Vector2i(0, 1)))
	assert(moves.has(Vector2i(1, 1)))
	assert(moves.has(Vector2i(2, 0)))   # slide right
	assert(not moves.has(Vector2i(-1, 0)))  # slide left off board
	assert(moves.size() == 3)

	game_state.free()

func test_b_movement_vertical():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.B
	piece.orientation = Piece.PieceOrientation.VERTICAL
	piece.cells = [Vector2i(5, 5), Vector2i(5, 6)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	assert(moves.has(Vector2i(4, 5)))
	assert(moves.has(Vector2i(6, 5)))
	assert(moves.has(Vector2i(4, 6)))
	assert(moves.has(Vector2i(6, 6)))
	assert(moves.has(Vector2i(5, 4)))  # slide up
	assert(moves.has(Vector2i(5, 7)))  # slide down
	assert(moves.size() == 6)

	game_state.free()	

func test_general_diagonal_constraint():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var general := Piece.new()
	general.type = Piece.Type.GENERAL
	general.owner = Piece.Owner.BLUE
	general.cells = [Vector2i(5, 5)]

	var moves := RulesEngine.legal_moves_for(general, game_state)

	for move in moves:
		var delta: Vector2i = move - Vector2i(5, 5)
		assert(abs(delta.x) == 1 and abs(delta.y) == 1)

	game_state.free()

func test_general_half_constraint():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var general := Piece.new()
	general.type = Piece.Type.GENERAL
	general.owner = Piece.Owner.BLUE
	general.cells = [Vector2i(5, 7)]

	var moves := RulesEngine.legal_moves_for(general, game_state)

	assert(not moves.has(Vector2i(4, 8)))
	assert(not moves.has(Vector2i(6, 8)))
	assert(moves.has(Vector2i(4, 6)))
	assert(moves.has(Vector2i(6, 6)))
	assert(moves.size() == 2)

	game_state.free()

func test_designation_from_cards():
	var type_card := Card.new()
	type_card.category = Card.Category.TYPE
	type_card.piece_types = [Piece.Type.C]

	var chart_card := Card.new()
	chart_card.category = Card.Category.CHART
	chart_card.chart_values = {
		Piece.Type.A: 1,
		Piece.Type.B: 3,
		Piece.Type.C: 2,
	}

	# Valid single-type pairing
	assert(RulesEngine.designation_from_cards(type_card, chart_card, Piece.Type.C) == "C2")

	# chosen_type not supported by this type card
	assert(RulesEngine.designation_from_cards(type_card, chart_card, Piece.Type.A) == "")

	# wrong category — two TYPE cards instead of TYPE + CHART
	var other_type_card := Card.new()
	other_type_card.category = Card.Category.TYPE
	other_type_card.piece_types = [Piece.Type.A]
	assert(RulesEngine.designation_from_cards(type_card, other_type_card, Piece.Type.C) == "")

	# multi-type card A/B — valid chosen type and invalid chosen type
	var multi_type_card := Card.new()
	multi_type_card.category = Card.Category.TYPE
	multi_type_card.piece_types = [Piece.Type.A, Piece.Type.B]
	assert(RulesEngine.designation_from_cards(multi_type_card, chart_card, Piece.Type.B) == "B3")
	assert(RulesEngine.designation_from_cards(multi_type_card, chart_card, Piece.Type.C) == "")

	# chart card missing value for the chosen type
	var incomplete_chart_card := Card.new()
	incomplete_chart_card.category = Card.Category.CHART
	incomplete_chart_card.chart_values = {
		Piece.Type.A: 1,
		Piece.Type.B: 3,
	}
	assert(RulesEngine.designation_from_cards(type_card, incomplete_chart_card, Piece.Type.C) == "")

func test_draw_card():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	var card_b := Card.new()
	card_b.uid = 2
	game_state.deck = [card_a, card_b]

	var drawn := game_state.draw_card(Piece.Owner.BLUE)

	assert(drawn == card_a)
	assert(game_state.hands[Piece.Owner.BLUE].has(card_a))
	assert(not game_state.deck.has(card_a))
	assert(game_state.deck.size() == 1)

	game_state.free()

func test_draw_card_empty_deck():
	var game_state := GameState.new()
	game_state.deck = []

	var drawn := game_state.draw_card(Piece.Owner.BLUE)

	assert(drawn == null)
	assert(game_state.hands[Piece.Owner.BLUE].is_empty())

	game_state.free()

func test_discard_card():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	game_state.hands[Piece.Owner.BLUE] = [card_a]

	var result := game_state.discard_card(Piece.Owner.BLUE, card_a)

	assert(result == true)
	assert(not game_state.hands[Piece.Owner.BLUE].has(card_a))
	assert(game_state.discard_pile.has(card_a))

	game_state.free()

func test_discard_card_not_in_hand():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	# card_a is never added to any hand

	var result := game_state.discard_card(Piece.Owner.BLUE, card_a)

	assert(result == false)
	assert(game_state.discard_pile.is_empty())

	game_state.free()
	
func test_capture_draws_card():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	game_state.deck = [card_a]

	game_state.resolve_capture_draws(RulesEngine.CaptureResult.CAPTURED, Piece.Owner.BLUE, Piece.Owner.RED)

	assert(game_state.hands[Piece.Owner.BLUE].has(card_a))
	assert(game_state.hands[Piece.Owner.RED].is_empty())
	assert(game_state.deck.is_empty())

	game_state.free()

func test_mutual_destruction_draws_both():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	var card_b := Card.new()
	card_b.uid = 2
	game_state.deck = [card_a, card_b]

	game_state.resolve_capture_draws(RulesEngine.CaptureResult.MUTUAL_DESTROY, Piece.Owner.BLUE, Piece.Owner.RED)

	assert(game_state.hands[Piece.Owner.BLUE].has(card_a))
	assert(game_state.hands[Piece.Owner.RED].has(card_b))
	assert(game_state.deck.is_empty())

	game_state.free()

func test_hand_limit_discard():
	var game_state := GameState.new()

	var cards: Array[Card] = []
	for i in range(10):
		var c := Card.new()
		c.uid = i
		cards.append(c)
	game_state.hands[Piece.Owner.BLUE] = cards

	assert(game_state.is_hand_over_limit(Piece.Owner.BLUE))

	var discarded: Card = cards[5]
	var result := game_state.discard_to_deck(Piece.Owner.BLUE, discarded)

	assert(result == true)
	assert(not game_state.hands[Piece.Owner.BLUE].has(discarded))
	assert(game_state.deck.has(discarded))
	assert(not game_state.is_hand_over_limit(Piece.Owner.BLUE))

	game_state.free()

func test_hand_exactly_at_limit():
	var game_state := GameState.new()

	var cards: Array[Card] = []
	for i in range(9):
		var c := Card.new()
		c.uid = i
		cards.append(c)
	game_state.hands[Piece.Owner.BLUE] = cards

	assert(not game_state.is_hand_over_limit(Piece.Owner.BLUE))

	game_state.free()

func test_end_to_end_saboteur_declaration():
	var game_state := GameState.new()

	# Set up an opponent piece to target
	var target_piece := Piece.new()
	target_piece.uid = 1
	target_piece.designation = "C2"
	target_piece.type = Piece.Type.C
	target_piece.owner = Piece.Owner.RED
	game_state.pieces[target_piece.uid] = target_piece

	# Build the two cards needed
	var type_card := Card.new()
	type_card.uid = 10
	type_card.category = Card.Category.TYPE
	type_card.piece_types = [Piece.Type.C]

	var chart_card := Card.new()
	chart_card.uid = 11
	chart_card.category = Card.Category.CHART
	chart_card.chart_values = { Piece.Type.A: 1, Piece.Type.B: 3, Piece.Type.C: 2 }

	# Put both cards in BLUE's hand
	game_state.hands[Piece.Owner.BLUE] = [type_card, chart_card]

	# Successful declaration
	var result := game_state.declare_saboteur(Piece.Owner.BLUE, type_card, chart_card, Piece.Type.C)
	assert(result == true)
	assert(target_piece.owner == Piece.Owner.BLUE)
	assert(target_piece.has_status("saboteur"))
	assert(not game_state.hands[Piece.Owner.BLUE].has(type_card))
	assert(not game_state.hands[Piece.Owner.BLUE].has(chart_card))
	assert(game_state.discard_pile.has(type_card))
	assert(game_state.discard_pile.has(chart_card))

	# Card not in hand — should fail
	var extra_type_card := Card.new()
	extra_type_card.uid = 12
	extra_type_card.category = Card.Category.TYPE
	extra_type_card.piece_types = [Piece.Type.A]
	var result2 := game_state.declare_saboteur(Piece.Owner.BLUE, extra_type_card, chart_card, Piece.Type.A)
	assert(result2 == false)

	game_state.free()

func test_draw_triggers_reshuffle():
	var game_state := GameState.new()

	var card_a := Card.new()
	card_a.uid = 1
	var card_b := Card.new()
	card_b.uid = 2

	# Deck is empty, discard has two cards
	game_state.deck = []
	game_state.discard_pile = [card_a, card_b]

	var drawn := game_state.draw_card(Piece.Owner.BLUE)

	assert(drawn != null)
	assert(game_state.hands[Piece.Owner.BLUE].has(drawn))
	assert(game_state.deck.size() == 1)
	assert(game_state.discard_pile.is_empty())

	game_state.free()

func test_end_turn():
	var game_state := GameState.new()

	assert(game_state.current_player == Piece.Owner.BLUE)
	assert(game_state.turn_number == 1)

	game_state.end_turn()
	assert(game_state.current_player == Piece.Owner.RED)
	assert(game_state.turn_number == 2)

	game_state.end_turn()
	assert(game_state.current_player == Piece.Owner.BLUE)
	assert(game_state.turn_number == 3)

	game_state.free()

func test_double_agent():
	var game_state := GameState.new()

	var piece := Piece.new()
	piece.uid = 1
	piece.type = Piece.Type.C
	piece.owner = Piece.Owner.RED
	piece.status_effects["saboteur"] = true
	game_state.pieces[piece.uid] = piece

	# Blue reclaims piece converted by Red
	var result := game_state.apply_double_agent(Piece.Owner.BLUE)
	assert(result == true)
	assert(piece.owner == Piece.Owner.BLUE)
	assert(not piece.has_status("saboteur"))

	# No opponent saboteur left — should fail
	var result2 := game_state.apply_double_agent(Piece.Owner.BLUE)
	assert(result2 == false)

	game_state.free()

func test_he_seemed_suspicious():
	var game_state := GameState.new()

	assert(game_state.can_capture_own_piece == false)

	game_state.apply_he_seemed_suspicious()
	assert(game_state.can_capture_own_piece == true)

	game_state.end_turn()
	assert(game_state.can_capture_own_piece == false)

	game_state.free()

func test_just_this_once():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var objective := Piece.new()
	objective.uid = 1
	objective.type = Piece.Type.OBJECTIVE
	objective.owner = Piece.Owner.BLUE
	objective.cells = [Vector2i(4, 4)]
	game_state.pieces[objective.uid] = objective

	assert(game_state.objective_has_moved.get(Piece.Owner.BLUE, false) == false)

	# Diagonal move is illegal
	assert(game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(5, 5)) == false)
	# Too far (4 spaces) is illegal
	assert(game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 0)) == false)
	# Objective hasn't moved yet after illegal attempts
	assert(game_state.objective_has_moved.get(Piece.Owner.BLUE, false) == false)
	assert(objective.cells[0] == Vector2i(4, 4))

	# Valid: 3 spaces straight up (orthogonal, clear path, own half)
	var result := game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 1))
	assert(result == true)
	assert(objective.cells[0] == Vector2i(4, 1))
	assert(game_state.objective_has_moved.get(Piece.Owner.BLUE, false) == true) 

	# Second attempt fails (once per game)
	var result2 := game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 2))
	assert(result2 == false)
	assert(objective.cells[0] == Vector2i(4, 1))

	game_state.free()

func test_just_this_once_blocked_path():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var objective := Piece.new()
	objective.uid = 1
	objective.type = Piece.Type.OBJECTIVE
	objective.owner = Piece.Owner.BLUE
	objective.cells = [Vector2i(4, 4)]
	game_state.pieces[objective.uid] = objective

	# A blocking piece two cells up
	var blocker := Piece.new()
	blocker.uid = 2
	blocker.type = Piece.Type.A
	blocker.owner = Piece.Owner.BLUE
	blocker.cells = [Vector2i(4, 2)]
	game_state.pieces[blocker.uid] = blocker

	# Can't move 3 up (path passes through the blocker at (4,2))
	assert(game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 1)) == false)
	# Can't land on the blocker either
	assert(game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 2)) == false)
	# Can move 1 up (clear)
	assert(game_state.apply_just_this_once(Piece.Owner.BLUE, Vector2i(4, 3)) == true)

	game_state.free()

func test_get_move_on():
	var game_state := GameState.new()

	var a5 := Piece.new()
	a5.uid = 1; a5.type = Piece.Type.A
	var a7 := Piece.new()
	a7.uid = 2; a7.type = Piece.Type.A
	var c3 := Piece.new()
	c3.uid = 3; c3.type = Piece.Type.C

	# No GaMO active
	assert(not game_state.piece_has_gamo_move(a5))

	# Activate GaMO for A
	game_state.apply_get_move_on(Piece.Type.A)
	# Any unclaimed A is eligible; C is not
	assert(game_state.piece_has_gamo_move(a5))
	assert(game_state.piece_has_gamo_move(a7))
	assert(not game_state.piece_has_gamo_move(c3))

	# a5 claims the bonus by spending it
	game_state.spend_gamo_move(a5)
	# a5 has used its one bonus move — no more
	assert(not game_state.piece_has_gamo_move(a5))
	# a7 no longer eligible — the bonus was claimed by a5
	assert(not game_state.piece_has_gamo_move(a7))

	# end_turn clears GaMO
	game_state.board = Board.new()
	game_state.end_turn()
	assert(not game_state.piece_has_gamo_move(a5))

	game_state.free()

func test_close_call():
	var game_state := GameState.new()

	var a1 := Piece.new(); a1.type = Piece.Type.A; a1.owner = Piece.Owner.BLUE
	var a2 := Piece.new(); a2.type = Piece.Type.A; a2.owner = Piece.Owner.RED
	var c1 := Piece.new(); c1.type = Piece.Type.C; c1.owner = Piece.Owner.RED

	# Without Close Call — A vs A is mutual destruction
	assert(game_state.resolve_capture_with_effects(a1, a2) == RulesEngine.CaptureResult.MUTUAL_DESTROY)

	# With Close Call — A vs A becomes a capture
	game_state.apply_close_call(Piece.Type.A)
	assert(game_state.close_call_active.has(Piece.Type.A))
	assert(game_state.resolve_capture_with_effects(a1, a2) == RulesEngine.CaptureResult.CAPTURED)

	# Close Call consumed — A vs A is mutual destruction again
	assert(not game_state.close_call_active.has(Piece.Type.A))
	assert(game_state.resolve_capture_with_effects(a1, a2) == RulesEngine.CaptureResult.MUTUAL_DESTROY)

	# Close Call does not trigger on non-same-type captures — persists across them
	game_state.apply_close_call(Piece.Type.A)
	assert(game_state.resolve_capture_with_effects(a1, c1) == RulesEngine.CaptureResult.CAPTURED)
	assert(game_state.close_call_active.has(Piece.Type.A))

	# Clears on end turn
	game_state.end_turn()
	assert(not game_state.close_call_active.has(Piece.Type.A))

	game_state.free()

func test_im_on_to_you():
	var game_state := GameState.new()

	var general := Piece.new()
	general.type = Piece.Type.GENERAL
	general.owner = Piece.Owner.BLUE

	var saboteur_piece := Piece.new()
	saboteur_piece.type = Piece.Type.A
	saboteur_piece.owner = Piece.Owner.RED
	saboteur_piece.status_effects["saboteur"] = true

	# Without I'm On To You — General cannot capture Saboteur
	assert(RulesEngine.resolve_capture(general, saboteur_piece) == RulesEngine.CaptureResult.ILLEGAL)

	# With I'm On To You — General can capture Saboteur via resolve_capture_with_effects
	game_state.apply_im_on_to_you()
	assert(game_state.general_can_capture_saboteur == true)

	var result := game_state.resolve_capture_with_effects(general, saboteur_piece)
	assert(result == RulesEngine.CaptureResult.CAPTURED)

	# Clears on end turn
	game_state.end_turn()
	assert(game_state.general_can_capture_saboteur == false)

	game_state.free()

func test_one_man_army():
	var game_state := GameState.new()

	var type_card := Card.new()
	type_card.uid = 1
	type_card.category = Card.Category.TYPE
	type_card.piece_types = [Piece.Type.B]
	game_state.hands[Piece.Owner.BLUE] = [type_card]

	var b_piece := Piece.new()
	b_piece.type = Piece.Type.B
	b_piece.owner = Piece.Owner.BLUE

	var general := Piece.new()
	general.type = Piece.Type.GENERAL
	general.owner = Piece.Owner.RED

	# Without One Man Army — B cannot capture General
	assert(game_state.resolve_capture_with_effects(b_piece, general) == RulesEngine.CaptureResult.ILLEGAL)

	# With One Man Army — B can capture General
	var result := game_state.apply_one_man_army(Piece.Owner.BLUE, type_card, Piece.Type.B)
	assert(result == true)
	assert(game_state.one_man_army_active == true)
	assert(not game_state.hands[Piece.Owner.BLUE].has(type_card))
	assert(game_state.resolve_capture_with_effects(b_piece, general) == RulesEngine.CaptureResult.CAPTURED)

	# Wrong type — A cannot capture General under B One Man Army
	var a_piece := Piece.new()
	a_piece.type = Piece.Type.A
	a_piece.owner = Piece.Owner.BLUE
	assert(game_state.resolve_capture_with_effects(a_piece, general) == RulesEngine.CaptureResult.ILLEGAL)

	# Clears on end turn
	game_state.end_turn()
	assert(game_state.one_man_army_active == false)

	game_state.free()

func test_blitzkrieg():
	var game_state := GameState.new()

	assert(not game_state.blitzkrieg_active)
	assert(game_state.can_move_another_piece(1) == true)

	game_state.record_piece_moved(1)
	assert(game_state.can_move_another_piece(1) == false)
	assert(game_state.can_move_another_piece(2) == false)

	game_state.apply_blitzkrieg()
	assert(game_state.blitzkrieg_active == true)
	assert(game_state.can_move_another_piece(2) == true)
	assert(game_state.can_move_another_piece(1) == false)

	game_state.record_piece_moved(2)
	assert(game_state.can_move_another_piece(3) == false)

	game_state.end_turn()
	assert(game_state.blitzkrieg_active == false)
	assert(game_state.can_move_another_piece(1) == true)

	game_state.free()

func test_just_in_case():
	var game_state := GameState.new()

	var card_a := Card.new(); card_a.uid = 1
	var card_b := Card.new(); card_b.uid = 2
	var card_c := Card.new(); card_c.uid = 3
	game_state.deck = [card_a, card_b, card_c]

	game_state.apply_just_in_case(Piece.Owner.BLUE)
	assert(game_state.bonus_draw_on_next_capture.has(Piece.Owner.BLUE))

	game_state.resolve_capture_draws(RulesEngine.CaptureResult.CAPTURED, Piece.Owner.BLUE, Piece.Owner.RED)

	assert(game_state.hands[Piece.Owner.BLUE].size() == 2)
	assert(not game_state.bonus_draw_on_next_capture.has(Piece.Owner.BLUE))

	game_state.free()

func test_ineffective_leadership():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var general := Piece.new()
	general.type = Piece.Type.GENERAL
	general.owner = Piece.Owner.RED
	general.cells = [Vector2i(5, 9)]

	var moves_before := RulesEngine.legal_moves_for(general, game_state)
	assert(moves_before.size() > 0)

	game_state.apply_ineffective_leadership(Piece.Owner.BLUE)
	assert(game_state.is_general_frozen(Piece.Owner.RED))

	var moves_frozen := RulesEngine.legal_moves_for(general, game_state)
	assert(moves_frozen.is_empty())

	# 6 end_turn() calls = 3 of RED's turns
	game_state.end_turn()  # BLUE ends — RED not decremented yet
	assert(game_state.is_general_frozen(Piece.Owner.RED))
	game_state.end_turn()  # RED ends — decrement to 2
	assert(game_state.is_general_frozen(Piece.Owner.RED))
	game_state.end_turn()  # BLUE ends
	assert(game_state.is_general_frozen(Piece.Owner.RED))
	game_state.end_turn()  # RED ends — decrement to 1
	assert(game_state.is_general_frozen(Piece.Owner.RED))
	game_state.end_turn()  # BLUE ends
	assert(game_state.is_general_frozen(Piece.Owner.RED))
	game_state.end_turn()  # RED ends — decrement to 0, erase
	assert(not game_state.is_general_frozen(Piece.Owner.RED))

	var moves_after := RulesEngine.legal_moves_for(general, game_state)
	assert(moves_after.size() > 0)

	game_state.free()

func test_i_thought_you_were_dead():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var captured_a := Piece.new()
	captured_a.uid = 1
	captured_a.type = Piece.Type.A
	captured_a.owner = Piece.Owner.BLUE
	captured_a.cells = [Vector2i(0, 0)]
	game_state.captured_pieces[Piece.Owner.BLUE].append(captured_a)

	assert(game_state.apply_i_thought_you_were_dead(Piece.Owner.BLUE, 999, [Vector2i(5, 3)]) == false)

	var result := game_state.apply_i_thought_you_were_dead(Piece.Owner.BLUE, 1, [Vector2i(5, 3)])
	assert(result == true)
	assert(game_state.pieces.has(captured_a.uid))
	assert(captured_a.cells[0] == Vector2i(5, 3))
	assert(not game_state.captured_pieces[Piece.Owner.BLUE].has(captured_a))

	var a_left := Piece.new()
	a_left.uid = 10
	a_left.type = Piece.Type.A
	a_left.owner = Piece.Owner.BLUE
	a_left.cells = [Vector2i(0, 0)]
	var a_right := Piece.new()
	a_right.uid = 11
	a_right.type = Piece.Type.A
	a_right.owner = Piece.Owner.BLUE
	a_right.cells = [Vector2i(0, 0)]
	game_state.captured_pieces[Piece.Owner.BLUE].append(a_left)
	game_state.captured_pieces[Piece.Owner.BLUE].append(a_right)
	assert(game_state.apply_i_thought_you_were_dead(Piece.Owner.BLUE, 11, [Vector2i(6, 3)]) == true)
	assert(game_state.pieces.has(11))
	assert(not game_state.pieces.has(10))
	assert(game_state.captured_pieces[Piece.Owner.BLUE].has(a_left))
	assert(not game_state.captured_pieces[Piece.Owner.BLUE].has(a_right))

	var captured_b := Piece.new()
	captured_b.uid = 20
	captured_b.type = Piece.Type.B
	captured_b.owner = Piece.Owner.BLUE
	captured_b.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	game_state.captured_pieces[Piece.Owner.BLUE].append(captured_b)
	var b_ok := game_state.apply_i_thought_you_were_dead(Piece.Owner.BLUE, 20, [Vector2i(7, 2), Vector2i(7, 3)], Piece.PieceOrientation.VERTICAL)
	assert(b_ok == true)
	assert(game_state.pieces.has(20))
	assert(captured_b.orientation == Piece.PieceOrientation.VERTICAL)
	assert(captured_b.cells.has(Vector2i(7, 2)) and captured_b.cells.has(Vector2i(7, 3)))

	var captured_a2 := Piece.new()
	captured_a2.uid = 2
	captured_a2.type = Piece.Type.A
	captured_a2.owner = Piece.Owner.BLUE
	captured_a2.cells = [Vector2i(0, 0)]
	game_state.captured_pieces[Piece.Owner.BLUE].append(captured_a2)
	assert(game_state.apply_i_thought_you_were_dead(Piece.Owner.BLUE, 2, [Vector2i(5, 9)]) == false)

	game_state.free()

func test_capture_piece():
	var game_state := GameState.new()

	var piece := Piece.new()
	piece.uid = 1
	piece.type = Piece.Type.A
	piece.owner = Piece.Owner.BLUE
	piece.cells = [Vector2i(5, 5)]
	piece.status_effects["saboteur"] = true
	game_state.pieces[piece.uid] = piece

	game_state.capture_piece(piece.uid)

	assert(not game_state.pieces.has(piece.uid))
	assert(game_state.captured_pieces[Piece.Owner.BLUE].has(piece))
	assert(not piece.has_status("saboteur"))

	game_state.free()

func test_croce_valid_placement():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.uid = 1
	piece.type = Piece.Type.A
	piece.owner = Piece.Owner.BLUE
	piece.cells = [Vector2i(0, 0)]

	# Valid — own half, on board, no overlap
	assert(CroceSetup.place_piece(piece, [Vector2i(5, 3)], game_state) == true)
	assert(game_state.pieces.has(piece.uid))
	assert(piece.cells[0] == Vector2i(5, 3))

	# Overlap — same cell already occupied
	var piece2 := Piece.new()
	piece2.uid = 2
	piece2.type = Piece.Type.A
	piece2.owner = Piece.Owner.BLUE
	piece2.cells = [Vector2i(0, 0)]
	assert(CroceSetup.place_piece(piece2, [Vector2i(5, 3)], game_state) == false)

	game_state.free()

func test_croce_invalid_placement():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.uid = 1
	piece.type = Piece.Type.A
	piece.owner = Piece.Owner.BLUE
	piece.cells = [Vector2i(0, 0)]

	# Opponent's half — row 9 is RED's territory
	assert(CroceSetup.place_piece(piece, [Vector2i(5, 9)], game_state) == false)
	assert(not game_state.pieces.has(piece.uid))

	# Off board entirely
	assert(CroceSetup.place_piece(piece, [Vector2i(-1, 0)], game_state) == false)

	game_state.free()

func test_croce_setup_complete():
	var game_state := GameState.new()
	game_state.board = Board.new()

	# Incomplete — no pieces yet
	assert(CroceSetup.is_setup_complete(Piece.Owner.BLUE, game_state) == false)

	# Place correct counts for BLUE
	var uid := 1
	for i in range(12):
		var p := Piece.new(); p.uid = uid; uid += 1
		p.type = Piece.Type.A; p.owner = Piece.Owner.BLUE
		p.cells = [Vector2i(i, 0)]
		game_state.pieces[p.uid] = p
	for i in range(6):
		var p := Piece.new(); p.uid = uid; uid += 1
		p.type = Piece.Type.B; p.owner = Piece.Owner.BLUE
		p.cells = [Vector2i(i, 1), Vector2i(i + 1, 1)]
		game_state.pieces[p.uid] = p
	for i in range(3):
		var p := Piece.new(); p.uid = uid; uid += 1
		p.type = Piece.Type.C; p.owner = Piece.Owner.BLUE
		p.cells = [Vector2i(i*2, 2), Vector2i(i*2+1, 2), Vector2i(i*2, 3), Vector2i(i*2+1, 3)]
		game_state.pieces[p.uid] = p
	var gen := Piece.new(); gen.uid = uid; uid += 1
	gen.type = Piece.Type.GENERAL; gen.owner = Piece.Owner.BLUE
	gen.cells = [Vector2i(0, 4)]
	game_state.pieces[gen.uid] = gen
	var obj := Piece.new(); obj.uid = uid; uid += 1
	obj.type = Piece.Type.OBJECTIVE; obj.owner = Piece.Owner.BLUE
	obj.cells = [Vector2i(1, 4)]
	game_state.pieces[obj.uid] = obj

	assert(CroceSetup.is_setup_complete(Piece.Owner.BLUE, game_state) == true)
	# RED still incomplete
	assert(CroceSetup.is_setup_complete(Piece.Owner.RED, game_state) == false)

	game_state.free()

func test_general_captures_piece():
	var general := Piece.new(); general.type = Piece.Type.GENERAL
	var a := Piece.new(); a.type = Piece.Type.A
	var b := Piece.new(); b.type = Piece.Type.B
	var c := Piece.new(); c.type = Piece.Type.C
	assert(RulesEngine.resolve_capture(general, a) == RulesEngine.CaptureResult.CAPTURED)
	assert(RulesEngine.resolve_capture(general, b) == RulesEngine.CaptureResult.CAPTURED)
	assert(RulesEngine.resolve_capture(general, c) == RulesEngine.CaptureResult.CAPTURED)

func test_general_cannot_capture_saboteur():
	var general := Piece.new(); general.type = Piece.Type.GENERAL
	var sab := Piece.new(); sab.type = Piece.Type.A
	sab.status_effects["saboteur"] = true
	assert(RulesEngine.resolve_capture(general, sab) == RulesEngine.CaptureResult.ILLEGAL)

func test_b_slide_moves():
	var game_state := GameState.new()
	game_state.board = Board.new()

	var piece := Piece.new()
	piece.type = Piece.Type.B
	piece.orientation = Piece.PieceOrientation.HORIZONTAL
	piece.cells = [Vector2i(5, 5), Vector2i(6, 5)]

	var moves := RulesEngine.legal_moves_for(piece, game_state)

	# Slides
	assert(moves.has(Vector2i(4, 5)))  # slide left
	assert(moves.has(Vector2i(7, 5)))  # slide right
	# Pivots still present
	assert(moves.has(Vector2i(5, 4)))
	assert(moves.has(Vector2i(5, 6)))
	assert(moves.has(Vector2i(6, 4)))
	assert(moves.has(Vector2i(6, 6)))
	assert(moves.size() == 6)

	game_state.free()
	
func test_captured_saboteur_reverts_to_original_owner():
	var game_state := GameState.new()

	var piece := Piece.new()
	piece.uid = 1
	piece.type = Piece.Type.A
	piece.owner = Piece.Owner.BLUE
	piece.cells = [Vector2i(5, 5)]
	game_state.pieces[piece.uid] = piece
	piece.apply_saboteur_conversion(Piece.Owner.RED)
	assert(piece.owner == Piece.Owner.RED)

	game_state.capture_piece(piece.uid)

	assert(piece.owner == Piece.Owner.BLUE)
	assert(not piece.has_status("saboteur"))
	assert(game_state.captured_pieces[Piece.Owner.BLUE].has(piece))
	assert(not game_state.captured_pieces[Piece.Owner.RED].has(piece))

	game_state.free()	

func test_legal_destinations_filter():
	var game_state := GameState.new()
	game_state.board = Board.new()

	# Blue A at (5,5). Geometry gives four orthogonal destinations.
	var a := Piece.new()
	a.uid = 1; a.type = Piece.Type.A; a.owner = Piece.Owner.BLUE
	a.cells = [Vector2i(5, 5)]
	game_state.pieces[a.uid] = a
	assert(RulesEngine.legal_destinations_for(a, game_state).size() == 4)

	# Friendly A north — blocked, not capturable.
	var friend := Piece.new()
	friend.uid = 2; friend.type = Piece.Type.A; friend.owner = Piece.Owner.BLUE
	friend.cells = [Vector2i(5, 4)]
	game_state.pieces[friend.uid] = friend
	var dests := RulesEngine.legal_destinations_for(a, game_state)
	assert(not dests.has(Vector2i(5, 4)))
	assert(dests.size() == 3)

	# He Seemed Suspicious opens own-piece capture — A vs A is a legal mutual.
	game_state.can_capture_own_piece = true
	assert(RulesEngine.legal_destinations_for(a, game_state).has(Vector2i(5, 4)))
	game_state.can_capture_own_piece = false

	# Enemy B east — A loses to B, so that capture is ILLEGAL and filtered out.
	var enemy_b := Piece.new()
	enemy_b.uid = 3; enemy_b.type = Piece.Type.B; enemy_b.owner = Piece.Owner.RED
	enemy_b.orientation = Piece.PieceOrientation.HORIZONTAL
	enemy_b.cells = [Vector2i(6, 5), Vector2i(7, 5)]
	game_state.pieces[enemy_b.uid] = enemy_b
	assert(not RulesEngine.legal_destinations_for(a, game_state).has(Vector2i(6, 5)))

	# Enemy C west — A beats C, so that capture IS legal and survives the filter.
	var enemy_c := Piece.new()
	enemy_c.uid = 4; enemy_c.type = Piece.Type.C; enemy_c.owner = Piece.Owner.RED
	enemy_c.cells = [Vector2i(3, 5), Vector2i(4, 5), Vector2i(3, 6), Vector2i(4, 6)]
	game_state.pieces[enemy_c.uid] = enemy_c
	assert(RulesEngine.legal_destinations_for(a, game_state).has(Vector2i(4, 5)))

	# A frozen General has no geometry, so no destinations either.
	var gen := Piece.new()
	gen.uid = 5; gen.type = Piece.Type.GENERAL; gen.owner = Piece.Owner.BLUE
	gen.cells = [Vector2i(9, 3)]
	game_state.pieces[gen.uid] = gen
	assert(RulesEngine.legal_destinations_for(gen, game_state).size() > 0)
	game_state.general_frozen_remaining[Piece.Owner.BLUE] = 3
	assert(RulesEngine.legal_destinations_for(gen, game_state).size() == 0)

	game_state.free()
