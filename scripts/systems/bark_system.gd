extends Node

## Phase 5.34 — NPC reaction barks. When a boss is defeated, every arrived
## NPC has a chance to surface a short reaction line via a UI toast. Lines
## are keyed by `npc_id` × `boss_id`; missing combos fall through to a generic
## "{npc}: …" line so every NPC always has *something* to say.

const REACTIONS: Dictionary = {
	&"npc_aelstren": {
		&"boss_glaurem": "Aelstren bows her head. \"Quiet at last.\"",
		&"_generic": "Aelstren marks the map with a fresh stroke of ink.",
	},
	&"npc_brindle": {
		&"boss_glaurem": "Brindle grins. \"The stone yields. Now we forge.\"",
		&"_generic": "Brindle's hammer rings once. He nods.",
	},
}


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(boss_id: StringName) -> void:
	# Stagger so multiple barks don't overlap.
	var delay: float = 1.5
	for npc_id in GameState.arrived_npcs.keys():
		if not GameState.arrived_npcs[npc_id]:
			continue
		var line: String = _line_for(npc_id, boss_id)
		if line == "":
			continue
		_schedule(line, delay)
		delay += 3.0


func _line_for(npc_id: StringName, boss_id: StringName) -> String:
	var table: Dictionary = REACTIONS.get(npc_id, {})
	if table.is_empty():
		return ""
	return table.get(boss_id, table.get(&"_generic", ""))


func _schedule(line: String, delay_seconds: float) -> void:
	var t := get_tree().create_timer(delay_seconds)
	t.timeout.connect(func() -> void:
		EventBus.ui_toast.emit(line, 3.5)
	)
