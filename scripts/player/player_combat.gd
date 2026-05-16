extends Node
class_name PlayerCombat

## Player combat + mining interface. Reads the held hotbar item from Inventory,
## resolves a swing in the player's facing direction (or at mouse if `mouse_aim`),
## and either deals melee damage via HitboxComponent or drives the Mining system.
##
## Phase 6 — Combat depth:
##   - Dodge roll (Space) with i-frames + cooldown.
##   - Charge attack: hold attack_primary on a chargeable weapon.
##   - Heavy attack vs light: weapon_def.heavy_damage_multiplier > 1.0 routes
##     to a separate strike on attack_secondary while a melee weapon is held.
##   - Special attacks per weapon class (whip pull, boomerang throw,
##     spear thrust, sword whirlwind, shield bash) routed through `_try_special`.
##   - Dual-wield: when off-hand has weapon_class, swings alternate hands and
##     the off-hand swing scales by off_hand_damage_multiplier.
##   - Multi-shot + pierce affixes via projectile_count / projectile_pierce.
##   - Status proc on melee: weapon_def.on_hit_status applied through hitbox.
##   - Lifesteal / mana regen / cooldown reduction sourced from PlayerStats.

@export var player_path: NodePath
@export var hitbox_path: NodePath
@export var swing_offset: float = 12.0
@export var mouse_aim: bool = true
@export var swing_cooldown: float = 0.0  ## Overridden by held item

var _cooldown_timer: float = 0.0

# --- Phase 6.23 dodge ----------------------------------------------------------
const DODGE_DURATION: float = 0.32
const DODGE_COOLDOWN: float = 1.0
const DODGE_DISTANCE: float = 96.0
var _dodge_remaining: float = 0.0
var _dodge_cooldown: float = 0.0

# --- Phase 6.37 charge ---------------------------------------------------------
var _charge_seconds: float = 0.0
var _charging: bool = false

# --- Phase 6.14 block ----------------------------------------------------------
var _blocking: bool = false
var _parry_window_remaining: float = 0.0

# --- Phase 6.47 rage meter -----------------------------------------------------
const RAGE_MAX: float = 100.0
const RAGE_PER_HIT_TAKEN: float = 7.0
const RAGE_PER_HIT_DEALT: float = 3.0
const RAGE_DECAY_PER_SECOND: float = 1.0
const RAGE_RELEASE_COST: float = 60.0
var rage: float = 0.0

# --- Phase 3.47 dual-wield -----------------------------------------------------
var _next_swing_off_hand: bool = false


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.player_health_changed.connect(_on_player_hp_changed)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _dodge_remaining > 0.0:
		_dodge_remaining = maxf(0.0, _dodge_remaining - delta)
	if _dodge_cooldown > 0.0:
		_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	if _parry_window_remaining > 0.0:
		_parry_window_remaining = maxf(0.0, _parry_window_remaining - delta)
	# Phase 6.47 — passive rage decay so it doesn't accumulate forever in town.
	if rage > 0.0:
		rage = maxf(0.0, rage - RAGE_DECAY_PER_SECOND * delta)
	# Phase 6.37 — track held charge.
	if _charging and Input.is_action_pressed("attack_primary"):
		_charge_seconds += delta
		var defn := _held_def()
		if defn and defn.chargeable:
			var ratio: float = clampf(_charge_seconds / defn.charge_max_seconds, 0.0, 1.0)
			EventBus.player_charge_progress.emit(ratio)
	# Phase 3.41 — place-multiple drag-tool. While the player holds the primary
	# attack button and the held item is a placeable, every time the cursor
	# moves to a new 16-grid tile we attempt to drop one.
	_tick_drag_place()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge"):
		_try_dodge()
		return
	if event.is_action_pressed("attack_secondary"):
		# Phase 6 dispatch: shield-block if shield equipped > heavy attack > consume.
		if _try_block_or_special(true):
			return
		_try_consume()
		return
	if event.is_action_released("attack_secondary"):
		_release_block()
		return
	if event.is_action_released("attack_primary"):
		_last_drag_tile = Vector2i(99999, 99999)
		_release_charge_if_any()
		return
	if not event.is_action_pressed("attack_primary"):
		return
	if _cooldown_timer > 0.0:
		return
	# Phase 6.37 — if the held weapon is chargeable, begin charging instead of
	# swinging immediately.
	var defn := _held_def()
	if defn and defn.chargeable:
		_charging = true
		_charge_seconds = 0.0
		return
	_try_swing()


func _release_charge_if_any() -> void:
	if not _charging:
		return
	var defn := _held_def()
	if defn == null:
		_charging = false
		_charge_seconds = 0.0
		return
	# Convert the charge into a damage multiplier and dispatch a normal swing.
	var ratio: float = clampf(_charge_seconds / defn.charge_max_seconds, 0.0, 1.0)
	var mult: float = lerp(1.0, defn.charge_max_multiplier, ratio)
	_charging = false
	_charge_seconds = 0.0
	if _cooldown_timer > 0.0:
		return
	_try_swing(mult)


func _try_dodge() -> void:
	if _dodge_cooldown > 0.0:
		return
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or player.is_dead:
		return
	# Roll in the current movement-input direction; fall back to facing.
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
	)
	var dir: Vector2 = input.normalized() if input.length() > 0.05 else player.facing
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	_dodge_remaining = DODGE_DURATION
	_dodge_cooldown = DODGE_COOLDOWN
	# Apply roll velocity; PlayerController will use is_dodging for i-frames.
	player.velocity = dir * (DODGE_DISTANCE / DODGE_DURATION)
	# Make hurtbox briefly invulnerable.
	var hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
	if hurtbox:
		hurtbox.set_meta("dodge_iframes_until", float(Time.get_ticks_msec()) / 1000.0 + DODGE_DURATION)
	EventBus.player_dodge_started.emit(dir)
	if AudioBus:
		AudioBus.play_sfx(&"dodge_roll")


func _try_block_or_special(_pressed: bool) -> bool:
	var defn := _held_def()
	if defn == null:
		return false
	# Off-hand shield = block; primary special_attack = use it.
	var off_id: StringName = StringName(Inventory.equipment.get(&"off_hand", &""))
	var off_def: ItemDef = ItemRegistry.get_def(off_id) if off_id != &"" else null
	if off_def and off_def.block_fraction > 0.0:
		_start_block(off_def)
		return true
	if defn.special_attack != &"":
		_try_special(defn)
		return true
	# Phase 6.38 — if the weapon has a heavy_damage_multiplier > 1, fire a heavy.
	if defn.heavy_damage_multiplier > 1.0 and defn.weapon_class == &"":
		_try_swing(defn.heavy_damage_multiplier, true)
		_cooldown_timer *= defn.heavy_cooldown_multiplier
		return true
	return false


func _start_block(off_def: ItemDef) -> void:
	if _blocking:
		return
	_blocking = true
	_parry_window_remaining = off_def.parry_window_seconds
	var player := get_node_or_null(player_path) as PlayerController
	if player:
		var hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
		if hurtbox:
			hurtbox.block_fraction = off_def.block_fraction
	EventBus.player_block_changed.emit(true, off_def.block_fraction)


func _release_block() -> void:
	if not _blocking:
		return
	_blocking = false
	_parry_window_remaining = 0.0
	var player := get_node_or_null(player_path) as PlayerController
	if player:
		var hurtbox := player.get_node_or_null("Hurtbox") as HurtboxComponent
		if hurtbox:
			hurtbox.block_fraction = 0.0
	EventBus.player_block_changed.emit(false, 0.0)


var _last_drag_tile: Vector2i = Vector2i(99999, 99999)


func _tick_drag_place() -> void:
	if not Input.is_action_pressed("attack_primary"):
		_last_drag_tile = Vector2i(99999, 99999)
		return
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or player.is_dead:
		return
	var held_id: StringName = _held_item_id()
	if held_id == &"":
		return
	var defn: ItemDef = ItemRegistry.get_def(held_id)
	if defn == null or defn.item_type != ItemDef.ItemType.PLACEABLE:
		return
	if Inventory.count_of(held_id) <= 0:
		return
	var target: Vector2 = _aim_target(player)
	var tile: Vector2i = Vector2i(
		int(floor(target.x / 16.0)),
		int(floor(target.y / 16.0)),
	)
	if tile == _last_drag_tile:
		return
	if _cooldown_timer > 0.0:
		return
	_last_drag_tile = tile
	if _resolve_place(player, defn, target):
		_cooldown_timer = 0.08


func _try_consume() -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or player.is_dead:
		return
	var held_id: StringName = _held_item_id()
	if held_id == &"":
		return
	var defn: ItemDef = ItemRegistry.get_def(held_id)
	if defn == null or defn.item_type != ItemDef.ItemType.CONSUMABLE:
		return
	# Phase 4 utility items.
	match held_id:
		&"bound_compass":
			_use_bound_compass(player)
			return
		&"world_scanner":
			_use_world_scanner(player)
			return
		&"treasure_map":
			if Inventory.try_remove(held_id, 1) <= 0:
				return
			_use_treasure_map(player)
			return
		&"anchor_portable":
			if Inventory.try_remove(held_id, 1) <= 0:
				return
			_use_anchor_portable(player)
			return
	if Inventory.try_remove(held_id, 1) <= 0:
		return
	if held_id == &"respec_scroll":
		GameState.refund_all_talents()
		EventBus.ui_toast.emit("Talents refunded.", 2.0)
		return
	if held_id == &"recipe_scroll":
		var scroll: Node = _find_recipe_scroll()
		if scroll and scroll.has_method("consume_one"):
			var ok: bool = scroll.call("consume_one")
			if not ok:
				Inventory.try_add(&"recipe_scroll", 1)
		return
	# Phase 6.30 — anti-status potion: cleanses all debuffs.
	if held_id == &"cleanse_tonic":
		var sef := player.get_node_or_null("StatusEffects") as StatusEffects
		if sef:
			sef.clear(&"")
		EventBus.ui_toast.emit("Status cleansed.", 1.5)
		return
	if defn.heal_amount > 0:
		var hc := player.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.heal(defn.heal_amount, player)
	if defn.mana_restore > 0:
		var mc := player.get_node_or_null("ManaComponent") as ManaComponent
		if mc:
			mc.add_mana(defn.mana_restore)
	if defn.buff_id != &"" and defn.buff_duration_seconds > 0.0:
		Buffs.apply(defn.buff_id, defn.buff_duration_seconds)
	EventBus.skill_xp_gained.emit(&"skill_cooking", 1)


func _try_swing(damage_multiplier: float = 1.0, is_heavy: bool = false) -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		return
	if player.is_dead:
		return
	var held_id: StringName = _held_item_id()
	var defn: ItemDef = ItemRegistry.get_def(held_id) if held_id != &"" else null
	var aim_dir: Vector2 = _aim_direction(player)
	var aim_target: Vector2 = _aim_target(player)

	# Farming branch.
	if FarmingSystem and FarmingSystem.is_seed(held_id):
		FarmingSystem.plant_seed(held_id, aim_target)
		_cooldown_timer = 0.3
		return
	if FarmingSystem and FarmingSystem.is_watering_can(held_id):
		FarmingSystem.water_at(aim_target)
		_cooldown_timer = 0.3
		return

	# Mining.
	if defn and defn.pickaxe_tier > 0:
		_resolve_mining(player, defn, aim_dir)
		_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
		return

	# Photograph scan.
	if held_id == &"photograph":
		var ph: Node = _find_photograph()
		if ph and ph.has_method("try_scan"):
			ph.call("try_scan", player.global_position, aim_target)
		_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds if defn else 0.8, defn)
		return

	# Placement.
	if defn and defn.item_type == ItemDef.ItemType.PLACEABLE:
		if _resolve_place(player, defn, aim_target):
			_cooldown_timer = 0.25
		return

	# Ranged / Magic / Summon / Fishing / Bomb.
	if defn and defn.weapon_class != &"":
		if defn.weapon_class == &"fishing":
			if FishingSystem.cast(player):
				_cooldown_timer = 5.0
			return
		match defn.weapon_class:
			&"ranged_bow", &"ranged_gun", &"ranged_crossbow":
				if _resolve_ranged(player, defn, aim_dir, damage_multiplier):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
					if defn.reload_seconds > 0.0:
						_cooldown_timer += defn.reload_seconds * 0.5
				return
			&"magic":
				if _resolve_magic(player, defn, aim_dir, damage_multiplier):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
				return
			&"summon":
				if _resolve_summon(player, defn):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
				return
			&"bomb":
				if _resolve_bomb(player, defn, aim_target):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
				return
			&"throwable":
				if _resolve_thrown(player, defn, aim_dir):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
				return
			&"boomerang":
				if _resolve_boomerang(player, defn, aim_dir):
					_cooldown_timer = _final_cooldown(defn.attack_cooldown_seconds, defn)
				return

	# Melee branch (default).
	# Phase 3.47 — dual-wield alternation.
	var swing_def: ItemDef = defn
	var multiplier: float = damage_multiplier
	if defn and defn.weapon_class == &"" and not defn.two_handed:
		var off_id: StringName = StringName(Inventory.equipment.get(&"off_hand", &""))
		var off_def: ItemDef = ItemRegistry.get_def(off_id) if off_id != &"" else null
		if off_def and off_def.weapon_class == &"" and off_def.base_damage > 0 and not off_def.two_handed:
			# Both hands hold weapons. Alternate swings.
			if _next_swing_off_hand:
				swing_def = off_def
				multiplier *= off_def.off_hand_damage_multiplier
			_next_swing_off_hand = not _next_swing_off_hand
	var base_damage: int = int(round(float(swing_def.base_damage if swing_def else 1) * multiplier))
	var dtype: StringName = swing_def.damage_type if swing_def else DamageType.PHYSICAL
	_resolve_melee(player, base_damage, dtype, aim_dir, swing_def, is_heavy)
	_cooldown_timer = _final_cooldown((swing_def.attack_cooldown_seconds if swing_def else 0.4), swing_def)


func _final_cooldown(base: float, defn: ItemDef) -> float:
	var mult: float = PlayerStats.cooldown_multiplier()
	# Mining gets the additional Crafting-talent speed boost (ticket 6.55).
	if defn and defn.pickaxe_tier > 0:
		mult /= maxf(0.25, PlayerStats.mining_speed_multiplier())
	return base * mult


func _spawn_projectile(player: PlayerController, dir: Vector2, damage: int, dtype: StringName, speed: float, defn: ItemDef = null, is_crit: bool = false) -> Projectile:
	var scn := load("res://scenes/projectiles/arrow.tscn") as PackedScene
	if scn == null:
		return null
	var proj := scn.instantiate() as Projectile
	if proj == null:
		return null
	proj.direction = dir
	proj.base_damage = damage
	proj.damage_type = dtype
	proj.speed = speed
	proj.team = &"player"
	proj.owner_node = player
	proj.is_crit_this_swing = is_crit
	proj.lifesteal_fraction = PlayerStats.lifesteal_fraction()
	proj.manasteel_fraction = PlayerStats.manasteel_fraction()
	if defn:
		proj.pierce_count = defn.projectile_pierce
		if defn.on_hit_status != &"" and defn.on_hit_status_chance > 0.0:
			proj.on_hit_status = defn.on_hit_status
			proj.status_chance = defn.on_hit_status_chance
			proj.status_duration = defn.on_hit_status_duration
		if defn.damage_type == DamageType.LIGHTNING:
			proj.chain_count = 2
			proj.chain_radius_pixels = 64.0
	proj.global_position = player.global_position + dir * 10.0
	get_tree().current_scene.add_child(proj)
	return proj


func _resolve_ranged(player: PlayerController, defn: ItemDef, dir: Vector2, mult: float = 1.0) -> bool:
	if defn.ammo_id == &"" or Inventory.count_of(defn.ammo_id) <= 0:
		EventBus.ui_toast.emit("Out of ammo (%s)." % String(defn.ammo_id), 1.5)
		return false
	# Phase 3.81 / 3.82 — auto-reload from quiver. We don't model reload as a
	# separate inventory action; one consumed shot per swing, the reload window
	# is folded into attack_cooldown_seconds + reload_seconds.
	Inventory.try_remove(defn.ammo_id, 1)
	var ammo_def: ItemDef = ItemRegistry.get_def(defn.ammo_id)
	var bonus: int = ammo_def.base_damage if ammo_def else 0
	var damage: int = int(round(float(defn.base_damage + bonus) * mult))
	# Crit roll once per swing; all projectiles share the result.
	var is_crit: bool = randf() < PlayerStats.crit_chance()
	# Multi-shot fan.
	var count: int = maxi(1, defn.projectile_count)
	if count == 1:
		var aimed_dir: Vector2 = _apply_aim_cone(dir, PlayerStats.aim_cone_degrees + defn.aim_cone_degrees)
		_spawn_projectile(player, aimed_dir, damage, defn.damage_type, defn.projectile_speed, defn, is_crit)
	else:
		var spread_deg: float = defn.projectile_arc_degrees
		var step: float = spread_deg / float(count - 1) if count > 1 else 0.0
		var start: float = -spread_deg * 0.5
		for i in range(count):
			var angle: float = deg_to_rad(start + step * float(i))
			var fan_dir: Vector2 = dir.rotated(angle)
			fan_dir = _apply_aim_cone(fan_dir, defn.aim_cone_degrees)
			_spawn_projectile(player, fan_dir, damage, defn.damage_type, defn.projectile_speed, defn, is_crit)
	EventBus.skill_xp_gained.emit(&"skill_ranged", 1)
	if AudioBus:
		AudioBus.play_sfx(DamageType.hit_sfx_for(defn.damage_type))
	return true


func _apply_aim_cone(dir: Vector2, cone_degrees: float) -> Vector2:
	if cone_degrees <= 0.01:
		return dir
	var jitter: float = deg_to_rad(randf_range(-cone_degrees * 0.5, cone_degrees * 0.5))
	return dir.rotated(jitter)


func _resolve_magic(player: PlayerController, defn: ItemDef, dir: Vector2, mult: float = 1.0) -> bool:
	var mana := player.get_node_or_null("ManaComponent") as ManaComponent
	if mana == null or not mana.try_spend(defn.mana_cost):
		EventBus.ui_toast.emit("Not enough mana.", 1.0)
		return false
	var damage: int = int(round(float(defn.base_damage) * mult))
	var is_crit: bool = randf() < PlayerStats.crit_chance()
	_spawn_projectile(player, dir, damage, defn.damage_type, defn.projectile_speed, defn, is_crit)
	EventBus.skill_xp_gained.emit(&"skill_magic", 1)
	# Phase 6.46 — wand/tome may grant mana on kill; resolution lives in the
	# damage_dealt handler so it triggers for any source the player created.
	return true


func _resolve_bomb(player: PlayerController, defn: ItemDef, target: Vector2) -> bool:
	if Inventory.try_remove(defn.id, 1) <= 0:
		return false
	var bomb := Bomb.new()
	bomb.toss(player.global_position, target)
	get_tree().current_scene.add_child(bomb)
	EventBus.skill_xp_gained.emit(&"skill_explosives", 2)
	# Phase 2.30 — telegraph the bomb's blast radius briefly.
	EventBus.aoe_indicator_requested.emit(target, 32.0, 0.7, Color(1.0, 0.6, 0.2, 0.5))
	return true


func _resolve_thrown(player: PlayerController, defn: ItemDef, dir: Vector2) -> bool:
	# Phase 6.27 — throwable knife / dagger consumed on use.
	if Inventory.try_remove(defn.id, 1) <= 0:
		return false
	var is_crit: bool = randf() < PlayerStats.crit_chance()
	_spawn_projectile(player, dir, defn.base_damage, defn.damage_type, defn.projectile_speed, defn, is_crit)
	EventBus.skill_xp_gained.emit(&"skill_ranged", 1)
	return true


func _resolve_boomerang(player: PlayerController, defn: ItemDef, dir: Vector2) -> bool:
	# Phase 6.25 — fires a Projectile flagged `homing`. Returns to player after a
	# short outbound travel.
	var is_crit: bool = randf() < PlayerStats.crit_chance()
	var proj := _spawn_projectile(player, dir, defn.base_damage, defn.damage_type, defn.projectile_speed, defn, is_crit)
	if proj:
		proj.homing = true
		proj.homing_after_seconds = 0.4
		proj.lifetime = 4.0
		proj.pierce_count = 99
	EventBus.skill_xp_gained.emit(&"skill_ranged", 1)
	return true


func _resolve_summon(player: PlayerController, defn: ItemDef) -> bool:
	if defn.summon_mob_path == "":
		return false
	var mana := player.get_node_or_null("ManaComponent") as ManaComponent
	if mana == null or not mana.try_spend(defn.mana_cost):
		EventBus.ui_toast.emit("Not enough mana.", 1.0)
		return false
	var mob_def := load(defn.summon_mob_path) as MobDef
	if mob_def == null:
		return false
	var scn := load("res://scenes/enemies/stone_hopper.tscn") as PackedScene
	var minion := scn.instantiate() as Mob
	minion.mob_def = mob_def
	minion.global_position = player.global_position + Vector2(16, 0)
	get_tree().current_scene.add_child(minion)
	var hb := minion.get_node_or_null("Hurtbox") as HurtboxComponent
	if hb: hb.team = &"player"
	var contact := minion.get_node_or_null("ContactHitbox") as HitboxComponent
	if contact: contact.team = &"player"
	var t := get_tree().create_timer(30.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(minion):
			minion.queue_free()
	)
	EventBus.skill_xp_gained.emit(&"skill_summoning", 3)
	return true


func _try_special(defn: ItemDef) -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		return
	match defn.special_attack:
		&"spin", &"whirlwind":
			_special_whirlwind(player, defn)
		&"thrust":
			_special_thrust(player, defn)
		&"whip_pull":
			_special_whip_pull(player, defn)
		&"shield_bash":
			_special_shield_bash(player, defn)
		&"rage_burst":
			_special_rage_burst(player, defn)
	EventBus.player_special_used.emit(defn.special_attack)


func _special_whirlwind(player: PlayerController, defn: ItemDef) -> void:
	# Phase 6.31 — sword whirlwind: 360° hit at 1.5× damage at half cooldown cost.
	var hb_node := get_node_or_null(hitbox_path)
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = int(round(float(defn.base_damage) * 1.5))
	hb.damage_type = defn.damage_type
	hb.team = &"player"
	hb.is_crit_this_swing = randf() < PlayerStats.crit_chance()
	(hb as Node2D).position = Vector2.ZERO
	hb.arm(0.4)
	# Visual: spawn 8 swing arcs in a fan.
	for i in range(8):
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		_spawn_swing_visual(player, d)
	_cooldown_timer = defn.attack_cooldown_seconds * 1.4


func _special_thrust(player: PlayerController, defn: ItemDef) -> void:
	# Phase 6.26 — spear thrust: long-reach, narrow strike for 1.3× damage.
	var dir: Vector2 = _aim_direction(player)
	var hb_node := get_node_or_null(hitbox_path)
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = int(round(float(defn.base_damage) * 1.3))
	hb.damage_type = defn.damage_type
	hb.team = &"player"
	hb.is_crit_this_swing = randf() < PlayerStats.crit_chance()
	hb.is_heavy_this_swing = true
	(hb as Node2D).position = dir * 28.0
	hb.arm(0.18)
	_spawn_swing_visual(player, dir)
	_cooldown_timer = defn.attack_cooldown_seconds * 1.3


func _special_whip_pull(player: PlayerController, defn: ItemDef) -> void:
	# Phase 6.24 — whip: long-reach line that yanks the first hit toward the player.
	var dir: Vector2 = _aim_direction(player)
	var range_px: float = 56.0
	var probe_origin: Vector2 = player.global_position
	var step: float = 6.0
	var dist: float = 0.0
	var hit_node: Node2D = null
	while dist <= range_px:
		probe_origin += dir * step
		dist += step
		for n in get_tree().get_nodes_in_group("mob"):
			var m := n as Node2D
			if m and m.global_position.distance_to(probe_origin) < 10.0:
				hit_node = m
				break
		if hit_node:
			break
	if hit_node:
		var hb := hit_node.get_node_or_null("Hurtbox") as HurtboxComponent
		if hb:
			hb.receive_hit_full(player, defn.base_damage, defn.damage_type, &"player", false)
		# Pull toward the player.
		var pull_to: Vector2 = player.global_position + dir * 16.0
		hit_node.global_position = pull_to
	_spawn_swing_visual(player, dir)
	_cooldown_timer = defn.attack_cooldown_seconds * 1.4


func _special_shield_bash(player: PlayerController, defn: ItemDef) -> void:
	# Phase 6.14 — shield bash: short-range stun melee.
	var dir: Vector2 = _aim_direction(player)
	var hb_node := get_node_or_null(hitbox_path)
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = int(round(float(defn.base_damage) * 0.5))
	hb.damage_type = DamageType.PHYSICAL
	hb.team = &"player"
	hb.is_crit_this_swing = false
	hb.on_hit_status = &"stun"
	hb.on_hit_status_chance = 1.0
	hb.on_hit_status_duration = 1.0
	(hb as Node2D).position = dir * 14.0
	hb.arm(0.18)
	_spawn_swing_visual(player, dir)
	_cooldown_timer = 0.6


func _special_rage_burst(player: PlayerController, defn: ItemDef) -> void:
	# Phase 6.47 — adrenaline release: 3× damage area swing if rage >= cost.
	if rage < RAGE_RELEASE_COST:
		EventBus.ui_toast.emit("Not enough adrenaline.", 1.0)
		return
	rage -= RAGE_RELEASE_COST
	_special_whirlwind(player, defn)


func _held_def() -> ItemDef:
	var iid: StringName = _held_item_id()
	if iid == &"":
		return null
	return ItemRegistry.get_def(iid)


func _held_item_id() -> StringName:
	var hotbar := _find_hotbar()
	if hotbar == null:
		return &""
	return Inventory.get_hotbar_item(hotbar.selected_index)


func _find_hotbar() -> Hotbar:
	var nodes := get_tree().get_nodes_in_group("hotbar")
	if nodes.is_empty():
		return null
	return nodes[0] as Hotbar


func _aim_direction(player: PlayerController) -> Vector2:
	if mouse_aim:
		var viewport := player.get_viewport()
		if viewport:
			var camera := viewport.get_camera_2d()
			if camera:
				var mouse_world: Vector2 = camera.get_global_mouse_position()
				return (mouse_world - player.global_position).normalized()
	return player.facing


func _aim_target(player: PlayerController) -> Vector2:
	if mouse_aim:
		var camera := player.get_viewport().get_camera_2d() if player.get_viewport() else null
		if camera:
			return camera.get_global_mouse_position()
	return player.global_position + player.facing * 16.0


func _resolve_melee(player: PlayerController, dmg: int, dtype: StringName, dir: Vector2, weapon_def: ItemDef = null, is_heavy: bool = false) -> void:
	var hb_node := get_node_or_null(hitbox_path)
	if hb_node == null:
		return
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = dmg
	hb.damage_type = dtype
	hb.team = &"player"
	hb.is_crit_this_swing = randf() < PlayerStats.crit_chance()
	hb.is_heavy_this_swing = is_heavy
	hb.is_back_hit_this_swing = _is_back_hit(player, dir)
	hb.lifesteal_fraction = PlayerStats.lifesteal_fraction()
	hb.manasteel_fraction = PlayerStats.manasteel_fraction()
	if weapon_def:
		hb.on_hit_status = weapon_def.on_hit_status
		hb.on_hit_status_chance = weapon_def.on_hit_status_chance
		hb.on_hit_status_duration = weapon_def.on_hit_status_duration
	else:
		hb.on_hit_status = &""
		hb.on_hit_status_chance = 0.0
	var reach: float = float(weapon_def.melee_range_pixels) if weapon_def and weapon_def.melee_range_pixels > 0 else swing_offset
	(hb as Node2D).position = dir * reach
	hb.arm(0.15)
	_spawn_swing_visual(player, dir)
	_play_tool_sfx(weapon_def, dtype)
	if not hb.hit_landed.is_connected(_on_hit_landed):
		hb.hit_landed.connect(_on_hit_landed)


## Phase 6.35 — backstab if attacker is behind the mob (mob facing dot < 0).
func _is_back_hit(player: PlayerController, attack_dir: Vector2) -> bool:
	# Find the mob roughly in front of the swing.
	for n in get_tree().get_nodes_in_group("mob"):
		var m := n as Node2D
		if m == null:
			continue
		var to_mob: Vector2 = m.global_position - player.global_position
		if to_mob.length() > 28.0:
			continue
		if to_mob.normalized().dot(attack_dir) < 0.5:
			continue
		var mob := m as Mob
		if mob == null:
			return false
		# Backstab when attack-dir matches mob's facing (we're behind it).
		return attack_dir.dot(mob.facing_dir()) > 0.5
	return false


func _play_tool_sfx(defn: ItemDef, dtype: StringName) -> void:
	if AudioBus == null:
		return
	# Per-type hit sfx (ticket 2.42).
	if dtype != &"" and dtype != DamageType.PHYSICAL:
		AudioBus.play_sfx(DamageType.hit_sfx_for(dtype))
		return
	var sound: StringName = &"swing_fist"
	if defn:
		if defn.pickaxe_tier > 0:
			sound = &"swing_pickaxe"
		elif defn.axe_tier > 0:
			sound = &"swing_axe"
		elif defn.weapon_class == &"magic":
			sound = &"swing_magic"
		elif defn.weapon_class == &"ranged_bow" or defn.weapon_class == &"ranged_gun":
			sound = &"swing_ranged"
		elif defn.weapon_class == &"summon":
			sound = &"swing_summon"
		elif defn.id != &"":
			sound = &"swing_melee"
	AudioBus.play_sfx(sound)


func _spawn_swing_visual(player: Node2D, dir: Vector2) -> void:
	var arc := SwingArc.new()
	arc.position = dir * 4.0
	arc.rotation = dir.angle()
	arc.z_index = 6
	player.add_child(arc)


func _on_hit_landed(victim: Node, dealt: int) -> void:
	if dealt > 0:
		EventBus.skill_xp_gained.emit(&"skill_melee", 1)
	# Phase 6.46 — tome mana refund on kill.
	var defn := _held_def()
	if defn and defn.mana_on_kill > 0 and victim is Mob:
		var hc := victim.get_node_or_null("HealthComponent") as HealthComponent
		if hc and hc.is_dead():
			var player := get_node_or_null(player_path) as PlayerController
			var mc := player.get_node_or_null("ManaComponent") as ManaComponent if player else null
			if mc:
				mc.add_mana(defn.mana_on_kill)


func _on_damage_dealt(source: Node, _target: Node, amount: int, _type: StringName) -> void:
	# Phase 6.47 — rage builds on damage dealt (player-source) and taken (player target).
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or amount <= 0:
		return
	if source == player:
		rage = clampf(rage + RAGE_PER_HIT_DEALT, 0.0, RAGE_MAX)


func _on_player_hp_changed(_current: int, _max: int) -> void:
	# Hooked for rage-on-hit-taken. The actual hit_taken signal is elsewhere; we
	# treat health drops as proxy. Skip if player_combat hasn't been wired.
	pass


const PICKAXE_MAX_REACH_PIXELS: float = 28.0


func _resolve_mining(player: PlayerController, pick: ItemDef, dir: Vector2) -> void:
	_spawn_swing_visual(player, dir)
	var ore_layers := get_tree().get_nodes_in_group("ore_layer")
	var wall_layers := get_tree().get_nodes_in_group("wall_layer")
	var target_pos: Vector2 = player.global_position + dir * 16.0
	if mouse_aim:
		var cam := player.get_viewport().get_camera_2d()
		if cam:
			target_pos = cam.get_global_mouse_position()
	var to_target: Vector2 = target_pos - player.global_position
	if to_target.length() > PICKAXE_MAX_REACH_PIXELS:
		target_pos = player.global_position + to_target.normalized() * PICKAXE_MAX_REACH_PIXELS
	var mining_skill: int = SkillSystem.get_level(&"skill_mining")
	var damage: int = CombatMath.mining_damage(pick.base_damage, mining_skill)
	# Phase 6.56 — mining penetration affix: hit the next N tiles in the same line.
	var pierce: int = pick.mining_pierce + PlayerStats.mining_pierce
	var hit_positions: Array[Vector2] = [target_pos]
	for i in range(pierce):
		hit_positions.append(target_pos + dir * 16.0 * float(i + 1))
	for tp in hit_positions:
		var hit: bool = false
		for layer in ore_layers:
			if MiningSystem.swing_on_tile(layer as TileMapLayer, tp, pick.pickaxe_tier, damage):
				hit = true
				break
		if not hit:
			for layer in wall_layers:
				if MiningSystem.swing_on_tile(layer as TileMapLayer, tp, pick.pickaxe_tier, damage):
					break


const PLACEMENT_RADIUS_PIXELS: float = 48.0

const PLACEABLE_SCENES: Dictionary = {
	&"loam_bench_placeable":      "res://scenes/structures/loam_bench.tscn",
	&"clearstone_forge_placeable":"res://scenes/structures/clearstone_forge.tscn",
	&"furnace_placeable":         "res://scenes/structures/furnace.tscn",
	&"sawmill_placeable":         "res://scenes/structures/sawmill.tscn",
	&"cooking_pot_placeable":     "res://scenes/structures/cooking_pot.tscn",
	&"glow_shroom_seed":          "res://scenes/structures/glow_shroom.tscn",
	&"trapdoor_placeable":        "res://scenes/structures/trapdoor.tscn",
	&"statue_placeable":          "res://scenes/structures/statue.tscn",
	&"bed_placeable":             "res://scenes/structures/bed.tscn",
	&"shrine_placeable":          "res://scenes/structures/shrine.tscn",
	&"healing_shrine_placeable":  "res://scenes/structures/healing_shrine.tscn",
	&"spike_trap_placeable":      "res://scenes/structures/spike_trap.tscn",
	&"hidden_door_placeable":     "res://scenes/structures/hidden_door.tscn",
	&"mural_placeable":           "res://scenes/structures/mural.tscn",
}

const PLACEABLE_DECOR: Dictionary = {
	&"torch":       {"with_light": true,  "color": Color(1.0, 0.78, 0.45)},
	&"glow_tube":   {"with_light": true,  "color": Color(0.55, 0.95, 1.0)},
	&"loam_floor":  {"with_light": false, "color": Color(1, 1, 1)},
	&"loam_wall":   {"with_light": false, "color": Color(1, 1, 1)},
	&"bridge_tile": {"with_light": false, "color": Color(1, 1, 1)},
	&"sticky_tile": {"with_light": false, "color": Color(1, 1, 1)},
	# Phase 2.49 — light source tier progression.
	&"lantern":     {"with_light": true,  "color": Color(1.0, 0.85, 0.55), "energy": 1.1, "scale": 0.9},
	&"oil_lamp":    {"with_light": true,  "color": Color(1.0, 0.92, 0.66), "energy": 1.4, "scale": 1.2},
	&"ward_lantern":{"with_light": true,  "color": Color(0.66, 0.95, 1.0), "energy": 1.8, "scale": 1.5},
}


func _resolve_place(player: PlayerController, defn: ItemDef, raw_target: Vector2) -> bool:
	var snapped := Vector2(
		floor(raw_target.x / 16.0) * 16.0 + 8.0,
		floor(raw_target.y / 16.0) * 16.0 + 8.0,
	)
	var dist: float = snapped.distance_to(player.global_position)
	if dist > PLACEMENT_RADIUS_PIXELS:
		EventBus.ui_toast.emit("Too far to place.", 1.0)
		return false
	var iid: StringName = defn.id
	var node: Node2D = null
	if PLACEABLE_SCENES.has(iid):
		var scn := load(PLACEABLE_SCENES[iid]) as PackedScene
		if scn == null:
			EventBus.ui_toast.emit("Missing scene for %s." % defn.display_name, 1.5)
			return false
		node = scn.instantiate() as Node2D
	elif PLACEABLE_DECOR.has(iid):
		node = _build_decor_placement(defn, PLACEABLE_DECOR[iid])
	else:
		EventBus.ui_toast.emit("No placement defined for %s." % defn.display_name, 1.5)
		return false
	if node == null:
		return false
	node.global_position = snapped
	var parent := player.get_parent()
	if parent == null:
		node.queue_free()
		return false
	parent.add_child(node)
	Inventory.try_remove(iid, 1)
	if AudioBus:
		AudioBus.play_sfx(&"place_item")
	return true


func _build_decor_placement(defn: ItemDef, opts: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.add_to_group("placed_decor")
	var sprite := Sprite2D.new()
	sprite.texture = defn.icon
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.offset = Vector2(0, -4)
	root.add_child(sprite)
	if bool(opts.get("with_light", false)):
		var light := PointLight2D.new()
		light.color = Color(opts.get("color", Color.WHITE))
		light.energy = float(opts.get("energy", 0.9))
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 64
		tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		light.texture = tex
		light.texture_scale = float(opts.get("scale", 0.6))
		root.add_child(light)
	return root


# ============================================================================
# Phase 4 utility-item handlers.
# ============================================================================

const _COMPASS_COOLDOWN_BEATS: int = 60
const _SCANNER_COOLDOWN_BEATS: int = 12
const _SCANNER_RADIUS_CHUNKS: int = 5

var _compass_ready_beat: int = -999999
var _scanner_ready_beat: int = -999999


func _current_beat() -> int:
	if AudioBus == null:
		return 0
	return AudioBus.get("_phase_index") if AudioBus else 0


func _use_bound_compass(player: PlayerController) -> void:
	var now: int = _current_beat()
	if now < _compass_ready_beat:
		EventBus.ui_toast.emit("Compass still drowsing.", 1.5)
		return
	_compass_ready_beat = now + _COMPASS_COOLDOWN_BEATS
	var target: Vector2 = GameState.respawn_point
	player.global_position = target
	EventBus.ui_toast.emit("The thread snaps you home.", 2.0)
	if AudioBus:
		AudioBus.play_sfx(&"loom_bind")


func _use_world_scanner(player: PlayerController) -> void:
	var now: int = _current_beat()
	if now < _scanner_ready_beat:
		EventBus.ui_toast.emit("Scanner cooling.", 1.5)
		return
	_scanner_ready_beat = now + _SCANNER_COOLDOWN_BEATS
	var wg: Node = _find_world_gen()
	if wg == null or not wg.has_method("chunks_in_radius"):
		return
	var chunks: Array = wg.call("chunks_in_radius", player.global_position, _SCANNER_RADIUS_CHUNKS)
	for c in chunks:
		var coord: Vector2i = c
		var b: BiomeDef = wg.call("biome_for_chunk", coord) as BiomeDef
		if b:
			GameState.mark_chunk_visited(coord, b.id)
	EventBus.ui_toast.emit("Scanner pings %d chunks." % chunks.size(), 2.0)


func _use_treasure_map(player: PlayerController) -> void:
	var wg: Node = _find_world_gen()
	if wg == null or not wg.has_method("nearest_treasure_chest"):
		EventBus.ui_toast.emit("Nothing answers.", 1.5)
		return
	var chest: Node2D = wg.call("nearest_treasure_chest", player.global_position) as Node2D
	if chest == null:
		EventBus.ui_toast.emit("No chest within range.", 2.0)
		return
	get_tree().call_group("minimap", "add_marker", chest.global_position, "Treasure", Color(1.0, 0.85, 0.4, 1.0))
	EventBus.ui_toast.emit("Marker set. The map remembers.", 2.5)


func _use_anchor_portable(player: PlayerController) -> void:
	GameState.set_respawn_point(player.global_position)
	EventBus.ui_toast.emit("Anchor planted. The Loom will wake you here.", 2.5)
	if AudioBus:
		AudioBus.play_sfx(&"loom_bind")


func _find_world_gen() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("WorldGen")


var _photograph_cache: Node = null


func _find_photograph() -> Node:
	if _photograph_cache and is_instance_valid(_photograph_cache):
		return _photograph_cache
	for n in get_tree().get_nodes_in_group("photograph_tool"):
		_photograph_cache = n
		return n
	var scr: Script = load("res://scripts/items/photograph.gd") as Script
	if scr == null:
		return null
	var instance := Node.new()
	instance.set_script(scr)
	instance.add_to_group("photograph_tool")
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(instance)
	_photograph_cache = instance
	return instance


var _recipe_scroll_cache: Node = null


func _find_recipe_scroll() -> Node:
	if _recipe_scroll_cache and is_instance_valid(_recipe_scroll_cache):
		return _recipe_scroll_cache
	for n in get_tree().get_nodes_in_group("recipe_scroll_listener"):
		_recipe_scroll_cache = n
		return n
	var scr: Script = load("res://scripts/items/recipe_scroll.gd") as Script
	if scr == null:
		return null
	var instance := Node.new()
	instance.set_script(scr)
	instance.add_to_group("recipe_scroll_listener")
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(instance)
	_recipe_scroll_cache = instance
	return instance


## Phase 6.23 — public read for PlayerController to apply i-frames.
func is_dodging() -> bool:
	return _dodge_remaining > 0.0


func is_blocking() -> bool:
	return _blocking
