extends Node2D
class_name RippleMarker
# Faint pond ripples radiating from the last piece moved, shown to the player
# about to act. Purely cosmetic: it draws and dies, and touches no game state.
#
# Lifetime: emits rings on an interval, then fades out on its own. Can be
# dismissed early by the controller when the player clicks anything.

const RING_INTERVAL := 0.85   # seconds between new rings
const RING_LIFE := 2.4        # seconds for one ring to expand and vanish
const RING_MAX_R := 190.0     # how far a ring travels
const RING_MIN_R := 18.0      # where a ring starts
const TOTAL_LIFE := 9.0       # emit for this long, then fade out
const FADE_OUT := 1.6

var color: Color = Color("#141414")

var _rings: Array = []        # each: elapsed seconds
var _since_ring: float = 0.0
var _age: float = 0.0
var _dying: bool = false

func _ready() -> void:
	z_index = 2               # above the board, below the pieces (z 5)
	_rings.append(0.0)        # first ring immediately

func _process(delta: float) -> void:
	_age += delta

	if not _dying:
		_since_ring += delta
		if _since_ring >= RING_INTERVAL:
			_since_ring = 0.0
			_rings.append(0.0)
		if _age >= TOTAL_LIFE:
			dismiss()

	for i in range(_rings.size()):
		_rings[i] += delta
	# Drop rings that have finished expanding.
	var kept: Array = []
	for t in _rings:
		if t < RING_LIFE:
			kept.append(t)
	_rings = kept

	queue_redraw()

func dismiss() -> void:
	if _dying:
		return
	_dying = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)

func _draw() -> void:
	for t in _rings:
		var f: float = clamp(t / RING_LIFE, 0.0, 1.0)
		# Ease outward so it slows as it spreads, like a real ripple.
		var eased: float = 1.0 - pow(1.0 - f, 2.2)
		var r: float = RING_MIN_R + (RING_MAX_R - RING_MIN_R) * eased
		# Fade in fast, out slow.
		var a: float = 0.0
		if f < 0.12:
			a = f / 0.12
		else:
			a = 1.0 - ((f - 0.12) / 0.88)
		a *= 0.30    # overall faintness — raise for a stronger effect
		if a <= 0.0:
			continue
		var c := color
		c.a = a
		var w: float = 3.0 * (1.0 - f * 0.55)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, w, true)
