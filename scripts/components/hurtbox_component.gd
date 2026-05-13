extends Area2D
class_name HurtboxComponent

## Receives damage from HitboxComponent overlaps and forwards to a HealthComponent.
## Place as a child of the entity. Connect a CollisionShape2D inside it.

@export var health_component: HealthComponent
@export var team: StringName = &"neutral"
@export var i_frames_seconds: float = 0.2
@export var knockback_resistance: float = 0.0  ## 0..1; bosses set high
@export var knockback_base: float = 80.0       ## px/s impulse before damage scaling

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
	_apply_knockback(source, dealt)
	EventBus.damage_dealt.emit(source, get_parent(), dealt, type)
	return dealt


func _apply_knockback(source: Node, dealt: int) -> void:
	if dealt <= 0 or source == null:
		return
	if knockback_resistance >= 1.0:
		return
	var victim := get_parent()
	if victim == null or not (victim is Node2D):
		return
	var src2d := source as Node2D
	if src2d == null:
		return
	var dir: Vector2 = (victim as Node2D).global_position - src2d.global_position
	if dir.length_squared() < 0.001:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var strength: float = (knockback_base + float(dealt) * 4.0) * (1.0 - knockback_resistance)
	var impulse: Vector2 = dir * strength
	if victim is CharacterBody2D:
		(victim as CharacterBody2D).velocity = impulse
	elif victim.has_method("apply_knockback"):
		victim.call("apply_knockback", impulse)
