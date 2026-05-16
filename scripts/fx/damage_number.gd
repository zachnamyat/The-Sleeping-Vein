extends Node2D
class_name DamageNumber

## Phase 2.20 / 2.29 — floating-text VFX that pops out of a damaged entity and
## drifts upward while fading. Crit hits render larger in the warm-gold ramp,
## normal hits in plain white. Spawned by DamageNumberSpawner in response to
## EventBus.damage_floated.

const LIFETIME: float = 0.75
const RISE_PIXELS: float = 18.0

var amount: int = 0
var is_crit: bool = false
var _t: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _drift_x: float = 0.0


func _ready() -> void:
	z_index = 20
	_start_pos = position
	# Small horizontal drift so stacked hits don't all overlap at the same xy.
	_drift_x = randf_range(-6.0, 6.0)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	var p: float = clampf(_t / LIFETIME, 0.0, 1.0)
	position = _start_pos + Vector2(_drift_x * p, -RISE_PIXELS * p)
	queue_redraw()


func _draw() -> void:
	var p: float = clampf(_t / LIFETIME, 0.0, 1.0)
	var alpha: float = 1.0 - p
	var text: String = str(amount)
	var color: Color
	var scale_factor: float = 1.0
	if is_crit:
		color = Color(1.0, 0.85, 0.35, alpha)  # warm gold
		scale_factor = 1.3
	else:
		color = Color(1.0, 1.0, 1.0, alpha)
	# Use m5x7 at its 16-px design size so damage numbers render with crisp
	# pixel alignment. Crit numbers bump 1.3× to 21 px.
	var font: Font = load("res://assets/fonts/m5x7.ttf") as Font
	if font == null:
		font = ThemeDB.fallback_font
	var font_size: int = int(round(16.0 * scale_factor))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := Vector2(-width * 0.5, 0)
	# Outline for readability against busy biome tiles.
	for offset in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		font.draw_string(get_canvas_item(), origin + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.7))
	font.draw_string(get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
