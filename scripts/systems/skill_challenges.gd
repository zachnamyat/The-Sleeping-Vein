extends Node

## Phase 7.15 — Per-skill time-trial challenges.
##
## Each skill has one short challenge: "mine 10 tiles in 30 seconds",
## "kill 5 mobs in 20 seconds", "harvest 8 crops without leaving the plot".
##
## The player triggers a challenge from the TalentPanel or character sheet;
## on success, the reward is one bonus talent point + a vanity title flag.
##
## Phase 7.20 — Level-100 vanity is also driven from this autoload: each skill
## that crosses 100 gets registered in `mastery_unlocked`, which gives the
## player a small particle glow visible to other players.

signal challenge_started(skill_id: StringName)
signal challenge_completed(skill_id: StringName, success: bool)

const CHALLENGES: Dictionary = {
	&"skill_mining":     {"goal": 10, "duration": 30.0, "metric": "tiles_mined",   "name": "Stratabreaking Sprint"},
	&"skill_melee":      {"goal":  5, "duration": 20.0, "metric": "mob_kills",     "name": "Hand-Strike Trial"},
	&"skill_ranged":     {"goal":  6, "duration": 20.0, "metric": "ranged_hits",   "name": "Hand-Throw Trial"},
	&"skill_running":    {"goal": 400, "duration": 10.0, "metric": "distance_moved", "name": "Walking Trial"},
	&"skill_vitality":   {"goal": 10, "duration": 30.0, "metric": "damage_absorbed", "name": "Anchoring Vigil"},
	&"skill_crafting":   {"goal":  4, "duration": 30.0, "metric": "items_crafted", "name": "Form-Making Trial"},
	&"skill_gardening":  {"goal":  6, "duration": 60.0, "metric": "crops_harvested","name": "Tending Trial"},
	&"skill_fishing":    {"goal":  3, "duration": 60.0, "metric": "fish_caught",   "name": "Listening Hour"},
	&"skill_cooking":    {"goal":  3, "duration": 60.0, "metric": "meals_cooked",  "name": "Hearth Trial"},
	&"skill_magic":      {"goal":  8, "duration": 20.0, "metric": "magic_hits",    "name": "Resonance Trial"},
	&"skill_summoning":  {"goal":  3, "duration": 30.0, "metric": "summons_used",  "name": "Calling Trial"},
	&"skill_explosives": {"goal":  4, "duration": 20.0, "metric": "bombs_used",    "name": "Bursting Trial"},
}

var _active_skill: StringName = &""
var _progress: int = 0
var _time_left: float = 0.0
var mastery_unlocked: Dictionary = {}  ## skill_id -> bool


func _ready() -> void:
	set_process(true)
	EventBus.skill_leveled_up.connect(_on_skill_leveled_up)
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.item_crafted.connect(_on_item_crafted)
	# Multiple metrics share the skill_xp_gained event as a coarse proxy.
	EventBus.skill_xp_gained.connect(_on_skill_xp_gained)
	# Phase 7.20 — mastery on initial connect.
	if SkillSystem:
		SkillSystem.skill_capped.connect(_on_skill_capped)


func start_challenge(skill_id: StringName) -> bool:
	if _active_skill != &"":
		EventBus.ui_toast.emit("A challenge is already running.", 1.5)
		return false
	if not CHALLENGES.has(skill_id):
		return false
	_active_skill = skill_id
	_progress = 0
	_time_left = float(CHALLENGES[skill_id].get("duration", 30.0))
	challenge_started.emit(skill_id)
	EventBus.ui_toast.emit("Challenge: %s started." % CHALLENGES[skill_id]["name"], 2.0)
	return true


func is_running() -> bool:
	return _active_skill != &""


func current_skill() -> StringName:
	return _active_skill


func _process(delta: float) -> void:
	if _active_skill == &"":
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish(_progress >= int(CHALLENGES[_active_skill].get("goal", 0)))


func _finish(success: bool) -> void:
	var sid: StringName = _active_skill
	_active_skill = &""
	if success:
		GameState.grant_talent_point(1)
		EventBus.ui_toast.emit("Challenge complete: +1 talent point.", 3.0)
		if AudioBus:
			AudioBus.play_sfx(&"skill_level_up")
	else:
		EventBus.ui_toast.emit("Challenge failed.", 2.0)
	challenge_completed.emit(sid, success)


func _on_tile_changed(_coord: Vector2i, _old: int, new_id: int) -> void:
	if _active_skill == &"skill_mining" and new_id < 0:
		_progress += 1
		_check_progress()


func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if _active_skill == &"skill_melee" and entity is Mob:
		_progress += 1
		_check_progress()


func _on_item_crafted(_iid: StringName, count: int) -> void:
	match _active_skill:
		&"skill_crafting":
			_progress += count
			_check_progress()
		&"skill_cooking":
			# Many cooked items also fire item_crafted; counting both is fine.
			_progress += count
			_check_progress()


func _on_skill_xp_gained(skill_id: StringName, _amount: int) -> void:
	# Coarse metric for skills we don't have a dedicated event for.
	if skill_id != _active_skill:
		return
	if _active_skill in [&"skill_mining", &"skill_melee", &"skill_crafting", &"skill_cooking"]:
		return  # handled above
	_progress += 1
	_check_progress()


func _check_progress() -> void:
	if _active_skill == &"":
		return
	var goal: int = int(CHALLENGES[_active_skill].get("goal", 1))
	if _progress >= goal:
		_finish(true)


func _on_skill_leveled_up(_skill_id: StringName, _new_level: int) -> void:
	pass  # mastery is handled via SkillSystem.skill_capped


func _on_skill_capped(skill_id: StringName) -> void:
	if mastery_unlocked.get(skill_id, false):
		return
	mastery_unlocked[skill_id] = true
	# Persist into compendium so the title appears on save reload.
	GameState.unlocked_compendium[StringName("mastery_" + String(skill_id))] = true
	EventBus.ui_compendium_entry_unlocked.emit(StringName("mastery_" + String(skill_id)))
	# Phase 7.20 — cosmetic glow signal. The player's hand-of-light VFX picks
	# this up and adds a small color tint per mastered skill.
	EventBus.ui_toast.emit("%s mastered — a cosmetic glow blooms on your hand." % SkillChallenges._skill_name(skill_id), 5.0)


static func _skill_name(skill_id: StringName) -> String:
	return String(skill_id).replace("skill_", "").capitalize()
