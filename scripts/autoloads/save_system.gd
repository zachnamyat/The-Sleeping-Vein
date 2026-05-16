extends Node

## Save / load system.
## Each save slot is a directory under user://saves/<slot>/ containing:
##   - meta.json     (save_version, slot_name, timestamp, world_seed)
##   - state.json    (GameState dump: slivers, defeated_bosses, recipes, etc.)
##   - world.json    (chunk diffs, placed structures, mob spawns — phase 4+)
##   - players.json  (per-Walker inventory, position, skills — phase 1+)
##
## JSON chosen for readability and forward-compat. Switch to binary if save size becomes a problem.
## Save format version is bumped any time a save-affecting field changes.

const SAVE_ROOT: String = "user://saves/"
## Save format version.
##   v2 — Phase 2: player/inventory/skills.
##   v3 — Phase 3: chest persistence.
##   v4 — Phase 4: explored_chunks + respawn_point. Older saves load with an
##        empty exploration log; the map just appears fresh.
##   v5 — Phase 7: allocated_talent_nodes, talent_presets, equipped_affixes,
##        SkillChallenges.mastery_unlocked.
##   v6 — Phase 8: cooking_discovered_recipes, fishing_trophies, pets dict,
##        and per-Aquarium/Beehive/NetTrap/FishTrophy dump_state.
##   v7 — Phase 9: npc_lifecycle (friendship, mood, reputation, daily quests,
##        flagged branches), housing.beds_to_npc, per-Sign/Mailbox/TradingBlock/
##        PetBowl/Painting dump_state.
##   v8 — Phase 10: phase10_helpers (boss cooldowns, kill counts, awakened
##        flags, lore moments, Verdancy age, Sunken Glyph fragments,
##        Glow-Crane quest), per-LarvaTrap dump_state, Sythrenn mercy +
##        Vol'thaar release flags (already stored in GameState.collected_relics).
const SAVE_VERSION: int = 8

signal save_started(slot_name: String)
signal save_completed(slot_name: String)
signal save_failed(slot_name: String, reason: String)
signal load_started(slot_name: String)
signal load_completed(slot_name: String)
signal load_failed(slot_name: String, reason: String)


## True between load_from_slot() and the next time the loaded world's
## WorldBootstrap consumes it. WorldBootstrap reads this to skip granting
## starter items / spawning at origin when the saved state should take over.
var pending_load: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))


func consume_pending_load() -> bool:
	var was_pending: bool = pending_load
	pending_load = false
	return was_pending


# ----- Public API -----

func save_to_slot(slot_name: String) -> Error:
	save_started.emit(slot_name)
	var dir_path := SAVE_ROOT + slot_name + "/"
	var make_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if make_err != OK and make_err != ERR_ALREADY_EXISTS:
		save_failed.emit(slot_name, "cannot create slot dir: %s" % error_string(make_err))
		return make_err

	var meta := {
		"save_version": SAVE_VERSION,
		"slot_name": slot_name,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"timestamp_iso": Time.get_datetime_string_from_system(),
		"world_seed": GameState.world_seed,
		"engine_version": Engine.get_version_info(),
	}
	var state := _dump_game_state()

	var meta_err := _write_json(dir_path + "meta.json", meta)
	if meta_err != OK:
		save_failed.emit(slot_name, "meta write failed: %s" % error_string(meta_err))
		return meta_err
	var state_err := _write_json(dir_path + "state.json", state)
	if state_err != OK:
		save_failed.emit(slot_name, "state write failed: %s" % error_string(state_err))
		return state_err

	save_completed.emit(slot_name)
	return OK


func load_from_slot(slot_name: String) -> Error:
	load_started.emit(slot_name)
	var dir_path := SAVE_ROOT + slot_name + "/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		load_failed.emit(slot_name, "slot directory not found")
		return ERR_FILE_NOT_FOUND

	var meta: Dictionary = {}
	var meta_err := _read_json(dir_path + "meta.json", meta)
	if meta_err != OK:
		load_failed.emit(slot_name, "meta read failed: %s" % error_string(meta_err))
		return meta_err

	var saved_version: int = int(meta.get("save_version", 0))
	if saved_version != SAVE_VERSION:
		# Phase 0: warn + best-effort. Phase 1+: migration scripts in scripts/systems/save_migrations/.
		push_warning("SaveSystem: save_version %d differs from current %d — attempting best-effort load" % [saved_version, SAVE_VERSION])

	var state: Dictionary = {}
	var state_err := _read_json(dir_path + "state.json", state)
	if state_err != OK:
		load_failed.emit(slot_name, "state read failed: %s" % error_string(state_err))
		return state_err

	GameState.world_seed = int(meta.get("world_seed", 0))
	_restore_game_state(state)
	pending_load = true

	load_completed.emit(slot_name)
	return OK


func slot_exists(slot_name: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_ROOT + slot_name + "/"))


func delete_slot(slot_name: String) -> Error:
	var dir_path := ProjectSettings.globalize_path(SAVE_ROOT + slot_name + "/")
	if not DirAccess.dir_exists_absolute(dir_path):
		return ERR_FILE_NOT_FOUND
	return _remove_directory_recursive(dir_path)


func list_slots() -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(SAVE_ROOT)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return result


func get_slot_meta(slot_name: String) -> Dictionary:
	var meta: Dictionary = {}
	_read_json(SAVE_ROOT + slot_name + "/meta.json", meta)
	return meta


# ----- Internals -----

func _dump_game_state() -> Dictionary:
	return {
		"aphelion_slivers_remaining": GameState.aphelion_slivers_remaining,
		"defeated_bosses": GameState.defeated_bosses,
		"collected_relics": GameState.collected_relics,
		"arrived_npcs": GameState.arrived_npcs,
		"unlocked_recipes": GameState.unlocked_recipes,
		"unlocked_compendium": GameState.unlocked_compendium,
		"sovereign_threads": GameState.sovereign_threads,
		"unallocated_talent_points": GameState.unallocated_talent_points,
		"allocated_talents": _stringify_keys(GameState.allocated_talents),
		"allocated_talent_nodes": _stringify_nested_talents(GameState.allocated_talent_nodes),
		"talent_presets": _stringify_presets(GameState.talent_presets),
		"active_preset_index": GameState.active_preset_index,
		"equipped_affixes": _stringify_equipped_affixes(),
		"mastery_unlocked": _stringify_keys(SkillChallenges.mastery_unlocked) if SkillChallenges else {},
		"player": _dump_player(),
		"inventory": _dump_inventory(),
		"skills": _dump_skills(),
		"chests": _dump_chests(),
		# Phase 4 — exploration + respawn anchor. Both already string-keyed /
		# JSON-safe; no per-key conversion needed.
		"explored_chunks": GameState.explored_chunks.duplicate(),
		"respawn_point_x": GameState.respawn_point.x,
		"respawn_point_y": GameState.respawn_point.y,
		# Phase 8 v6.
		"cooking_discovered": _stringify_keys(CookingSystem._discovered) if CookingSystem else {},
		"fishing_trophies": _stringify_keys(FishingSystem.trophies) if FishingSystem else {},
		"pets": _stringify_pets(),
		"phase8_structures": _dump_phase8_structures(),
		# Phase 9 v7.
		"npc_lifecycle": NpcLifecycle.dump_state() if NpcLifecycle else {},
		"housing": Housing.dump_state() if Housing else {},
		"phase9_structures": _dump_phase9_structures(),
		# Phase 10 v8.
		"phase10_helpers": Phase10Helpers.dump_state() if Phase10Helpers else {},
	}


func _restore_game_state(state: Dictionary) -> void:
	GameState.aphelion_slivers_remaining = int(state.get("aphelion_slivers_remaining", GameState.APHELION_STARTING_SLIVERS))
	GameState.defeated_bosses = state.get("defeated_bosses", {})
	GameState.collected_relics = state.get("collected_relics", {})
	GameState.arrived_npcs = state.get("arrived_npcs", {})
	GameState.unlocked_recipes = state.get("unlocked_recipes", {})
	GameState.unlocked_compendium = state.get("unlocked_compendium", {})
	GameState.sovereign_threads = int(state.get("sovereign_threads", 0))
	GameState.unallocated_talent_points = int(state.get("unallocated_talent_points", 0))
	GameState.allocated_talents = _stringname_keys(state.get("allocated_talents", {}))
	GameState.allocated_talent_nodes = _restore_nested_talents(state.get("allocated_talent_nodes", {}))
	GameState.talent_presets = _restore_presets(state.get("talent_presets", [{}, {}, {}]))
	GameState.active_preset_index = clampi(int(state.get("active_preset_index", 0)), 0, GameState.PRESET_COUNT - 1)
	_restore_equipped_affixes(state.get("equipped_affixes", {}))
	if SkillChallenges:
		SkillChallenges.mastery_unlocked = _stringname_keys(state.get("mastery_unlocked", {}))
	GameState.explored_chunks = state.get("explored_chunks", {})
	GameState.respawn_point = Vector2(
		float(state.get("respawn_point_x", 0.0)),
		float(state.get("respawn_point_y", 0.0)),
	)
	_restore_inventory(state.get("inventory", {}))
	_restore_skills(state.get("skills", {}))
	_pending_chests_restore = state.get("chests", [])
	# Phase 8 v6.
	if CookingSystem:
		CookingSystem._discovered = _stringname_keys(state.get("cooking_discovered", {}))
	if FishingSystem:
		FishingSystem.trophies = _stringname_keys(state.get("fishing_trophies", {}))
	_restore_pets(state.get("pets", {}))
	_pending_phase8_structures = state.get("phase8_structures", [])
	# Phase 9 v7.
	if NpcLifecycle:
		NpcLifecycle.restore_state(state.get("npc_lifecycle", {}))
	if Housing:
		Housing.restore_state(state.get("housing", {}))
	_pending_phase9_structures = state.get("phase9_structures", [])
	# Phase 10 v8.
	if Phase10Helpers:
		Phase10Helpers.restore_state(state.get("phase10_helpers", {}))
	# Player restore is signal-driven: when SaveSystem holds pending state, it
	# subscribes once to EventBus.player_spawned. The next player to spawn
	# (either the existing one re-detected, or a fresh one after scene change)
	# receives the saved position + vitals.
	_pending_player_restore = state.get("player", {})
	if not _pending_player_restore.is_empty():
		if not EventBus.player_spawned.is_connected(_on_player_spawned_for_restore):
			EventBus.player_spawned.connect(_on_player_spawned_for_restore)
		# Also try immediately in case the player already exists in the tree
		# (e.g. mid-game pause-menu Load on the active world).
		var players := get_tree().get_nodes_in_group("player") if get_tree() else []
		if not players.is_empty():
			_apply_player_restore(players[0])


# Per-Walker state. Position + hp + mana. Multiplayer (Phase 13) will replace
# with an array keyed by peer_id.
func _dump_player() -> Dictionary:
	var players := get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.is_empty():
		return {}
	var p := players[0] as Node2D
	if p == null:
		return {}
	var out: Dictionary = {
		"position_x": p.global_position.x,
		"position_y": p.global_position.y,
	}
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp:
		out["hp_current"] = hp.current_health
		out["hp_max"] = hp.max_health
	var mp := p.get_node_or_null("ManaComponent") as ManaComponent
	if mp:
		out["mp_current"] = mp.current_mana
		out["mp_max"] = mp.max_mana
	return out


var _pending_player_restore: Dictionary = {}


func _on_player_spawned_for_restore(player: Node) -> void:
	_apply_player_restore(player)


func _apply_player_restore(player: Node) -> void:
	if _pending_player_restore.is_empty() or player == null:
		return
	var p := player as Node2D
	if p == null:
		return
	var pos := Vector2(
		float(_pending_player_restore.get("position_x", 0.0)),
		float(_pending_player_restore.get("position_y", 0.0)),
	)
	p.global_position = pos
	if p is PlayerController:
		(p as PlayerController).set_respawn_position(pos)
	var hp := p.get_node_or_null("HealthComponent") as HealthComponent
	if hp and _pending_player_restore.has("hp_current"):
		hp.max_health = int(_pending_player_restore.get("hp_max", hp.max_health))
		hp.current_health = clampi(int(_pending_player_restore["hp_current"]), 1, hp.max_health)
		hp.health_changed.emit(hp.current_health, hp.max_health)
	var mp := p.get_node_or_null("ManaComponent") as ManaComponent
	if mp and _pending_player_restore.has("mp_current"):
		mp.max_mana = int(_pending_player_restore.get("mp_max", mp.max_mana))
		mp.current_mana = clampf(float(_pending_player_restore["mp_current"]), 0.0, float(mp.max_mana))
		mp.mana_changed.emit(int(mp.current_mana), mp.max_mana)
	_pending_player_restore = {}
	# Player state has been applied — nothing left for a future WorldBootstrap
	# to honour, so clear the bootstrap skip-flag too.
	pending_load = false
	if EventBus.player_spawned.is_connected(_on_player_spawned_for_restore):
		EventBus.player_spawned.disconnect(_on_player_spawned_for_restore)


func _dump_inventory() -> Dictionary:
	var slots: Array = []
	for s in Inventory.slots:
		if s == null:
			slots.append(null)
		else:
			slots.append({"item_id": String(s.get("item_id", "")), "count": int(s.get("count", 0))})
	var equipment: Dictionary = {}
	for k in Inventory.equipment.keys():
		equipment[String(k)] = String(Inventory.equipment[k])
	return {"slots": slots, "equipment": equipment}


func _restore_inventory(data: Dictionary) -> void:
	if data.is_empty():
		return
	Inventory.clear()
	var slots: Array = data.get("slots", [])
	for i in range(mini(slots.size(), Inventory.slots.size())):
		var s = slots[i]
		if s == null:
			continue
		var item_id := StringName(String(s.get("item_id", "")))
		var count := int(s.get("count", 0))
		if item_id == &"" or count <= 0:
			continue
		Inventory.slots[i] = {"item_id": item_id, "count": count}
		Inventory.slot_changed.emit(i, item_id, count)
	for k in (data.get("equipment", {}) as Dictionary).keys():
		Inventory.equip(StringName(String(k)), StringName(String(data["equipment"][k])))
	EventBus.inventory_changed.emit()


## Phase 3.6 — Persist every Chest in the scene tree.
func _dump_chests() -> Array:
	var out: Array = []
	if get_tree() == null:
		return out
	for c in get_tree().get_nodes_in_group("chest"):
		if not is_instance_valid(c):
			continue
		if c.has_method("dump_state"):
			out.append(c.call("dump_state"))
	return out


var _pending_chests_restore: Array = []


## Restore chest contents into the scene. Called by world_bootstrap after the
## main world finishes spawning placeable chests; matches by unique_id.
func consume_pending_chests() -> Array:
	var out: Array = _pending_chests_restore.duplicate(true)
	_pending_chests_restore = []
	return out


func _dump_skills() -> Dictionary:
	var out: Dictionary = {}
	for s in SkillSystem.ALL_SKILLS:
		out[String(s)] = {
			"xp": int(SkillSystem.get_xp(s)),
			"level": int(SkillSystem.get_level(s)),
		}
	return out


func _restore_skills(data: Dictionary) -> void:
	if data.is_empty():
		return
	for s in SkillSystem.ALL_SKILLS:
		var rec: Dictionary = data.get(String(s), {})
		if rec.is_empty():
			SkillSystem._xp[s] = 0
			SkillSystem._level[s] = 0
		else:
			SkillSystem._xp[s] = int(rec.get("xp", 0))
			SkillSystem._level[s] = int(rec.get("level", 0))


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = d[k]
	return out


func _stringname_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(String(k))] = d[k]
	return out


## Phase 7 — talent presets are Array[Dictionary] with nested skill/node maps.
## JSON loses StringName so we must round-trip both layers.
func _stringify_nested_talents(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for skill in d.keys():
		var inner: Dictionary = d[skill]
		var inner_out: Dictionary = {}
		for node in inner.keys():
			inner_out[String(node)] = int(inner[node])
		out[String(skill)] = inner_out
	return out


func _restore_nested_talents(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for skill in d.keys():
		var inner: Dictionary = d[skill]
		var inner_out: Dictionary = {}
		for node in inner.keys():
			inner_out[StringName(String(node))] = int(inner[node])
		out[StringName(String(skill))] = inner_out
	return out


func _stringify_presets(presets: Array) -> Array:
	var out: Array = []
	for p in presets:
		out.append(_stringify_nested_talents(p))
	return out


func _restore_presets(arr: Array) -> Array:
	var out: Array = []
	for p in arr:
		out.append(_restore_nested_talents(p))
	while out.size() < GameState.PRESET_COUNT:
		out.append({})
	return out


func _stringify_equipped_affixes() -> Dictionary:
	var out: Dictionary = {}
	for slot in Inventory.equipped_affixes.keys():
		var affix: Dictionary = Inventory.equipped_affixes[slot]
		var clean: Dictionary = {}
		for k in affix.keys():
			clean[String(k)] = affix[k]
		out[String(slot)] = clean
	return out


func _stringify_pets() -> Dictionary:
	var out: Dictionary = {}
	if Pets == null:
		return out
	for k in Pets.pets.keys():
		var rec: Dictionary = Pets.pets[k]
		out[String(k)] = {
			"xp": int(rec.get("xp", 0)),
			"level": int(rec.get("level", 1)),
			"mood": int(rec.get("mood", 50)),
			"dead": bool(rec.get("dead", false)),
		}
	return out


func _restore_pets(d: Dictionary) -> void:
	if Pets == null:
		return
	Pets.pets.clear()
	for k in d.keys():
		var src: Dictionary = d[k]
		Pets.pets[StringName(String(k))] = {
			"xp": int(src.get("xp", 0)),
			"level": int(src.get("level", 1)),
			"mood": int(src.get("mood", 50)),
			"dead": bool(src.get("dead", false)),
		}


## Phase 8 — per-structure persistence for aquariums / beehives / net traps /
## fish trophies. Each contributing class implements dump_state() + restore_state().
var _pending_phase8_structures: Array = []


func _dump_phase8_structures() -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for group in [&"aquarium", &"beehive", &"net_trap", &"fish_trophy"]:
		for n in tree.get_nodes_in_group(group):
			if not is_instance_valid(n):
				continue
			if not n.has_method("dump_state"):
				continue
			var node := n as Node2D
			if node == null:
				continue
			out.append({
				"group": String(group),
				"x": node.global_position.x,
				"y": node.global_position.y,
				"state": node.call("dump_state"),
			})
	return out


func consume_pending_phase8_structures() -> Array:
	var out: Array = _pending_phase8_structures.duplicate(true)
	_pending_phase8_structures = []
	return out


# Phase 9 — Sign / Painting / Mailbox / TradingBlock / PetBowl persistence.
var _pending_phase9_structures: Array = []


func _dump_phase9_structures() -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for group in [&"sign", &"painting", &"mailbox", &"trading_block", &"pet_bowl"]:
		for n in tree.get_nodes_in_group(group):
			if not is_instance_valid(n):
				continue
			if not n.has_method("dump_state"):
				continue
			var node := n as Node2D
			if node == null:
				continue
			out.append({
				"group": String(group),
				"x": node.global_position.x,
				"y": node.global_position.y,
				"state": node.call("dump_state"),
			})
	return out


func consume_pending_phase9_structures() -> Array:
	var out: Array = _pending_phase9_structures.duplicate(true)
	_pending_phase9_structures = []
	return out


func _restore_equipped_affixes(d: Dictionary) -> void:
	Inventory.equipped_affixes.clear()
	for slot in d.keys():
		var clean: Dictionary = {}
		var src: Dictionary = d[slot]
		for k in src.keys():
			clean[k] = src[k]
		Inventory.equipped_affixes[StringName(String(slot))] = clean


func _write_json(path: String, data: Variant) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


func _read_json(path: String, out_data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return err
	if typeof(json.data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	for k in (json.data as Dictionary).keys():
		out_data[k] = (json.data as Dictionary)[k]
	return OK


func _remove_directory_recursive(abs_path: String) -> Error:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return ERR_FILE_NOT_FOUND
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child := abs_path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(abs_path)
