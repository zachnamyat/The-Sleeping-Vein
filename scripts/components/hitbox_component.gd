extends Area2D
class_name HitboxComponent

## Deals damage to overlapped HurtboxComponents. Place as a child of any attacker
## (player swing, projectile, enemy hitbox). Activate via `arm()` for a duration.
##
## Phase 6 additions:
##   - on_hit_status: applies a StatusEffects entry to victims with non-zero chance.
##   - is_heavy_this_swing: tagged by the attacker; routes to HealthComponent
##     stagger-meter accumulation.
##   - is_back_hit_this_swing: precomputed positional flag (player_combat sets when
##     attacking a mob's back) — bonus damage applied here so the floated number
##     reflects the real value.
##   - lifesteal_fraction / manasteel_fraction: caller sets per-swing; applied to
##     parent player on connect.

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
var is_heavy_this_swing: bool = false
var is_back_hit_this_swing: bool = false
@export var crit_bonus_fraction: float = 0.5  ## +50% damage on crit
@export var lifesteal_fraction: float = 0.0
@export var manasteel_fraction: float = 0.0
@export var on_hit_status: StringName = &""
@export var on_hit_status_chance: float = 0.0
@export var on_hit_status_duration: float = 0.0
## Phase 6.20 — lightning chain count. When > 0, a successful hit triggers a
## chain-arc to N nearest hurtboxes via EventBus.lightning_chain_requested.
@export var chain_count: int = 0
@export var chain_radius_pixels: float = 64.0
@export var chain_falloff: float = 0.5

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
			# Phase 6.35 — backstab bonus. +50% to mob's vulnerable side.
			if is_back_hit_this_swing:
				swing_damage = int(round(float(swing_damage) * 1.5))
			# Phase 6.38 — heavy attack carries a flag through to HealthComponent
			# so the stagger meter advances.
			var dealt: int = (area as HurtboxComponent).receive_hit_full(get_parent(), swing_damage, damage_type, team, is_heavy_this_swing)
			if dealt > 0:
				hit_landed.emit((area as HurtboxComponent).get_parent(), dealt)
				var victim := (area as HurtboxComponent).get_parent() as Node2D
				if victim:
					EventBus.damage_floated.emit(victim.global_position, dealt, crit, damage_type)
				_apply_on_hit_extras(victim, dealt)


func _apply_on_hit_extras(victim: Node2D, dealt: int) -> void:
	if victim == null:
		return
	# Phase 6 — status proc.
	if on_hit_status != &"" and on_hit_status_chance > 0.0:
		if randf() < on_hit_status_chance:
			var sef := victim.get_node_or_null("StatusEffects") as StatusEffects
			if sef:
				sef.apply(on_hit_status, on_hit_status_duration, get_parent())
	# Phase 6.28 — lifesteal/manasteal go to the player (parent).
	var owner_node: Node = get_parent()
	if owner_node and owner_node.is_in_group("player"):
		if lifesteal_fraction > 0.0:
			var heal_amt: int = int(round(float(dealt) * lifesteal_fraction))
			if heal_amt > 0:
				var hc := owner_node.get_node_or_null("HealthComponent") as HealthComponent
				if hc:
					hc.heal(heal_amt, owner_node)
		if manasteel_fraction > 0.0:
			var mana_amt: int = int(round(float(dealt) * manasteel_fraction))
			if mana_amt > 0:
				var mc := owner_node.get_node_or_null("ManaComponent") as ManaComponent
				if mc:
					mc.add_mana(mana_amt)
	# Phase 6.20 — lightning chain bounces to nearby hurtboxes.
	if chain_count > 0:
		_chain_lightning(victim, dealt)


func _chain_lightning(initial_victim: Node2D, base_dealt: int) -> void:
	var chained: Dictionary = { initial_victim: true }
	var current_victim: Node2D = initial_victim
	var current_damage: int = int(round(float(base_dealt) * chain_falloff))
	for i in range(chain_count):
		if current_damage <= 0:
			return
		# Find nearest hurtbox to current_victim, not in chained.
		var best: Node2D = null
		var best_d: float = chain_radius_pixels
		for area in get_tree().get_nodes_in_group("hurtbox_chain"):
			var hb := area as HurtboxComponent
			if hb == null:
				continue
			var hb_owner := hb.get_parent() as Node2D
			if hb_owner == null or chained.has(hb_owner) or hb_owner == get_parent():
				continue
			if hb.team == team:
				continue
			var d: float = hb_owner.global_position.distance_to(current_victim.global_position)
			if d < best_d:
				best_d = d
				best = hb_owner
		if best == null:
			return
		var hbox := best.get_node_or_null("Hurtbox") as HurtboxComponent
		if hbox:
			var dealt2: int = hbox.receive_hit_full(get_parent(), current_damage, DamageType.LIGHTNING, team, false)
			if dealt2 > 0:
				EventBus.damage_floated.emit(best.global_position, dealt2, false, DamageType.LIGHTNING)
				EventBus.lightning_arc_requested.emit(current_victim.global_position, best.global_position)
		chained[best] = true
		current_victim = best
		current_damage = int(round(float(current_damage) * chain_falloff))
