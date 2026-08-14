extends RefCounted
class_name CardDatabase

static func build_full_deck() -> Array[Card]:
	var deck: Array[Card] = []
	var uid := 1

	# --- CHART CARDS (24: 12 unique rows x2) ---
	var chart_rows := [
		{ Piece.Type.A: 1,  Piece.Type.B: 1, Piece.Type.C: 1 },
		{ Piece.Type.A: 2,  Piece.Type.B: 2, Piece.Type.C: 2 },
		{ Piece.Type.A: 3,  Piece.Type.B: 3, Piece.Type.C: 3 },
		{ Piece.Type.A: 4,  Piece.Type.B: 4, Piece.Type.C: 1 },
		{ Piece.Type.A: 5,  Piece.Type.B: 5, Piece.Type.C: 2 },
		{ Piece.Type.A: 6,  Piece.Type.B: 6, Piece.Type.C: 3 },
		{ Piece.Type.A: 7,  Piece.Type.B: 1, Piece.Type.C: 1 },
		{ Piece.Type.A: 8,  Piece.Type.B: 2, Piece.Type.C: 2 },
		{ Piece.Type.A: 9,  Piece.Type.B: 3, Piece.Type.C: 3 },
		{ Piece.Type.A: 10, Piece.Type.B: 4, Piece.Type.C: 1 },
		{ Piece.Type.A: 11, Piece.Type.B: 5, Piece.Type.C: 2 },
		{ Piece.Type.A: 12, Piece.Type.B: 6, Piece.Type.C: 3 },
	]
	for row in chart_rows:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.CHART
			c.chart_values = row
			deck.append(c)

	# --- TYPE CARDS (20) ---
	# Single-type: A x4, B x4, C x4
	for piece_type in [Piece.Type.A, Piece.Type.B, Piece.Type.C]:
		for i in range(4):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.TYPE
			c.piece_types = [piece_type]
			deck.append(c)
	# Multi-type: A/B x2, B/C x2, A/C x2, A/B/C x2
	var multi_types: Array = [
		[Piece.Type.A, Piece.Type.B],
		[Piece.Type.B, Piece.Type.C],
		[Piece.Type.A, Piece.Type.C],
		[Piece.Type.A, Piece.Type.B, Piece.Type.C],
	]
	for combo in multi_types:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.TYPE
			var typed_combo: Array[Piece.Type] = []
			for t in combo:
				typed_combo.append(t)
			c.piece_types = typed_combo
			deck.append(c)

	# --- MINOR POWER CARDS (20: 10 unique x2) ---
	# Get Move On! A/B/C x2 each
	for piece_type in [Piece.Type.A, Piece.Type.B, Piece.Type.C]:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.MINOR_POWER
			c.minor_effect = Card.MinorEffect.GET_MOVE_ON
			c.effect_piece_type = piece_type
			deck.append(c)
	# Close Call! A/B/C x2 each
	for piece_type in [Piece.Type.A, Piece.Type.B, Piece.Type.C]:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.MINOR_POWER
			c.minor_effect = Card.MinorEffect.CLOSE_CALL
			c.effect_piece_type = piece_type
			deck.append(c)
	# I Thought You Were Dead! A/B/C x2 each
	for piece_type in [Piece.Type.A, Piece.Type.B, Piece.Type.C]:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.MINOR_POWER
			c.minor_effect = Card.MinorEffect.I_THOUGHT_YOU_WERE_DEAD
			c.effect_piece_type = piece_type
			deck.append(c)
	# Just In Case... x2
	for i in range(2):
		var c := Card.new()
		c.uid = uid; uid += 1
		c.category = Card.Category.MINOR_POWER
		c.minor_effect = Card.MinorEffect.JUST_IN_CASE
		deck.append(c)

	# --- MAJOR POWER CARDS (7: all unique) ---
	var major_effects := [
		Card.MajorEffect.INEFFECTIVE_LEADERSHIP,
		Card.MajorEffect.HE_SEEMED_SUSPICIOUS,
		Card.MajorEffect.JUST_THIS_ONCE,
		Card.MajorEffect.BLITZKRIEG,
		Card.MajorEffect.IM_ON_TO_YOU,
		Card.MajorEffect.ONE_MAN_ARMY,
		Card.MajorEffect.DOUBLE_AGENT,
	]
	for effect in major_effects:
		var c := Card.new()
		c.uid = uid; uid += 1
		c.category = Card.Category.MAJOR_POWER
		c.major_effect = effect
		deck.append(c)

	return deck

static func build_starter_deck() -> Array[Card]:
	var deck: Array[Card] = []
	var uid := 1000  # offset from full deck uids to avoid collisions in tests

	for piece_type in [Piece.Type.A, Piece.Type.B, Piece.Type.C]:
		for i in range(2):
			var c := Card.new()
			c.uid = uid; uid += 1
			c.category = Card.Category.TYPE
			c.piece_types = [piece_type]
			deck.append(c)

	var chart_rows := [
		{ Piece.Type.A: 1, Piece.Type.B: 2, Piece.Type.C: 3 },
		{ Piece.Type.A: 4, Piece.Type.B: 5, Piece.Type.C: 6 },
		{ Piece.Type.A: 7, Piece.Type.B: 8, Piece.Type.C: 9 },
	]
	for row in chart_rows:
		var c := Card.new()
		c.uid = uid; uid += 1
		c.category = Card.Category.CHART
		c.chart_values = row
		deck.append(c)

	return deck
