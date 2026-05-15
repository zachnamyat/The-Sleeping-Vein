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
	# Phase 3.41 — place-multiple drag-tool. While the player holds the primary
	# attack button and the held item is a placeable, every time the cursor
	# moves to a new 16-grid tile we attempt to drop one. Initial click on the
	# tile is handled by the normal _try_swing path; this drag adds the rest.
	_tick_drag_place()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_secondary"):
		_try_consume()
		return
	if event.is_action_released("attack_primary"):
		_last_drag_tile = Vector2i(99999, 99999)
		return
	if not event.is_action_pressed("attack_primary"):
		return
	if _cooldown_timer > 0.0:
		return
	_try_swing()


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
		# Drag-place cooldown is shorter than the click cooldown so the player
		# can lay a row of bridge tiles smoothly without stalling.
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
	# Phase 4 utility items — dispatch by id BEFORE the consume so cooldowned
	# items (bound_compass, world_scanner) don't lose a charge when they're
	# locked out.
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

	# Placement branch: held item is a placeable. Spawn the matching scene at
	# the snapped target tile, consume one from inventory.
	if defn and defn.item_type == ItemDef.ItemType.PLACEABLE:
		if _resolve_place(player, defn, aim_target):
			_cooldown_timer = 0.25
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


## Phase 3 — placement commit. Snaps to the 16-grid, validates against the
## PlaceablePreview's 48 px range, instantiates the matching scene from
## PLACEABLE_SCENES, consumes 1 from inventory.
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
}

## Items that don't have a dedicated scene get spawned as a generic
## PlacedDecor (sprite + optional Light2D). Maps id -> {with_light, light_color}.
const PLACEABLE_DECOR: Dictionary = {
	&"torch":       {"with_light": true,  "color": Color(1.0, 0.78, 0.45)},
	&"glow_tube":   {"with_light": true,  "color": Color(0.55, 0.95, 1.0)},
	&"loam_floor":  {"with_light": false, "color": Color(1, 1, 1)},
	&"loam_wall":   {"with_light": false, "color": Color(1, 1, 1)},
	&"bridge_tile": {"with_light": false, "color": Color(1, 1, 1)},
	&"sticky_tile": {"with_light": false, "color": Color(1, 1, 1)},
}


func _resolve_place(player: PlayerController, defn: ItemDef, raw_target: Vector2) -> bool:
	# Snap to 16-grid, mirroring the PlaceablePreview ghost.
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
	# Drop into the same parent the player lives in (the entities y-sort layer)
	# so the placement participates in y-sort + persistence.
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
		light.energy = 0.9
		# Tiny gradient texture so the light has actual shape.
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
		light.texture_scale = 0.6
		root.add_child(light)
	return root


# ============================================================================
# Phase 4 utility-item handlers (bound_compass, world_scanner, treasure_map,
# anchor_portable). Each is invoked from _try_consume after id-dispatch.
# ============================================================================

const _COMPASS_COOLDOWN_BEATS: int = 60
const _SCANNER_COOLDOWN_BEATS: int = 12
const _SCANNER_RADIUS_CHUNKS: int = 5

var _compass_ready_beat: int = -999999
var _scanner_ready_beat: int = -999999


func _current_beat() -> int:
	if AudioBus == null:
		return 0
	# AudioBus._phase_index increments every beat — use that as a global clock.
	return AudioBus.get("_phase_index") if AudioBus else 0


func _use_bound_compass(player: PlayerController) -> void:
	var now: int = _current_beat()
	if now < _compass_ready_beat:
		EventBus.ui_toast.emit("Compass still drowsing.", 1.5)
		return
	# 60 beats * ~23s = 23 minutes. Tweak via _COMPASS_COOLDOWN_BEATS.
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
	# Reveal CHUNK_TILES around the player.
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
	# Phase 4.19 — place a map marker at the chest's chunk.
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
