extends Node

## Phase 15 — Polish & Parity Gap Closure helper autoload.
## Coordinates ship-quality polish state across many small systems that each
## need a tiny slice of save-persisted memory. Specifically:
##
## • Difficulty preset + hardcore flag (15.38 / 15.39)
## • Run history (15.48) — last 16 runs with playtime / deaths / bosses
## • World statistics page (15.47) — per-world running tally
## • Speedrun timer + splits (15.28)
## • Boss-rush + endless + daily/weekly challenge state (15.29-15.31)
## • Photo-mode last-snapshot path + filter (15.22)
## • Tutorial-completion + first-boss-kill rewards (15.68)
## • Login streak (15.49)
## • Easter-egg / hidden-room discovery log (15.57)
## • Anniversary + Winter + Halloween + yearly seasonal events (15.6 / 15.58)
## • Damage-breakdown frame buffer for post-boss screen (15.40)
## • Cheat-detection (disable Steam achievements if console used) (15.35)
## • Combo counter + last-damage source for the death recap (2.26 / 2.39)
## • New-Game+ inheritance rule set (15.94)
## • Cloud-save sync timestamps (15.12) — local-only stub
## • Beta-branch flag (15.50)
## • Hidden-achievement reveal state (15.41)
## • World template / preset starting kit (15.34)
## • Multi-character per world (15.33)
## • Run history-log row addition + clamp.
##
## State is restorable via dump_state / restore_state so SaveSystem v13 can
## persist a single phase15_helpers dict and not balloon the file.

# ---------- Constants ----------

const RUN_HISTORY_MAX: int = 16
const SPEEDRUN_SPLIT_MAX: int = 32
const COMBO_DECAY_SECONDS: float = 3.0
const TUTORIAL_REWARD_COINS: int = 50
const FIRST_BOSS_REWARD_COINS: int = 100
const EASTER_EGG_MAX_LOG: int = 32

## Difficulty presets — drives mob damage / mob HP / loot quantity multipliers
## and toggles whether achievements are disabled.
const DIFFICULTY_PRESETS: Dictionary = {
	&"casual": {
		"label": "Casual",
		"player_damage_mult": 1.25,
		"mob_damage_mult": 0.6,
		"mob_hp_mult": 0.8,
		"loot_drop_mult": 1.25,
		"achievements_enabled": true,
	},
	&"normal": {
		"label": "Normal",
		"player_damage_mult": 1.0,
		"mob_damage_mult": 1.0,
		"mob_hp_mult": 1.0,
		"loot_drop_mult": 1.0,
		"achievements_enabled": true,
	},
	&"hard": {
		"label": "Hard",
		"player_damage_mult": 0.85,
		"mob_damage_mult": 1.3,
		"mob_hp_mult": 1.5,
		"loot_drop_mult": 1.1,
		"achievements_enabled": true,
	},
	&"hard_plus": {
		"label": "Hard+",
		"player_damage_mult": 0.7,
		"mob_damage_mult": 1.6,
		"mob_hp_mult": 2.0,
		"loot_drop_mult": 1.25,
		"achievements_enabled": true,
	},
}

## Seasonal events — 7-day windows around real-world dates. Anniversary is the
## game's launch month (set to May to match our 2026-05-12 milestone).
const SEASONAL_EVENTS: Dictionary = {
	&"halloween": { "start_month": 10, "start_day": 25, "end_month": 11, "end_day": 7 },
	&"winter":    { "start_month": 12, "start_day": 18, "end_month": 1,  "end_day": 7 },
	&"anniversary": { "start_month": 5, "start_day": 9, "end_month": 5,  "end_day": 19 },
}

## NG+ inheritance rule set. Each key is a GameState field; value is bool
## `carry_over` — when true, the value survives a New Game+ reset.
const NG_PLUS_INHERITANCE: Dictionary = {
	&"sovereign_threads": true,
	&"unlocked_compendium": true,
	&"unlocked_recipes": false,
	&"defeated_bosses": false,
	&"aphelion_slivers_remaining": false,
	&"collected_relics": false,
	&"arrived_npcs": false,
	&"allocated_talent_nodes": true,
	&"unallocated_talent_points": true,
	&"explored_chunks": false,
	&"talent_presets": true,
	&"ng_plus_cycles": true,
	&"character_name": true,
	&"character_template": true,
	&"character_hair": true,
	&"character_skin": true,
	&"character_outfit": true,
}

## Easter-egg + hidden-room registry. Each entry is {id, biome, hint}. The
## player discovers them via the Easter-Egg trigger volumes; flag persists.
const EASTER_EGGS: Array[Dictionary] = [
	{ "id": &"egg_dev_credits", "biome": &"root_hollows", "hint": "A wall with too many names." },
	{ "id": &"egg_secret_loot", "biome": &"glasswright_reaches", "hint": "A statue with a hollow chest." },
	{ "id": &"egg_listening_post", "biome": &"vesari_necropolis", "hint": "A bell that rings only in night." },
	{ "id": &"egg_lonesome_pet", "biome": &"sunless_verdancy", "hint": "A stuffed toy in deep grass." },
	{ "id": &"egg_glow_pit", "biome": &"drowned_aphelion", "hint": "A drowned room with a working torch." },
	{ "id": &"egg_forge_echo", "biome": &"emberforge", "hint": "Hammering you can't see." },
	{ "id": &"egg_salt_seer", "biome": &"salt_wastes", "hint": "A salt-block that hums." },
	{ "id": &"egg_aurora_door", "biome": &"auroric_veil", "hint": "Frost flowers in a cave." },
	{ "id": &"egg_unspoken_name", "biome": &"final_spiral", "hint": "A page with one syllable left." },
]

# ---------- Signals ----------

signal difficulty_changed(preset: StringName)
signal hardcore_toggled(active: bool)
signal speedrun_started()
signal speedrun_split_added(split_index: int, seconds: float, label: String)
signal speedrun_finished(total_seconds: float)
signal run_history_added(record: Dictionary)
signal photo_mode_toggled(active: bool)
signal cheat_detected_lockout()
signal easter_egg_discovered(id: StringName)
signal seasonal_event_started(event_id: StringName)
signal seasonal_event_ended(event_id: StringName)
signal first_boss_reward_granted()
signal tutorial_reward_granted()
signal combo_changed(count: int)
signal world_stats_changed()
signal cloud_sync_state_changed(state: StringName)

# ---------- Runtime state ----------

# World difficulty + hardcore.
var difficulty_preset: StringName = &"normal"
var hardcore_active: bool = false   # 15.38 permadeath rules
var world_size_mult: float = 1.0    # 15.5
var creative_mode: bool = false     # 15.5

# Run timing & history.
var current_run_started_unix: int = 0
var current_run_playtime_seconds: int = 0
var current_run_deaths: int = 0
var run_history: Array[Dictionary] = []

# World statistics — pure cumulative counters.
var world_stats: Dictionary = {
	&"tiles_mined": 0,
	&"distance_walked_px": 0,
	&"damage_dealt": 0,
	&"damage_taken": 0,
	&"items_picked_up": 0,
	&"items_crafted": 0,
	&"food_eaten": 0,
	&"fish_caught": 0,
	&"crops_harvested": 0,
	&"mobs_killed": 0,
	&"bosses_defeated": 0,
	&"chests_opened": 0,
	&"slivers_lost": 0,
	&"days_passed": 0,
}

# Combo + last-damage source (death recap).
var combo_counter: int = 0
var combo_max: int = 0
var _last_hit_at_ms: int = 0
var last_damage_source: String = ""

# Damage-breakdown frame buffer (per-boss). Cleared on boss_engaged.
var damage_breakdown_active: bool = false
var damage_breakdown: Dictionary = {
	&"dps_peak": 0.0,
	&"dps_avg": 0.0,
	&"hits_taken": 0,
	&"dodges": 0,
	&"crits_landed": 0,
	&"highest_single_hit": 0,
	&"damage_dealt": 0,
	&"damage_taken": 0,
	&"duration_seconds": 0.0,
}
var _dps_samples: PackedFloat32Array = PackedFloat32Array()
var _boss_engagement_started_at_ms: int = 0

# Speedrun timer + splits.
var speedrun_active: bool = false
var speedrun_started_ms: int = 0
var speedrun_paused_seconds: float = 0.0
var speedrun_splits: Array[Dictionary] = []   # [{label, seconds_total, seconds_since_prev}, ...]

# Boss-rush + endless mode.
var boss_rush_active: bool = false
var boss_rush_progress: int = 0
var endless_mode_active: bool = false
var endless_floor: int = 0

# Challenge mode (15.29).
var challenge_seed: int = 0
var challenge_window_iso: String = ""
var challenge_active: bool = false

# Photo mode (15.22).
var photo_mode_active: bool = false
var photo_filter: StringName = &"none"   # none | sepia | bw | aurora | aphelion | final
var photo_last_path: String = ""

# First-boss / tutorial rewards.
var tutorial_reward_granted_flag: bool = false
var first_boss_reward_granted_flag: bool = false

# Login streak (15.49).
var last_login_iso: String = ""
var login_streak_days: int = 0
var streak_reward_pending: bool = false

# Easter eggs.
var discovered_eggs: Dictionary = {}   # egg_id -> bool

# Active seasonal events (computed on _ready + every minute).
var active_seasonal_events: Dictionary = {}   # event_id -> bool

# Cheat-detection: when DevConsole has been opened at any point this run,
# Steam achievements are blocked (15.35). Reset on new game.
var console_was_used: bool = false

# Cloud-save state (15.12 — Steam Cloud / EOS local stub).
var cloud_last_sync_unix: int = 0
var cloud_last_sync_state: StringName = &"idle"   # idle | syncing | ok | conflict | offline

# Multi-character per world (15.33).
var characters_per_world: Dictionary = {}   # world_id -> [character_id, ...]

# Beta branch flag (15.50).
var on_beta_branch: bool = false

# World template / preset starting kit (15.34).
var starting_kit_id: StringName = &""

# Hidden-achievement reveal state (15.41).
var hidden_achievement_revealed: Dictionary = {}   # ach_id -> bool

# Demo / free-trial gate (15.84). When true, content past the first boss is locked.
var demo_build: bool = false

# 15.94 NG+ inheritance overrides — user can flip carry_over flags per save.
var ng_plus_inheritance_overrides: Dictionary = {}

# Internal ticker
var _seasonal_check_accum: float = 0.0
var _playtime_accum: float = 0.0


func _ready() -> void:
	# Subscribe to gameplay signals for stats + combo + damage breakdown.
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_engaged.connect(_on_boss_engaged)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.aphelion_dimmed.connect(_on_sliver_lost)

	# Start a run timer; consumed by run history on completion.
	if current_run_started_unix == 0:
		current_run_started_unix = Time.get_unix_time_from_system()

	_refresh_seasonal_events()
	_check_login_streak()
	set_process(true)


func _process(delta: float) -> void:
	# Playtime ticker — accumulate float, push to seconds counter on whole-second.
	_playtime_accum += delta
	if _playtime_accum >= 1.0:
		var whole: int = int(floor(_playtime_accum))
		_playtime_accum -= float(whole)
		current_run_playtime_seconds += whole

	# Combo decay.
	if combo_counter > 0:
		var now: int = Time.get_ticks_msec()
		if now - _last_hit_at_ms > int(COMBO_DECAY_SECONDS * 1000.0):
			_set_combo(0)

	# Speedrun timer is sampled on read; nothing to do here.

	# Seasonal-event check every 60 s.
	_seasonal_check_accum += delta
	if _seasonal_check_accum >= 60.0:
		_seasonal_check_accum = 0.0
		_refresh_seasonal_events()

	# Damage-breakdown DPS sampling (every 1.0 s while engaged).
	if damage_breakdown_active:
		_dps_samples.append(float(damage_breakdown[&"damage_dealt"]))
		if _dps_samples.size() > 60:
			_dps_samples.remove_at(0)


# ---------- Difficulty ----------

func set_difficulty(preset: StringName) -> bool:
	if not DIFFICULTY_PRESETS.has(preset):
		return false
	difficulty_preset = preset
	difficulty_changed.emit(preset)
	return true


func difficulty_record() -> Dictionary:
	return DIFFICULTY_PRESETS.get(difficulty_preset, DIFFICULTY_PRESETS[&"normal"])


func player_damage_mult() -> float:
	return float(difficulty_record().get("player_damage_mult", 1.0))


func mob_damage_mult() -> float:
	return float(difficulty_record().get("mob_damage_mult", 1.0))


func mob_hp_mult() -> float:
	return float(difficulty_record().get("mob_hp_mult", 1.0))


func loot_drop_mult() -> float:
	return float(difficulty_record().get("loot_drop_mult", 1.0))


func achievements_enabled() -> bool:
	if console_was_used:
		return false
	if not bool(difficulty_record().get("achievements_enabled", true)):
		return false
	return true


# ---------- Hardcore (15.38) ----------

func set_hardcore(enabled: bool) -> void:
	hardcore_active = enabled
	hardcore_toggled.emit(enabled)


# ---------- Speedrun timer (15.28) ----------

func speedrun_start() -> void:
	speedrun_active = true
	speedrun_started_ms = Time.get_ticks_msec()
	speedrun_paused_seconds = 0.0
	speedrun_splits.clear()
	speedrun_started.emit()


func speedrun_elapsed_seconds() -> float:
	if not speedrun_active:
		return 0.0
	return float(Time.get_ticks_msec() - speedrun_started_ms) / 1000.0


func speedrun_add_split(label: String) -> void:
	if not speedrun_active or speedrun_splits.size() >= SPEEDRUN_SPLIT_MAX:
		return
	var total: float = speedrun_elapsed_seconds()
	var prev: float = 0.0
	if not speedrun_splits.is_empty():
		prev = float(speedrun_splits[-1].get("seconds_total", 0.0))
	speedrun_splits.append({
		"label": label,
		"seconds_total": total,
		"seconds_since_prev": total - prev,
	})
	speedrun_split_added.emit(speedrun_splits.size() - 1, total, label)


func speedrun_stop() -> float:
	if not speedrun_active:
		return 0.0
	var total: float = speedrun_elapsed_seconds()
	speedrun_active = false
	speedrun_finished.emit(total)
	return total


# ---------- Boss-rush + endless + challenge ----------

func boss_rush_start() -> void:
	boss_rush_active = true
	boss_rush_progress = 0


func boss_rush_record_kill() -> void:
	if boss_rush_active:
		boss_rush_progress += 1


func endless_start() -> void:
	endless_mode_active = true
	endless_floor = 1


func endless_descend() -> int:
	if not endless_mode_active:
		return 0
	endless_floor += 1
	return endless_floor


func challenge_start(seed_value: int, window_iso: String) -> void:
	challenge_seed = seed_value
	challenge_window_iso = window_iso
	challenge_active = true


func challenge_seed_for_today() -> int:
	var iso: String = Time.get_date_string_from_system()
	return int(iso.hash()) ^ 0x534C5650   # "SLVP" sleeping-vein-phase


func challenge_seed_for_week() -> int:
	var dt := Time.get_datetime_dict_from_system()
	var w: int = int(dt.get("year", 2026)) * 53 + int(dt.get("month", 1)) * 5 + (int(dt.get("day", 1)) / 7)
	return int(w) ^ 0x57454559   # "WEEY"


# ---------- World statistics (15.47) ----------

func bump_stat(key: StringName, by: int = 1) -> void:
	world_stats[key] = int(world_stats.get(key, 0)) + by
	world_stats_changed.emit()


func get_stat(key: StringName) -> int:
	return int(world_stats.get(key, 0))


# ---------- Combo (2.39) + last-damage source (2.26) ----------

func register_hit_landed() -> void:
	_last_hit_at_ms = Time.get_ticks_msec()
	_set_combo(combo_counter + 1)


func _set_combo(new_value: int) -> void:
	combo_counter = max(0, new_value)
	if combo_counter > combo_max:
		combo_max = combo_counter
	combo_changed.emit(combo_counter)


func note_last_damage_source(source_name: String) -> void:
	last_damage_source = source_name


# ---------- Damage breakdown (15.40) ----------

func _on_boss_engaged(_boss_id: StringName) -> void:
	damage_breakdown_active = true
	_boss_engagement_started_at_ms = Time.get_ticks_msec()
	damage_breakdown = {
		&"dps_peak": 0.0,
		&"dps_avg": 0.0,
		&"hits_taken": 0,
		&"dodges": 0,
		&"crits_landed": 0,
		&"highest_single_hit": 0,
		&"damage_dealt": 0,
		&"damage_taken": 0,
		&"duration_seconds": 0.0,
	}
	_dps_samples.clear()


func _on_boss_defeated(boss_id: StringName) -> void:
	damage_breakdown_active = false
	var dur_ms: int = Time.get_ticks_msec() - _boss_engagement_started_at_ms
	damage_breakdown[&"duration_seconds"] = float(dur_ms) / 1000.0
	# DPS average and peak from the sampler.
	if _dps_samples.size() > 1:
		var first: float = _dps_samples[0]
		var last: float = _dps_samples[-1]
		var seconds: float = float(_dps_samples.size())
		damage_breakdown[&"dps_avg"] = (last - first) / max(1.0, seconds)
		var peak: float = 0.0
		for i in range(1, _dps_samples.size()):
			var d: float = (_dps_samples[i] - _dps_samples[i - 1])
			if d > peak:
				peak = d
		damage_breakdown[&"dps_peak"] = peak
	world_stats[&"bosses_defeated"] = int(world_stats.get(&"bosses_defeated", 0)) + 1
	# 15.30 boss-rush
	boss_rush_record_kill()
	# 15.68 first-boss reward
	maybe_grant_first_boss_reward(boss_id)


func record_dodge() -> void:
	if damage_breakdown_active:
		damage_breakdown[&"dodges"] = int(damage_breakdown.get(&"dodges", 0)) + 1


func record_crit_landed() -> void:
	if damage_breakdown_active:
		damage_breakdown[&"crits_landed"] = int(damage_breakdown.get(&"crits_landed", 0)) + 1


# ---------- Photo mode (15.22) ----------

func toggle_photo_mode() -> bool:
	photo_mode_active = not photo_mode_active
	get_tree().paused = photo_mode_active
	photo_mode_toggled.emit(photo_mode_active)
	return photo_mode_active


func set_photo_filter(filter: StringName) -> void:
	if filter in [&"none", &"sepia", &"bw", &"aurora", &"aphelion", &"final"]:
		photo_filter = filter


# ---------- Easter eggs (15.57) ----------

func discover_easter_egg(id: StringName) -> bool:
	if discovered_eggs.get(id, false):
		return false
	discovered_eggs[id] = true
	easter_egg_discovered.emit(id)
	EventBus.ui_toast.emit("Found something hidden.", 2.5)
	return true


func easter_egg_count_discovered() -> int:
	var n: int = 0
	for k in discovered_eggs.keys():
		if discovered_eggs[k]:
			n += 1
	return n


# ---------- Seasonal events (15.6 / 15.58) ----------

func _refresh_seasonal_events() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var month: int = int(dt.get("month", 1))
	var day: int = int(dt.get("day", 1))
	for event_id in SEASONAL_EVENTS.keys():
		var rec: Dictionary = SEASONAL_EVENTS[event_id]
		var in_window: bool = _date_within_range(
			month, day,
			int(rec.get("start_month", 1)), int(rec.get("start_day", 1)),
			int(rec.get("end_month", 1)), int(rec.get("end_day", 1)),
		)
		var was_active: bool = bool(active_seasonal_events.get(event_id, false))
		active_seasonal_events[event_id] = in_window
		if in_window and not was_active:
			seasonal_event_started.emit(event_id)
		elif was_active and not in_window:
			seasonal_event_ended.emit(event_id)


func is_seasonal_event_active(event_id: StringName) -> bool:
	return bool(active_seasonal_events.get(event_id, false))


func _date_within_range(month: int, day: int, sm: int, sd: int, em: int, ed: int) -> bool:
	# Handles wrap-around (e.g. Dec 18 → Jan 7 for Winter).
	var start_ord: int = sm * 100 + sd
	var end_ord: int = em * 100 + ed
	var cur: int = month * 100 + day
	if start_ord <= end_ord:
		return cur >= start_ord and cur <= end_ord
	# Wrap.
	return cur >= start_ord or cur <= end_ord


# ---------- Login streak (15.49) ----------

func _check_login_streak() -> void:
	var today_iso: String = Time.get_date_string_from_system()
	if last_login_iso == today_iso:
		return
	if last_login_iso == "":
		login_streak_days = 1
	else:
		var prev_unix: int = _parse_iso_date(last_login_iso)
		var today_unix: int = _parse_iso_date(today_iso)
		var diff_days: int = int(round(float(today_unix - prev_unix) / 86400.0))
		if diff_days == 1:
			login_streak_days += 1
		elif diff_days > 1:
			login_streak_days = 1
		# Same day == 0, no change.
	last_login_iso = today_iso
	streak_reward_pending = true


func consume_streak_reward() -> int:
	if not streak_reward_pending:
		return 0
	streak_reward_pending = false
	return min(7, login_streak_days) * 10  # coins


func _parse_iso_date(iso: String) -> int:
	# iso "YYYY-MM-DD"
	var parts: PackedStringArray = iso.split("-")
	if parts.size() < 3:
		return 0
	return Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 0, "minute": 0, "second": 0,
	})


# ---------- Tutorial + first-boss reward (15.68) ----------

func maybe_grant_tutorial_reward() -> void:
	if tutorial_reward_granted_flag:
		return
	tutorial_reward_granted_flag = true
	tutorial_reward_granted.emit()


func maybe_grant_first_boss_reward(boss_id: StringName) -> void:
	if first_boss_reward_granted_flag:
		return
	# Only fires for Glaur-em (the first boss); later boss kills don't trigger.
	if boss_id != &"boss_glaurem":
		return
	first_boss_reward_granted_flag = true
	first_boss_reward_granted.emit()


# ---------- Cheat detection (15.35) ----------

func note_console_opened() -> void:
	console_was_used = true
	cheat_detected_lockout.emit()


# ---------- NG+ inheritance (15.94) ----------

func is_ng_plus_carry_over(field: StringName) -> bool:
	if ng_plus_inheritance_overrides.has(field):
		return bool(ng_plus_inheritance_overrides[field])
	return bool(NG_PLUS_INHERITANCE.get(field, false))


func set_ng_plus_carry_override(field: StringName, carry_over: bool) -> void:
	ng_plus_inheritance_overrides[field] = carry_over


# ---------- Run history (15.48) ----------

func close_current_run(outcome: StringName) -> void:
	var record: Dictionary = {
		"started_unix": current_run_started_unix,
		"ended_unix": Time.get_unix_time_from_system(),
		"playtime_seconds": current_run_playtime_seconds,
		"deaths": current_run_deaths,
		"bosses_defeated": int(world_stats.get(&"bosses_defeated", 0)),
		"outcome": String(outcome),
		"difficulty": String(difficulty_preset),
		"hardcore": hardcore_active,
	}
	run_history.append(record)
	while run_history.size() > RUN_HISTORY_MAX:
		run_history.pop_front()
	run_history_added.emit(record)


# ---------- Damage / signal bridges ----------

func _on_tile_changed(_coord: Vector2i, old_id: int, new_id: int) -> void:
	if old_id >= 0 and new_id < 0:
		bump_stat(&"tiles_mined", 1)


func _on_entity_killed(entity: Node, killer: Node) -> void:
	if killer != null and (killer is PlayerController or _has_group(killer, "player")):
		bump_stat(&"mobs_killed", 1)
		register_hit_landed()
	if entity != null and (entity is PlayerController or _has_group(entity, "player")):
		bump_stat(&"slivers_lost", 1)


func _has_group(n: Node, g: String) -> bool:
	return n != null and n.is_in_group(g)


func _on_damage_dealt(source: Node, target: Node, amount: int, _type: StringName) -> void:
	if source != null and (source is PlayerController or _has_group(source, "player")):
		bump_stat(&"damage_dealt", amount)
		if damage_breakdown_active:
			damage_breakdown[&"damage_dealt"] = int(damage_breakdown.get(&"damage_dealt", 0)) + amount
			if amount > int(damage_breakdown.get(&"highest_single_hit", 0)):
				damage_breakdown[&"highest_single_hit"] = amount
	if target != null and (target is PlayerController or _has_group(target, "player")):
		bump_stat(&"damage_taken", amount)
		if damage_breakdown_active:
			damage_breakdown[&"damage_taken"] = int(damage_breakdown.get(&"damage_taken", 0)) + amount
			damage_breakdown[&"hits_taken"] = int(damage_breakdown.get(&"hits_taken", 0)) + 1
		var src_name: String = ""
		if source:
			src_name = String(source.name)
		note_last_damage_source(src_name)


func _on_item_picked_up(_item_id: StringName, count: int) -> void:
	bump_stat(&"items_picked_up", count)


func _on_item_crafted(_item_id: StringName, count: int) -> void:
	bump_stat(&"items_crafted", count)


func _on_player_died(_player: Node) -> void:
	current_run_deaths += 1
	bump_stat(&"slivers_lost", 1)


func _on_player_respawned(_player: Node, _slivers: int) -> void:
	# nothing per-respawn yet; combo resets via timer
	_set_combo(0)


func _on_sliver_lost(_remaining: int) -> void:
	pass  # bump occurs from player_died


# ---------- Cloud-save (15.12) ----------

func cloud_mark_synced() -> void:
	cloud_last_sync_unix = Time.get_unix_time_from_system()
	cloud_last_sync_state = &"ok"
	cloud_sync_state_changed.emit(&"ok")


func cloud_mark_syncing() -> void:
	cloud_last_sync_state = &"syncing"
	cloud_sync_state_changed.emit(&"syncing")


func cloud_mark_conflict() -> void:
	cloud_last_sync_state = &"conflict"
	cloud_sync_state_changed.emit(&"conflict")


func cloud_mark_offline() -> void:
	cloud_last_sync_state = &"offline"
	cloud_sync_state_changed.emit(&"offline")


# ---------- Multi-character (15.33) ----------

func register_character(world_id: String, character_id: String) -> void:
	var arr: Array = characters_per_world.get(world_id, [])
	if character_id not in arr:
		arr.append(character_id)
		characters_per_world[world_id] = arr


func characters_in_world(world_id: String) -> Array:
	return characters_per_world.get(world_id, [])


# ---------- Save round-trip ----------

func dump_state() -> Dictionary:
	return {
		"difficulty_preset": String(difficulty_preset),
		"hardcore_active": hardcore_active,
		"world_size_mult": world_size_mult,
		"creative_mode": creative_mode,
		"current_run_started_unix": current_run_started_unix,
		"current_run_playtime_seconds": current_run_playtime_seconds,
		"current_run_deaths": current_run_deaths,
		"run_history": run_history.duplicate(true),
		"world_stats": _stringify_keys(world_stats),
		"combo_max": combo_max,
		"last_damage_source": last_damage_source,
		"damage_breakdown": _stringify_keys(damage_breakdown),
		"discovered_eggs": _stringify_keys(discovered_eggs),
		"hidden_achievement_revealed": _stringify_keys(hidden_achievement_revealed),
		"tutorial_reward_granted": tutorial_reward_granted_flag,
		"first_boss_reward_granted": first_boss_reward_granted_flag,
		"last_login_iso": last_login_iso,
		"login_streak_days": login_streak_days,
		"console_was_used": console_was_used,
		"cloud_last_sync_unix": cloud_last_sync_unix,
		"cloud_last_sync_state": String(cloud_last_sync_state),
		"characters_per_world": characters_per_world.duplicate(true),
		"on_beta_branch": on_beta_branch,
		"starting_kit_id": String(starting_kit_id),
		"demo_build": demo_build,
		"ng_plus_inheritance_overrides": _stringify_keys(ng_plus_inheritance_overrides),
		"boss_rush_progress": boss_rush_progress,
		"endless_floor": endless_floor,
	}


func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	difficulty_preset = StringName(String(d.get("difficulty_preset", "normal")))
	hardcore_active = bool(d.get("hardcore_active", false))
	world_size_mult = float(d.get("world_size_mult", 1.0))
	creative_mode = bool(d.get("creative_mode", false))
	current_run_started_unix = int(d.get("current_run_started_unix", Time.get_unix_time_from_system()))
	current_run_playtime_seconds = int(d.get("current_run_playtime_seconds", 0))
	current_run_deaths = int(d.get("current_run_deaths", 0))
	var history_in: Array = d.get("run_history", [])
	run_history.clear()
	for entry in history_in:
		if entry is Dictionary:
			run_history.append(entry.duplicate(true))
	var stats_in: Dictionary = d.get("world_stats", {})
	for k in stats_in.keys():
		world_stats[StringName(String(k))] = int(stats_in[k])
	combo_max = int(d.get("combo_max", 0))
	last_damage_source = String(d.get("last_damage_source", ""))
	var dbr_in: Dictionary = d.get("damage_breakdown", {})
	for k in dbr_in.keys():
		damage_breakdown[StringName(String(k))] = dbr_in[k]
	var eggs_in: Dictionary = d.get("discovered_eggs", {})
	discovered_eggs.clear()
	for k in eggs_in.keys():
		discovered_eggs[StringName(String(k))] = bool(eggs_in[k])
	var ach_in: Dictionary = d.get("hidden_achievement_revealed", {})
	hidden_achievement_revealed.clear()
	for k in ach_in.keys():
		hidden_achievement_revealed[StringName(String(k))] = bool(ach_in[k])
	tutorial_reward_granted_flag = bool(d.get("tutorial_reward_granted", false))
	first_boss_reward_granted_flag = bool(d.get("first_boss_reward_granted", false))
	last_login_iso = String(d.get("last_login_iso", ""))
	login_streak_days = int(d.get("login_streak_days", 0))
	console_was_used = bool(d.get("console_was_used", false))
	cloud_last_sync_unix = int(d.get("cloud_last_sync_unix", 0))
	cloud_last_sync_state = StringName(String(d.get("cloud_last_sync_state", "idle")))
	var chars_in: Dictionary = d.get("characters_per_world", {})
	characters_per_world.clear()
	for k in chars_in.keys():
		characters_per_world[String(k)] = (chars_in[k] as Array).duplicate(true)
	on_beta_branch = bool(d.get("on_beta_branch", false))
	starting_kit_id = StringName(String(d.get("starting_kit_id", "")))
	demo_build = bool(d.get("demo_build", false))
	var ng_in: Dictionary = d.get("ng_plus_inheritance_overrides", {})
	ng_plus_inheritance_overrides.clear()
	for k in ng_in.keys():
		ng_plus_inheritance_overrides[StringName(String(k))] = bool(ng_in[k])
	boss_rush_progress = int(d.get("boss_rush_progress", 0))
	endless_floor = int(d.get("endless_floor", 0))


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = d[k]
	return out
