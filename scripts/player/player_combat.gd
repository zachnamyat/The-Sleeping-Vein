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

	# Ranged / Magic / Summon / Fishing branch
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

	# Melee branch
	var base_damage: int = defn.base_damage if defn else 1
	var dtype: StringName = defn.damage_type if defn else DamageType.PHYSICAL
	_resolve_melee(player, base_damage, dtype, aim_dir)
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


func _resolve_melee(player: PlayerController, dmg: int, dtype: StringName, dir: Vector2) -> void:
	var hb_node := get_node_or_null(hitbox_path)
	if hb_node == null:
		return
	var hb := hb_node as HitboxComponent
	if hb == null:
		return
	hb.base_damage = dmg
	hb.damage_type = dtype
	hb.team = &"player"
	(hb as Node2D).position = dir * swing_offset
	hb.arm(0.15)
	# Player melee XP for connecting attacks is awarded in the hitbox signal
	if not hb.hit_landed.is_connected(_on_hit_landed):
		hb.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(victim: Node, dealt: int) -> void:
	if dealt > 0:
		EventBus.skill_xp_gained.emit(&"skill_melee", 1)


func _resolve_mining(player: PlayerController, pick: ItemDef, dir: Vector2) -> void:
	# Find the ore layer in the current scene by group.
	var ore_layers := get_tree().get_nodes_in_group("ore_layer")
	var wall_layers := get_tree().get_nodes_in_group("wall_layer")
	var target_pos: Vector2 = player.global_position + dir * 16.0
	if mouse_aim:
		var cam := player.get_viewport().get_camera_2d()
		if cam:
			target_pos = cam.get_global_mouse_position()
	var mining_skill: int = SkillSystem.get_level(&"skill_mining")
	var damage: int = pick.base_damage + mining_skill
	var hit: bool = false
	for layer in ore_layers:
		hit = MiningSystem.swing_on_tile(layer as TileMapLayer, target_pos, pick.pickaxe_tier, damage) or hit
	for layer in wall_layers:
		hit = MiningSystem.swing_on_tile(layer as TileMapLayer, target_pos, pick.pickaxe_tier, damage) or hit
