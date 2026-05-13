extends Area2D
class_name HitboxComponent

## Deals damage to overlapped HurtboxComponents. Place as a child of any attacker
## (player swing, projectile, enemy hitbox). Activate via `arm()` for a duration.

signal hit_landed(victim: Node, dealt: int)

@export var base_damage: int = 10
@export var damage_type: StringName = DamageType.PHYSICAL
@export var team: StringName = &"neutral"
@export var lifetime: float = 0.0
## When > 0, the `_already_hit` ledger is cleared at this cadence so a
## permanently-armed hitbox (e.g. enemy contact damage) keeps applying damage
## to the same victim. Per-victim i-frames still gate via HurtboxComponent.
@export var repeat_interval: float = 0.0
## Ticket 2.29 — set per-swing by the attacker (player_combat). When true, the
## resulting damage gets the crit bonus and the floated-number VFX uses the
## crit colour ramp.
var is_crit_this_swing: bool = false
@export var crit_bonus_fraction: float = 0.5  ## +50% damage on crit

var _active: bool = false
var _timer: float = 0.0
var _repeat_accum: float = 0.0
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
	if repeat_interval > 0.0:
		_repeat_accum += delta
		if _repeat_accum >= repeat_interval:
			_repeat_accum = 0.0
			_already_hit.clear()
	for area in get_overlapping_areas():
		if area is HurtboxComponent and not _already_hit.has(area):
			_already_hit[area] = true
			var crit: bool = is_crit_this_swing
			var swing_damage: int = base_damage
			if crit:
				swing_damage = int(round(float(base_damage) * (1.0 + crit_bonus_fraction)))
			var dealt: int = (area as HurtboxComponent).receive_hit(get_parent(), swing_damage, damage_type, team)
			if dealt > 0:
				hit_landed.emit((area as HurtboxComponent).get_parent(), dealt)
				var victim := (area as HurtboxComponent).get_parent() as Node2D
				if victim:
					EventBus.damage_floated.emit(victim.global_position, dealt, crit, damage_type)
