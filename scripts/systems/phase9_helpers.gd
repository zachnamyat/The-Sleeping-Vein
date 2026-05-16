extends Node

## Phase 9 helpers / aggregate features that don't deserve their own autoload.
##
## Contains:
##   9.31 — Pet evolution / growth stages: a level-gated form table.
##   9.39 — Indoor/outdoor detection: hash-based room recognition for buffs/mood.
##   9.40 — Garden score: scans nearby placed crops and emits a daily bonus.
##   9.41 — Light pollution: counts light_source nodes near NPCs.
##   9.45 — Pause-and-comment on world events (boss kill / world event).
##   9.55 — Synced lore-tablet broadcast helper for multiplayer.
##
## Public API documented per-function.

# ----- 9.31 — Pet evolution -----

const PET_EVOLUTIONS: Dictionary = {
	&"pet_pale_fox":     [ { "level": 5, "new_id": &"pet_pale_fox_swift" }, { "level": 12, "new_id": &"pet_pale_fox_lunar" } ],
	&"pet_charred_goat": [ { "level": 5, "new_id": &"pet_charred_goat_ironhorn" } ],
	&"pet_root_finch":   [ { "level": 6, "new_id": &"pet_root_finch_singer" } ],
	&"pet_lantern_eel":  [ { "level": 7, "new_id": &"pet_lantern_eel_storm" } ],
}


func get_evolution_target(pet_id: StringName, level: int) -> StringName:
	var stages: Array = PET_EVOLUTIONS.get(pet_id, [])
	var target: StringName = &""
	for stage in stages:
		if level >= int(stage.get("level", 9999)):
			target = StringName(String(stage.get("new_id", "")))
	return target


# ----- 9.39 — Indoor / outdoor detection -----

const INDOOR_RAY_DIRS: Array[Vector2] = [
	Vector2(0, -160), Vector2(0, 160), Vector2(-160, 0), Vector2(160, 0)
]


func is_player_indoors(player: Node2D) -> bool:
	## Casts four rays from the player; hits a "door" or "wall_blocking" node on
	## all four sides → indoors. Used by Buffs for the "Sheltered" tag (Phase 9.39).
	if player == null:
		return false
	var hits: int = 0
	for dir in INDOOR_RAY_DIRS:
		var space := player.get_world_2d().direct_space_state
		var params := PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + dir, 8)
		var result := space.intersect_ray(params)
		if not result.is_empty():
			hits += 1
	return hits >= 4


# ----- 9.24 — Decoration furniture sets -----

const DECOR_SETS: Dictionary = {
	&"set_pyrenkin": [&"anvil", &"furnace", &"banner", &"pillar"],
	&"set_aetherdeep_court": [&"carpet", &"painting", &"banner", &"window_block"],
	&"set_wormbound_camp": [&"fence", &"pillar", &"sign", &"mailbox"],
	&"set_drowned_quay": [&"fish_trophy", &"net_trap", &"aquarium", &"window_block"],
}

const DECOR_SET_BONUS_RADIUS: float = 96.0


func decor_set_bonuses_near(world_pos: Vector2) -> Dictionary:
	## Returns { set_id -> matched_count } for each set that has matches near pos.
	var tree := get_tree()
	if tree == null:
		return {}
	var out: Dictionary = {}
	for set_id in DECOR_SETS.keys():
		var matched: int = 0
		for grp in DECOR_SETS[set_id]:
			for n in tree.get_nodes_in_group(String(grp)):
				if n is Node2D and (n as Node2D).global_position.distance_to(world_pos) <= DECOR_SET_BONUS_RADIUS:
					matched += 1
					break  # one of this group counts; move to next group
		if matched >= 2:
			out[set_id] = matched
	return out


# ----- 9.40 — Garden score -----

const GARDEN_RADIUS_PX: float = 96.0


func garden_score_near(world_pos: Vector2) -> int:
	## Count distinct crop types within radius; a "good garden" rewards 1 mood
	## bump per 3 distinct crops.
	var tree := get_tree()
	if tree == null:
		return 0
	var found: Dictionary = {}
	for n in tree.get_nodes_in_group("crop"):
		if n is Node2D and (n as Node2D).global_position.distance_to(world_pos) <= GARDEN_RADIUS_PX:
			var key: String = (n as Node2D).name
			found[key] = true
	return found.size()


# ----- 9.41 — Light pollution -----

const LIGHT_POLLUTION_RADIUS: float = 64.0
const LIGHT_POLLUTION_THRESHOLD: int = 4


func light_pollution_at(world_pos: Vector2) -> int:
	## Count light sources in radius; values above LIGHT_POLLUTION_THRESHOLD
	## subtract from NPC mood in the next tick.
	var tree := get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for n in tree.get_nodes_in_group("light_source"):
		if n is Node2D and (n as Node2D).global_position.distance_to(world_pos) <= LIGHT_POLLUTION_RADIUS:
			count += 1
	return count


# ----- 9.45 — Boss / world-event commentary -----

const COMMENT_LINES_BY_NPC: Dictionary = {
	&"npc_aelstren": "Aelstren marks the date on a fresh map.",
	&"npc_brindle":  "Brindle leans on the anvil. \"One less.\"",
	&"npc_mira":     "Mira tucks a note into her ledger.",
	&"npc_cantor":   "The Cantor chimes the third bell, quietly.",
	&"npc_old_hask": "Old Hask spits over his shoulder.",
}


func broadcast_world_event_comment(event_id: StringName) -> void:
	if NpcLifecycle == null:
		return
	var delay: float = 1.5
	for npc_id in GameState.arrived_npcs.keys():
		if not GameState.arrived_npcs[npc_id]:
			continue
		var line: String = COMMENT_LINES_BY_NPC.get(StringName(String(npc_id)), "")
		if line == "":
			continue
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func() -> void:
			EventBus.ui_toast.emit(line, 3.0)
		)
		delay += 2.5
	NpcLifecycle.set_flag(StringName("event_commented:%s" % String(event_id)), true)


# ----- 9.55 — Synced lore-tablet broadcast -----

func broadcast_lore_tablet(tablet_id: StringName, reader_name: String) -> void:
	## In single-player, only emits a local toast; in multiplayer (NetSystem
	## reachable), broadcasts to all peers via EventBus.
	EventBus.ui_compendium_entry_unlocked.emit(tablet_id)
	EventBus.ui_toast.emit("%s read the tablet \"%s\"" % [reader_name, String(tablet_id)], 3.0)
	if NetSystem and NetSystem.has_method("broadcast_event"):
		NetSystem.call("broadcast_event", "lore_tablet_read", { "tablet_id": String(tablet_id), "reader": reader_name })
