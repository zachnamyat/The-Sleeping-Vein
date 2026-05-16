extends Node2D
class_name StatusOverlay

## Phase 6.50–6.54 — character-level status visuals.
## Spawned automatically by StatusOverlaySpawner whenever a player or mob has a
## StatusEffects child. Listens for `effect_applied` / `effect_expired` and
## renders the matching aesthetic:
##   burn      — orange flame jitter (6.50)
##   poison    — green bubble specks (6.50)
##   cold      — frost-blue flecks (6.50)
##   freeze    — full ice cube tint (6.52)
##   bleed     — red drip particles (6.53)
##   confusion — drifting question marks above head (6.51)
##   stun      — yellow swirling stars
##
## Drawn procedurally so we don't depend on per-effect sprite assets at this stage.

@export var status_path: NodePath
var _status: StatusEffects
var _t: float = 0.0


func _ready() -> void:
	z_index = 8
	_status = get_node_or_null(status_path) as StatusEffects
	if _status == null and get_parent():
		_status = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _status == null:
		return
	queue_redraw()


func _draw() -> void:
	if _status == null:
		return
	# Base offset above feet.
	var head: Vector2 = Vector2(0, -22)
	if _status.has_effect(&"burn"):
		_draw_burn(head)
	if _status.has_effect(&"poison"):
		_draw_poison(head)
	if _status.has_effect(&"cold"):
		_draw_cold(head)
	if _status.has_effect(&"freeze"):
		_draw_freeze(head)
	if _status.has_effect(&"bleed"):
		_draw_bleed(head)
	if _status.has_effect(&"confusion"):
		_draw_confusion(head)
	if _status.has_effect(&"stun"):
		_draw_stun(head)


func _draw_burn(head: Vector2) -> void:
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + _t * 4.0
		var p: Vector2 = head + Vector2(cos(a) * 4.0, sin(a) * 2.0 - sin(_t * 6.0 + i) * 3.0)
		draw_circle(p, 1.6, Color(1.0, 0.55, 0.18, 0.85))


func _draw_poison(head: Vector2) -> void:
	for i in range(3):
		var off_y: float = -((_t * 18.0 + i * 6.0) - floor((_t * 18.0 + i * 6.0) / 14.0) * 14.0)
		var p: Vector2 = head + Vector2(((i - 1) * 4), off_y)
		draw_circle(p, 1.4, Color(0.55, 0.95, 0.35, 0.85))


func _draw_cold(head: Vector2) -> void:
	for i in range(3):
		var a: float = _t * 2.0 + i
		var p: Vector2 = head + Vector2(sin(a) * 5.0, cos(a) * 3.0)
		draw_circle(p, 1.0, Color(0.55, 0.85, 1.0, 0.8))


func _draw_freeze(head: Vector2) -> void:
	# Phase 6.52 — translucent ice cube around the entity.
	var rect := Rect2(-7, head.y - 3, 14, 22)
	draw_rect(rect, Color(0.6, 0.85, 1.0, 0.30), true)
	draw_rect(rect, Color(0.7, 0.95, 1.0, 0.65), false, 1.0)


func _draw_bleed(head: Vector2) -> void:
	# Phase 6.53 — drips fall from torso to feet.
	for i in range(3):
		var t_off: float = fmod(_t * 1.8 + i * 0.5, 1.0)
		var p: Vector2 = Vector2((i - 1) * 3.0, lerp(head.y + 6.0, head.y + 18.0, t_off))
		draw_circle(p, 1.2, Color(0.85, 0.18, 0.22, 1.0 - t_off))


func _draw_confusion(head: Vector2) -> void:
	# Phase 6.51 — small "?" glyphs orbit above head.
	var fnt: Font = load("res://assets/fonts/m5x7.ttf") as Font
	if fnt == null:
		fnt = ThemeDB.fallback_font
	for i in range(3):
		var a: float = TAU * float(i) / 3.0 + _t * 1.5
		var p: Vector2 = head + Vector2(cos(a) * 6.0, -3.0 + sin(a) * 2.0)
		fnt.draw_string(get_canvas_item(), p, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.45, 0.9))


func _draw_stun(head: Vector2) -> void:
	# Phase 6.51 — gold stars circling overhead.
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + _t * 3.0
		var p: Vector2 = head + Vector2(cos(a) * 7.0, sin(a) * 2.5 - 3.0)
		draw_circle(p, 1.4, Color(1.0, 0.92, 0.45, 0.95))
