extends Node
class_name GameState

const HAND_LIMIT := 9

var board: Board
var pieces: Dictionary = {}   # uid -> Piece
var game_history: Array[Dictionary] = []

var current_player: Piece.Owner = Piece.Owner.BLUE
var turn_number: int = 1

var rules: GameRules = GameRules.new()

var can_capture_own_piece: bool = false
var objective_has_moved: Dictionary = {}  # { Piece.Owner: true } — per-player, each Objective moves once
var get_move_on_type: int = -1          # Piece.Type with GaMO active this turn, or -1
var get_move_on_claimant_uid: int = -1  # first matching piece to move claims the bonus
var get_move_on_bonus_used: bool = false  # true once the claimant has taken its extra move
var close_call_active: Dictionary = {}  # { Piece.Type: true }
var general_can_capture_saboteur: bool = false

var moves_remaining: int = 1        # general move budget this turn (base 1, +1 per Blitzkrieg pre-move)
var has_moved_this_turn: bool = false
var blitzkrieg_active: bool = false
var pieces_moved_this_turn: Array = []
var bonus_draw_on_next_capture: Dictionary = {}
var general_frozen_remaining: Dictionary = {}
var captured_pieces: Dictionary = {
	Piece.Owner.BLUE: [],
	Piece.Owner.RED: [],
}

var one_man_army_type: Piece.Type = Piece.Type.A  # only valid when one_man_army_active is true
var one_man_army_active: bool = false

var deck: Array[Card] = []
var discard_pile: Array[Card] = []
var hands: Dictionary = {
	Piece.Owner.BLUE: [],
	Piece.Owner.RED: [],
}

func initialize_deck() -> void:
	deck = CardDatabase.build_full_deck()
	deck.shuffle()

func draw_card(player: Piece.Owner) -> Card:
	if deck.is_empty():
		if discard_pile.is_empty():
			return null
		deck = discard_pile.duplicate()
		discard_pile.clear()
		deck.shuffle()
	var card: Card = deck.pop_front()
	hands[player].append(card)
	print(">>> DREW ", player, " hand=", hands[player].size(), " deck=", deck.size())
	return card

func discard_card(player: Piece.Owner, card: Card) -> bool:
	if not hands[player].has(card):
		return false
	hands[player].erase(card)
	discard_pile.append(card)
	return true

func resolve_capture_draws(result: RulesEngine.CaptureResult, attacker_owner: Piece.Owner, defender_owner: Piece.Owner) -> void:
	print(">>> CAP DRAWS result=", result, " atk=", attacker_owner, " def=", defender_owner)
	match result:
		RulesEngine.CaptureResult.CAPTURED:
			var bonus: int = bonus_draw_on_next_capture.get(attacker_owner, 0)
			if bonus > 0:
				for i in range(bonus):
					draw_card(attacker_owner)
				bonus_draw_on_next_capture.erase(attacker_owner)
			else:
				draw_card(attacker_owner)
		RulesEngine.CaptureResult.MUTUAL_DESTROY:
			if not rules.mutual_destruction_both_draw:
				pass
			else:
				var attacker_bonus: int = bonus_draw_on_next_capture.get(attacker_owner, 0)
				if attacker_bonus > 0:
					for i in range(attacker_bonus):
						draw_card(attacker_owner)
					bonus_draw_on_next_capture.erase(attacker_owner)
				else:
					draw_card(attacker_owner)
				var defender_bonus: int = bonus_draw_on_next_capture.get(defender_owner, 0)
				if defender_bonus > 0:
					for i in range(defender_bonus):
						draw_card(defender_owner)
					bonus_draw_on_next_capture.erase(defender_owner)
				else:
					draw_card(defender_owner)
		RulesEngine.CaptureResult.ILLEGAL:
			pass

func is_hand_over_limit(player: Piece.Owner) -> bool:
	return hands[player].size() > HAND_LIMIT

func discard_to_deck(player: Piece.Owner, card: Card) -> bool:
	if not hands[player].has(card):
		return false
	hands[player].erase(card)
	deck.append(card)
	return true
	
func declare_saboteur(declaring_player: Piece.Owner, type_card: Card, chart_card: Card, chosen_type: Piece.Type) -> bool:
	if not hands[declaring_player].has(type_card):
		return false
	if not hands[declaring_player].has(chart_card):
		return false
	var designation := RulesEngine.designation_from_cards(type_card, chart_card, chosen_type)
	if designation == "":
		return false
	var opponent := Piece.Owner.RED if declaring_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	var target := _find_piece_by_designation(designation, opponent)
	if target == null:
		return false
	if not RulesEngine.can_declare_saboteur(declaring_player, self):
		return false
	target.apply_saboteur_conversion(declaring_player)
	discard_card(declaring_player, type_card)
	discard_card(declaring_player, chart_card)
	return true

func apply_double_agent(playing_player: Piece.Owner) -> bool:
	var opponent := Piece.Owner.RED if playing_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	for piece in pieces.values():
		if piece.owner == opponent and piece.has_status("saboteur"):
			piece.reverse_saboteur_conversion(playing_player)
			return true
	return false
	
func apply_he_seemed_suspicious() -> void:
	can_capture_own_piece = true
	
func apply_just_this_once(playing_player: Piece.Owner, destination: Vector2i) -> bool:
	if objective_has_moved.get(playing_player, false):
		return false
	var objective: Piece = null
	for piece in pieces.values():
		if piece.type == Piece.Type.OBJECTIVE and piece.owner == playing_player:
			objective = piece
			break
	if objective == null:
		return false
	if not _is_legal_objective_move(objective.cells[0], destination, playing_player):
		return false
	objective.cells[0] = destination
	objective_has_moved[playing_player] = true
	return true

func _is_legal_objective_move(from: Vector2i, to: Vector2i, player: Piece.Owner) -> bool:
	# Orthogonal only, 1-3 spaces, clear path, destination in own half, all cells empty.
	if not RulesEngine.is_on_board(to, board):
		return false
	if not RulesEngine.is_in_own_half(to, player, board):
		return false
	var dx := to.x - from.x
	var dy := to.y - from.y
	# Must be a straight orthogonal line
	if dx != 0 and dy != 0:
		return false
	var dist: int = abs(dx) + abs(dy)
	if dist < 1 or dist > 3:
		return false
	# Walk the path, every step must be empty (including destination)
	var step := Vector2i(sign(dx), sign(dy))
	var cell := from + step
	for i in range(dist):
		if _cell_occupied(cell):
			return false
		cell += step
	return true

func _cell_occupied(cell: Vector2i) -> bool:
	for piece in pieces.values():
		if piece.cells.has(cell):
			return true
	return false
		
func apply_get_move_on(piece_type: Piece.Type) -> void:
	get_move_on_type = piece_type
	get_move_on_claimant_uid = -1
	get_move_on_bonus_used = false

# Returns true if this piece is entitled to a free GaMO move right now.
# Either it already claimed the bonus, or it's the first matching-type piece to move.
func piece_has_gamo_move(piece: Piece) -> bool:
	if get_move_on_type == -1:
		return false
	if piece.type != get_move_on_type:
		return false
	# GaMO grants one extra move, to the first matching-type piece that takes it.
	if get_move_on_bonus_used:
		return false
	if get_move_on_claimant_uid == -1:
		return true                              # unclaimed — this piece can take it
	return get_move_on_claimant_uid == piece.uid

func spend_gamo_move(piece: Piece) -> void:
	# Claim and consume together: the bonus is a single extra move.
	get_move_on_claimant_uid = piece.uid
	get_move_on_bonus_used = true
		
func apply_close_call(piece_type: Piece.Type) -> void:
	close_call_active[piece_type] = true

func resolve_capture_with_effects(attacker: Piece, defender: Piece, consume: bool = true) -> RulesEngine.CaptureResult:
	var result := RulesEngine.resolve_capture(attacker, defender)
	if result == RulesEngine.CaptureResult.MUTUAL_DESTROY and close_call_active.get(attacker.type, false):
		if consume:
			close_call_active.erase(attacker.type)
		return RulesEngine.CaptureResult.CAPTURED
	if result == RulesEngine.CaptureResult.ILLEGAL \
		and attacker.type == Piece.Type.GENERAL \
		and defender.has_status("saboteur") \
		and defender.original_owner == attacker.owner \
		and general_can_capture_saboteur:
		return RulesEngine.CaptureResult.CAPTURED
	if result == RulesEngine.CaptureResult.ILLEGAL \
		and defender.type == Piece.Type.GENERAL \
		and one_man_army_active \
		and attacker.type == one_man_army_type:
		return RulesEngine.CaptureResult.CAPTURED
	if result == RulesEngine.CaptureResult.CAPTURED \
		and defender.type == Piece.Type.OBJECTIVE \
		and not rules.objective_saboteurs_only \
		and not attacker.has_status("saboteur"):
		return RulesEngine.CaptureResult.ILLEGAL
	return result

func apply_im_on_to_you() -> void:
	general_can_capture_saboteur = true
	print(">>> I'm On To You applied, flag now: ", general_can_capture_saboteur)
	
func apply_one_man_army(playing_player: Piece.Owner, type_card: Card, chosen_type: Piece.Type) -> bool:
	if not hands[playing_player].has(type_card):
		return false
	if not type_card.piece_types.has(chosen_type):
		return false
	discard_card(playing_player, type_card)
	one_man_army_type = chosen_type
	one_man_army_active = true
	return true	
	
func capture_piece(uid: int) -> void:
	if pieces.has(uid):
		var piece: Piece = pieces[uid]
		# A captured/annihilated saboteur reverts to its original side.
		if piece._original_owner_set:
			piece.owner = piece.original_owner
		piece.status_effects.clear()
		captured_pieces[piece.owner].append(piece)
		pieces.erase(uid)

func can_move_now() -> bool:
	return moves_remaining > 0

func piece_can_move(piece: Piece) -> bool:
	if not can_move_another_piece(piece.uid):
		return false
	return moves_remaining > 0 or piece_has_gamo_move(piece)

func spend_move() -> void:
	moves_remaining -= 1
	has_moved_this_turn = true

func can_play_move_card() -> bool:
	# Move-granting cards (BK, GaMO) may only be played before any move this turn
	return not has_moved_this_turn
	
func record_piece_moved(uid: int) -> void:
	if not pieces_moved_this_turn.has(uid):
		pieces_moved_this_turn.append(uid)

func can_move_another_piece(uid: int) -> bool:
	if rules.blitzkrieg_old_different_piece:
		return true  # standard: no restriction on which piece takes a bonus move
	if pieces_moved_this_turn.is_empty():
		return true
	if blitzkrieg_active and pieces_moved_this_turn.size() == 1 and not pieces_moved_this_turn.has(uid):
		return true
	return false

func apply_blitzkrieg() -> void:
	blitzkrieg_active = true      # kept for the old-BK House Rule
	moves_remaining += 1          # default BK: +1 general move

func apply_just_in_case(player: Piece.Owner) -> void:
	bonus_draw_on_next_capture[player] = 2

func apply_ineffective_leadership(playing_player: Piece.Owner) -> void:
	var opponent := Piece.Owner.RED if playing_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	general_frozen_remaining[opponent] = 3

func is_general_frozen(owner: Piece.Owner) -> bool:
	return general_frozen_remaining.get(owner, 0) > 0

func apply_i_thought_you_were_dead(playing_player: Piece.Owner, piece_uid: int, new_cells: Array[Vector2i], orientation: Piece.PieceOrientation = Piece.PieceOrientation.VERTICAL) -> bool:
	var target: Piece = null
	for piece in captured_pieces[playing_player]:
		if piece.uid == piece_uid:
			target = piece
			break
	if target == null:
		return false
	for cell in new_cells:
		if not RulesEngine.is_on_board(cell, board):
			return false
		if not RulesEngine.is_in_own_half(cell, playing_player, board):
			return false
	for cell in new_cells:
		for piece in pieces.values():
			if piece.cells.has(cell):
				return false
	target.cells = new_cells
	target.orientation = orientation
	captured_pieces[playing_player].erase(target)
	pieces[target.uid] = target
	return true
		
func _find_piece_by_designation(designation: String, owner: Piece.Owner) -> Piece:
	for piece in pieces.values():
		if piece.designation != designation:
			continue
		# Skip pieces that are already saboteurs — can't re-declare on them
		if piece.has_status("saboteur"):
			continue
		# Match on the piece's true side: original_owner if it was ever converted,
		# otherwise current owner (which equals original side for un-converted pieces)
		var true_side: Piece.Owner = piece.original_owner if piece._original_owner_set else piece.owner
		if true_side == owner:
			return piece
	return null
	
func end_turn() -> void:
	if general_frozen_remaining.has(current_player):
		general_frozen_remaining[current_player] -= 1
		if general_frozen_remaining[current_player] <= 0:
			general_frozen_remaining.erase(current_player)
	current_player = Piece.Owner.RED if current_player == Piece.Owner.BLUE else Piece.Owner.BLUE
	turn_number += 1
	can_capture_own_piece = false
	get_move_on_type = -1
	get_move_on_claimant_uid = -1
	get_move_on_bonus_used = false
	close_call_active.clear()
	general_can_capture_saboteur = false
	one_man_army_active = false
	blitzkrieg_active = false
	pieces_moved_this_turn.clear()
	moves_remaining = 1
	has_moved_this_turn = false

# ============================================================
# CARD DEPLOYMENT — classifier + dispatcher (Piece 1: no-target cards)
# ============================================================

enum DeployKind {
	NONE,                # selection isn't a valid deployment
	SABOTEUR,            # Type + Chart  [TARGETED — Piece 2]
	ONE_MAN_ARMY,        # One Man Army (Major) + Type  [TARGETED — Piece 2]
	JUST_THIS_ONCE,      # Just This Once (Major)  [TARGETED — Piece 2]
	I_THOUGHT_YOU_WERE_DEAD, # ITYD (Minor)  [DEFERRED — needs tray]
	SIMPLE,              # any single no-target power card  [Piece 1 — buildable now]
}

# Inspect a selection and report what it would deploy as.
# Returns { "kind": DeployKind, "cards": Array[Card], "reason": String }
func classify_deployment(selected: Array) -> Dictionary:
	if selected.is_empty():
		return { "kind": DeployKind.NONE, "cards": [], "reason": "No cards selected." }

	var charts := []
	var types := []
	var minors := []
	var majors := []
	for c in selected:
		match c.category:
			Card.Category.CHART: charts.append(c)
			Card.Category.TYPE: types.append(c)
			Card.Category.MINOR_POWER: minors.append(c)
			Card.Category.MAJOR_POWER: majors.append(c)

	# Type + Chart pair → Saboteur declaration
	if types.size() == 1 and charts.size() == 1 and minors.is_empty() and majors.is_empty():
		return { "kind": DeployKind.SABOTEUR, "cards": selected, "reason": "" }

	# One Man Army (Major) + Type → OMA
	if majors.size() == 1 and majors[0].major_effect == Card.MajorEffect.ONE_MAN_ARMY \
			and types.size() == 1 and charts.is_empty() and minors.is_empty():
		return { "kind": DeployKind.ONE_MAN_ARMY, "cards": selected, "reason": "" }

	# Single card from here on for the remaining kinds
	if selected.size() == 1:
		var c = selected[0]
		if c.category == Card.Category.MAJOR_POWER:
			match c.major_effect:
				Card.MajorEffect.JUST_THIS_ONCE:
					return { "kind": DeployKind.JUST_THIS_ONCE, "cards": selected, "reason": "" }
				Card.MajorEffect.DOUBLE_AGENT, Card.MajorEffect.HE_SEEMED_SUSPICIOUS, \
				Card.MajorEffect.IM_ON_TO_YOU, Card.MajorEffect.BLITZKRIEG, \
				Card.MajorEffect.INEFFECTIVE_LEADERSHIP:
					return { "kind": DeployKind.SIMPLE, "cards": selected, "reason": "" }
				Card.MajorEffect.ONE_MAN_ARMY:
					return { "kind": DeployKind.NONE, "cards": [], "reason": "One Man Army must be paired with a Type card." }
		elif c.category == Card.Category.MINOR_POWER:
			match c.minor_effect:
				Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
					return { "kind": DeployKind.I_THOUGHT_YOU_WERE_DEAD, "cards": selected, "reason": "" }
				Card.MinorEffect.GET_MOVE_ON, Card.MinorEffect.CLOSE_CALL, Card.MinorEffect.JUST_IN_CASE:
					return { "kind": DeployKind.SIMPLE, "cards": selected, "reason": "" }
		elif c.category == Card.Category.TYPE:
			return { "kind": DeployKind.NONE, "cards": [], "reason": "A Type card needs a Chart card (Saboteur) or One Man Army." }
		elif c.category == Card.Category.CHART:
			return { "kind": DeployKind.NONE, "cards": [], "reason": "A Chart card needs a Type card to declare a Saboteur." }

	return { "kind": DeployKind.NONE, "cards": [], "reason": "That combination can't be deployed." }

# Discard every card in the selection that's still in the player's hand.
# Harmless for cards an effect function already self-discarded (has() guard in discard_card).
func _discard_deployed(player: Piece.Owner, cards: Array) -> void:
	for c in cards:
		discard_card(player, c)  # returns false + no-ops if already gone

# Deploy a no-target card (DeployKind.SIMPLE). Returns { ok: bool, message: String }.
func deploy_simple(player: Piece.Owner, selected: Array) -> Dictionary:
	var info := classify_deployment(selected)
	if info["kind"] != DeployKind.SIMPLE:
		return { "ok": false, "message": "Not a simple deployable card." }

	var c = selected[0]
	var applied := false
	var msg := ""

	if c.category == Card.Category.MAJOR_POWER:
		match c.major_effect:
			Card.MajorEffect.DOUBLE_AGENT:
				applied = apply_double_agent(player)
				if not applied:
					msg = "No converted piece to reclaim."
			Card.MajorEffect.HE_SEEMED_SUSPICIOUS:
				apply_he_seemed_suspicious(); applied = true
			Card.MajorEffect.IM_ON_TO_YOU:
				apply_im_on_to_you(); applied = true
			Card.MajorEffect.BLITZKRIEG:
					if has_moved_this_turn:
						return { "ok": false, "message": "Can't play move-granting cards after moving." }
					apply_blitzkrieg(); applied = true
			Card.MajorEffect.INEFFECTIVE_LEADERSHIP:
				apply_ineffective_leadership(player); applied = true
	elif c.category == Card.Category.MINOR_POWER:
		match c.minor_effect:
			Card.MinorEffect.GET_MOVE_ON:
					if has_moved_this_turn:
						return { "ok": false, "message": "Can't play move-granting cards after moving." }
					apply_get_move_on(c.effect_piece_type); applied = true
			Card.MinorEffect.CLOSE_CALL:
				apply_close_call(c.effect_piece_type); applied = true
			Card.MinorEffect.JUST_IN_CASE:
				apply_just_in_case(player); applied = true

	if applied:
		_discard_deployed(player, selected)
		return { "ok": true, "message": msg }
	# Effect failed (e.g. Double Agent with no target) — do NOT discard, player keeps the card
	return { "ok": false, "message": msg if msg != "" else "Card could not be played right now." }
