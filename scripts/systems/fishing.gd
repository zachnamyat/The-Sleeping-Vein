extends Node

## Phase 8 fishing. PlayerCombat calls `cast(player)` when the player swings
## with a fishing rod. We run a short minigame:
##   1. CAST  — line in the water, waiting for a bite.
##   2. HOOK  — bite window (a brief opportunity to click).
##   3. REEL  — hold attack_primary inside a wobbling bar to reel.
##
## Each rod tier has a faster cast + shorter hook window + opens new species.
## Bait in the off_hand slot biases the catch table (ticket 8.11 + 8.20).
## Net Trap (ticket 8.21) bypasses the minigame entirely and yields on a timer.

signal cast_started(seconds: float)
signal bite_started(window_seconds: float)
signal reel_started(target_position: float)
signal cast_resolved(caught_id: StringName)
signal cast_failed(reason: String)
signal minigame_state(stage: int, t01: float)   ## stage = 0..3, t01 = progress

enum Stage { IDLE, CAST, HOOK, REEL, RESOLVED }

const ROD_DATA: Dictionary = {
	&"fishing_rod_wood":   { "cast_seconds": 5.0, "hook_window": 1.20, "reel_difficulty": 1.0, "tier": 1 },
	&"fishing_rod_copper": { "cast_seconds": 4.0, "hook_window": 1.00, "reel_difficulty": 0.9, "tier": 2 },
	&"fishing_rod_iron":   { "cast_seconds": 3.0, "hook_window": 0.85, "reel_difficulty": 0.8, "tier": 3 },
	## Phase 8.26 — tier-4+ rods land alongside their biomes; data lives here so
	## the items can drop in without retouching this script.
	&"fishing_rod_scarlet":  { "cast_seconds": 2.5, "hook_window": 0.75, "reel_difficulty": 0.75, "tier": 4 },
	&"fishing_rod_octarine": { "cast_seconds": 2.2, "hook_window": 0.70, "reel_difficulty": 0.70, "tier": 5 },
	&"fishing_rod_galaxite": { "cast_seconds": 1.8, "hook_window": 0.60, "reel_difficulty": 0.65, "tier": 6 },
	&"fishing_rod_solarite": { "cast_seconds": 1.5, "hook_window": 0.55, "reel_difficulty": 0.60, "tier": 7 },
}

## Phase 8.12 — Fish list per biome. tier filters by rod power so beginner rods
## can't pull rare species. Weight is the relative pick frequency within the
## biome.
const BIOME_FISH: Dictionary = {
	&"root_hollows": [
		{ "id": &"cave_guppy",   "weight": 8.0, "rod_tier": 1 },
		{ "id": &"root_bream",   "weight": 3.0, "rod_tier": 2 },
		{ "id": &"glow_eel",     "weight": 1.0, "rod_tier": 3 },
	],
	&"glasswright_reaches": [
		{ "id": &"cave_guppy",   "weight": 5.0, "rod_tier": 1 },
		{ "id": &"lantern_glint","weight": 2.0, "rod_tier": 2 },
		{ "id": &"tide_perch",   "weight": 3.0, "rod_tier": 2 },
		{ "id": &"glass_pike",   "weight": 1.0, "rod_tier": 3 },
	],
	&"vesari_necropolis": [
		{ "id": &"salt_minnow",  "weight": 6.0, "rod_tier": 1 },
		{ "id": &"cave_guppy",   "weight": 2.0, "rod_tier": 1 },
		{ "id": &"vesari_eel",   "weight": 2.0, "rod_tier": 3 },
		{ "id": &"drowned_pearl","weight": 0.5, "rod_tier": 4 },
	],
	&"drowned_aphelion": [
		{ "id": &"salt_minnow",  "weight": 3.0, "rod_tier": 1 },
		{ "id": &"lantern_glint","weight": 3.0, "rod_tier": 2 },
		{ "id": &"deep_pike",    "weight": 2.0, "rod_tier": 3 },
		{ "id": &"drowned_pearl","weight": 1.0, "rod_tier": 4 },
	],
}

var _stage: int = Stage.IDLE
var _stage_t: float = 0.0
var _cast_seconds: float = 5.0
var _hook_window: float = 1.0
var _reel_difficulty: float = 1.0
var _reel_target: float = 0.5
var _reel_progress: float = 0.0
var _cast_player: Node2D
var _active_rod_id: StringName = &""
var _active_bait_id: StringName = &""


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _stage == Stage.IDLE or _stage == Stage.RESOLVED:
		return
	_stage_t += delta
	match _stage:
		Stage.CAST:
			minigame_state.emit(_stage, clampf(_stage_t / _cast_seconds, 0.0, 1.0))
			if _stage_t >= _cast_seconds:
				_enter_hook_stage()
		Stage.HOOK:
			minigame_state.emit(_stage, clampf(_stage_t / _hook_window, 0.0, 1.0))
			if _stage_t >= _hook_window:
				_miss("Bite missed.")
		Stage.REEL:
			# REEL phase: 2 seconds, player holds attack_primary inside the
			# wobble band (a 0..1 oscillator).
			_reel_target = 0.5 + 0.4 * sin(_stage_t * 4.5)
			if Input.is_action_pressed("attack_primary"):
				if absf(_reel_progress - _reel_target) < 0.18 * _reel_difficulty:
					_reel_progress = lerp(_reel_progress, _reel_target, 0.18)
				else:
					# Player jerks the rod — drift back.
					_reel_progress = lerp(_reel_progress, 0.2, 0.05)
			else:
				_reel_progress = lerp(_reel_progress, 0.2, 0.05)
			minigame_state.emit(_stage, _reel_progress)
			if _reel_progress > 0.92:
				_resolve_catch()
			if _stage_t > 3.5 * _reel_difficulty:
				_miss("Line snapped.")


func cast(player: Node2D) -> bool:
	if _stage != Stage.IDLE and _stage != Stage.RESOLVED:
		return false
	_cast_player = player
	# Determine which rod is held.
	_active_rod_id = _detect_rod()
	var rod_data: Dictionary = ROD_DATA.get(_active_rod_id, ROD_DATA[&"fishing_rod_wood"])
	_cast_seconds = float(rod_data.get("cast_seconds", 5.0))
	_hook_window = float(rod_data.get("hook_window", 1.0))
	_reel_difficulty = float(rod_data.get("reel_difficulty", 1.0))
	# Bait?
	_active_bait_id = _detect_bait()
	_stage = Stage.CAST
	_stage_t = 0.0
	cast_started.emit(_cast_seconds)
	EventBus.ui_toast.emit("[Cast — wait for bite]", _cast_seconds)
	return true


## Phase 8.10 — click-to-hook. Called by PlayerCombat when attack_primary is
## pressed while a cast is active in the HOOK window.
func try_hook() -> bool:
	if _stage != Stage.HOOK:
		return false
	_stage = Stage.REEL
	_stage_t = 0.0
	_reel_progress = 0.2
	reel_started.emit(0.5)
	EventBus.ui_toast.emit("Hooked! Reel inside the bar.", 1.2)
	return true


func _detect_rod() -> StringName:
	# Player's hotbar slot is the rod. If they're holding a non-rod we still
	# default to the wood rod for the data lookup.
	var hotbar := _find_hotbar()
	if hotbar:
		var iid: StringName = Inventory.get_hotbar_item(hotbar.selected_index)
		if ROD_DATA.has(iid):
			return iid
	for cand in ROD_DATA.keys():
		if Inventory.count_of(cand) > 0:
			return cand
	return &"fishing_rod_wood"


func _detect_bait() -> StringName:
	var off: StringName = StringName(Inventory.equipment.get(&"off_hand", &""))
	if FarmingSystem.BAIT_BONUS.has(off):
		return off
	return &""


func _find_hotbar() -> Hotbar:
	var nodes := get_tree().get_nodes_in_group("hotbar")
	if nodes.is_empty():
		return null
	return nodes[0] as Hotbar


func _enter_hook_stage() -> void:
	_stage = Stage.HOOK
	_stage_t = 0.0
	bite_started.emit(_hook_window)


func _miss(reason: String) -> void:
	_stage = Stage.RESOLVED
	cast_failed.emit(reason)
	EventBus.ui_toast.emit(reason, 1.5)


func _resolve_catch() -> void:
	_stage = Stage.RESOLVED
	if _cast_player == null or not is_instance_valid(_cast_player):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var worldgen := tree.current_scene.get_node_or_null("WorldGen") if tree and tree.current_scene else null
	var biome_id: StringName = &"root_hollows"
	if worldgen and worldgen.has_method("biome_at"):
		var biome: BiomeDef = worldgen.biome_at(_cast_player.global_position) as BiomeDef
		if biome:
			biome_id = biome.id
	var table: Array = BIOME_FISH.get(biome_id, BIOME_FISH[&"root_hollows"])
	var rod_data: Dictionary = ROD_DATA.get(_active_rod_id, ROD_DATA[&"fishing_rod_wood"])
	var rod_tier: int = int(rod_data.get("tier", 1))
	var bait_data: Dictionary = FarmingSystem.BAIT_BONUS.get(_active_bait_id, {})
	var rarity_bias: float = float(bait_data.get("rarity_bias", 0.0))
	var weight_mult: float = float(bait_data.get("weight_mult", 1.0))
	# Build a filtered + biased pool.
	var pool: Array = []
	var total: float = 0.0
	for entry in table:
		if int(entry.get("rod_tier", 1)) > rod_tier:
			continue
		var w: float = float(entry.get("weight", 1.0)) * weight_mult
		# Rarer = higher rod_tier; bias bumps it.
		w += rarity_bias * float(entry.get("rod_tier", 1)) * 2.0
		pool.append({ "id": StringName(entry.get("id", "")), "w": w })
		total += w
	if pool.is_empty() or total <= 0.0:
		_miss("No fish in these waters.")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: float = rng.randf() * total
	var cum: float = 0.0
	var caught: StringName = &""
	for entry in pool:
		cum += float(entry.w)
		if roll <= cum:
			caught = entry.id
			break
	if caught == &"":
		_miss("Line came up empty.")
		return
	# Consume one bait.
	if _active_bait_id != &"":
		Inventory.try_remove(_active_bait_id, 1)
	Inventory.try_add(caught, 1)
	cast_resolved.emit(caught)
	EventBus.skill_xp_gained.emit(&"skill_fishing", 4)
	# Phase 8.36 — record the biggest fish for trophy mounts.
	_update_trophy_record(caught)
	var defn: ItemDef = ItemRegistry.get_def(caught)
	EventBus.ui_toast.emit("Caught: %s" % (defn.display_name if defn else String(caught)), 2.0)


# Phase 8.36 — fish-to-trophy: keep the heaviest fish of each species.
var trophies: Dictionary = {}


func _update_trophy_record(fish_id: StringName) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var size_g: int = rng.randi_range(80, 360)
	var best: int = int(trophies.get(fish_id, 0))
	if size_g > best:
		trophies[fish_id] = size_g


# Phase 8.21 — Net Trap helper. Called by NetTrap.gd to roll a passive catch.
func net_trap_roll(biome_id: StringName) -> StringName:
	var table: Array = BIOME_FISH.get(biome_id, BIOME_FISH[&"root_hollows"])
	if table.is_empty():
		return &""
	var pool: Array = []
	var total: float = 0.0
	for entry in table:
		if int(entry.get("rod_tier", 1)) > 2:
			continue   # Net Trap only catches tier-1/2 fish.
		var w: float = float(entry.get("weight", 1.0))
		pool.append({ "id": StringName(entry.get("id", "")), "w": w })
		total += w
	if pool.is_empty() or total <= 0.0:
		return &""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: float = rng.randf() * total
	var cum: float = 0.0
	for entry in pool:
		cum += float(entry.w)
		if roll <= cum:
			return entry.id
	return StringName(pool[0].id)


# Phase 8.37 — fishing tournament. A 2-min event; score is fish caught * tier.
var tournament_active: bool = false
var tournament_seconds_remaining: float = 0.0
var tournament_score: int = 0


func start_tournament(duration: float = 120.0) -> void:
	tournament_active = true
	tournament_seconds_remaining = duration
	tournament_score = 0
	EventBus.ui_toast.emit("Fishing tournament! 2:00 on the clock.", 3.0)


func _record_tournament_catch(fish_id: StringName) -> void:
	if not tournament_active:
		return
	# Look up rod_tier of the fish across all biomes.
	for biome_table in BIOME_FISH.values():
		for entry in biome_table:
			if StringName(entry.get("id", "")) == fish_id:
				tournament_score += int(entry.get("rod_tier", 1))
				return


func is_active() -> bool:
	return _stage != Stage.IDLE and _stage != Stage.RESOLVED


func current_stage() -> int:
	return _stage
