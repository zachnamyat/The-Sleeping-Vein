extends Node
class_name PlayerCombat

## Player combat + mining interface. Reads the held hotbar item from Inventory,
## resolves a swing in the player's facing direction (or at mouse if `mouse_aim`),
## and either deals melee damage via HitboxComponent or drives the Mining system.

@export var player_path: NodePath
@export var hitbox_path: NodePath
@export var swing_offset: float = 12.0
@export var mouse_aim: bool = true
@export var swing_cooldown: float = 0.0  ## Overridden by held item

var _cooldown_timer: float = 0.0


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_secondary"):
		_try_consume()
		return
	if not event.is_action_pressed("attack_primary"):
		return
	if _cooldown_timer > 0.0:
		return
	_try_swing()


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
	if Inventory.try_remove(held_id, 1) <= 0:
		return
	# Phase 7 — respec scroll refunds all allocated talent points.
	if held_id == &"respec_scroll":
		GameState.refund_all_talents()
		EventBus.ui_toast.emit("Talents refunded.", 2.0)
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


func _try_swing() -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		return
	if player.is_dead:
		return
	var held_id: StringName = _held_item_id()
	var defn: ItemDef = ItemRegistry.get_def(held_id) if held_id != &"" else null
	var aim_dir: Vector2 = _aim_direction(player)
	var aim_target: Vector2 = _aim_target(player)

	# Farming branch: seed → plant; watering can → water
	if FarmingSystem and FarmingSystem.is_seed(held_id):
		FarmingSystem.plant_seed(held_id, aim_target)
		_cooldown_timer = 0.3
		return
	if FarmingSystem and FarmingSystem.is_watering_can(held_id):
		FarmingSystem.water_at(aim_target)
		_cooldown_timer = 0.3
		return

	# Mining branch: held item is a pickaxe
	if defn and defn.pickaxe_tier > 0:
		_resolve_mining(player, defn, aim_dir)
		_cooldown_timer = defn.attack_cooldown_seconds
		return

	# Ranged / Magic / Summon / Fishing / Bomb branch
	if defn and defn.weapon_class != &"":
		if defn.weapon_class == &"fishing":
			if FishingSystem.cast(player):
				_cooldown_timer = 5.0
			return
		match defn.weapon_class:
			&"ranged_bow", &"ranged_gun":
				if _resolve_ranged(player, defn, aim_dir):
					_cooldown_timer = defn.attack_cooldown_seconds
				return
			&"magic":
				if _resolve_magic(player, defn, aim_dir):
					_cooldown_timer = defn.attack_cooldown_seconds
				return
			&"summon":
				if _resolve_summon(player, defn):
					_cooldown_timer = defn.attack_cooldown_seconds
				return
			&"bomb":
				if _resolve_bomb(player, defn, aim_target):
					_cooldown_timer = defn.attack_cooldown_seconds
				return

	# Melee branch
	var base_damage: int = defn.base_damage if defn else 1
	var dtype: StringName = defn.damage_type if defn else DamageType.PHYSICAL
	_resolve_melee(player, base_damage, dtype, aim_dir, defn)
	_cooldown_timer = defn.attack_cooldown_seconds if defn else 0.4


func _spawn_projectile(player: PlayerController, dir: Vector2, damage: int, dtype: StringName, speed: float) -> Projectile:
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
	proj.global_position = player.global_position + dir * 10.0
	get_tree().current_scene.add_child(proj)
	return proj


func _resolve_ranged(player: PlayerController, defn: ItemDef, dir: Vector2) -> bool:
	if defn.ammo_id == &"" or Inventory.count_of(defn.ammo_id) <= 0:
		EventBus.ui_toast.emit("Out of ammo (%s)." % String(defn.ammo_id), 1.5)
		return false
	Inventory.try_remove(defn.ammo_id, 1)
	var ammo_def: ItemDef = ItemRegistry.get_def(defn.ammo_id)
	var bonus: int = ammo_def.base_damage if ammo_def else 0
	_spawn_projectile(player, dir, defn.base_damage + bonus, defn.damage_type, defn.projectile_speed)
	EventBus.skill_xp_gained.emit(&"skill_ranged", 1)
	return true


func _resolve_magic(player: PlayerController, defn: ItemDef, dir: Vector2) -> bool:
	var mana := player.get_node_or_null("ManaComponent") as ManaComponent
	if mana == null or not mana.try_spend(defn.mana_cost):
		EventBus.ui_toast.emit("Not enough mana.", 1.0)
		return false
	_spawn_projectile(player, dir, defn.base_damage, defn.damage_type, defn.projectile_speed)
	EventBus.skill_xp_gained.emit(&"skill_magic", 1)
	return true


func _resolve_bomb(player: PlayerController, defn: ItemDef, target: Vector2) -> bool:
	# Ticket 2.17 — consume one bomb from inventory, lob a Bomb scene toward
	# the aim point. The bomb owns its own fuse + AoE resolution.
	if Inventory.try_remove(defn.id, 1) <= 0:
		return false
	var bomb := Bomb.new()
	bomb.toss(player.global_position, target)
	get_tree().current_scene.add_child(bomb)
	EventBus.skill_xp_gained.emit(&"skill_explosives", 2)
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


func _resolve_melee(player: PlayerController, dmg: int, dtype: StringName, dir: Vector2, weapon_def: ItemDef = null) -> void:
	var hb_node := get_node_or_null(hitbox_path)
	if hb_node == null:
		return
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = dmg
	hb.damage_type = dtype
	hb.team = &"player"
	# Ticket 2.29 — roll crit before arming so HitboxComponent applies the
	# bonus and the damage-float VFX uses the crit colour.
	hb.is_crit_this_swing = randf() < CombatMath.player_crit_chance()
	# Ticket 2.45 — reach is data-driven per weapon (sword = 18, dagger could be
	# 12, spear could be 28). Fallback to the inspector default if no def.
	var reach: float = float(weapon_def.melee_range_pixels) if weapon_def and weapon_def.melee_range_pixels > 0 else swing_offset
	(hb as Node2D).position = dir * reach
	hb.arm(0.15)
	_spawn_swing_visual(player, dir)
	# Play tool-use SFX per tool (ticket 2.41).
	_play_tool_sfx(weapon_def)
	# Player melee XP for connecting attacks is awarded in the hitbox signal
	if not hb.hit_landed.is_connected(_on_hit_landed):
		hb.hit_landed.connect(_on_hit_landed)


func _play_tool_sfx(defn: ItemDef) -> void:
	if AudioBus == null:
		return
	# Ticket 2.41 — distinct swing tone per tool class.
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
	arc.position = dir * 4.0  # nudge the arc slightly forward of the player
	arc.rotation = dir.angle()
	arc.z_index = 6  # above the player sprite (z=5)
	player.add_child(arc)


func _on_hit_landed(victim: Node, dealt: int) -> void:
	if dealt > 0:
		EventBus.skill_xp_gained.emit(&"skill_melee", 1)


const PICKAXE_MAX_REACH_PIXELS: float = 28.0  ## ~1.75 tiles; CK parity is short reach.


func _resolve_mining(player: PlayerController, pick: ItemDef, dir: Vector2) -> void:
	_spawn_swing_visual(player, dir)
	var ore_layers := get_tree().get_nodes_in_group("ore_layer")
	var wall_layers := get_tree().get_nodes_in_group("wall_layer")
	var target_pos: Vector2 = player.global_position + dir * 16.0
	if mouse_aim:
		var cam := player.get_viewport().get_camera_2d()
		if cam:
			target_pos = cam.get_global_mouse_position()
	# Clamp reach so the mouse can't whiff a click across half the screen and
	# end up hitting a wall the player isn't standing next to.
	var to_target: Vector2 = target_pos - player.global_position
	if to_target.length() > PICKAXE_MAX_REACH_PIXELS:
		target_pos = player.global_position + to_target.normalized() * PICKAXE_MAX_REACH_PIXELS
	var mining_skill: int = SkillSystem.get_level(&"skill_mining")
	var damage: int = CombatMath.mining_damage(pick.base_damage, mining_skill)
	# One swing damages one tile. Prefer ore over wall when both share a cell
	# (random world-gen sometimes co-locates them) so a single click can't
	# silently chunk two stacked blocks at once.
	var hit: bool = false
	for layer in ore_layers:
		if MiningSystem.swing_on_tile(layer as TileMapLayer, target_pos, pick.pickaxe_tier, damage):
			hit = true
			break
	if not hit:
		for layer in wall_layers:
			if MiningSystem.swing_on_tile(layer as TileMapLayer, target_pos, pick.pickaxe_tier, damage):
				hit = true
				break
