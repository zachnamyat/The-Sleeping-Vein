extends Area2D
class_name HurtboxComponent

## Receives damage from HitboxComponent overlaps and forwards to a HealthComponent.
## Place as a child of the entity. Connect a CollisionShape2D inside it.
##
## Phase 6 additions:
##   - receive_hit_full carries the heavy-attack flag for stagger.
##   - block_fraction is consulted before damage application (shield off-hand).
##   - thorns_damage reflects back to attackers (player ring/cloak).
##   - shock chain hooks routed via group "hurtbox_chain" so HitboxComponent
##     can find peers efficiently.

@export var health_component: HealthComponent
@export var team: StringName = &"neutral"
@export var i_frames_seconds: float = 0.2
@export var knockback_resistance: float = 0.0  ## 0..1; bosses set high
@export var knockback_base: float = 80.0       ## px/s impulse before damage scaling
@export var block_fraction: float = 0.0        ## set by player_combat while RMB holds shield
@export var thorns_damage: int = 0             ## set by PlayerStats per equipment refresh

var _hit_log: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	add_to_group("hurtbox_chain")


## Phase 6 — superseding signature; preserved old `receive_hit` for backwards
## compatibility with any external callers (none in-tree currently).
func receive_hit(source: Node, base_damage: int, type: StringName, src_team: StringName) -> int:
	return receive_hit_full(source, base_damage, type, src_team, false)


func receive_hit_full(source: Node, base_damage: int, type: StringName, src_team: StringName, is_heavy: bool) -> int:
	if src_team == team:
		return 0
	if health_component == null:
		return 0
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	# Phase 6.23 — dodge roll i-frames. PlayerCombat tags the player hurtbox via
	# meta `dodge_iframes_until` (absolute seconds) on roll start.
	if has_meta("dodge_iframes_until") and now < float(get_meta("dodge_iframes_until")):
		return 0
	var last: float = _hit_log.get(source, -10.0)
	if now - last < i_frames_seconds:
		return 0
	_hit_log[source] = now
	# Phase 6.14 — block. Active block fraction subtracts before HealthComponent.
	var amt: int = base_damage
	if block_fraction > 0.0:
		amt = int(round(float(amt) * (1.0 - clampf(block_fraction, 0.0, 0.95))))
	var dealt: int = health_component.apply_damage(amt, source, type, is_heavy)
	_apply_knockback(source, dealt)
	EventBus.damage_dealt.emit(source, get_parent(), dealt, type)
	# Phase 6.29 — reflect a flat amount back to the attacker if they have a hurtbox.
	if thorns_damage > 0 and dealt > 0 and source != null:
		var attacker_hb := source.get_node_or_null("Hurtbox") as HurtboxComponent
		if attacker_hb and attacker_hb.team != team:
			attacker_hb.receive_hit_full(get_parent(), thorns_damage, DamageType.PHYSICAL, team, false)
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
