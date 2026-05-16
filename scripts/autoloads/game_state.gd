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

## Phase 4.10 — chunk visit log for the persistent map. Keyed by "x,y" so the
## save round-trip can stringify without losing precision; value is the biome id
## the chunk belonged to when first revealed. Survives scene reload.
var explored_chunks: Dictionary = {}

## Phase 4.5 — current Loom-bound respawn point. Defaults to world origin (the
## Anchor's Loom). Updated when the player presses "Set Respawn" at the Loom or
## places a Bed; consumed by PlayerController on death.
var respawn_point: Vector2 = Vector2.ZERO

## Echo-Walker meta (per Lore §7.7) — gold threads earned per Sovereign kill.
var sovereign_threads: int = 0

## Phase 7 talent points: granted 1 per skill level-up. Allocated via TalentPanel.
## Per-skill allocation: { skill_id (StringName) -> int allocated_points }.
## `allocated_talents` remains the per-skill sum so Phase 6 callers (CombatMath,
## PlayerStats.mining_speed_multiplier) keep working. Phase 7 also tracks the
## individual node ranks in `allocated_talent_nodes` for the tree UI + tooltips.
var unallocated_talent_points: int = 0
var allocated_talents: Dictionary = {}
## { skill_id -> { node_id -> rank_int } }. Drives TalentEffects.sum_value.
var allocated_talent_nodes: Dictionary = {}

## Phase 7.16 — three named talent build presets per Walker. Each preset is a
## snapshot of allocated_talent_nodes; switching costs one Respec Scroll OR is
## free if the preset hasn't been touched since last save.
const PRESET_COUNT: int = 3
var talent_presets: Array = [{}, {}, {}]  ## Array[Dictionary], each: skill -> {node -> rank}
var active_preset_index: int = 0


func grant_talent_point(amount: int = 1) -> void:
	unallocated_talent_points += amount


## Phase 7 legacy path: bulk-allocate a single point into a skill without
## targeting a specific node. Used as fallback when talent trees aren't loaded
## (tests, headless minimal). Tree-aware allocation lives in
## `allocate_talent_node` below.
func allocate_talent(skill_id: StringName) -> bool:
	if unallocated_talent_points <= 0:
		return false
	allocated_talents[skill_id] = int(allocated_talents.get(skill_id, 0)) + 1
	unallocated_talent_points -= 1
	if Achievements:
		Achievements.unlock(&"ach_first_talent")
	EventBus.stat_recompute_requested.emit()
	return true


## Phase 7.7 + 7.13 — Allocate one point into a specific node. Validates
## prerequisites + per-node max rank. Returns true if the rank went up.
func allocate_talent_node(skill_id: StringName, node_id: StringName) -> bool:
	if unallocated_talent_points <= 0:
		return false
	var reg: Node = get_node_or_null(^"/root/TalentRegistry")
	if reg == null:
		# No registry available — fall back to the bulk per-skill counter.
		return allocate_talent(skill_id)
	var tree: TalentTree = reg.tree_for(skill_id)
	if tree == null:
		return allocate_talent(skill_id)
	var node_def := tree.node_by_id(node_id)
	if node_def.is_empty():
		return false
	if not reg.prerequisites_met(skill_id, node_id):
		EventBus.ui_toast.emit("Prerequisite not met.", 1.5)
		return false
	var by_node: Dictionary = allocated_talent_nodes.get(skill_id, {})
	var current: int = int(by_node.get(node_id, 0))
	var max_ranks: int = int(node_def.get("max_ranks", 1))
	if current >= max_ranks:
		return false
	by_node[node_id] = current + 1
	allocated_talent_nodes[skill_id] = by_node
	allocated_talents[skill_id] = int(allocated_talents.get(skill_id, 0)) + 1
	unallocated_talent_points -= 1
	if Achievements:
		Achievements.unlock(&"ach_first_talent")
	EventBus.talent_unlocked.emit(skill_id, node_id)
	EventBus.stat_recompute_requested.emit()
	return true


func refund_all_talents() -> void:
	for k in allocated_talents.keys():
		unallocated_talent_points += int(allocated_talents[k])
	allocated_talents.clear()
	allocated_talent_nodes.clear()
	EventBus.stat_recompute_requested.emit()


## Phase 7.16 — save the current allocation into a preset slot. Returns false
## if the index is out of range.
func save_talent_preset(index: int) -> bool:
	if index < 0 or index >= PRESET_COUNT:
		return false
	var snapshot: Dictionary = {}
	for k in allocated_talent_nodes.keys():
		snapshot[k] = (allocated_talent_nodes[k] as Dictionary).duplicate(true)
	talent_presets[index] = snapshot
	return true


## Phase 7.16 — load a saved preset. Refunds the current allocation first, then
## re-spends the talent points to match the preset. Returns false if the
## preset is empty or the player doesn't have enough points to fund it.
func load_talent_preset(index: int) -> bool:
	if index < 0 or index >= PRESET_COUNT:
		return false
	var snapshot: Dictionary = talent_presets[index]
	if snapshot == null or snapshot.is_empty():
		return false
	# Total points the preset wants to spend.
	var total_needed: int = 0
	for skill in snapshot.keys():
		for node_id in (snapshot[skill] as Dictionary).keys():
			total_needed += int(snapshot[skill][node_id])
	var have: int = unallocated_talent_points
	for k in allocated_talents.keys():
		have += int(allocated_talents[k])
	if total_needed > have:
		EventBus.ui_toast.emit("Not enough talent points for that build.", 2.0)
		return false
	refund_all_talents()
	for skill in snapshot.keys():
		for node_id in (snapshot[skill] as Dictionary).keys():
			var rank: int = int(snapshot[skill][node_id])
			for _i in range(rank):
				allocate_talent_node(StringName(skill), StringName(node_id))
	active_preset_index = index
	EventBus.ui_toast.emit("Talent preset %d loaded." % (index + 1), 2.0)
	return true


## Phase 7.16 — count talent points spent in a given preset (without loading
## it). Used by the preset dropdown to label the slots.
func talent_preset_point_total(index: int) -> int:
	if index < 0 or index >= PRESET_COUNT:
		return 0
	var snapshot: Dictionary = talent_presets[index]
	if snapshot == null or snapshot.is_empty():
		return 0
	var total: int = 0
	for skill in snapshot.keys():
		for node_id in (snapshot[skill] as Dictionary).keys():
			total += int(snapshot[skill][node_id])
	return total


## Phase 7.7 — total talent points the Walker has ever earned (allocated +
## unallocated). Equals the sum of skill levels (1 point per level).
func total_talent_points_earned() -> int:
	var have: int = unallocated_talent_points
	for k in allocated_talents.keys():
		have += int(allocated_talents[k])
	return have


## Phase 1 ticket 1.16 — character cosmetics persisted at world creation.
var character_name: String = "Walker"
var character_template: String = "Walker (default)"
var character_hair: String = "Short"
var character_skin: String = "Tan"
var character_outfit: String = "Starter Robes"
## Phase 9.56 — Idle pose. Default 'Stand'.
var character_idle_pose: String = "Stand"


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
	allocated_talent_nodes.clear()
	talent_presets = [{}, {}, {}]
	active_preset_index = 0
	ng_plus = false
	ng_plus_cycles = 0
	explored_chunks.clear()
	respawn_point = Vector2.ZERO


## Phase 4.5 — bind the player's respawn to a world-space position. Called by
## the Loom panel's Set-Respawn button and (Phase 9) Bed placement. Emits so
## the HUD/Compass can refresh their anchor target.
func set_respawn_point(world_pos: Vector2) -> void:
	respawn_point = world_pos
	EventBus.respawn_point_set.emit(world_pos)


## Phase 4.10 — register a chunk as visited. Idempotent; first biome wins so the
## map history doesn't flicker if a re-roll repaints the chunk.
func mark_chunk_visited(chunk_coord: Vector2i, biome_id: StringName) -> void:
	var key: String = "%d,%d" % [chunk_coord.x, chunk_coord.y]
	if explored_chunks.has(key):
		return
	explored_chunks[key] = String(biome_id)
	EventBus.chunk_visited.emit(chunk_coord, biome_id)


func has_visited_chunk(chunk_coord: Vector2i) -> bool:
	return explored_chunks.has("%d,%d" % [chunk_coord.x, chunk_coord.y])


func explored_chunk_biome(chunk_coord: Vector2i) -> StringName:
	var key: String = "%d,%d" % [chunk_coord.x, chunk_coord.y]
	return StringName(String(explored_chunks.get(key, "")))


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
