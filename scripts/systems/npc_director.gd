extends Node

## NPC arrival director. Listens for boss kills + relic insertions and spawns NPCs
## at the Anchor (world origin).
##
## Phase 5 polish (2026-05-15):
##   5.20 — arrival "cinematic-toast": a longer pause + EventBus letterbox
##           dip + screen pulse instead of a plain toast.
##   5.36 — first-NPC warm-up: when the first NPC arrives in a fresh world we
##           also play an extended sting + a paper-bird flutter from the Loom.

const ANCHOR_TILE_RADIUS: int = 4

var _npc_scenes: Dictionary = {
	&"npc_aelstren": "res://scenes/npcs/aelstren.tscn",
	&"npc_brindle": "res://scenes/npcs/brindle.tscn",
}

var _npc_positions: Dictionary = {
	&"npc_aelstren": Vector2(-32, 32),
	&"npc_brindle": Vector2(32, 48),
}

var _spawned: Dictionary = {}


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	# Phase 5: Aelstren arrives once world is loaded (no prerequisite).
	call_deferred("_spawn_npc_if_needed", &"npc_aelstren")


func _spawn_npc_if_needed(npc_id: StringName) -> void:
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
	npc.position = _npc_positions.get(npc_id, Vector2.ZERO)
	var tree := get_tree()
	if tree and tree.current_scene:
		var entities := tree.current_scene.get_node_or_null("WorldGen/YSortRoot/Entities") as Node2D
		if entities:
			entities.add_child(npc)
			_spawned[npc_id] = true
			GameState.arrived_npcs[npc_id] = true
			EventBus.npc_arrived.emit(npc_id)
			_play_arrival_cinematic(npc_id, npc)


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
	# Loom sits at world origin in the Anchor scene; pull from a node in the
	# group if possible, fall back to origin.
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


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"boss_glaurem":
		call_deferred("_spawn_npc_if_needed", &"npc_brindle")


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	# Mining first shaleseed brings Brindle out fastest.
	if item_id == &"shaleseed":
		call_deferred("_spawn_npc_if_needed", &"npc_brindle")
