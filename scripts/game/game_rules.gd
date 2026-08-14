extends Resource
class_name GameRules

# Close Call! shields C from ALL simultaneous mutuals in one move (base rule)
# false: only converts the first mutual; subsequent mutuals still apply (house rule)
var close_call_shields_all_simultaneous_mutuals: bool = true

# Each piece overlapped by C resolves its own card draw independently (base rule)
# false: only the primary target resolves a draw
var c_captures_resolve_independently: bool = true

# General captures A/B/C freely (base rule)
# false: General follows normal cycle restrictions
var general_can_capture_cycle_pieces: bool = true

# Both players draw on mutual destruction (base rule)
# false: neither draws
var mutual_destruction_both_draw: bool = true

# The Blitzkrieg bonus move may be used on the same piece that already moved
# this turn (base rule)
# false: the bonus move must go to a DIFFERENT piece
var blitzkrieg_old_different_piece: bool = true

# A card may be deployed alone to end a turn - "deploy and pass" (base rule)
# false: at least one piece must move before End Turn is allowed
var require_move_to_end_turn: bool = true

# Any piece may capture the enemy Objective (base rule)
# false: only a Saboteur-status piece may capture the Objective
var objective_saboteurs_only: bool = true
