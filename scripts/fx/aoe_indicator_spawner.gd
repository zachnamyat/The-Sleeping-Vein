extends Node
class_name AoeIndicatorSpawner

## Phase 2.30 / 6.48 — listens to EventBus.aoe_indicator_requested and spawns
## an AoeIndicator at the requested world position. Lives as a child of the
## main world scene; despawned automatically with the scene.

@export var spawn_parent_path: NodePath = NodePath("..")


func _ready() -> void:
	EventBus.aoe_indicator_requested.connect(_on_aoe_requested)
	EventBus.lightning_arc_requested.connect(_on_lightning_arc)


func _on_aoe_requested(world_pos: Vector2, radius: float, duration: float, color: Color) -> void:
	var parent := get_node_or_null(spawn_parent_path)
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var node := AoeIndicator.new()
	node.radius = radius
	node.duration = duration
	node.color = color
	node.global_position = world_pos
	parent.add_child(node)


func _on_lightning_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent := get_node_or_null(spawn_parent_path)
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var arc := LightningArc.new()
	arc.from_pos = from_pos
	arc.to_pos = to_pos
	parent.add_child(arc)


class LightningArc extends Node2D:
	var from_pos: Vector2 = Vector2.ZERO
	var to_pos: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	const LIFETIME: float = 0.22

	func _ready() -> void:
		z_index = 30
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFETIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p: float = clampf(_t / LIFETIME, 0.0, 1.0)
		var alpha: float = 1.0 - p
		# Phase 6.54 — jagged polyline for the chain-arc visual.
		var segments: int = 6
		var pts := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(from_pos.x) * 91 + int(to_pos.y) * 33
		for i in range(segments + 1):
			var f: float = float(i) / float(segments)
			var base: Vector2 = lerp(from_pos, to_pos, f)
			var perp: Vector2 = (to_pos - from_pos).normalized().rotated(PI * 0.5)
			var jitter: float = rng.randf_range(-3.0, 3.0) if i > 0 and i < segments else 0.0
			pts.append(to_local(base + perp * jitter))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(0.85, 0.95, 1.0, alpha), 2.0)
			draw_line(pts[i], pts[i + 1], Color(0.55, 0.7, 1.0, alpha * 0.5), 4.0)
