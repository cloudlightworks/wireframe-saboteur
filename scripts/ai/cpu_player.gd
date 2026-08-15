extends RefCounted
class_name CpuPlayer

# ============================================================
# CPU opponent
# ------------------------------------------------------------
# Tier 0 — uniform random legal move.
# Tier 1 — one-ply scored move: captures and card farming, threat avoidance,
#          Objective defence, General as a home guard, slow advance.
#
# HIDDEN INFORMATION RULE: this class may read the board, its own pieces,
# and its own hand. It must NEVER read the opposing player's hand or
# unrevealed Croce data. It currently reads no hand at all.
# The mechanical audit is: grep -c "hands\[" -> 0
#
# Pure decision-making. Touches no scene tree, mutates no state, knows
# nothing about PieceView. board_controller owns execution.
#
# CAPTURE FACTS this scoring depends on, read from rules_engine.gd:
#   - A beats C, C beats B, B beats A. Same type mutually destroys.
#   - ANY piece may capture an Objective except a General (illegal).
#   - Only a Saboteur may capture a General.
#   - A General captures anything that isn't a General, Objective, or Saboteur.
#   - Captures draw cards; mutual destroys draw for both when the house rule is on.
# ============================================================

# --- Material -------------------------------------------------
# Captures are rock-paper-scissors, so no type dominates. These track
# SCARCITY and USEFULNESS. A pieces are a glut (12 a side) and are cheap
# to spend — trading one for a card is a fine deal.
const VALUE := {
	Piece.Type.A: 6.0,
	Piece.Type.B: 12.0,
	Piece.Type.C: 18.0,
	Piece.Type.GENERAL: 200.0,
	Piece.Type.OBJECTIVE: 500.0,
}

const SABOTEUR_VALUE := 90.0         # the only thing that can take a General
const WIN_SCORE := 100000.0          # any piece can take an Objective — this ends it
const CARD_VALUE := 8.0              # a capture draws; that's the farm
const FREE_CAPTURE := 14.0           # flat: a sitting duck is always worth eating
const ENEMY_CARD_COST := 4.0         # mutual destroy feeds them a card too

# --- Safety ---------------------------------------------------
const THREAT_WEIGHT := 0.7           # how much we fear being taken back
const MUTUAL_THREAT := 0.55          # a same-type trade costs us the piece too
const ESCAPE_WEIGHT := 1.0           # urgency of pulling a piece out of danger
const ESCAPE_BASE := 10.0            # flat bonus so even cheap pieces bother running
const OBJECTIVE_GUARD := 400.0       # killing a piece that can reach our Objective
const DEFEND_WEIGHT := 0.8           # killing a piece that threatens our other pieces

# --- The General ----------------------------------------------
# It cannot capture an Objective and cannot be captured except by a Saboteur.
# So it does not attack — it guards.
const GENERAL_HOME_RADIUS := 4       # rough patrol range around our Objective
const GENERAL_STRAY_COST := 9.0     # per cell beyond that radius
const GENERAL_INTERCEPT := 22.0      # per cell closer to a piece aimed at our Objective
const GENERAL_COVER := 14.0           # per cell closer to a threatened friendly piece

# --- Tempo ----------------------------------------------------
const ADVANCE_WEIGHT := 1.2          # horizontal drift toward the Objective column
const SABOTEUR_ADVANCE := 12.0       # Saboteurs push hard
const FORWARD_WEIGHT := 7.0          # forward progress dominates; this stops milling
const LATERAL_PENALTY := 5.0         # a non-advancing shuffle is actively discouraged
const NOISE := 2.0                   # tiebreak jitter

# --- Cards ----------------------------------------------------
const SABOTEUR_BAR := 60.0           # minimum score before declaring
const SAB_DEFENSIVE := 220.0         # target can reach our Objective
const SAB_NEAR_GENERAL := 90.0       # target sits near our General
const SAB_NEAR_RANGE := 5            # what "near" means, in cells
const SAB_RUN_WEIGHT := 6.0          # closeness to THEIR Objective
const CARD_PLAY_BAR := 10.0          # minimum score before spending a card
const ITYD_BASE := 22.0              # bringing a piece back onto the board is good
const ITYD_ACTION_WEIGHT := 1.5      # prefer placing near recent action
const OMA_BASE := 40.0               # opens a second route to their General
const GENERAL_SAFE_APPROACH := 55.0  # orthogonally adjacent — the General can't hit us
const GENERAL_DIAGONAL_RISK := 30.0  # diagonally adjacent — it can, and we lose the piece
const OMA_RANGE := 6                 # how close a piece must be to bother
const JTO_THREAT_BAR := 1.0          # only move the Objective if it's in real danger

var side: Piece.Owner = Piece.Owner.RED
var tier: int = 1
var verbose: bool = true   # decision logging; set false before release

func _init(cpu_side: Piece.Owner = Piece.Owner.RED, cpu_tier: int = 1) -> void:
	side = cpu_side
	tier = cpu_tier

# ------------------------------------------------------------
# Entry point
# ------------------------------------------------------------

# Returns {"piece_uid": int, "dest": Vector2i}, or {} when no legal move exists.
func choose_move(game_state: GameState) -> Dictionary:
	var options := _all_legal_moves(game_state)
	if options.is_empty():
		return {}
	if tier <= 0:
		return options[randi() % options.size()]

	var scored: Array = []
	for opt in options:
		var piece: Piece = game_state.pieces[opt["piece_uid"]]
		scored.append({
			"opt": opt,
			"score": _score_move(game_state, piece, opt["dest"]),
			"who": piece.designation,
		})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	if verbose:
		var top := []
		for i in range(min(4, scored.size())):
			top.append("%s->%s %.1f" % [scored[i]["who"], scored[i]["opt"]["dest"], scored[i]["score"]])
		print("CPU move (%d options): %s" % [scored.size(), ", ".join(top)])

	return scored[0]["opt"]

func _all_legal_moves(game_state: GameState) -> Array:
	var options: Array = []
	for piece in game_state.pieces.values():
		if piece.owner != side:
			continue
		if piece.type == Piece.Type.OBJECTIVE:
			continue   # the Objective only moves via Just This Once, never on its own
		if not game_state.piece_can_move(piece):
			continue
		for dest in RulesEngine.legal_destinations_for(piece, game_state):
			options.append({"piece_uid": piece.uid, "dest": dest})
	return options

# ------------------------------------------------------------
# Scoring
# ------------------------------------------------------------

func _score_move(gs: GameState, piece: Piece, dest: Vector2i) -> float:
	var new_cells := _cells_after_move(piece, dest)
	var score := 0.0
	var mover_dies := false
	var doomed: Dictionary = {}   # uids this move removes — they can't threaten us

	# --- what this move captures ---
	for other in gs.pieces.values():
		if other.uid == piece.uid:
			continue
		if not _overlaps(new_cells, other.cells):
			continue
		var result := gs.resolve_capture_with_effects(piece, other, false)
		var worth := _value(other)
		if other.owner == side:
			worth = -worth   # He Seemed Suspicious lets us hit our own — that's a loss
		var guards: bool = other.owner != side and _threatens_our_objective(gs, other)
		# Removing an attacker is worth what it was about to take.
		var defends := 0.0
		if other.owner != side:
			defends = _defends_value(gs, other, piece)
		match result:
			RulesEngine.CaptureResult.CAPTURED:
				doomed[other.uid] = true
				score += worth + CARD_VALUE + FREE_CAPTURE
				if other.type == Piece.Type.OBJECTIVE and other.owner != side:
					score += WIN_SCORE
				if guards:
					score += OBJECTIVE_GUARD
				score += defends
			RulesEngine.CaptureResult.MUTUAL_DESTROY:
				score += worth
				mover_dies = true
				if gs.rules.mutual_destruction_both_draw:
					score += CARD_VALUE - ENEMY_CARD_COST
				else:
					score += CARD_VALUE
				if guards:
					score += OBJECTIVE_GUARD
				score += defends

	# --- danger, before and after ---
	if not mover_dies:
		var t_before := _threat_of(gs, piece, piece.cells)
		var t_after := _threat_of(gs, piece, new_cells, doomed)
		if t_after > 0.0:
			# Losing the piece also hands them a card.
			score -= (_value(piece) + ENEMY_CARD_COST) * t_after * THREAT_WEIGHT
		if t_before > t_after:
			# It was in danger and this move reduces it — worth doing for its
			# own sake, not just for landing on a quiet square.
			score += (ESCAPE_BASE + _value(piece)) * (t_before - t_after) * ESCAPE_WEIGHT
	if piece.type == Piece.Type.GENERAL:
		score += _score_general(gs, piece, new_cells)
	else:
		score += _score_advance(gs, piece, new_cells)
		score += _general_approach_bonus(gs, piece, new_cells)

	return score + randf() * NOISE

# The General guards. It never marches, because it cannot capture an Objective.
func _score_general(gs: GameState, general: Piece, new_cells: Array[Vector2i]) -> float:
	var score := 0.0
	var here: Vector2i = new_cells[0]
	var was: Vector2i = general.cells[0]

	# Stay in the neighbourhood of what we're protecting.
	var obj := _objective_of(gs, side)
	if obj != null and not obj.cells.is_empty():
		var stray := _dist(here, obj.cells[0]) - GENERAL_HOME_RADIUS
		if stray > 0:
			score -= stray * GENERAL_STRAY_COST

	# Move toward whatever is aiming at our Objective, if we could take it.
	var intercept_before := _nearest_dist(was, _objective_hunters(gs))
	var intercept_after := _nearest_dist(here, _objective_hunters(gs))
	if intercept_before >= 0 and intercept_after >= 0:
		score += (intercept_before - intercept_after) * GENERAL_INTERCEPT

	# Otherwise drift toward friendly pieces that are currently under threat.
	var cover_before := _nearest_dist(was, _threatened_friendly_cells(gs, general))
	var cover_after := _nearest_dist(here, _threatened_friendly_cells(gs, general))
	if cover_before >= 0 and cover_after >= 0:
		score += (cover_before - cover_after) * GENERAL_COVER

	return score

# Everyone else drifts toward the enemy Objective.
func _score_advance(gs: GameState, piece: Piece, new_cells: Array[Vector2i]) -> float:
	# Only hunt the General with a piece that could actually take one. Everything
	# else heads for the Objective — approaching a General it can't capture is
	# pointless and just walks into the one thing that kills it.
	var target := _objective_of(gs, _enemy())
	var their_gen := _general_of(gs, _enemy())
	if their_gen != null and not their_gen.cells.is_empty() and _can_take_general(gs, piece):
		target = their_gen
	if target == null or target.cells.is_empty() or piece.cells.is_empty():
		return 0.0

	var from: Vector2i = piece.cells[0]
	var to: Vector2i = new_cells[0]
	var weight := SABOTEUR_ADVANCE if piece.has_status("saboteur") else ADVANCE_WEIGHT

	# Forward progress (toward the enemy's rows) is what we actually want, so
	# score the y-advance directly rather than lumping it in with sideways moves.
	# Blue starts at low y and advances toward high y; Red is the reverse.
	var forward: int = (to.y - from.y) if side == Piece.Owner.BLUE else (from.y - to.y)
	var score := forward * FORWARD_WEIGHT

	# Closing horizontal distance to the Objective's column still helps, but
	# counts for much less, so it can't tie with a real forward step.
	var obj_x: int = target.cells[0].x
	var col_gain: int = abs(from.x - obj_x) - abs(to.x - obj_x)
	score += col_gain * weight * 0.25

	# A move that stays on our own side and doesn't advance is milling — give it
	# nothing, so noise can't make it look as good as pushing forward.
	if forward <= 0:
		score -= LATERAL_PENALTY

	return score

func _value(piece: Piece) -> float:
	var v: float = VALUE.get(piece.type, 10.0)
	if piece.has_status("saboteur"):
		v += SABOTEUR_VALUE
	return v

# 0.0 = safe, MUTUAL_THREAT = they can force a same-type trade,
# 1.0 = they can capture it outright and keep their piece.
#
# NOTE: uses raw geometry from legal_moves_for(), which ignores pieces that
# would block the path — so this is PESSIMISTIC and sees threats that may not
# be real. Acceptable for Tier 1; wrong in the cautious direction.
func _threat_of(gs: GameState, mover: Piece, cells: Array[Vector2i], doomed: Dictionary = {}) -> float:
	var worst := 0.0
	for enemy in gs.pieces.values():
		if enemy.owner == side:
			continue
		if doomed.has(enemy.uid):
			continue   # this move kills it; it can't retaliate
		if enemy.type == Piece.Type.OBJECTIVE:
			continue   # Objectives can't capture: no entry in the beats table
		var result := RulesEngine.resolve_capture(enemy, mover)
		var level := 0.0
		if result == RulesEngine.CaptureResult.CAPTURED:
			level = 1.0
		elif result == RulesEngine.CaptureResult.MUTUAL_DESTROY:
			level = MUTUAL_THREAT
		if level <= worst:
			continue
		for dest in RulesEngine.legal_moves_for(enemy, gs):
			if _overlaps(_cells_after_move(enemy, dest), cells):
				worst = level
				break
		if worst >= 1.0:
			return 1.0
	return worst

func _cells_threatened(gs: GameState, mover: Piece, cells: Array[Vector2i]) -> bool:
	return _threat_of(gs, mover, cells) > 0.0

func _threatens_our_objective(gs: GameState, enemy: Piece) -> bool:
	var obj := _objective_of(gs, side)
	if obj == null:
		return false
	if RulesEngine.resolve_capture(enemy, obj) != RulesEngine.CaptureResult.CAPTURED:
		return false
	for dest in RulesEngine.legal_moves_for(enemy, gs):
		if _overlaps(_cells_after_move(enemy, dest), obj.cells):
			return true
	return false

# What this enemy piece is currently threatening among our pieces, excluding
# the one doing the capturing (its own safety is scored separately).
func _defends_value(gs: GameState, enemy: Piece, mover: Piece) -> float:
	var total := 0.0
	for friend in gs.pieces.values():
		if friend.owner != side or friend.uid == mover.uid or friend.cells.is_empty():
			continue
		if friend.type == Piece.Type.OBJECTIVE:
			continue   # covered by OBJECTIVE_GUARD
		var result := RulesEngine.resolve_capture(enemy, friend)
		var level := 0.0
		if result == RulesEngine.CaptureResult.CAPTURED:
			level = 1.0
		elif result == RulesEngine.CaptureResult.MUTUAL_DESTROY:
			level = MUTUAL_THREAT
		if level <= 0.0:
			continue
		for dest in RulesEngine.legal_moves_for(enemy, gs):
			if _overlaps(_cells_after_move(enemy, dest), friend.cells):
				total += _value(friend) * level * DEFEND_WEIGHT
				break
	return total
# Enemy pieces aiming at our Objective that our General could actually take.
func _objective_hunters(gs: GameState) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var general := _general_of(gs, side)
	for enemy in gs.pieces.values():
		if enemy.owner == side or enemy.cells.is_empty():
			continue
		if not _threatens_our_objective(gs, enemy):
			continue
		if general != null and RulesEngine.resolve_capture(general, enemy) != RulesEngine.CaptureResult.CAPTURED:
			continue   # a Saboteur, for instance — the General can't touch it
		out.append(enemy.cells[0])
	return out

func _threatened_friendly_cells(gs: GameState, exclude: Piece) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for friend in gs.pieces.values():
		if friend.owner != side or friend.uid == exclude.uid or friend.cells.is_empty():
			continue
		if friend.type == Piece.Type.OBJECTIVE:
			continue   # handled by the Objective terms above
		if _cells_threatened(gs, friend, friend.cells):
			out.append(friend.cells[0])
	return out

# ------------------------------------------------------------
# Helpers — all pure, no mutation of game_state
# ------------------------------------------------------------

func _cells_after_move(piece: Piece, dest: Vector2i) -> Array[Vector2i]:
	if piece.type == Piece.Type.B:
		return RulesEngine.b_new_cells_for_dest(piece, dest)
	return RulesEngine.cells_at(piece, dest)

func _overlaps(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	for cell in a:
		if b.has(cell):
			return true
	return false

func _dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# Distance to the closest cell in the list, or -1 when the list is empty.
func _nearest_dist(from: Vector2i, cells: Array[Vector2i]) -> int:
	var best := -1
	for cell in cells:
		var d := _dist(from, cell)
		if best < 0 or d < best:
			best = d
	return best

func _enemy() -> Piece.Owner:
	return Piece.Owner.BLUE if side == Piece.Owner.RED else Piece.Owner.RED

func _objective_of(gs: GameState, owner: Piece.Owner) -> Piece:
	for piece in gs.pieces.values():
		if piece.type == Piece.Type.OBJECTIVE and piece.owner == owner:
			return piece
	return null

func _general_of(gs: GameState, owner: Piece.Owner) -> Piece:
	for piece in gs.pieces.values():
		if piece.type == Piece.Type.GENERAL and piece.owner == owner:
			return piece
	return null

# ============================================================
# Cards
# ------------------------------------------------------------
# The hand is passed IN rather than read from game_state. That keeps this
# class incapable of reaching the opponent's hand even by accident, and it
# mirrors the projection model the online branch needs.
# The audit: this file must never index a player's hand directly.
# ============================================================

# Returns one of:
#   {"kind": "saboteur", "type_card": Card, "chart_card": Card, "chosen_type": int}
#   {"kind": "simple", "cards": [Card]}
#   {}  — play nothing
func choose_deployment(gs: GameState, hand: Array) -> Dictionary:
	if tier <= 0 or hand.is_empty():
		return {}

	var sab := _best_saboteur(gs, hand)
	if not sab.is_empty():
		return sab

	var best_card: Card = null
	var best_score := CARD_PLAY_BAR
	for card in hand:
		var info := gs.classify_deployment([card])
		if info["kind"] != GameState.DeployKind.SIMPLE:
			continue
		var s := _score_simple_card(gs, card)
		if s > best_score:
			best_score = s
			best_card = card
	if best_card != null:
		return {"kind": "simple", "cards": [best_card]}
	return {}

# Every Type x Chart x chosen-type combination points at exactly one enemy
# piece. Enumerate them all, score the piece each one would convert, take
# the best if it clears the bar.
func _best_saboteur(gs: GameState, hand: Array) -> Dictionary:
	if not RulesEngine.can_declare_saboteur(side, gs):
		return {}   # we already have one on the board

	var best: Dictionary = {}
	var best_score := SABOTEUR_BAR
	var opponent := _enemy()

	for type_card in hand:
		if type_card.category != Card.Category.TYPE:
			continue
		for chart_card in hand:
			if chart_card.category != Card.Category.CHART:
				continue
			for chosen_type in type_card.piece_types:
				var designation := RulesEngine.designation_from_cards(type_card, chart_card, chosen_type)
				if designation == "":
					continue
				var target: Piece = gs._find_piece_by_designation(designation, opponent)
				if target == null:
					continue
				var s := _score_saboteur_target(gs, target)
				if s > best_score:
					best_score = s
					best = {
						"kind": "saboteur",
						"type_card": type_card,
						"chart_card": chart_card,
						"chosen_type": chosen_type,
					}
	return best

# Converting takes the piece off their side AND puts it on ours, so a good
# target is one that is dangerous to us, useful to them, or well placed to run.
func _score_saboteur_target(gs: GameState, target: Piece) -> float:
	var score := _value(target)

	if _threatens_our_objective(gs, target):
		score += SAB_DEFENSIVE

	var general := _general_of(gs, side)
	if general != null and not general.cells.is_empty() and not target.cells.is_empty():
		if _dist(target.cells[0], general.cells[0]) <= SAB_NEAR_RANGE:
			score += SAB_NEAR_GENERAL

	# Once converted it becomes our Saboteur — the only piece that can take
	# their General. Closer to their half is a shorter run.
	var their_obj := _objective_of(gs, _enemy())
	if their_obj != null and not their_obj.cells.is_empty() and not target.cells.is_empty():
		var board_span := 30.0   # generous upper bound on Manhattan distance
		score += (board_span - _dist(target.cells[0], their_obj.cells[0])) * SAB_RUN_WEIGHT / board_span * 10.0

	return score

func _score_simple_card(gs: GameState, card: Card) -> float:
	if card.category == Card.Category.MAJOR_POWER:
		match card.major_effect:
			Card.MajorEffect.BLITZKRIEG:
				# An extra move, but only before we've moved.
				if gs.has_moved_this_turn:
					return -1.0
				return 40.0
			Card.MajorEffect.INEFFECTIVE_LEADERSHIP:
				# Freezes their General for three turns. Only worth it if
				# theirs is actually doing something near our pieces.
				var their_gen := _general_of(gs, _enemy())
				if their_gen == null or their_gen.cells.is_empty():
					return -1.0
				return 25.0 if _general_is_active(gs, their_gen) else 5.0
			Card.MajorEffect.DOUBLE_AGENT:
				# Reclaims a piece of ours they converted. Only if one exists.
				return 60.0 if _they_hold_our_saboteur(gs) else -1.0
			Card.MajorEffect.IM_ON_TO_YOU:
				# Lets our General capture the Saboteur they made from our piece.
				return 30.0 if _they_hold_our_saboteur(gs) else -1.0
			Card.MajorEffect.HE_SEEMED_SUSPICIOUS:
				# Permits capturing our own pieces. We have no use for that yet.
				return -1.0
	elif card.category == Card.Category.MINOR_POWER:
		match card.minor_effect:
			Card.MinorEffect.GET_MOVE_ON:
				if gs.has_moved_this_turn:
					return -1.0
				return 35.0 if _has_movable_of_type(gs, card.effect_piece_type) else -1.0
			Card.MinorEffect.CLOSE_CALL:
				# Turns a mutual destroy into a clean capture for that type.
				# Worth it when a same-type standoff is actually on the board.
				return 30.0 if _standoff_exists(gs, card.effect_piece_type) else 4.0
			Card.MinorEffect.JUST_IN_CASE:
				# Bonus draw on our next capture. Cheap filler.
				return 12.0
	return -1.0

# ------------------------------------------------------------
# Discarding
# ------------------------------------------------------------

# Called when the hand is over the limit. Returns the least useful card.
func choose_discard(gs: GameState, hand: Array) -> Card:
	var worst: Card = null
	var worst_score := INF
	for card in hand:
		var s := _keep_value(gs, card, hand)
		if s < worst_score:
			worst_score = s
			worst = card
	return worst

func _keep_value(gs: GameState, card: Card, hand: Array) -> float:
	match card.category:
		Card.Category.MAJOR_POWER, Card.Category.MINOR_POWER:
			var s := _score_simple_card(gs, card)
			return s if s > 0.0 else 8.0   # situational, but may become live
		Card.Category.TYPE, Card.Category.CHART:
			# Only worth holding if it can currently form a Saboteur pair.
			if not RulesEngine.can_declare_saboteur(side, gs):
				return 1.0
			return 30.0 if _card_forms_a_pair(gs, card, hand) else 2.0
	return 5.0

func _card_forms_a_pair(gs: GameState, card: Card, hand: Array) -> bool:
	var opponent := _enemy()
	for other in hand:
		var type_card: Card = null
		var chart_card: Card = null
		if card.category == Card.Category.TYPE and other.category == Card.Category.CHART:
			type_card = card
			chart_card = other
		elif card.category == Card.Category.CHART and other.category == Card.Category.TYPE:
			type_card = other
			chart_card = card
		else:
			continue
		for chosen_type in type_card.piece_types:
			var designation := RulesEngine.designation_from_cards(type_card, chart_card, chosen_type)
			if designation == "":
				continue
			if gs._find_piece_by_designation(designation, opponent) != null:
				return true
	return false

# ------------------------------------------------------------
# Card-scoring helpers
# ------------------------------------------------------------

func _has_movable_of_type(gs: GameState, piece_type: Piece.Type) -> bool:
	for piece in gs.pieces.values():
		if piece.owner != side or piece.type != piece_type:
			continue
		if not RulesEngine.legal_destinations_for(piece, gs).is_empty():
			return true
	return false

# A same-type pair within striking distance, where Close Call would convert
# a mutual destroy into a clean capture for us.
func _standoff_exists(gs: GameState, piece_type: Piece.Type) -> bool:
	for mine in gs.pieces.values():
		if mine.owner != side or mine.type != piece_type:
			continue
		for dest in RulesEngine.legal_destinations_for(mine, gs):
			var cells := _cells_after_move(mine, dest)
			for other in gs.pieces.values():
				if other.owner == side or other.type != piece_type:
					continue
				if _overlaps(cells, other.cells):
					return true
	return false

func _they_hold_our_saboteur(gs: GameState) -> bool:
	for piece in gs.pieces.values():
		if piece.owner == _enemy() and piece.has_status("saboteur") and piece.original_owner == side:
			return true
	return false

func _general_is_active(gs: GameState, their_general: Piece) -> bool:
	if their_general.cells.is_empty():
		return false
	for mine in gs.pieces.values():
		if mine.owner != side or mine.cells.is_empty():
			continue
		if _dist(their_general.cells[0], mine.cells[0]) <= 4:
			return true
	return false

# ============================================================
# I Thought You Were Dead
# ------------------------------------------------------------
# Redeploys one captured piece back onto the board. The CPU chooses WHICH
# captured piece and WHICH cell; the controller supplies the legal cells
# (so band-vs-half house rules stay in one place) and the anchor cell of
# recent action. Returns {} to decline.
#
# legal_cells: Array of Vector2i already filtered to empty, in-zone cells.
# anchor: Vector2i of the last-moved piece, or (-1,-1) if none.
# ============================================================
func choose_ityd(gs: GameState, hand: Array, captured: Array, legal_cells: Array, anchor: Vector2i) -> Dictionary:
	if legal_cells.is_empty() or captured.is_empty():
		return {}

	# Find an ITYD card and the captured piece type it can redeploy.
	var card: Card = null
	for c in hand:
		if c.category == Card.Category.MINOR_POWER and c.minor_effect == Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD:
			card = c
			break
	if card == null:
		return {}

	# Best captured piece of the card's type — most valuable first.
	var piece: Piece = null
	var best_val := -INF
	for cap in captured:
		if cap.type != card.effect_piece_type:
			continue
		var v := _value(cap)
		if v > best_val:
			best_val = v
			piece = cap
	if piece == null:
		return {}   # no captured piece matches the card's type

	# Best legal cell — closest to recent action, tie-broken toward the enemy.
	var target_obj := _objective_of(gs, _enemy())
	var enemy_y: int = target_obj.cells[0].y if (target_obj != null and not target_obj.cells.is_empty()) else 0
	var best_cell: Vector2i = legal_cells[0]
	var best_cell_score := -INF
	for cell in legal_cells:
		var s := 0.0
		if anchor.x >= 0:
			s -= _dist(cell, anchor) * ITYD_ACTION_WEIGHT
		s -= abs(cell.y - enemy_y) * 0.2   # gentle nudge forward
		if s > best_cell_score:
			best_cell_score = s
			best_cell = cell

	# Don't redeploy into danger — a piece brought back onto a threatened cell
	# just gets taken again. Hold the card unless the best cell is safe.
	var footprint := _cells_after_move(piece, best_cell) if piece.type == Piece.Type.B \
		else RulesEngine.cells_at(piece, best_cell)
	if _threat_of(gs, piece, footprint) >= 1.0:
		return {}   # best available cell is still a capture risk — wait

	return {"card": card, "piece_uid": piece.uid, "cell": best_cell}

# ============================================================
# One Man Army — lets a chosen type capture the enemy General.
# Worth playing when we have a piece of some type within striking range
# of their General, since that's an alternate win.
# Returns {"type_card": Card, "chosen_type": int} or {}.
# ============================================================
func choose_one_man_army(gs: GameState, hand: Array) -> Dictionary:
	if gs.one_man_army_active:
		return {}
	var their_general := _general_of(gs, _enemy())
	if their_general == null or their_general.cells.is_empty():
		return {}

	var best: Dictionary = {}
	var best_score := OMA_BASE
	for type_card in hand:
		if type_card.category != Card.Category.MAJOR_POWER:
			continue
		if type_card.major_effect != Card.MajorEffect.ONE_MAN_ARMY:
			continue
		for chosen_type in type_card.piece_types:
			# Closest own piece of this type to their General.
			var nearest := 999
			for p in gs.pieces.values():
				if p.owner != side or p.type != chosen_type or p.cells.is_empty():
					continue
				nearest = min(nearest, _dist(p.cells[0], their_general.cells[0]))
			# OMA expires at end_turn(), so only declare when a piece of this
			# type can reach the General THIS turn.
			if nearest > 1:
				continue
			var s := OMA_BASE + (2 - nearest) * 8.0
			if s > best_score:
				best_score = s
				best = {"type_card": type_card, "chosen_type": chosen_type}
	return best

# ============================================================
# Just This Once — moves the Objective 1-3 cells, once per game.
# A defensive escape when the Objective is threatened and can reach a safe
# cell a normal single-step move can't. legal_dests supplied by controller.
# Returns {"card": Card, "dest": Vector2i} or {}.
# ============================================================
func choose_just_this_once(gs: GameState, hand: Array, legal_dests: Array) -> Dictionary:
	if gs.objective_has_moved.get(side, false) or legal_dests.is_empty():
		return {}
	var card: Card = null
	for c in hand:
		if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.JUST_THIS_ONCE:
			card = c
			break
	if card == null:
		return {}

	var obj := _objective_of(gs, side)
	if obj == null or obj.cells.is_empty():
		return {}
	# Last-resort only: play JTO when an enemy can capture the Objective on its
	# very next move (threat == 1.0). Never sooner — it's a once-per-game stall.
	if _threat_of(gs, obj, obj.cells) < 1.0:
		return {}

	# Among safe cells, run as far as possible from the nearest attacker.
	# If nowhere is fully safe, still take the cell that maximizes distance —
	# buying the most time is the whole point of the once-per-game move.
	var best_dest: Vector2i = legal_dests[0]
	var best_key := -INF
	for dest in legal_dests:
		var t := _threat_of(gs, obj, [dest] as Array[Vector2i])
		var nearest := _nearest_dist(dest, _attacker_cells(gs, obj))
		if nearest < 0:
			nearest = 99
		# Safe cells always beat threatened ones; among equals, more distance wins.
		var key := (1000.0 if t < 1.0 else 0.0) + float(nearest)
		if key > best_key:
			best_key = key
			best_dest = dest
	return {"card": card, "dest": best_dest}

func _attacker_cells(gs: GameState, obj: Piece) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for enemy in gs.pieces.values():
		if enemy.owner == side or enemy.cells.is_empty():
			continue
		if RulesEngine.resolve_capture(enemy, obj) != RulesEngine.CaptureResult.CAPTURED:
			continue
		for dest in RulesEngine.legal_moves_for(enemy, gs):
			if _overlaps(_cells_after_move(enemy, dest), obj.cells):
				out.append(enemy.cells[0])
				break
	return out

# Piece types our hand's One Man Army cards could name. Refreshed each turn by
# note_hand(); empty when we hold no OMA card.
var _oma_types: Dictionary = {}

# The controller calls this before choose_move() so the scorer knows what our
# hand makes possible. Keeps all hand-reading on the controller side.
func note_hand(hand: Array) -> void:
	_oma_types.clear()
	for c in hand:
		if c.category == Card.Category.MAJOR_POWER and c.major_effect == Card.MajorEffect.ONE_MAN_ARMY:
			for t in c.piece_types:
				_oma_types[t] = true

# True when this piece could actually capture an enemy General: it's a Saboteur,
# OMA is live on its type this turn, or we HOLD an OMA card naming its type —
# the last case is what motivates the multi-turn walk before declaring.
func _can_take_general(gs: GameState, piece: Piece) -> bool:
	if piece.has_status("saboteur"):
		return true
	if gs.one_man_army_active and piece.type == gs.one_man_army_type:
		return true
	return _oma_types.has(piece.type)

# A General captures diagonally only (rules_engine.gd: four diagonal dirs, one
# step). So an orthogonally adjacent square is safe and a diagonal one is not.
func _general_approach_bonus(gs: GameState, piece: Piece, new_cells: Array[Vector2i]) -> float:
	if not _can_take_general(gs, piece):
		return 0.0
	var their_gen := _general_of(gs, _enemy())
	if their_gen == null or their_gen.cells.is_empty():
		return 0.0
	var g: Vector2i = their_gen.cells[0]
	for cell in new_cells:
		var dx: int = abs(cell.x - g.x)
		var dy: int = abs(cell.y - g.y)
		if dx + dy == 1:
			return GENERAL_SAFE_APPROACH
		if dx == 1 and dy == 1:
			return -GENERAL_DIAGONAL_RISK
	return 0.0
