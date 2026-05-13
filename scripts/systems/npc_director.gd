extends Node

## NPC arrival director. Listens for boss kills + relic insertions and spawns NPCs
## at the Anchor (world origin).

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
			EventBus.ui_toast.emit("%s has arrived." % String(npc_id).replace("npc_", "").capitalize(), 3.0)


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"boss_glaurem":
		call_deferred("_spawn_npc_if_needed", &"npc_brindle")


func _on_item_picked_up(item_id: StringName, _count: int) -> void:
	# Mining first shaleseed brings Brindle out fastest.
	if item_id == &"shaleseed":
		call_deferred("_spawn_npc_if_needed", &"npc_brindle")
