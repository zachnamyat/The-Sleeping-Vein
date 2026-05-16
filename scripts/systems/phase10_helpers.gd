extends Node

## Phase 10 — consolidated helpers autoload.
##
## Hosts the systems that don't deserve their own autoload but cross-cut the
## Phase 10 feature set:
##   10.17 — boss respawn cooldowns + Awakened variants (BossDirector calls in)
##   10.18 — Awakened variant flag table
##   10.19 — pack-AI policy hint (consumed by world_gen)
##   10.24/10.25/10.26 — tile-hazard tick (slime / acid / cobweb)
##   10.27 — vine wall-climb traversal (Verdancy)
##   10.28 — mushroom propagation tick (Verdancy crop-like spread)
##   10.33 — pheromone trail (mob aggro spreads through the chain)
##   10.34 — per-biome champion-affix bias table
##   10.36..10.43 — lore moments (proximity-triggered scripted events)
##   10.46 — wandering Glow-Crane sub-quest counter
##   10.47 — Verdancy crop-survives-Auriax mercy moment
##   10.48 — Sythrenn spore-spread zones (registered when boss enters phase 2)
##   10.49 — boss cinematic camera angle hooks
##   10.50 — per-biome reverb zone constants
##
## Like Phase9Helpers, all state is restorable via dump_state / restore_state.

signal boss_respawn_ready(boss_id: StringName)
signal awakened_unlocked(boss_id: StringName)
signal lore_moment_triggered(moment_id: StringName)

# ---------------------------------------------------------------------------
# 10.17 — Boss respawn timer / cooldown system.
# After defeat, each boss enters a TIMEOUT during which the BossAltar
# cannot resummon. Cooldown lengths scale with first-kill vs. rematches:
# first kill = 60 beats (~23 min real time at 23s/beat); awakened rematches
# = 40 beats.
# ---------------------------------------------------------------------------

const FIRST_KILL_COOLDOWN_BEATS: int = 60
const REMATCH_COOLDOWN_BEATS: int = 40

# boss_id -> remaining beats until respawn
var boss_cooldowns: Dictionary = {}
# boss_id -> int (number of times the player has killed this boss; awakens at >= 1)
var kill_counts: Dictionary = {}
# boss_id -> bool (Awakened variant available)
var awakened_available: Dictionary = {}

# ---------------------------------------------------------------------------
# 10.19 — pack AI hint. Read by world_gen when laying down a chunk's mobs.
# ---------------------------------------------------------------------------

@warning_ignore("unused_private_class_variable")
const PACK_CHANCE: float = 0.18

# ---------------------------------------------------------------------------
# 10.24..10.26 — tile-hazard ids. World_gen paints these source ids inside
# Drowned/Verdancy/Necropolis chunks; Phase10Helpers polls the tile under
# the player every TICK seconds and dispatches per-kind effects.
# Source ids match the TileSet entries added in this pass.
# ---------------------------------------------------------------------------

const TILE_SOURCE_SLIME: int = 30
const TILE_SOURCE_ACID: int = 31
const TILE_SOURCE_COBWEB: int = 32
const TILE_SOURCE_VERDANT_SOIL: int = 33
const TILE_SOURCE_LAVA: int = 34   ## Phase 11 - heat tile reused here for lava boots

const HAZARD_TICK_SECONDS: float = 0.5
var _hazard_accum: float = 0.0
var _current_tile_kind: StringName = &""

# ---------------------------------------------------------------------------
# 10.28 — Mushroom propagation. Each placed glow_cap_placeable in the
# Verdancy biome has a chance to spread to an adjacent open tile every
# PROPAGATE_BEATS beats. Limited to MAX_PROPAGATED_PER_PARENT per parent.
# ---------------------------------------------------------------------------

const PROPAGATE_BEATS: int = 6
const MAX_PROPAGATED_PER_PARENT: int = 3
var _propagation_counts: Dictionary = {}   # parent_position_key -> children spread
var _beat_counter: int = 0

# ---------------------------------------------------------------------------
# 10.33 — Pheromone trail. When a hostile mob takes damage, it broadcasts
# its position via this autoload; nearby mobs of the same biome aggro for
# free. Decay window is short to avoid runaway aggro.
# ---------------------------------------------------------------------------

const PHEROMONE_RADIUS_PX: float = 96.0
const PHEROMONE_LIFETIME_SECONDS: float = 4.0
var _pheromone_marks: Array = []   # Array of {pos: Vector2, biome: StringName, time: float}

# ---------------------------------------------------------------------------
# 10.34 — Per-biome champion-affix bias. MobAffixes already rolls; this
# table biases certain affixes toward biomes (poison in Verdancy, salt
# corrosion in Necropolis, etc.). Read by mob_affixes when in phase 10
# biomes.
# ---------------------------------------------------------------------------

const BIOME_AFFIX_BIAS: Dictionary = {
	&"vesari_necropolis": [&"affix_armored", &"affix_brittle"],
	&"sunless_verdancy": [&"affix_venomous", &"affix_swift"],
	&"drowned_aphelion": [&"affix_chill", &"affix_charged"],
}

# ---------------------------------------------------------------------------
# 10.36..10.43, 10.46..10.48 — Lore moments. Most are one-shot proximity
# triggers, gated by a unique id. The dictionary records which have already
# fired so they don't repeat in the same save.
# ---------------------------------------------------------------------------

var lore_moments_fired: Dictionary = {}
# 10.41 — Auriax dying-forest progressive timer. Beats since Aelstren first
# spoke the Verdancy line; at 200 beats, the named tree dies (10.36).
var verdancy_age_beats: int = 0
const VERDANCY_TREE_DEATH_BEATS: int = 200
# 10.42 — Sunken Glyph Fragments collected so far.
var sunken_glyph_fragments_collected: int = 0
const SUNKEN_GLYPHS_TOTAL: int = 7

# ---------------------------------------------------------------------------
# 10.46 — Wandering Glow-Crane sub-quest (Brindle). Brindle asks for 3
# feathers; on delivery she sells the Vorrkell's Lantern recipe.
# ---------------------------------------------------------------------------

var glow_crane_quest_state: StringName = &"locked"   ## locked / active / done
var glow_crane_feathers_delivered: int = 0
const GLOW_CRANE_FEATHERS_REQUIRED: int = 3

# ---------------------------------------------------------------------------
# 10.48 — Sythrenn spore-spread zone registry. Boss script registers world
# positions; Phase10Helpers ticks them, applying poison to anything inside
# until the boss dies.
# ---------------------------------------------------------------------------

var sythrenn_spore_zones: Array = []  # Array of Vector2
var sythrenn_active: bool = false

# ---------------------------------------------------------------------------
# 10.49 — Boss-specific cinematic camera angles. Mapping boss_id -> Dict
# {phase_index -> { shake: float, zoom: float, letterbox: bool }}.
# ---------------------------------------------------------------------------

const BOSS_PHASE_CAMERA: Dictionary = {
	&"boss_vorrkell":       { 1: { "shake": 3.0, "zoom": 1.1, "letterbox": false }, 2: { "shake": 5.0, "zoom": 1.3, "letterbox": true } },
	&"boss_spawnmother":    { 1: { "shake": 3.0, "zoom": 1.05, "letterbox": false } },
	&"boss_sythrenn":       { 1: { "shake": 4.0, "zoom": 1.2, "letterbox": false }, 2: { "shake": 6.0, "zoom": 1.4, "letterbox": true } },
	&"boss_auriax":         { 2: { "shake": 8.0, "zoom": 1.5, "letterbox": true }, 3: { "shake": 2.0, "zoom": 1.0, "letterbox": true } },
	&"boss_volthaar":       { 3: { "shake": 0.0, "zoom": 1.3, "letterbox": true } },
	&"boss_drowned_crown":  { 2: { "shake": 0.5, "zoom": 1.05, "letterbox": false } },
}

# ---------------------------------------------------------------------------
# 10.50 — Per-biome reverb zones (consumed by AudioBus when biome changes).
# ---------------------------------------------------------------------------

const BIOME_REVERB: Dictionary = {
	&"vesari_necropolis": { "wet_db": 1.2, "room_size": 0.75 },   # Necropolis halls echo
	&"sunless_verdancy":  { "wet_db": 0.4, "room_size": 0.30 },   # foliage absorbs sound
	&"drowned_aphelion":  { "wet_db": 1.8, "room_size": 0.85 },   # underwater muffle + echo
	&"emberforge":        { "wet_db": 0.8, "room_size": 0.50 },
	&"salt_wastes":       { "wet_db": 0.2, "room_size": 0.20 },
	&"auroric_veil":      { "wet_db": 1.0, "room_size": 0.60 },
	&"final_spiral":      { "wet_db": 1.5, "room_size": 0.90 },
}

# ---------------------------------------------------------------------------
# Mob def lookup cache. world_gen calls mob_def_for(id) to resolve a mob
# id from biome.mob_spawn_table. Populated lazily on first call.
# ---------------------------------------------------------------------------

var _mob_def_cache: Dictionary = {}


func _ready() -> void:
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.biome_changed.connect(_on_biome_changed)
		EventBus.boss_engaged.connect(_on_boss_engaged)
	set_process(true)


func _process(delta: float) -> void:
	_hazard_accum += delta
	if _hazard_accum >= HAZARD_TICK_SECONDS:
		_hazard_accum = 0.0
		_tick_tile_hazards()
		_tick_sythrenn_spore_zones()
	_decay_pheromone(delta)


# ---------------------------------------------------------------------------
# 10.17 — Boss respawn cooldown.
# ---------------------------------------------------------------------------


func _on_boss_defeated(boss_id: StringName) -> void:
	var count: int = int(kill_counts.get(boss_id, 0))
	kill_counts[boss_id] = count + 1
	var cd: int = FIRST_KILL_COOLDOWN_BEATS if count == 0 else REMATCH_COOLDOWN_BEATS
	boss_cooldowns[boss_id] = cd
	if count >= 1:
		awakened_available[boss_id] = true
		awakened_unlocked.emit(boss_id)
		EventBus.ui_toast.emit("Awakened variant available: %s" % boss_id, 3.0)


func is_boss_on_cooldown(boss_id: StringName) -> bool:
	return int(boss_cooldowns.get(boss_id, 0)) > 0


func cooldown_remaining_beats(boss_id: StringName) -> int:
	return int(boss_cooldowns.get(boss_id, 0))


# ---------------------------------------------------------------------------
# 10.18 — Awakened variant config. Returns a multiplier dict the BossAltar
# applies to a boss def when summoning the rematch.
# ---------------------------------------------------------------------------


func awakened_config(boss_id: StringName) -> Dictionary:
	if not awakened_available.get(boss_id, false):
		return {}
	return {
		"hp_mult": 1.45,
		"damage_mult": 1.30,
		"speed_mult": 1.15,
		"extra_pattern_index": 1,  # cycle through one phase deeper
	}


# ---------------------------------------------------------------------------
# 10.24 — Tile hazard tick. Reads the floor layer source id under the
# player and applies the matching effect. Cobweb slows, slime makes the
# player slip (random sideways nudge), acid damages.
# ---------------------------------------------------------------------------


func _tick_tile_hazards() -> void:
	var players := get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return
	var p := players[0] as PlayerController
	if p == null:
		return
	var wg: Node = get_tree().current_scene.get_node_or_null("WorldGen") if get_tree().current_scene else null
	if wg == null:
		return
	var floor_layer := wg.get_node_or_null(wg.get("floor_layer_path")) as TileMapLayer
	if floor_layer == null:
		return
	var tile_px: int = int(wg.get("TILE_PX")) if wg.has_method("get") else 16
	if tile_px <= 0:
		tile_px = 16
	var coord: Vector2i = Vector2i(
		floori(p.global_position.x / float(tile_px)),
		floori(p.global_position.y / float(tile_px)),
	)
	var src: int = floor_layer.get_cell_source_id(coord)
	var kind: StringName = &""
	match src:
		TILE_SOURCE_SLIME: kind = &"slime"
		TILE_SOURCE_ACID: kind = &"acid"
		TILE_SOURCE_COBWEB: kind = &"cobweb"
		TILE_SOURCE_LAVA: kind = &"lava"
		_: kind = &""
	if kind != _current_tile_kind:
		if _current_tile_kind != &"":
			EventBus.player_exited_hazard_tile.emit(_current_tile_kind)
		_current_tile_kind = kind
		if kind != &"":
			EventBus.player_entered_hazard_tile.emit(kind)
	if kind == &"":
		return
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	var se := p.get_node_or_null("StatusEffects") as StatusEffects
	match kind:
		&"slime":
			# 10.24 — Slippery. Apply a one-tick slow + sideways drift.
			if se:
				se.apply(&"slow", 0.6, null, 0.4)
			p.velocity += Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		&"acid":
			# 10.25 — Acid damage tile. 4 dmg / 0.5s tick. Lava boots don't help.
			if hc and not hc.is_dead():
				hc.apply_damage(4, null, &"poison")
		&"cobweb":
			# 10.26 — Cobweb slow zone. 75% speed for 1s.
			if se:
				se.apply(&"slow", 1.0, null, 0.75)
		&"lava":
			# 11.4 / 10.30 — Lava tile. Skip damage if lava boots equipped.
			if Inventory.count_of(&"lava_boots") > 0:
				return
			if hc and not hc.is_dead():
				hc.apply_damage(8, null, &"fire")


# ---------------------------------------------------------------------------
# 10.27 — Vine wall-climb. While the player is in Verdancy AND a vine tile
# is at or adjacent to their position, treat the next wall they touch as
# climbable for 1 second. Implemented as a temporary phase-through that
# nudges them past the wall. Public hook so PlayerController/Doors can ask.
# ---------------------------------------------------------------------------


func can_climb_walls_here(world_pos: Vector2) -> bool:
	var wg: Node = get_tree().current_scene.get_node_or_null("WorldGen") if get_tree().current_scene else null
	if wg == null or not wg.has_method("biome_at"):
		return false
	var biome: BiomeDef = wg.call("biome_at", world_pos)
	return biome != null and biome.id == &"sunless_verdancy"


# ---------------------------------------------------------------------------
# 10.28 — Mushroom propagation. Called by glow_shroom placeable + the beat.
# ---------------------------------------------------------------------------


func _on_beat() -> void:
	_beat_counter += 1
	# Update boss cooldowns.
	for k in boss_cooldowns.keys():
		boss_cooldowns[k] = maxi(0, int(boss_cooldowns[k]) - 1)
		if boss_cooldowns[k] == 0:
			boss_respawn_ready.emit(k)
	# 10.41 — Verdancy aging.
	if GameState.has_defeated_boss(&"boss_auriax") and verdancy_age_beats < VERDANCY_TREE_DEATH_BEATS + 1:
		verdancy_age_beats += 1
		if verdancy_age_beats == VERDANCY_TREE_DEATH_BEATS:
			_trigger_verdancy_tree_death()
	# 10.28 propagation runs every PROPAGATE_BEATS.
	if _beat_counter % PROPAGATE_BEATS == 0:
		_tick_mushroom_propagation()


func _tick_mushroom_propagation() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for shroom in tree.get_nodes_in_group("glow_shroom"):
		if not is_instance_valid(shroom):
			continue
		var pos: Vector2 = (shroom as Node2D).global_position
		var key: String = "%d,%d" % [int(pos.x), int(pos.y)]
		var count: int = int(_propagation_counts.get(key, 0))
		if count >= MAX_PROPAGATED_PER_PARENT:
			continue
		# Verdancy-only.
		var wg: Node = get_tree().current_scene.get_node_or_null("WorldGen") if get_tree().current_scene else null
		if wg == null or not wg.has_method("biome_at"):
			continue
		var biome: BiomeDef = wg.call("biome_at", pos)
		if biome == null or biome.id != &"sunless_verdancy":
			continue
		# Roll: only 30% per parent per cycle.
		if randf() > 0.30:
			continue
		# Spawn a new glow_shroom one tile away in a random open direction.
		var dirs: Array[Vector2] = [Vector2(16,0), Vector2(-16,0), Vector2(0,16), Vector2(0,-16)]
		var spawn_pos: Vector2 = pos + dirs[randi() % 4]
		var scn := load("res://scenes/structures/glow_shroom.tscn") as PackedScene
		if scn == null:
			continue
		var inst := scn.instantiate() as Node2D
		if inst == null:
			continue
		inst.position = spawn_pos
		shroom.get_parent().add_child(inst)
		_propagation_counts[key] = count + 1


# ---------------------------------------------------------------------------
# 10.33 — Pheromone trail. Mobs broadcast on damage, peers in radius pick up.
# ---------------------------------------------------------------------------


func emit_pheromone(world_pos: Vector2, biome_id: StringName) -> void:
	_pheromone_marks.append({
		"pos": world_pos,
		"biome": biome_id,
		"time": PHEROMONE_LIFETIME_SECONDS,
	})


func _decay_pheromone(delta: float) -> void:
	for i in range(_pheromone_marks.size() - 1, -1, -1):
		_pheromone_marks[i]["time"] = float(_pheromone_marks[i]["time"]) - delta
		if float(_pheromone_marks[i]["time"]) <= 0.0:
			_pheromone_marks.remove_at(i)


func pheromone_present(world_pos: Vector2, biome_id: StringName) -> bool:
	for m in _pheromone_marks:
		if String(m.get("biome", "")) != String(biome_id):
			continue
		if Vector2(m.get("pos", Vector2.ZERO)).distance_to(world_pos) <= PHEROMONE_RADIUS_PX:
			return true
	return false


# ---------------------------------------------------------------------------
# 10.34 — Champion-affix bias.
# ---------------------------------------------------------------------------


func biome_affix_bias(biome_id: StringName) -> Array:
	return BIOME_AFFIX_BIAS.get(biome_id, [])


# ---------------------------------------------------------------------------
# 10.42 — Sunken Glyph Fragments — quest counter.
# ---------------------------------------------------------------------------


func register_sunken_glyph() -> void:
	sunken_glyph_fragments_collected = mini(sunken_glyph_fragments_collected + 1, SUNKEN_GLYPHS_TOTAL)
	if sunken_glyph_fragments_collected >= SUNKEN_GLYPHS_TOTAL:
		EventBus.ui_toast.emit("All seven Sunken Glyphs collected. The Hall of First Names awaits.", 4.0)
		lore_moments_fired[&"hall_of_first_names_unlocked"] = true
		trigger_lore_moment(&"hall_of_first_names_unlocked")


# ---------------------------------------------------------------------------
# Lore-moment dispatch (10.36-10.43, 10.46-10.47).
# ---------------------------------------------------------------------------


func trigger_lore_moment(moment_id: StringName) -> void:
	if lore_moments_fired.get(moment_id, false):
		return
	lore_moments_fired[moment_id] = true
	lore_moment_triggered.emit(moment_id)
	match moment_id:
		&"laughing_child_echo":
			# 10.37 — proximity-triggered when entering an Auriax approach chunk.
			EventBus.ui_toast.emit("A child's laughter drifts through the leaves.", 4.0)
		&"hall_of_first_names_unlocked":
			# 10.38 — Plays the 23s wait reveal. Triggered after fragment 7.
			EventBus.ui_toast.emit("The Hall of First Names unlocks in 23 seconds.", 5.0)
			var t := get_tree().create_timer(23.0, true, false, false)
			t.timeout.connect(func() -> void: EventBus.ui_toast.emit("The names rise.", 4.0))
		&"spawnmother_toy":
			# 10.39 — A no-pickup toy. Just a flavour toast on proximity.
			EventBus.ui_toast.emit("A child's wooden toy. Leave it where it sits.", 4.0)
		&"sythrenn_pacifist_mural_1":
			EventBus.ui_toast.emit("Mural: \"They came to forgive us.\"", 4.0)
		&"sythrenn_pacifist_mural_2":
			EventBus.ui_toast.emit("Mural: \"We could not stop ourselves.\"", 4.0)
		&"sythrenn_pacifist_mural_3":
			EventBus.ui_toast.emit("Mural: \"We laid the children among the roots.\"", 4.0)
		&"verdancy_named_tree_death":
			EventBus.ui_toast.emit("The named tree falls silent. The Verdancy keeps growing without it.", 5.0)
		&"verdancy_crop_survives":
			# 10.47 — A small mercy.
			EventBus.ui_toast.emit("One sprig of Verdancy still grows from the ash.", 4.0)
		&"underwater_echo_sailors":
			EventBus.ui_toast.emit("Ghostly sailors drift past — they cannot see you.", 4.0)


func _trigger_verdancy_tree_death() -> void:
	trigger_lore_moment(&"verdancy_named_tree_death")
	# 10.36 — schedule the crop-survives moment 30 beats later (10.47).
	var t := get_tree().create_timer(30.0 * 23.0, true, false, false)
	t.timeout.connect(func() -> void: trigger_lore_moment(&"verdancy_crop_survives"))


# ---------------------------------------------------------------------------
# 10.46 — Glow-Crane sub-quest helpers.
# ---------------------------------------------------------------------------


func unlock_glow_crane_quest() -> void:
	if glow_crane_quest_state != &"locked":
		return
	glow_crane_quest_state = &"active"
	EventBus.ui_toast.emit("Brindle: \"I'd pay for a few Glow-Crane feathers, if you find them.\"", 4.0)


func deliver_glow_crane_feathers(count: int) -> bool:
	if glow_crane_quest_state != &"active":
		return false
	glow_crane_feathers_delivered += count
	if glow_crane_feathers_delivered >= GLOW_CRANE_FEATHERS_REQUIRED:
		glow_crane_quest_state = &"done"
		Inventory.try_add(&"recipe_scroll", 1)
		Inventory.try_add(&"vorrkell_lantern", 1)
		EventBus.ui_toast.emit("Brindle slips you a recipe scroll and a strange brass lantern.", 5.0)
		return true
	return false


# ---------------------------------------------------------------------------
# 10.48 — Sythrenn spore-spread zones.
# ---------------------------------------------------------------------------


func _on_boss_engaged(boss_id: StringName) -> void:
	if boss_id == &"boss_sythrenn":
		sythrenn_active = true
	if boss_id == &"boss_drowned_crown":
		# 10.49 cinematic hook — boss engagement starts cinematic camera mode.
		EventBus.letterbox_requested.emit(true, 0.8)


func _on_biome_changed(_old_id: StringName, new_id: StringName) -> void:
	# 10.50 — apply reverb profile when crossing a biome.
	if BIOME_REVERB.has(new_id):
		# AudioBus reads this via apply_reverb_profile().
		if AudioBus and AudioBus.has_method("apply_reverb_profile"):
			AudioBus.call("apply_reverb_profile", BIOME_REVERB[new_id])
	# 10.37 — entering Verdancy near a defeated Auriax triggers the Echo.
	if new_id == &"sunless_verdancy" and GameState.has_defeated_boss(&"boss_auriax"):
		trigger_lore_moment(&"laughing_child_echo")
	# 10.43 — entering Drowned Aphelion triggers the underwater Echo sailors.
	if new_id == &"drowned_aphelion":
		trigger_lore_moment(&"underwater_echo_sailors")


func register_sythrenn_spore_zone(world_pos: Vector2) -> void:
	if not sythrenn_active:
		return
	if sythrenn_spore_zones.size() >= 6:
		return
	sythrenn_spore_zones.append(world_pos)


func _tick_sythrenn_spore_zones() -> void:
	if not sythrenn_active or sythrenn_spore_zones.is_empty():
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p == null:
		return
	for zone_pos in sythrenn_spore_zones:
		if p.global_position.distance_to(zone_pos) <= 48.0:
			var se := p.get_node_or_null("StatusEffects") as StatusEffects
			if se:
				se.apply(&"poison", 3.0, null, 1.0)
			break


# ---------------------------------------------------------------------------
# 10.49 — Boss-camera cinematic hook.
# ---------------------------------------------------------------------------


func cinematic_camera_for(boss_id: StringName, phase_index: int) -> Dictionary:
	var per_boss: Dictionary = BOSS_PHASE_CAMERA.get(boss_id, {})
	return per_boss.get(phase_index, {})


# ---------------------------------------------------------------------------
# mob_def_for(id) — used by world_gen + mob_spawner to resolve mob ids.
# ---------------------------------------------------------------------------


func mob_def_for(mob_id: StringName) -> MobDef:
	if _mob_def_cache.has(mob_id):
		return _mob_def_cache[mob_id]
	# Lazy scan resources/mobs/.
	var dir := DirAccess.open("res://resources/mobs/")
	if dir:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.ends_with(".tres"):
				var maybe: MobDef = load("res://resources/mobs/" + entry) as MobDef
				if maybe and maybe.id == mob_id:
					_mob_def_cache[mob_id] = maybe
					return maybe
			entry = dir.get_next()
		dir.list_dir_end()
	return null


# ---------------------------------------------------------------------------
# Persistence.
# ---------------------------------------------------------------------------


func dump_state() -> Dictionary:
	return {
		"boss_cooldowns": _stringify_keys(boss_cooldowns),
		"kill_counts": _stringify_keys(kill_counts),
		"awakened_available": _stringify_keys(awakened_available),
		"lore_moments_fired": _stringify_keys(lore_moments_fired),
		"verdancy_age_beats": verdancy_age_beats,
		"sunken_glyph_fragments_collected": sunken_glyph_fragments_collected,
		"glow_crane_quest_state": String(glow_crane_quest_state),
		"glow_crane_feathers_delivered": glow_crane_feathers_delivered,
		"beat_counter": _beat_counter,
	}


func restore_state(d: Dictionary) -> void:
	boss_cooldowns = _stringname_keys(d.get("boss_cooldowns", {}))
	kill_counts = _stringname_keys(d.get("kill_counts", {}))
	awakened_available = _stringname_keys(d.get("awakened_available", {}))
	lore_moments_fired = _stringname_keys(d.get("lore_moments_fired", {}))
	verdancy_age_beats = int(d.get("verdancy_age_beats", 0))
	sunken_glyph_fragments_collected = int(d.get("sunken_glyph_fragments_collected", 0))
	glow_crane_quest_state = StringName(String(d.get("glow_crane_quest_state", "locked")))
	glow_crane_feathers_delivered = int(d.get("glow_crane_feathers_delivered", 0))
	_beat_counter = int(d.get("beat_counter", 0))


func _stringify_keys(dd: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in dd.keys():
		out[String(k)] = dd[k]
	return out


func _stringname_keys(dd: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in dd.keys():
		out[StringName(String(k))] = dd[k]
	return out
