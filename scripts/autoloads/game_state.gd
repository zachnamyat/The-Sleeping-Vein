extends Node

## Global runtime state. Holds the current world seed, current player party,
## the Aphelion's remaining slivers, defeated bosses, etc. SaveSystem reads
## and writes this autoload.

## Semantic version of the build. Bump on every release; surfaced in title screen
## footer and pause-menu status. Matches the latest CHANGELOG.md entry.
const VERSION: String = "0.1.0-dev"

const APHELION_STARTING_SLIVERS: int = 70_000

var world_seed: int = 0
var aphelion_slivers_remaining: int = APHELION_STARTING_SLIVERS
var defeated_bosses: Dictionary = {}     # boss_id (StringName) -> defeat_timestamp (int)
var collected_relics: Dictionary = {}    # relic_id -> bool
var arrived_npcs: Dictionary = {}        # npc_id -> bool
var unlocked_recipes: Dictionary = {}    # recipe_id -> bool
var unlocked_compendium: Dictionary = {} # entry_id -> bool

## Echo-Walker meta (per Lore §7.7) — gold threads earned per Sovereign kill.
var sovereign_threads: int = 0

## Phase 7 talent points: granted 1 per skill level-up. Allocated via TalentPanel.
## Per-skill allocation: { skill_id (StringName) -> int allocated_points }.
var unallocated_talent_points: int = 0
var allocated_talents: Dictionary = {}


func grant_talent_point(amount: int = 1) -> void:
	unallocated_talent_points += amount


func allocate_talent(skill_id: StringName) -> bool:
	if unallocated_talent_points <= 0:
		return false
	allocated_talents[skill_id] = int(allocated_talents.get(skill_id, 0)) + 1
	unallocated_talent_points -= 1
	if Achievements:
		Achievements.unlock(&"ach_first_talent")
	return true


func refund_all_talents() -> void:
	for k in allocated_talents.keys():
		unallocated_talent_points += int(allocated_talents[k])
	allocated_talents.clear()


## NG+ flag. When true on world load, scale boss HP +30% and grant carry-over cosmetics.
var ng_plus: bool = false
var ng_plus_cycles: int = 0


func start_new_game_plus() -> void:
	# Preserve threads + compendium entries; reset slivers, bosses, relics, recipes.
	ng_plus = true
	ng_plus_cycles += 1
	aphelion_slivers_remaining = APHELION_STARTING_SLIVERS
	defeated_bosses.clear()
	collected_relics.clear()
	unlocked_recipes.clear()
	arrived_npcs.clear()
	world_seed = int(Time.get_unix_time_from_system())


## Called by WorldBootstrap when starting a fresh world (i.e. not loading a
## save). Autoloads persist across scene changes, so without this reset the
## second New Game in a session would inherit the previous run's slivers,
## XP, talents, and inventory. Distinct from start_new_game_plus, which
## preserves threads + compendium as legacy.
func reset_for_new_game() -> void:
	aphelion_slivers_remaining = APHELION_STARTING_SLIVERS
	defeated_bosses.clear()
	collected_relics.clear()
	arrived_npcs.clear()
	unlocked_recipes.clear()
	unlocked_compendium.clear()
	sovereign_threads = 0
	unallocated_talent_points = 0
	allocated_talents.clear()
	ng_plus = false
	ng_plus_cycles = 0


func has_defeated_boss(boss_id: StringName) -> bool:
	return defeated_bosses.has(boss_id)


func mark_boss_defeated(boss_id: StringName) -> void:
	if defeated_bosses.has(boss_id):
		return
	defeated_bosses[boss_id] = Time.get_unix_time_from_system()
	EventBus.boss_defeated.emit(boss_id)


func consume_sliver() -> void:
	aphelion_slivers_remaining = max(0, aphelion_slivers_remaining - 1)
	EventBus.aphelion_dimmed.emit(aphelion_slivers_remaining)
