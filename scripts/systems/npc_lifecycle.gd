extends Node

## Phase 9 — NpcLifecycle autoload. Holds per-NPC runtime state that does NOT
## belong in the scene tree (so it survives NPCs being instanced / freed):
##
##   - mood (0..100, drifts toward 50; weather / biome / world events tilt it)   (9.16, 9.21, 9.44)
##   - friendship (0..255 byte; gifts and quest completions grow it)             (9.16, 9.19)
##   - faction reputation (per-faction int; tinted by Walker world choices)      (9.60, 9.61)
##   - daily-quest log (slot per NPC + completion flag)                          (9.17, 9.18)
##   - flagged dialogue branches (Wormbound peace, Glaur-em killed, etc.)        (9.21, 9.45)
##   - last-bark timestamps (NPC voice barks throttle per-context)               (9.42, 9.45)
##
## All state is persisted by SaveSystem in `phase9_lifecycle`.
##
## Public signals other systems can listen to:
##   - friendship_changed(npc_id, new_value)
##   - reputation_changed(faction_id, new_value)
##   - quest_state_changed(quest_id, new_state)
##   - quest_completed(quest_id)
##   - daily_reset(new_day_index)

signal friendship_changed(npc_id: StringName, new_value: int)
signal reputation_changed(faction_id: StringName, new_value: int)
signal quest_state_changed(quest_id: StringName, new_state: String)
signal quest_completed(quest_id: StringName)
signal daily_reset(new_day_index: int)
signal npc_mood_changed(npc_id: StringName, new_mood: int)

const FRIENDSHIP_MAX: int = 255
const FRIENDSHIP_GIFT_FAVORITE: int = 24
const FRIENDSHIP_GIFT_GOOD: int = 12
const FRIENDSHIP_GIFT_NEUTRAL: int = 4
const FRIENDSHIP_GIFT_HATED: int = -10
const REPUTATION_MAX: int = 1000

## Per-NPC favorite/hated gift items (gift-giving 9.19).
const GIFT_PREFERENCES: Dictionary = {
	&"npc_aelstren":     { "favorite": [&"lore_tablet", &"map_fragment"], "hated": [&"raw_meat"] },
	&"npc_brindle":      { "favorite": [&"shaleseed", &"glaurem_jerky"], "hated": [&"glow_cap"] },
	&"npc_mira":         { "favorite": [&"aphelion_fragment", &"photograph"], "hated": [&"bomb"] },
	&"npc_cantor":       { "favorite": [&"glow_tube", &"recipe_scroll"], "hated": [&"loambeetle"] },
	&"npc_old_hask":     { "favorite": [&"deep_pike", &"drowned_pearl"], "hated": [&"flour"] },
	&"npc_veiled_buyer": { "favorite": [&"glaurem_trinket", &"aphelion_fragment"], "hated": [] },
}

## NPC faction membership for reputation hooks (9.60/9.61).
const NPC_FACTIONS: Dictionary = {
	&"npc_aelstren":     &"faction_chartwrights",
	&"npc_brindle":      &"faction_pyrenkin",
	&"npc_mira":         &"faction_outcasts",
	&"npc_cantor":       &"faction_five_bells",
	&"npc_old_hask":     &"faction_drowned",
	&"npc_veiled_buyer": &"faction_diadem_hidden",
}

## Each merchant has a *preferred biome*; mood drifts up when at Anchor in the
## right biome ring (9.44).
const NPC_PREFERRED_BIOME: Dictionary = {
	&"npc_aelstren":     &"biome_root_hollows",
	&"npc_brindle":      &"biome_glasswright_reaches",
	&"npc_mira":         &"biome_root_hollows",
	&"npc_cantor":       &"biome_vesari_necropolis",
	&"npc_old_hask":     &"biome_drowned_aphelion",
	&"npc_veiled_buyer": &"biome_root_hollows",
}

## Day-of-Aphelion length in real seconds (matches DayNightCycle 24-min clock).
const APHELION_DAY_SECONDS: int = 24 * 60

## Persistent state.
var friendship: Dictionary = {}   ## { npc_id -> 0..255 }
var npc_mood: Dictionary = {}     ## { npc_id -> 0..100 }
var faction_reputation: Dictionary = {}  ## { faction_id -> -1000..1000 }
var quest_states: Dictionary = {}        ## { quest_id -> "available" | "active" | "complete" | "claimed" }
var quest_progress: Dictionary = {}      ## { quest_id -> Dictionary of progress counters }
var flagged_branches: Dictionary = {}    ## { flag_id (StringName) -> bool }
var last_bark_unix: Dictionary = {}      ## { "<npc_id>:<context>" -> unix }
var day_index: int = 0
var last_aphelion_day_seen_unix: int = 0
var daily_quests_today: Array[StringName] = []
var seasonal_phase: StringName = &"phase_dawn"  ## one of phase_dawn, phase_noon, phase_dusk, phase_long_night

const SEASONAL_PHASES: Array[StringName] = [
	&"phase_dawn", &"phase_noon", &"phase_dusk", &"phase_long_night",
]


func _ready() -> void:
	# Seed defaults so getters don't have to special-case missing keys.
	for npc in GIFT_PREFERENCES.keys():
		friendship[npc] = friendship.get(npc, 32)
		npc_mood[npc] = npc_mood.get(npc, 50)
	# Tick the day clock every 30s (cheap; the actual rollover check is unix-time based).
	var t := Timer.new()
	t.wait_time = 30.0
	t.autostart = true
	t.one_shot = false
	add_child(t)
	t.timeout.connect(_tick_day)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.biome_changed.connect(_on_biome_changed)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.chunk_visited.connect(_on_chunk_visited)


func _on_entity_killed(entity: Node, killer: Node) -> void:
	if killer == null or not killer.is_in_group("player"):
		return
	# Hollowling = any mob in the Hollowling family. For Phase 9 we accept any
	# mob-group entity as a "Hollowling" for quest purposes.
	if entity and entity.is_in_group("mob"):
		record_quest_progress(&"quest_kill_10_hollowlings", 1)


func _on_item_picked_up(item_id: StringName, count: int) -> void:
	if item_id == &"shaleseed":
		record_quest_progress(&"quest_mine_15_shaleseed", count)
	elif item_id == &"glow_cap":
		record_quest_progress(&"quest_collect_3_glow_caps", count)
	elif item_id in [&"cave_guppy", &"glow_eel", &"glass_pike", &"deep_pike"]:
		record_quest_progress(&"quest_catch_5_fish", count)


func _on_item_crafted(item_id: StringName, count: int) -> void:
	record_quest_progress(&"quest_craft_5_items", count)
	if item_id == &"shaleseed_ingot":
		set_flag(&"first_ingot_crafted", true)


func _on_chunk_visited(_chunk_coord: Vector2i, _biome_id: StringName) -> void:
	record_quest_progress(&"quest_explore_4_chunks", 1)


# ----- Friendship / gift-giving (9.16, 9.19) -----

func gift_item(npc_id: StringName, item_id: StringName) -> int:
	## Returns friendship delta applied. 0 means item rejected (gift cooldown
	## already used today).
	var key := StringName("%s_today" % String(npc_id))
	if bool(flagged_branches.get(key, false)):
		EventBus.ui_toast.emit("They've already accepted a gift today.", 2.0)
		return 0
	var prefs: Dictionary = GIFT_PREFERENCES.get(npc_id, {})
	var favorites: Array = prefs.get("favorite", [])
	var hateds: Array = prefs.get("hated", [])
	var delta: int
	if hateds.has(item_id):
		delta = FRIENDSHIP_GIFT_HATED
	elif favorites.has(item_id):
		delta = FRIENDSHIP_GIFT_FAVORITE
	else:
		var defn: ItemDef = ItemRegistry.get_def(item_id)
		if defn == null:
			return 0
		# Higher-rarity items count as "good" gifts.
		delta = FRIENDSHIP_GIFT_GOOD if defn.rarity >= 2 else FRIENDSHIP_GIFT_NEUTRAL
	add_friendship(npc_id, delta)
	flagged_branches[key] = true  # cleared on daily reset
	npc_mood[npc_id] = clampi(int(npc_mood.get(npc_id, 50)) + (15 if delta > 0 else -15), 0, 100)
	npc_mood_changed.emit(npc_id, int(npc_mood[npc_id]))
	if delta > 0:
		EventBus.ui_toast.emit("They smile faintly.", 2.0)
	else:
		EventBus.ui_toast.emit("They look away.", 2.0)
	return delta


func add_friendship(npc_id: StringName, delta: int) -> int:
	var current: int = int(friendship.get(npc_id, 0))
	current = clampi(current + delta, 0, FRIENDSHIP_MAX)
	friendship[npc_id] = current
	friendship_changed.emit(npc_id, current)
	_check_gift_thresholds(npc_id, current)
	return current


# Phase 9.50/9.51/9.53/9.59 — NPC gift thresholds. When friendship crosses
# these, the NPC pushes a relic to the player.
const GIFT_THRESHOLDS: Dictionary = {
	&"npc_brindle":  { 120: &"brindle_pendant" },
	&"npc_old_hask": { 90: &"small_fishhook" },
	&"npc_mira":     { 150: &"map_fragment" },
	&"npc_aelstren": { 60: &"map_fragment" },
}


func _check_gift_thresholds(npc_id: StringName, current: int) -> void:
	var table: Dictionary = GIFT_THRESHOLDS.get(npc_id, {})
	if table.is_empty():
		return
	for threshold in table.keys():
		if current < int(threshold):
			continue
		var item_id: StringName = StringName(String(table[threshold]))
		var key := StringName("gifted_%s_%s" % [String(npc_id), String(item_id)])
		if get_flag(key):
			continue
		set_flag(key, true)
		if Inventory:
			Inventory.try_add(item_id, 1)
		EventBus.ui_toast.emit("%s gives you a gift." % String(npc_id).replace("npc_", "").capitalize(), 3.0)


func get_friendship(npc_id: StringName) -> int:
	return int(friendship.get(npc_id, 0))


func get_mood(npc_id: StringName) -> int:
	return int(npc_mood.get(npc_id, 50))


func set_mood(npc_id: StringName, value: int) -> void:
	var clamped: int = clampi(value, 0, 100)
	npc_mood[npc_id] = clamped
	npc_mood_changed.emit(npc_id, clamped)


## Phase 9.21 — dialogue mood category for branching: "happy" >= 65, "sad" <= 35,
## otherwise "neutral".
func mood_category(npc_id: StringName) -> StringName:
	var m := get_mood(npc_id)
	if m >= 65:
		return &"happy"
	if m <= 35:
		return &"sad"
	return &"neutral"


# ----- Faction reputation (9.60, 9.61) -----

func add_reputation(faction_id: StringName, delta: int) -> int:
	var current: int = int(faction_reputation.get(faction_id, 0))
	current = clampi(current + delta, -REPUTATION_MAX, REPUTATION_MAX)
	faction_reputation[faction_id] = current
	reputation_changed.emit(faction_id, current)
	return current


func get_reputation(faction_id: StringName) -> int:
	return int(faction_reputation.get(faction_id, 0))


## Phase 9.61 — reputation also bumps trade prices: 1.0 at 0 rep, -10% at 500,
## +10% at -500. Linear, clamped.
func price_multiplier_for_reputation(faction_id: StringName) -> float:
	var rep: int = get_reputation(faction_id)
	return clampf(1.0 - float(rep) * 0.0002, 0.6, 1.6)


# ----- Quests & daily reset (9.17, 9.18) -----

const DAILY_QUEST_POOL: Array[Dictionary] = [
	{ "id": &"quest_kill_10_hollowlings", "label": "Cull 10 Hollowlings", "goal": 10, "reward_coins": 35 },
	{ "id": &"quest_mine_15_shaleseed",   "label": "Mine 15 Shaleseed",   "goal": 15, "reward_coins": 30 },
	{ "id": &"quest_cook_3_meals",        "label": "Cook 3 meals",        "goal": 3,  "reward_coins": 25 },
	{ "id": &"quest_catch_5_fish",        "label": "Catch 5 fish",        "goal": 5,  "reward_coins": 30 },
	{ "id": &"quest_collect_3_glow_caps", "label": "Pick 3 Glow Caps",    "goal": 3,  "reward_coins": 20 },
	{ "id": &"quest_explore_4_chunks",    "label": "Scout 4 new chunks",  "goal": 4,  "reward_coins": 30 },
	{ "id": &"quest_craft_5_items",       "label": "Craft 5 items",       "goal": 5,  "reward_coins": 30 },
]


func _tick_day() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	if last_aphelion_day_seen_unix == 0:
		last_aphelion_day_seen_unix = now
		_assign_new_daily()
		return
	if now - last_aphelion_day_seen_unix >= APHELION_DAY_SECONDS:
		_perform_daily_reset(now)


func _perform_daily_reset(now: int) -> void:
	day_index += 1
	last_aphelion_day_seen_unix = now
	# Cycle seasonal phase index (drives 9.30 special inventory).
	var idx: int = SEASONAL_PHASES.find(seasonal_phase)
	if idx < 0:
		idx = 0
	idx = (idx + 1) % SEASONAL_PHASES.size()
	seasonal_phase = SEASONAL_PHASES[idx]
	# Clear daily-gift flags, re-roll daily-quest pool.
	var to_drop: Array = []
	for k in flagged_branches.keys():
		var s := String(k)
		if s.ends_with("_today"):
			to_drop.append(k)
	for k in to_drop:
		flagged_branches.erase(k)
	_assign_new_daily()
	daily_reset.emit(day_index)


func _assign_new_daily() -> void:
	daily_quests_today.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) ^ day_index
	var pool: Array = DAILY_QUEST_POOL.duplicate()
	pool.shuffle()
	for i in range(mini(3, pool.size())):
		var q: Dictionary = pool[i]
		var qid: StringName = q.get("id", &"")
		daily_quests_today.append(qid)
		quest_states[qid] = "active"
		quest_progress[qid] = { "current": 0, "goal": int(q.get("goal", 1)) }
		quest_state_changed.emit(qid, "active")


func quest_progress_lookup(quest_id: StringName) -> Dictionary:
	return quest_progress.get(quest_id, {})


func record_quest_progress(quest_id: StringName, amount: int = 1) -> void:
	if not quest_states.has(quest_id):
		return
	if String(quest_states[quest_id]) != "active":
		return
	var rec: Dictionary = quest_progress.get(quest_id, {"current": 0, "goal": 1})
	rec["current"] = int(rec.get("current", 0)) + amount
	quest_progress[quest_id] = rec
	if int(rec["current"]) >= int(rec.get("goal", 1)):
		quest_states[quest_id] = "complete"
		quest_state_changed.emit(quest_id, "complete")
		quest_completed.emit(quest_id)
		var reward: int = _reward_for(quest_id)
		Inventory.try_add(&"ancient_coin", reward)
		EventBus.ui_toast.emit("Daily quest done: +%dc" % reward, 2.5)


func _reward_for(quest_id: StringName) -> int:
	for q in DAILY_QUEST_POOL:
		if StringName(q.get("id", &"")) == quest_id:
			return int(q.get("reward_coins", 0))
	return 0


func get_today_quests() -> Array[StringName]:
	return daily_quests_today


# ----- Branch flags (9.21, 9.45, 9.54) -----

func set_flag(flag: StringName, value: bool = true) -> void:
	flagged_branches[flag] = value


func get_flag(flag: StringName) -> bool:
	return bool(flagged_branches.get(flag, false))


# ----- Barks / contextual lines throttle (9.42) -----

const BARK_COOLDOWN: int = 25


func can_bark(npc_id: StringName, context: StringName) -> bool:
	var key := "%s:%s" % [String(npc_id), String(context)]
	var now: int = int(Time.get_unix_time_from_system())
	var last: int = int(last_bark_unix.get(key, 0))
	if now - last < BARK_COOLDOWN:
		return false
	last_bark_unix[key] = now
	return true


# ----- Event-driven hooks (9.21, 9.44, 9.45) -----

func _on_boss_defeated(boss_id: StringName) -> void:
	# Boss kills add a small mood bump to allied NPCs.
	for npc in npc_mood.keys():
		npc_mood[npc] = clampi(int(npc_mood[npc]) + 8, 0, 100)
		npc_mood_changed.emit(npc, int(npc_mood[npc]))
	# Phase 9.45 hook: store who the NPCs should pause-and-comment about.
	set_flag(StringName("comment_pending:%s" % String(boss_id)), true)


func _on_biome_changed(_old_biome: StringName, new_biome: StringName) -> void:
	# Phase 9.44: bump mood for NPCs whose preferred biome matches new biome.
	for npc_id in NPC_PREFERRED_BIOME.keys():
		var biome: StringName = NPC_PREFERRED_BIOME[npc_id]
		var delta: int = 4 if biome == new_biome else -2
		npc_mood[npc_id] = clampi(int(npc_mood.get(npc_id, 50)) + delta, 0, 100)
		npc_mood_changed.emit(npc_id, int(npc_mood[npc_id]))


# ----- Save round-trip -----

func dump_state() -> Dictionary:
	return {
		"friendship": _stringify(friendship),
		"npc_mood": _stringify(npc_mood),
		"faction_reputation": _stringify(faction_reputation),
		"quest_states": _stringify(quest_states),
		"quest_progress": _stringify(quest_progress),
		"flagged_branches": _stringify(flagged_branches),
		"last_bark_unix": last_bark_unix.duplicate(),
		"day_index": day_index,
		"last_aphelion_day_seen_unix": last_aphelion_day_seen_unix,
		"daily_quests_today": _stringify_arr(daily_quests_today),
		"seasonal_phase": String(seasonal_phase),
	}


func restore_state(d: Dictionary) -> void:
	friendship = _restore_int_keys(d.get("friendship", {}))
	npc_mood = _restore_int_keys(d.get("npc_mood", {}))
	faction_reputation = _restore_int_keys(d.get("faction_reputation", {}))
	quest_states = _restore_string_keys(d.get("quest_states", {}))
	quest_progress = _restore_dict_keys(d.get("quest_progress", {}))
	flagged_branches = _restore_bool_keys(d.get("flagged_branches", {}))
	last_bark_unix = d.get("last_bark_unix", {}).duplicate()
	day_index = int(d.get("day_index", 0))
	last_aphelion_day_seen_unix = int(d.get("last_aphelion_day_seen_unix", 0))
	daily_quests_today.clear()
	for q in d.get("daily_quests_today", []):
		daily_quests_today.append(StringName(String(q)))
	seasonal_phase = StringName(String(d.get("seasonal_phase", "phase_dawn")))


func _stringify(dict_in: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in dict_in.keys():
		out[String(k)] = dict_in[k]
	return out


func _stringify_arr(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(String(v))
	return out


func _restore_int_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = int(d[k])
	return out


func _restore_string_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = String(d[k])
	return out


func _restore_bool_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = bool(d[k])
	return out


func _restore_dict_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = (d[k] as Dictionary).duplicate()
	return out
