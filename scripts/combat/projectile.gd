extends Area2D
class_name Projectile

## Generic projectile (arrow, bullet, staff bolt). Travels in `direction`, deals
## damage on hit, may apply a status effect via `on_hit_status`.
##
## Phase 6 additions:
##   - is_crit_this_swing flag carries crit through to the floated number.
##   - chain_count + chain_radius_pixels for lightning bolts.
##   - lifesteal/manasteel hooks applied when source is the player.
##   - homing flag for the boomerang.

@export var speed: float = 240.0
@export var lifetime: float = 1.2
@export var base_damage: int = 5
@export var damage_type: StringName = &"physical"
@export var team: StringName = &"player"
@export var pierce_count: int = 0
@export var on_hit_status: StringName = &""
@export var status_duration: float = 0.0
@export var status_chance: float = 1.0
@export var crit_bonus_fraction: float = 0.5
@export var lifesteal_fraction: float = 0.0
@export var manasteel_fraction: float = 0.0
@export var chain_count: int = 0
@export var chain_radius_pixels: float = 64.0
## Phase 6.25 — boomerang behaviour: travel out, then home back to source.
@export var homing: bool = false
@export var homing_after_seconds: float = 0.4
## Phase 6.44 — when a shield blocks while RMB held, projectile may be reflected
## to its source. ProjectileReflectionPolicy is implemented at the player layer;
## this flag is set when a projectile spawned for reflection.
var is_reflected: bool = false
var is_crit_this_swing: bool = false
var owner_node: Node = null

var direction: Vector2 = Vector2.RIGHT
var _alive_time: float = 0.0
var _hits: int = 0
var _homing: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 | 1  # hurtboxes + walls
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# Phase 6.25 — switch to homing after the outbound travel time elapses.
	if homing and not _homing and _alive_time >= homing_after_seconds:
		_homing = true
	if _homing and owner_node and is_instance_valid(owner_node) and owner_node is Node2D:
		var to_owner: Vector2 = ((owner_node as Node2D).global_position - global_position)
		direction = to_owner.normalized()
		# Auto-pickup when close enough so the boomerang vanishes back into the player.
		if to_owner.length() < 8.0:
			queue_free()
			return
	global_position += direction * speed * delta
	_alive_time += delta
	if _alive_time >= lifetime and not _homing:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if _homing:
		# Allow boomerang to fly back through walls; stop on victim only.
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt == null:
		return
	# Don't hit the same parent twice on outbound + return for boomerang.
	if hurt.team == team:
		return
	var swing_damage: int = base_damage
	if is_crit_this_swing:
		swing_damage = int(round(float(base_damage) * (1.0 + crit_bonus_fraction)))
	var dealt: int = hurt.receive_hit_full(self, swing_damage, damage_type, team, false)
	if dealt > 0:
		var victim := hurt.get_parent() as Node2D
		if victim:
			EventBus.damage_floated.emit(victim.global_position, dealt, is_crit_this_swing, damage_type)
		_apply_on_hit(hurt, dealt)
	_hits += 1
	if _hits > pierce_count:
		# Boomerangs return; everything else dies on full pierce.
		if not homing:
			queue_free()


func _apply_on_hit(hurt: HurtboxComponent, dealt: int) -> void:
	if on_hit_status != &"" and randf() < status_chance:
		var sef := hurt.get_parent().get_node_or_null("StatusEffects") as StatusEffects
		if sef:
			sef.apply(on_hit_status, status_duration, owner_node)
	# Player-owned projectiles route lifesteal / manasteel to the player.
	if owner_node and owner_node.is_in_group("player"):
		if lifesteal_fraction > 0.0:
			var hc := owner_node.get_node_or_null("HealthComponent") as HealthComponent
			if hc:
				hc.heal(int(round(float(dealt) * lifesteal_fraction)), owner_node)
		if manasteel_fraction > 0.0:
			var mc := owner_node.get_node_or_null("ManaComponent") as ManaComponent
			if mc:
				mc.add_mana(int(round(float(dealt) * manasteel_fraction)))
	# Lightning chain hops.
	if chain_count > 0:
		_chain_lightning(hurt.get_parent() as Node2D, dealt)


func _chain_lightning(initial_victim: Node2D, base_dealt: int) -> void:
	if initial_victim == null:
		return
	var chained: Dictionary = { initial_victim: true }
	var current: Node2D = initial_victim
	var dmg: int = int(round(float(base_dealt) * 0.6))
	for i in range(chain_count):
		if dmg <= 0:
			return
		var best: Node2D = null
		var best_d: float = chain_radius_pixels
		for n in get_tree().get_nodes_in_group("hurtbox_chain"):
			var hb := n as HurtboxComponent
			if hb == null:
				continue
			var owner2 := hb.get_parent() as Node2D
			if owner2 == null or chained.has(owner2):
				continue
			if hb.team == team:
				continue
			var d: float = owner2.global_position.distance_to(current.global_position)
			if d < best_d:
				best_d = d
				best = owner2
		if best == null:
			return
		var hbox := best.get_node_or_null("Hurtbox") as HurtboxComponent
		if hbox:
			var dealt2: int = hbox.receive_hit_full(self, dmg, DamageType.LIGHTNING, team, false)
			if dealt2 > 0:
				EventBus.damage_floated.emit(best.global_position, dealt2, false, DamageType.LIGHTNING)
				EventBus.lightning_arc_requested.emit(current.global_position, best.global_position)
		chained[best] = true
		current = best
		dmg = int(round(float(dmg) * 0.6))
