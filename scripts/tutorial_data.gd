extends RefCounted
# Tutorial copy and deterministic lesson definitions. Every lesson is
# self-contained so it can be restarted or entered directly from the timeline.

static func build_steps() -> Array[Dictionary]:
	return [
		{
			"id": "place_a",
			"title": "Croce: place an A",
			"body": "Croce is the secret deployment at the start of a match. Each player places all 23 pieces inside the five rows nearest that player's edge. A pieces occupy one square.",
			"instruction": "Move the green ghost anywhere inside Blue's deployment zone, then click to place A1.",
			"action": "place",
			"setup": "croce_a",
			"piece_type": Piece.Type.A,
			"designation": "A1",
			"owner": Piece.Owner.BLUE,
			"focus": Rect2i(0, 0, 18, 6),
		},
		{
			"id": "place_b",
			"title": "Croce: place a B",
			"body": "B pieces occupy two adjacent squares. Their orientation affects movement, so Croce includes a real choice about whether each B begins horizontal or vertical.",
			"instruction": "Move the two-square ghost to a clear position. Press R or use Rotate B to change orientation, then click.",
			"action": "place",
			"setup": "croce_b",
			"piece_type": Piece.Type.B,
			"designation": "B1",
			"owner": Piece.Owner.BLUE,
			"focus": Rect2i(0, 0, 18, 6),
		},
		{
			"id": "place_c",
			"title": "Croce: place a C",
			"body": "C pieces occupy a two-by-two block. The entire footprint must remain inside the deployment zone and clear of every other piece.",
			"instruction": "Move the two-by-two ghost to any legal position, then click to place C1.",
			"action": "place",
			"setup": "croce_c",
			"piece_type": Piece.Type.C,
			"designation": "C1",
			"owner": Piece.Owner.BLUE,
			"focus": Rect2i(0, 0, 18, 6),
		},
		{
			"id": "place_general",
			"title": "Croce: place the General",
			"body": "The General occupies one square. During play it moves diagonally, stays in its own half, and captures ordinary army pieces without using the A-C-B cycle.",
			"instruction": "Place the Blue General in any clear square inside the deployment zone.",
			"action": "place",
			"setup": "croce_general",
			"piece_type": Piece.Type.GENERAL,
			"designation": "General",
			"owner": Piece.Owner.BLUE,
			"focus": Rect2i(0, 0, 18, 6),
		},
		{
			"id": "place_objective",
			"title": "Croce: place the Objective",
			"body": "The Objective occupies one square and normally cannot move. Losing it ends the match, so its Croce position matters.",
			"instruction": "Place the Blue Objective in any remaining clear square inside the deployment zone.",
			"action": "place",
			"setup": "croce_objective",
			"piece_type": Piece.Type.OBJECTIVE,
			"designation": "Objective",
			"owner": Piece.Owner.BLUE,
			"focus": Rect2i(0, 0, 18, 6),
		},
		{
			"id": "move_a",
			"title": "Move an A",
			"body": "A normal turn includes one move. An A moves one square orthogonally: up, down, left, or right. Legal destinations appear only after the piece is selected.",
			"instruction": "Click Blue A1, then choose any green destination.",
			"action": "move",
			"setup": "movement_a",
			"accept_any_legal": true,
			"piece": "A1",
			"destination_click": Vector2i(6, 7),
			"new_cells": [Vector2i(6, 7)],
			"outcome": "move",
			"focus": Rect2i(2, 4, 10, 7),
		},
		{
			"id": "move_b",
			"title": "Move a B",
			"body": "A B may slide one square along its long axis or pivot around either end. Every legal move keeps at least one of the B's old cells occupied.",
			"instruction": "Click Blue B1, then choose any green slide or pivot.",
			"action": "move",
			"setup": "movement_b",
			"accept_any_legal": true,
			"piece": "B1",
			"destination_click": Vector2i(9, 7),
			"new_cells": [Vector2i(8, 7), Vector2i(9, 7)],
			"orientation": Piece.PieceOrientation.HORIZONTAL,
			"outcome": "move",
			"focus": Rect2i(4, 4, 10, 8),
		},
		{
			"id": "move_c",
			"title": "Move a C",
			"body": "A C shifts its entire two-by-two footprint one square orthogonally. All four destination cells must form one legal placement.",
			"instruction": "Click Blue C1, then choose any green one-square shift.",
			"action": "move",
			"setup": "movement_c",
			"accept_any_legal": true,
			"piece": "C1",
			"destination_click": Vector2i(10, 6),
			"new_cells": [Vector2i(10, 6), Vector2i(11, 6), Vector2i(10, 7), Vector2i(11, 7)],
			"outcome": "move",
			"focus": Rect2i(6, 3, 10, 10),
		},
		{
			"id": "move_general",
			"title": "Move the General",
			"body": "The General moves one square diagonally and must remain in its own half. The center line therefore removes some otherwise valid diagonal moves.",
			"instruction": "Click the Blue General, then choose any green diagonal destination.",
			"action": "move",
			"setup": "movement_general",
			"accept_any_legal": true,
			"piece": "General",
			"destination_click": Vector2i(6, 6),
			"new_cells": [Vector2i(6, 6)],
			"outcome": "move",
			"focus": Rect2i(2, 2, 10, 9),
		},
		{
			"id": "objective_capture",
			"title": "Capture the Objective",
			"body": "Any eligible non-General attacker captures the enemy Objective by entering its square. The Objective does not use the A-C-B cycle. A real match ends immediately when it is captured.",
			"instruction": "Click Blue A1, then click the Red Objective.",
			"action": "move",
			"setup": "objective_capture",
			"piece": "A1",
			"destination_click": Vector2i(15, 12),
			"new_cells": [Vector2i(15, 12)],
			"outcome": "capture",
			"targets": ["Objective"],
			"focus": Rect2i(11, 9, 7, 7),
		},
		{
			"id": "capture_ac",
			"title": "A captures C",
			"body": "Ordinary army captures follow one cycle: A beats C, C beats B, and B beats A. An A removes an entire C by entering any square in the C's footprint.",
			"instruction": "Click Blue A1, then move right onto Red C1.",
			"action": "move",
			"setup": "capture_ac",
			"piece": "A1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(7, 7)],
			"outcome": "capture",
			"targets": ["C1"],
			"focus": Rect2i(3, 4, 9, 8),
		},
		{
			"id": "capture_cb",
			"title": "C captures B",
			"body": "A C captures a B when its new two-by-two footprint overlaps any part of that B. The whole B is removed.",
			"instruction": "Click Blue C1, then shift it one square right onto Red B1.",
			"action": "move",
			"setup": "capture_cb",
			"piece": "C1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)],
			"outcome": "capture",
			"targets": ["B1"],
			"focus": Rect2i(2, 4, 10, 8),
		},
		{
			"id": "capture_ba",
			"title": "B captures A",
			"body": "A B captures an A through a legal slide or pivot when the B's new two-cell placement overlaps the A.",
			"instruction": "Click Blue B1, then pivot its right end downward onto Red A1.",
			"action": "move",
			"setup": "capture_ba",
			"piece": "B1",
			"destination_click": Vector2i(7, 8),
			"new_cells": [Vector2i(7, 7), Vector2i(7, 8)],
			"orientation": Piece.PieceOrientation.VERTICAL,
			"outcome": "capture",
			"targets": ["A1"],
			"focus": Rect2i(3, 4, 9, 8),
		},
		{
			"id": "mutual",
			"title": "Equal types destroy each other",
			"body": "When equal army types collide, both pieces are removed. The attacking player draws first; the defending player then draws as well.",
			"instruction": "Click Blue A1, then move onto Red A1.",
			"action": "move",
			"setup": "mutual",
			"piece": "A1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(7, 7)],
			"outcome": "mutual",
			"targets": ["A1_RED"],
			"focus": Rect2i(3, 4, 9, 7),
		},
		{
			"id": "double_c",
			"title": "A C can capture twice",
			"body": "A C resolves every enemy piece overlapped by its new footprint. One move can therefore capture two separate pieces.",
			"instruction": "Click Blue C1, then shift it right across both Red B pieces.",
			"action": "move",
			"setup": "double_c",
			"piece": "C1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)],
			"outcome": "capture",
			"targets": ["B1", "B2"],
			"focus": Rect2i(2, 4, 10, 9),
		},
		{
			"id": "draw_cards",
			"title": "Captures draw cards",
			"body": "Each captured piece produces one card draw for the attacker. The previous kind of C move captures two pieces, so it produces two draws. Mutual destruction produces one draw for each player.",
			"instruction": "Inspect the two example cards, then continue.",
			"action": "continue",
			"setup": "double_c_after",
			"hand": "reward_two",
			"focus": Rect2i(2, 4, 10, 9),
		},
		{
			"id": "general_capture",
			"title": "The General attacks freely",
			"body": "The General ignores the A-C-B cycle when attacking ordinary army pieces. It may capture an A, B, or C on a legal diagonal destination.",
			"instruction": "Click the Blue General, then move diagonally onto Red B1.",
			"action": "move",
			"setup": "general_capture",
			"piece": "General",
			"destination_click": Vector2i(6, 7),
			"new_cells": [Vector2i(6, 7)],
			"outcome": "capture",
			"targets": ["B1"],
			"focus": Rect2i(2, 3, 9, 9),
		},
		{
			"id": "general_immunity",
			"title": "Ordinary pieces cannot take a General",
			"body": "A normal A, B, or C cannot capture a General. Saboteurs and certain power-card effects create the important exceptions.",
			"instruction": "Click Blue A1, then try to move onto the Red General.",
			"action": "try_illegal",
			"setup": "general_immunity",
			"piece": "A1",
			"destination_click": Vector2i(7, 8),
			"focus": Rect2i(3, 5, 9, 7),
		},
		{
			"id": "card_catalog",
			"title": "The four card families",
			"body": "Type and Chart cards are combined to identify one enemy piece by designation. Minor and Major cards have individual effects. The board at left shows representative Type and Chart cards and one example of every Minor and Major effect.",
			"instruction": "Review the catalogue, then continue.",
			"action": "continue",
			"setup": "empty",
			"hand": "catalog",
			"focus": Rect2i(0, 0, 18, 16),
		},
		{
			"id": "saboteur_cards",
			"title": "Declare a Saboteur",
			"body": "A Type card supplies the letter. A Chart card supplies the number listed for that letter. Type A plus Chart 07 identifies Red A7. A player may control only one active Saboteur at a time.",
			"instruction": "Select Type A and Chart 07, then select Deploy.",
			"action": "saboteur_cards",
			"setup": "saboteur",
			"hand": "saboteur",
			"focus": Rect2i(3, 5, 10, 8),
		},
		{
			"id": "saboteur_capture",
			"title": "A Saboteur can kill a General",
			"body": "The declared piece changes control and keeps its normal movement geometry. Saboteur status permits it to capture the enemy General.",
			"instruction": "Click the converted A7, then move right onto the Red General.",
			"action": "move",
			"setup": "saboteur",
			"convert_piece": "A7",
			"convert_owner": Piece.Owner.BLUE,
			"piece": "A7",
			"destination_click": Vector2i(7, 8),
			"new_cells": [Vector2i(7, 8)],
			"outcome": "capture",
			"targets": ["General"],
			"focus": Rect2i(3, 5, 10, 8),
		},
		{
			"id": "close_call_card",
			"title": "Deploy Close Call",
			"body": "Close Call protects one named army type from its first same-type mutual destruction during the turn. The attacking piece survives and captures instead; the protection is then consumed.",
			"instruction": "Select Close Call — A, then select Deploy.",
			"action": "power_card",
			"setup": "close_call",
			"hand": "close_call",
			"focus": Rect2i(3, 4, 9, 7),
		},
		{
			"id": "close_call_capture",
			"title": "Close Call changes the collision",
			"body": "These two A pieces would normally destroy each other. Close Call is already active for this stage, so the attacking A survives and removes the defender.",
			"instruction": "Click Blue A1, then move onto Red A1.",
			"action": "move",
			"setup": "close_call",
			"close_call_armed": true,
			"piece": "A1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(7, 7)],
			"outcome": "capture",
			"targets": ["A1_RED"],
			"focus": Rect2i(3, 4, 9, 7),
		},
		{
			"id": "hand_limit",
			"title": "Reduce a hand to nine cards",
			"body": "A hand may contain no more than nine cards. When a draw raises the total above nine, play pauses until enough cards are returned to the bottom of the deck.",
			"instruction": "Select any one of the ten cards, then select Confirm Discard.",
			"action": "discard",
			"setup": "empty",
			"hand": "limit",
			"focus": Rect2i(0, 0, 18, 16),
		},
		{
			"id": "edge_c_blocked",
			"title": "An A can block a C attack",
			"body": "A C move is rejected when its new footprint overlaps an enemy A. The whole move is illegal even when the same footprint would also overlap a B or C that the attacker could otherwise capture.",
			"instruction": "Click Blue C1, then try to shift it right onto Red A1.",
			"action": "try_illegal",
			"setup": "c_blocked",
			"piece": "C1",
			"destination_click": Vector2i(7, 7),
			"new_cells": [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)],
			"focus": Rect2i(2, 4, 11, 8),
		},
		{
			"id": "card_timing",
			"title": "Card timing and exceptional moves",
			"body": "Blitzkrieg and Get Move On must be deployed before the first move of the turn. Just This Once moves your Objective one to three clear orthogonal spaces, once per player per game. I Thought You Were Dead redeploys a captured piece into its deployment zone. One Man Army temporarily lets a named army type capture a General.",
			"instruction": "Inspect the examples, then continue.",
			"action": "continue",
			"setup": "edge_display",
			"hand": "timing",
			"focus": Rect2i(1, 2, 15, 12),
		},
		{
			"id": "complete",
			"title": "Tutorial complete",
			"body": "You have used the normal Croce controls, moved every piece class, resolved the capture cycle, drawn and deployed cards, declared a Saboteur, handled the hand limit, and tested two important illegal moves. The timeline remains available for review.",
			"instruction": "Return to the menu when finished reviewing the lessons.",
			"action": "complete",
			"setup": "summary",
			"focus": Rect2i(0, 0, 18, 16),
		},
	]

static func setup_pieces(name: String) -> Array[Dictionary]:
	match name:
		"croce_a", "empty":
			return []
		"croce_b":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(4, 3)]),
			]
		"croce_c":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(4, 3)]),
				_piece("B1", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(6, 2), Vector2i(6, 3)], Piece.PieceOrientation.VERTICAL),
			]
		"croce_general":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(4, 3)]),
				_piece("B1", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(6, 2), Vector2i(6, 3)], Piece.PieceOrientation.VERTICAL),
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3)]),
			]
		"croce_objective":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(4, 3)]),
				_piece("B1", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(6, 2), Vector2i(6, 3)], Piece.PieceOrientation.VERTICAL),
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3)]),
				_piece("General", Piece.Type.GENERAL, Piece.Owner.BLUE, [Vector2i(2, 3)]),
			]
		"movement_a":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(5, 7)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(2, 5), Vector2i(2, 6)], Piece.PieceOrientation.VERTICAL),
				_piece("C2", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(9, 4), Vector2i(10, 4), Vector2i(9, 5), Vector2i(10, 5)]),
				_piece("A4", Piece.Type.A, Piece.Owner.RED, [Vector2i(8, 10)]),
			]
		"movement_b":
			return [
				_piece("B1", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(8, 6), Vector2i(8, 7)], Piece.PieceOrientation.VERTICAL),
				_piece("A2", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(4, 8)]),
				_piece("C2", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(11, 3), Vector2i(12, 3), Vector2i(11, 4), Vector2i(12, 4)]),
				_piece("B4", Piece.Type.B, Piece.Owner.RED, [Vector2i(12, 10), Vector2i(13, 10)], Piece.PieceOrientation.HORIZONTAL),
			]
		"movement_c":
			return [
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(11, 6), Vector2i(12, 6), Vector2i(11, 7), Vector2i(12, 7)]),
				_piece("A2", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(7, 5)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(15, 4), Vector2i(15, 5)], Piece.PieceOrientation.VERTICAL),
				_piece("C3", Piece.Type.C, Piece.Owner.RED, [Vector2i(8, 11), Vector2i(9, 11), Vector2i(8, 12), Vector2i(9, 12)]),
			]
		"movement_general":
			return [
				_piece("General", Piece.Type.GENERAL, Piece.Owner.BLUE, [Vector2i(5, 5)]),
				_piece("A2", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(2, 6)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(9, 4), Vector2i(10, 4)], Piece.PieceOrientation.HORIZONTAL),
				_piece("A5", Piece.Type.A, Piece.Owner.RED, [Vector2i(8, 10)]),
			]
		"objective_capture":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(14, 12)]),
				_piece("Objective", Piece.Type.OBJECTIVE, Piece.Owner.RED, [Vector2i(15, 12)]),
				_piece("B3", Piece.Type.B, Piece.Owner.RED, [Vector2i(12, 10), Vector2i(13, 10)], Piece.PieceOrientation.HORIZONTAL),
			]
		"capture_ac":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 7)]),
				_piece("C1", Piece.Type.C, Piece.Owner.RED, [Vector2i(7, 7), Vector2i(8, 7), Vector2i(7, 8), Vector2i(8, 8)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(4, 5), Vector2i(4, 6)], Piece.PieceOrientation.VERTICAL),
			]
		"capture_cb":
			return [
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(5, 7), Vector2i(6, 7), Vector2i(5, 8), Vector2i(6, 8)]),
				_piece("B1", Piece.Type.B, Piece.Owner.RED, [Vector2i(7, 7), Vector2i(7, 8)], Piece.PieceOrientation.VERTICAL),
				_piece("A4", Piece.Type.A, Piece.Owner.RED, [Vector2i(10, 10)]),
			]
		"capture_ba":
			return [
				_piece("B1", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(6, 7), Vector2i(7, 7)], Piece.PieceOrientation.HORIZONTAL),
				_piece("A1", Piece.Type.A, Piece.Owner.RED, [Vector2i(7, 8)]),
				_piece("C3", Piece.Type.C, Piece.Owner.RED, [Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 10), Vector2i(11, 10)]),
			]
		"mutual":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 7)]),
				_piece("A1", Piece.Type.A, Piece.Owner.RED, [Vector2i(7, 7)], Piece.PieceOrientation.VERTICAL, "A1_RED"),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(4, 5), Vector2i(5, 5)], Piece.PieceOrientation.HORIZONTAL),
			]
		"double_c":
			return [
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(5, 7), Vector2i(6, 7), Vector2i(5, 8), Vector2i(6, 8)]),
				_piece("B1", Piece.Type.B, Piece.Owner.RED, [Vector2i(7, 6), Vector2i(7, 7)], Piece.PieceOrientation.VERTICAL),
				_piece("B2", Piece.Type.B, Piece.Owner.RED, [Vector2i(7, 8), Vector2i(7, 9)], Piece.PieceOrientation.VERTICAL),
			]
		"double_c_after":
			return [
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(6, 7), Vector2i(7, 7), Vector2i(6, 8), Vector2i(7, 8)]),
			]
		"general_capture":
			return [
				_piece("General", Piece.Type.GENERAL, Piece.Owner.BLUE, [Vector2i(5, 6)]),
				_piece("B1", Piece.Type.B, Piece.Owner.RED, [Vector2i(6, 7), Vector2i(6, 8)], Piece.PieceOrientation.VERTICAL),
				_piece("A3", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(3, 5)]),
			]
		"general_immunity":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 8)]),
				_piece("General", Piece.Type.GENERAL, Piece.Owner.RED, [Vector2i(7, 8)]),
				_piece("B3", Piece.Type.B, Piece.Owner.RED, [Vector2i(10, 9), Vector2i(10, 10)], Piece.PieceOrientation.VERTICAL),
			]
		"saboteur":
			return [
				_piece("A7", Piece.Type.A, Piece.Owner.RED, [Vector2i(6, 8)]),
				_piece("General", Piece.Type.GENERAL, Piece.Owner.RED, [Vector2i(7, 8)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(3, 6), Vector2i(4, 6)], Piece.PieceOrientation.HORIZONTAL),
			]
		"close_call":
			return [
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 7)]),
				_piece("A1", Piece.Type.A, Piece.Owner.RED, [Vector2i(7, 7)], Piece.PieceOrientation.VERTICAL, "A1_RED"),
				_piece("C2", Piece.Type.C, Piece.Owner.RED, [Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 10), Vector2i(11, 10)]),
			]
		"c_blocked":
			return [
				_piece("C1", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(5, 7), Vector2i(6, 7), Vector2i(5, 8), Vector2i(6, 8)]),
				_piece("A1", Piece.Type.A, Piece.Owner.RED, [Vector2i(7, 7)]),
				_piece("B1", Piece.Type.B, Piece.Owner.RED, [Vector2i(7, 8), Vector2i(8, 8)], Piece.PieceOrientation.HORIZONTAL),
			]
		"edge_display":
			return [
				_piece("Objective", Piece.Type.OBJECTIVE, Piece.Owner.BLUE, [Vector2i(3, 5)]),
				_piece("A4", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 7)]),
				_piece("B2", Piece.Type.B, Piece.Owner.BLUE, [Vector2i(8, 7), Vector2i(9, 7)], Piece.PieceOrientation.HORIZONTAL),
				_piece("C2", Piece.Type.C, Piece.Owner.BLUE, [Vector2i(11, 6), Vector2i(12, 6), Vector2i(11, 7), Vector2i(12, 7)]),
				_piece("General", Piece.Type.GENERAL, Piece.Owner.RED, [Vector2i(13, 10)]),
			]
		"summary":
			return [
				_piece("Objective", Piece.Type.OBJECTIVE, Piece.Owner.BLUE, [Vector2i(2, 3)]),
				_piece("General", Piece.Type.GENERAL, Piece.Owner.BLUE, [Vector2i(4, 4)]),
				_piece("A1", Piece.Type.A, Piece.Owner.BLUE, [Vector2i(6, 5)]),
				_piece("B1", Piece.Type.B, Piece.Owner.RED, [Vector2i(11, 10), Vector2i(12, 10)], Piece.PieceOrientation.HORIZONTAL),
				_piece("C1", Piece.Type.C, Piece.Owner.RED, [Vector2i(14, 11), Vector2i(15, 11), Vector2i(14, 12), Vector2i(15, 12)]),
				_piece("Objective", Piece.Type.OBJECTIVE, Piece.Owner.RED, [Vector2i(16, 13)], Piece.PieceOrientation.VERTICAL, "Objective_RED"),
			]
		_:
			return []

static func _piece(
	designation: String,
	type: Piece.Type,
	owner: Piece.Owner,
	cells: Array,
	orientation: Piece.PieceOrientation = Piece.PieceOrientation.VERTICAL,
	key: String = ""
) -> Dictionary:
	return {
		"key": designation if key.is_empty() else key,
		"designation": designation,
		"type": type,
		"owner": owner,
		"cells": cells,
		"orientation": orientation,
	}
