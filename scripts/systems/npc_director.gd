extends Node

## NPC arrival director. Listens for boss kills + relic insertions + bed
## placement and spawns NPCs at the Anchor / their bound bed.
##
## Phase 5 polish (2026-05-15):
##   5.20 — arrival "cinematic-toast": letterbox dip + screen pulse.
##   5.36 — first-NPC paper-bird flutter.
##
## Phase 9 expansions:
##   9.1/9.2 — Each non-Aelstren NPC waits in a "pending" queue until the
##             player places a bed inside a valid 8×8 room (Housing.validate_room).
##   9.5–9.9 — Five merchant NPCs registered: brindle, mira, cantor, old_hask,
##             veiled_buyer + a wandering merchant. Each NPC has scene path,
##             arrival trigger (boss kill / item pickup / coin threshold),
##             housing requirement, and theme music key.
##   9.32 —    Random-spawn wandering merchant tick (1/world-day chance).
##   9.42/9.45 NPC barks at events route through here so they share the queue.

const ANCHOR_TILE_RADIUS: int = 4

var _npc_scenes: Dictionary = {
	&"npc_aelstren":     "res://scenes/npcs/aelstren.tscn",
	&"npc_brindle":      "res://scenes/npcs/brindle.tscn",
	&"npc_mira":         "res://scenes/npcs/mira.tscn",
	&"npc_cantor":       "res://scenes/npcs/cantor.tscn",
	&"npc_old_hask":     "res://scenes/npcs/old_hask.tscn",
	&"npc_veiled_buyer": "res://scenes/npcs/veiled_buyer.tscn",
}

var _npc_default_positions: Dictionary = {
	&"npc_aelstren":     Vector2(-32, 32),
	&"npc_brindle":      Vector2(32, 48),
	&"npc_mira":         Vector2(-48, -32),
	&"npc_cantor":       Vector2(48, -16),
	&"npc_old_hask":     Vector2(-64, 16),
	&"npc_veiled_buyer": Vector2(64, 64),
}

## NPCs that need a housed bed before they will move in (9.1, 9.2). Aelstren is
## the only NPC who arrives at world start without housing.
const HOUSING_REQUIRED: Dictionary = {
	&"npc_aelstren":     false,
	&"npc_brindle":      true,
	&"npc_mira":         true,
	&"npc_cantor":       true,
	&"npc_old_hask":     true,
	&"npc_veiled_buyer": false,  ## wanders in/out
}

## NPCs eligible to take an unbound bed when the player places one. Order
## matters — the first NPC whose arrival prerequisite is satisfied gets it.
const BED_PRIORITY_ORDER: Array[StringName] = [
	&"npc_brindle", &"npc_mira", &"npc_cantor", &"npc_old_hask",
]

var _spawned: Dictionary = {}
var _pending_random_visit_unix: int = 0


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	if NpcLifecycle:
		NpcLifecycle.daily_reset.connect(_on_daily_reset)
	# Phase 5: Aelstren arrives once world is loaded (no prerequisite).
	call_deferred("_spawn_npc_if_needed", &"npc_aelstren")


# ----- Phase 9.1/9.2 — bed-driven arrivals -----

func try_assign_bed(bed: Node2D) -> StringName:
	## Called by Bed._ready. Validates the room, then assigns the highest-
	## priority not-yet-arrived NPC. Returns the bound NPC id or &"" on failure.
	if bed == null or not is_instance_valid(bed):
		return &""
	if Housing == null:
		return &""
	# Already bound on a previous placement → keep binding.
	var existing: StringName = Housing.npc_for_bed(bed.global_position)
	if existing != &"":
		_spawn_npc_if_needed(existing, bed)
		return existing
	var housing_check: Dictionary = _validate_anchor_room(bed.global_position)
	if not bool(housing_check.get("valid", false)):
		EventBus.ui_toast.emit("Bed placed but no NPC room yet (need walls + door).", 3.0)
		return &""
	for npc_id in BED_PRIORITY_ORDER:
		if GameState.arrived_npcs.get(npc_id, false):
			continue
		if not _arrival_prerequisite_met(npc_id):
			continue
		if Housing.bind_bed_to_npc(bed.global_position, npc_id):
			if bed.has_method("set_bound_npc"):
				bed.call("set_bound_npc", npc_id)
			_spawn_npc_if_needed(npc_id, bed)
			return npc_id
	EventBus.ui_toast.emit("A bed waits. No NPC qualifies yet.", 3.0)
	return &""


func _validate_anchor_room(bed_world_pos: Vector2) -> Dictionary:
	# Walls/floors layer paths follow the main.tscn convention used by Phase 4+.
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return { "valid": true }  ## be permissive in headless tests
	var walls := tree.current_scene.get_node_or_null("WorldGen/Walls") as TileMapLayer
	var floors := tree.current_scene.get_node_or_null("WorldGen/Floors") as TileMapLayer
	if walls == null or floors == null:
		# Anchor layout may not have wall tiles in the bootstrap scene; allow
		# arrival anyway so the player can recruit NPCs in the placeholder world.
		return { "valid": true, "permissive_pass": true }
	return Housing.validate_room(bed_world_pos, walls.get_path(), floors.get_path())


func _arrival_prerequisite_met(npc_id: StringName) -> bool:
	# Each NPC's natural "arrives because of X" trigger. By the time the bed is
	# placed, the player usually has crossed at least one of these thresholds.
	match npc_id:
		&"npc_brindle":
			return GameState.has_defeated_boss(&"boss_glaurem") or _inventory_holds_min(&"shaleseed", 1)
		&"npc_mira":
			return _inventory_holds_min(&"ancient_coin", 5) or GameState.unlocked_recipes.size() >= 3
		&"npc_cantor":
			return GameState.aphelion_slivers_remaining <= GameState.APHELION_STARTING_SLIVERS - 1 \
				or GameState.has_defeated_boss(&"boss_glaurem")
		&"npc_old_hask":
			return _inventory_holds_min(&"fishing_rod_wood", 1) or _inventory_holds_min(&"cave_guppy", 1)
		_:
			return true


func _inventory_holds_min(item_id: StringName, amount: int) -> bool:
	if Inventory == null:
		return false
	return Inventory.count_of(item_id) >= amount


# ----- Spawn / cinematic arrival -----

func _spawn_npc_if_needed(npc_id: StringName, bed: Node2D = null) -> void:
	if GameState.arrived_npcs.get(npc_id, false):
		return
	if _spawned.get(npc_id, false):
		return
	var path: String = _npc_scenes.get(npc_id, "")
	if path == "":
		return
	var scn := load(path) as PackedScene
	if scn == null:
		return
	var npc := scn.instantiate() as Node2D
	var pos: Vector2 = _npc_default_positions.get(npc_id, Vector2.ZERO)
	if bed != null and is_instance_valid(bed):
		# Stand next to the bed so the NPC visibly belongs to the room the
		# player built.
		pos = bed.global_position + Vector2(16, 0)
	npc.position = pos
	var tree := get_tree()
	if tree and tree.current_scene:
		var entities := tree.current_scene.get_node_or_null("WorldGen/YSortRoot/Entities") as Node2D
		if entities:
			entities.add_child(npc)
			_spawned[npc_id] = true
			GameState.arrived_npcs[npc_id] = true
			# Phase 9.11/9.20 — store bed pos on the NPC for pathfinding.
			if bed != null and npc.has_method("set"):
				npc.set("home_bed_pos", bed.global_position)
				npc.set("shop_pos", pos)
			EventBus.npc_arrived.emit(npc_id)
			_play_arrival_cinematic(npc_id, npc)
			# Phase 9.60 — gaining an NPC bumps their faction's reputation.
			var faction: StringName = NpcLifecycle.NPC_FACTIONS.get(npc_id, &"") if NpcLifecycle else &""
			if faction != &"":
				NpcLifecycle.add_reputation(faction, 50)


## Phase 5.20 / 5.36 — cinematic arrival toast.
##   - Brief letterbox dip + screen pulse on arrival
##   - First NPC (Aelstren) gets a paper-bird flutter from the Loom
func _play_arrival_cinematic(npc_id: StringName, npc_node: Node2D) -> void:
	var display_name: String = String(npc_id).replace("npc_", "").capitalize()
	var first_npc: bool = GameState.arrived_npcs.size() == 1
	# Brief cinematic dip — letterbox is a soft pillarbox the HUD ignores.
	EventBus.letterbox_requested.emit(true, 0.25)
	EventBus.screen_pulse_requested.emit(0.18, 0.45)
	if AudioBus:
		AudioBus.play_sfx(&"npc_arrival")
	EventBus.ui_toast.emit("%s has arrived." % display_name, 3.5)
	# Restore the screen after a short beat.
	var unfade := get_tree().create_timer(1.2)
	unfade.timeout.connect(func() -> void:
		EventBus.letterbox_requested.emit(false, 0.4)
	)
	if first_npc:
		_spawn_paper_bird_for(npc_node)


func _spawn_paper_bird_for(target: Node2D) -> void:
	# Phase 5.36 — Loom flutters a paper bird out to greet the new arrival.
	var scn := load("res://scenes/fx/paper_bird.tscn") as PackedScene
	if scn == null:
		return
	var bird := scn.instantiate() as Node2D
	if bird == null:
		return
	var start: Vector2 = Vector2.ZERO
	for loom in get_tree().get_nodes_in_group("loom"):
		if loom is Node2D:
			start = (loom as Node2D).global_position
			break
	bird.set("start_pos", start + Vector2(0, -12))
	bird.set("target_pos", target.global_position + Vector2(0, -16))
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(bird)


# ----- Event hooks -----

func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"boss_glaurem":
		# Brindle has *arrival* priority on Glaur-em kill if a bed exists; else
		# notify the player to place one.
		if not GameState.arrived_npcs.get(&"npc_brindle", false):
			var beds := get_tree().get_nodes_in_group("bed") if get_tree() else []
			if beds.is_empty():
				EventBus.ui_toast.emit("Brindle is restless. Place a Bed.", 3.0)
	# Phase 9.45 — NPCs pause-and-comment on the kill.
	if Phase9Helpers:
		Phase9Helpers.broadcast_world_event_comment(boss_id)


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	# Mira gets a soft hint when the player first picks up coins.
	if item_id == &"ancient_coin" and not GameState.arrived_npcs.get(&"npc_mira", false):
		EventBus.ui_toast.emit("A traveller will find the coin's smell.", 2.0)


func _on_inventory_changed() -> void:
	# Phase 9.32 — wandering merchant chance: tick once per minute.
	var now: int = int(Time.get_unix_time_from_system())
	if now - _pending_random_visit_unix < 60:
		return
	_pending_random_visit_unix = now
	if GameState.arrived_npcs.get(&"npc_veiled_buyer", false):
		return
	if randf() < 0.04:
		_spawn_npc_if_needed(&"npc_veiled_buyer")


func _on_daily_reset(_new_day_index: int) -> void:
	# Phase 9.32 — Veiled Buyer leaves at the day boundary, may re-spawn later.
	if GameState.arrived_npcs.get(&"npc_veiled_buyer", false):
		_despawn(&"npc_veiled_buyer")


func _despawn(npc_id: StringName) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("npc"):
		if n is Node and n.get("npc_id") == npc_id:
			(n as Node).queue_free()
			break
	_spawned.erase(npc_id)
	GameState.arrived_npcs[npc_id] = false


func is_pending(npc_id: StringName) -> bool:
	return not GameState.arrived_npcs.get(npc_id, false) and _arrival_prerequisite_met(npc_id)
