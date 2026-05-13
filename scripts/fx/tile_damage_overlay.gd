extends Node2D
class_name TileDamageOverlay

## Phase 2.23 — visible-cracks overlay drawn on a TileMapLayer cell whose HP
## has been reduced. Each fresh hit shakes the overlay and increases the
## crack density. MiningSystem creates/updates these per cell; the overlay
## self-frees when the cell breaks (hp<=0) or heals back to full.

const SHAKE_SECONDS: float = 0.12
const SHAKE_PIXELS: float = 1.5

var damage_ratio: float = 0.0  ## 0 = full HP (no cracks), 1 = about-to-break
var _rng := RandomNumberGenerator.new()
var _shake_remaining: float = 0.0
var _base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rng.randomize()
	_base_position = position
	z_index = 5


func _process(delta: float) -> void:
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - delta)
		var jitter := Vector2(randf_range(-SHAKE_PIXELS, SHAKE_PIXELS), randf_range(-SHAKE_PIXELS, SHAKE_PIXELS))
		var damping: float = _shake_remaining / SHAKE_SECONDS
		position = _base_position + jitter * damping
		if _shake_remaining <= 0.0:
			position = _base_position
		queue_redraw()


func bump(new_ratio: float) -> void:
	damage_ratio = clampf(new_ratio, 0.0, 1.0)
	_shake_remaining = SHAKE_SECONDS
	queue_redraw()


func _draw() -> void:
	# Number of cracks scales with damage_ratio. At ratio < 0.25 we draw nothing
	# so the player only sees cracks after they've actually started chipping.
	if damage_ratio < 0.2:
		return
	var crack_count: int = clampi(int(round(damage_ratio * 5.0)), 1, 5)
	var alpha: float = 0.55 + 0.35 * damage_ratio
	var color := Color(0.05, 0.04, 0.04, alpha)
	_rng.seed = hash(int(damage_ratio * 1000.0))
	for i in range(crack_count):
		var a: float = _rng.randf_range(0.0, TAU)
		var len: float = _rng.randf_range(3.0, 6.0)
		var origin := Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
		var tip := origin + Vector2(cos(a), sin(a)) * len
		draw_line(origin, tip, color, 1.0)
