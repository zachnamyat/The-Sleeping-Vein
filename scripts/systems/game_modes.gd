extends Node

## Phase 15 — Alternate game modes.
## Tickets:
##   15.28 — Speedrun timer + split system
##   15.29 — Daily / weekly challenge mode (shared seed)
##   15.30 — Boss rush mode
##   15.31 — Endless mode
##   15.94 — NG+ inheritance rules
##
## Acts as a façade around Phase15Helpers: this autoload owns the mode
## *lifecycle* (start / abandon / complete / record), Phase15Helpers owns the
## raw counters.

const BOSS_RUSH_ORDER: Array[StringName] = [
	&"boss_glaurem", &"boss_vorrkell", &"boss_spawnmother", &"boss_sythrenn",
	&"boss_auriax", &"boss_volthaar", &"boss_skoldur", &"boss_naeren",
	&"boss_veyl_aurora", &"boss_diadem_bearer", &"boss_aphelion",
]

const ENDLESS_FLOOR_HP_MULT_STEP: float = 0.15
const ENDLESS_FLOOR_LOOT_MULT_STEP: float = 0.10

signal mode_started(mode: StringName)
signal mode_ended(mode: StringName, outcome: StringName)
signal endless_floor_changed(floor_number: int)
signal challenge_seed_announced(seed: int, window: String)
signal boss_rush_progress_changed(progress: int, total: int)


# Active mode tag — "normal" is the default play loop.
var active_mode: StringName = &"normal"

# Endless-mode floor multipliers.
var endless_floor_hp_mult: float = 1.0
var endless_floor_loot_mult: float = 1.0


# ---------- Speedrun (15.28) ----------

func speedrun_start() -> void:
	if Phase15Helpers == null:
		return
	Phase15Helpers.speedrun_start()
	active_mode = &"speedrun"
	mode_started.emit(&"speedrun")


func speedrun_split(label: String) -> void:
	if Phase15Helpers == null:
		return
	Phase15Helpers.speedrun_add_split(label)
	EventBus.phase15_speedrun_split_added.emit(label, Phase15Helpers.speedrun_elapsed_seconds())


func speedrun_finish() -> float:
	if Phase15Helpers == null:
		return 0.0
	var total: float = Phase15Helpers.speedrun_stop()
	mode_ended.emit(&"speedrun", &"complete")
	active_mode = &"normal"
	if AchievementsExtended:
		AchievementsExtended.note_speedrun_finished()
	return total


# ---------- Boss rush (15.30) ----------

func boss_rush_start() -> void:
	if Phase15Helpers == null:
		return
	Phase15Helpers.boss_rush_start()
	active_mode = &"boss_rush"
	mode_started.emit(&"boss_rush")
	boss_rush_progress_changed.emit(0, BOSS_RUSH_ORDER.size())


func boss_rush_next() -> StringName:
	if Phase15Helpers == null:
		return &""
	var p: int = Phase15Helpers.boss_rush_progress
	if p >= BOSS_RUSH_ORDER.size():
		return &""
	return BOSS_RUSH_ORDER[p]


func boss_rush_finish() -> void:
	if Phase15Helpers == null:
		return
	mode_ended.emit(&"boss_rush", &"complete")
	active_mode = &"normal"


# ---------- Endless (15.31) ----------

func endless_start() -> void:
	if Phase15Helpers == null:
		return
	Phase15Helpers.endless_start()
	endless_floor_hp_mult = 1.0
	endless_floor_loot_mult = 1.0
	active_mode = &"endless"
	mode_started.emit(&"endless")
	endless_floor_changed.emit(Phase15Helpers.endless_floor)


func endless_descend() -> int:
	if Phase15Helpers == null:
		return 0
	var floor_num: int = Phase15Helpers.endless_descend()
	endless_floor_hp_mult = 1.0 + ENDLESS_FLOOR_HP_MULT_STEP * float(floor_num - 1)
	endless_floor_loot_mult = 1.0 + ENDLESS_FLOOR_LOOT_MULT_STEP * float(floor_num - 1)
	endless_floor_changed.emit(floor_num)
	# Track achievement.
	if AchievementsExtended:
		AchievementsExtended.bump(&"ach_endless_floor_10", floor_num)
	return floor_num


func endless_abandon() -> void:
	if Phase15Helpers == null:
		return
	mode_ended.emit(&"endless", &"abandoned")
	active_mode = &"normal"


# ---------- Daily / weekly challenge (15.29) ----------

func start_daily_challenge() -> int:
	if Phase15Helpers == null:
		return 0
	var seed_v: int = Phase15Helpers.challenge_seed_for_today()
	var iso: String = Time.get_date_string_from_system()
	Phase15Helpers.challenge_start(seed_v, "daily-" + iso)
	active_mode = &"daily_challenge"
	mode_started.emit(&"daily_challenge")
	challenge_seed_announced.emit(seed_v, Phase15Helpers.challenge_window_iso)
	return seed_v


func start_weekly_challenge() -> int:
	if Phase15Helpers == null:
		return 0
	var seed_v: int = Phase15Helpers.challenge_seed_for_week()
	var iso: String = Time.get_date_string_from_system()
	Phase15Helpers.challenge_start(seed_v, "weekly-" + iso)
	active_mode = &"weekly_challenge"
	mode_started.emit(&"weekly_challenge")
	challenge_seed_announced.emit(seed_v, Phase15Helpers.challenge_window_iso)
	return seed_v


# ---------- NG+ inheritance (15.94) ----------

## Build a GameState snapshot containing only fields that should carry over
## per the NG_PLUS_INHERITANCE table.
func ng_plus_carry_snapshot() -> Dictionary:
	if Phase15Helpers == null:
		return {}
	var snap: Dictionary = {}
	for field in Phase15Helpers.NG_PLUS_INHERITANCE.keys():
		if not Phase15Helpers.is_ng_plus_carry_over(field):
			continue
		if not GameState.get(field) == null or GameState.has_meta(field):
			snap[String(field)] = GameState.get(field)
	return snap


func apply_ng_plus_carry(snapshot: Dictionary) -> void:
	for field in snapshot.keys():
		var sn: StringName = StringName(String(field))
		if GameState.get(sn) != null or GameState.has_meta(sn):
			GameState.set(sn, snapshot[field])
	if AchievementsExtended:
		AchievementsExtended.note_ng_plus_completed(GameState.ng_plus_cycles)


# ---------- Boss rush hook ----------

func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(_boss_id: StringName) -> void:
	if not Phase15Helpers:
		return
	if Phase15Helpers.boss_rush_active:
		boss_rush_progress_changed.emit(Phase15Helpers.boss_rush_progress, BOSS_RUSH_ORDER.size())
		if Phase15Helpers.boss_rush_progress >= BOSS_RUSH_ORDER.size():
			boss_rush_finish()
