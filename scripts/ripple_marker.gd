extends Node2D
class_name RippleMarker
# Faint pond ripples radiating from a board point, shown to the player about to
# act. Purely cosmetic: it draws and dies, and touches no game state.
#
# Two presets: the default (the last piece moved) and make_raindrop() (a smaller,
# briefer splash used to mark where a capture happened).
#
# Lifetime: waits out start_delay, emits rings on an interval, then fades out on
# its own. Can be dismissed early by the controller when the player clicks.

const RING_INTERVAL := 0.85   # seconds between new rings
const RING_LIFE := 2.4        # seconds for one ring to expand and vanish
const RING_MAX_R := 190.0     # how far a ring travels
const RING_MIN_R := 18.0      # where a ring starts
const TOTAL_LIFE := 9.0       # emit for this long, then fade out
const FADE_OUT := 1.6

# Per-instance overrides, defaulted from the constants above.
var ring_interval: float = RING_INTERVAL
var ring_life: float = RING_LIFE
var ring_max_r: float = RING_MAX_R
var ring_min_r: float = RING_MIN_R
var total_life: float = TOTAL_LIFE
var alpha_scale: float = 0.30   # overall faintness — raise for a stronger effect
var start_delay: float = 0.0    # wait before the first ring, for staggering

var color: Color = Color("#141414")

var _rings: Array = []        # each: elapsed seconds
var _since_ring: float = 0.0
var _age: float = 0.0
var _delay_left: float = 0.0
var _dying: bool = false

func _ready() -> void:
	z_index = 2               # above the board, below the pieces (z 5)
	_delay_left = start_delay
	if _delay_left <= 0.0:
		_rings.append(0.0)    # first ring immediately

# A smaller, quicker splash for marking a capture square.
func make_raindrop() -> void:
	ring_interval = 0.5
	ring_life = 1.4
	ring_max_r = 84.0
	ring_min_r = 6.0
	total_life = 1.9
	alpha_scale = 0.42

func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			_rings.append(0.0)
		return

	_age += delta

	if not _dying:
		_since_ring += delta
		if _since_ring >= ring_interval:
			_since_ring = 0.0
			_rings.append(0.0)
		if _age >= total_life:
			dismiss()

	for i in range(_rings.size()):
		_rings[i] += delta
	# Drop rings that have finished expanding.
	var kept: Array = []
	for t in _rings:
		if t < ring_life:
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
		var f: float = clamp(t / ring_life, 0.0, 1.0)
		# Ease outward so it slows as it spreads, like a real ripple.
		var eased: float = 1.0 - pow(1.0 - f, 2.2)
		var r: float = ring_min_r + (ring_max_r - ring_min_r) * eased
		# Fade in fast, out slow.
		var a: float = 0.0
		if f < 0.12:
			a = f / 0.12
		else:
			a = 1.0 - ((f - 0.12) / 0.88)
		a *= alpha_scale
		if a <= 0.0:
			continue
		var c := color
		c.a = a
		var w: float = 3.0 * (1.0 - f * 0.55)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, w, true)
