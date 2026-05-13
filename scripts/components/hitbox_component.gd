extends Area2D
class_name HitboxComponent

## Deals damage to overlapped HurtboxComponents. Place as a child of any attacker
## (player swing, projectile, enemy hitbox). Activate via `arm()` for a duration.

signal hit_landed(victim: Node, dealt: int)

@export var base_damage: int = 10
@export var damage_type: StringName = DamageType.PHYSICAL
@export var team: StringName = &"neutral"
@export var lifetime: float = 0.0

var _active: bool = false
var _timer: float = 0.0
var _already_hit: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)
	monitoring = false


func arm(active_seconds: float = -1.0) -> void:
	_active = true
	_timer = active_seconds if active_seconds > 0.0 else lifetime
	_already_hit.clear()
	monitoring = true


func disarm() -> void:
	_active = false
	monitoring = false


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			disarm()
			return
	for area in get_overlapping_areas():
		if area is HurtboxComponent and not _already_hit.has(area):
			_already_hit[area] = true
			var dealt: int = (area as HurtboxComponent).receive_hit(get_parent(), base_damage, damage_type, team)
			if dealt > 0:
				hit_landed.emit((area as HurtboxComponent).get_parent(), dealt)
