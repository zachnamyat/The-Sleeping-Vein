extends Area2D
class_name HurtboxComponent

## Receives damage from HitboxComponent overlaps and forwards to a HealthComponent.
## Place as a child of the entity. Connect a CollisionShape2D inside it.

@export var health_component: HealthComponent
@export var team: StringName = &"neutral"
@export var i_frames_seconds: float = 0.2

var _hit_log: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)


func receive_hit(source: Node, base_damage: int, type: StringName, src_team: StringName) -> int:
	if src_team == team:
		return 0
	if health_component == null:
		return 0
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var last: float = _hit_log.get(source, -10.0)
	if now - last < i_frames_seconds:
		return 0
	_hit_log[source] = now
	var dealt: int = health_component.apply_damage(base_damage, source, type)
	EventBus.damage_dealt.emit(source, get_parent(), dealt, type)
	return dealt
