extends Node2D
class_name SwingArc

## Transient visual for the player's melee swing. Spawned by PlayerCombat on each
## attack so the player gets feedback even when the swing connects with empty air.
## Fades out and self-frees after LIFETIME seconds.

const ARC_RADIUS: float = 14.0
const ARC_HALF_ANGLE: float = PI * 0.45   ## ~81-degree total arc
const ARC_SEGMENTS: int = 14
const LIFETIME: float = 0.18

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha: float = clampf(1.0 - (_t / LIFETIME), 0.0, 1.0)
	var col := Color(1.0, 0.95, 0.7, alpha * 0.9)
	var pts := PackedVector2Array()
	for i in range(ARC_SEGMENTS + 1):
		var a: float = -ARC_HALF_ANGLE + 2.0 * ARC_HALF_ANGLE * (float(i) / float(ARC_SEGMENTS))
		pts.append(Vector2(cos(a), sin(a)) * ARC_RADIUS)
	draw_polyline(pts, col, 1.5, true)
