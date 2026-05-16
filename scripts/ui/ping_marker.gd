extends Node2D
class_name PingMarker

## Phase 13.27 — Tab-to-ping world marker. Each Ping in Phase13Helpers.active_pings
## spawns one of these; the script draws a colored ring + label + fades over
## PING_DURATION_SECONDS.

const FADE_OUT_FRACTION: float = 0.2

@export var ping_kind: StringName = &"default"
@export var ping_color: Color = Color(0.85, 0.85, 1.0, 1.0)
@export var owner_peer: int = 1
@export var lifetime_seconds: float = 7.0

var _age: float = 0.0
var _label: Label
var _shape: ColorRect


func _ready() -> void:
	z_index = 50
	_shape = ColorRect.new()
	_shape.size = Vector2(12, 12)
	_shape.position = Vector2(-6, -6)
	_shape.color = ping_color
	add_child(_shape)
	_label = Label.new()
	_label.text = "!"
	_label.position = Vector2(-4, -22)
	add_child(_label)
	_apply_kind_visuals()


func _apply_kind_visuals() -> void:
	match String(ping_kind):
		"default":
			_label.text = "•"
			ping_color = Color(0.85, 0.85, 1.0, 1.0)
		"danger":
			_label.text = "!"
			ping_color = Color(0.95, 0.4, 0.3, 1.0)
		"attack_here":
			_label.text = "⚔"
			ping_color = Color(0.95, 0.7, 0.3, 1.0)
		"defend_here":
			_label.text = "🛡"
			ping_color = Color(0.4, 0.7, 0.95, 1.0)
		"on_my_way":
			_label.text = "→"
			ping_color = Color(0.7, 0.95, 0.4, 1.0)
	_shape.color = ping_color


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()
		return
	var fade_start: float = lifetime_seconds * (1.0 - FADE_OUT_FRACTION)
	if _age > fade_start:
		var alpha: float = clampf(1.0 - (_age - fade_start) / (lifetime_seconds - fade_start), 0.0, 1.0)
		modulate.a = alpha


static func spawn_at(parent: Node, world_pos: Vector2, kind: StringName, owner_peer_id: int, lifetime: float) -> PingMarker:
	var marker := PingMarker.new()
	marker.ping_kind = kind
	marker.owner_peer = owner_peer_id
	marker.lifetime_seconds = lifetime
	marker.global_position = world_pos
	parent.add_child(marker)
	return marker
