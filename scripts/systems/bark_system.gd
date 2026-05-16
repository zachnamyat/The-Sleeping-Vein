extends Node

## Phase 5.34 + Phase 9 extensions — NPC reaction barks.
##
## Triggers:
##   - boss kills          (5.34)
##   - player respawn      (9.52 — Cantor "sun grows dim" line)
##   - aphelion_dimmed     (9.45 — once-per-25-slivers world commentary)
##   - wormbound_peace     (9.54 — Aelstren announces map redraw)
##   - daily_reset         (9.42 — short morning lines)

const REACTIONS: Dictionary = {
	&"npc_aelstren": {
		&"boss_glaurem": "Aelstren bows her head. \"Quiet at last.\"",
		&"wormbound_peace": "Aelstren: \"Wormbound trails will draw themselves on the map now.\"",
		&"_generic": "Aelstren marks the map with a fresh stroke of ink.",
	},
	&"npc_brindle": {
		&"boss_glaurem": "Brindle grins. \"The stone yields. Now we forge.\"",
		&"_generic": "Brindle's hammer rings once. He nods.",
	},
	&"npc_mira": {
		&"boss_glaurem": "Mira: \"Add it to the ledger.\"",
		&"_generic": "Mira: \"I'll sort that.\"",
	},
	&"npc_cantor": {
		&"boss_glaurem": "The Cantor: \"The first bell.\"",
		&"_generic": "The Cantor's bells shift one tone lower.",
	},
	&"npc_old_hask": {
		&"_generic": "Old Hask: \"Aye. The deep heard it.\"",
	},
}

## Phase 9.52 — Cantor death-count thresholds. When player respawn count
## crosses these, the Cantor's line surfaces.
const CANTOR_RESPAWN_LINES: Array[Dictionary] = [
	{ "threshold": 5,   "line": "The Cantor: \"Walker. The sun grows dim because of mercies like yours.\"" },
	{ "threshold": 25,  "line": "The Cantor: \"You're still here. Of course.\"" },
	{ "threshold": 100, "line": "The Cantor: \"Five bells, but only three rings now. The fourth went somewhere with you.\"" },
]

var _respawn_count: int = 0
var _cantor_lines_used: Dictionary = {}


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_respawned.connect(_on_player_respawned)
	if NpcLifecycle:
		NpcLifecycle.daily_reset.connect(_on_daily_reset)


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


func _on_player_respawned(_player: Node, _slivers: int) -> void:
	_respawn_count += 1
	if not GameState.arrived_npcs.get(&"npc_cantor", false):
		return
	# Cantor death-count commentary (9.52).
	for row in CANTOR_RESPAWN_LINES:
		var t: int = int(row.get("threshold", 0))
		if _respawn_count == t and not bool(_cantor_lines_used.get(t, false)):
			_schedule(String(row.get("line", "")), 1.2)
			_cantor_lines_used[t] = true
			if NpcLifecycle:
				NpcLifecycle.set_flag(&"many_deaths", true)
			break


func _on_daily_reset(_new_day: int) -> void:
	# Phase 9.42 — every dawn, one NPC says a short line.
	var keys := GameState.arrived_npcs.keys()
	if keys.is_empty():
		return
	var pick: StringName = keys[randi() % keys.size()]
	if not GameState.arrived_npcs[pick]:
		return
	var line := _line_for(pick, &"_generic")
	if line != "":
		_schedule(line, 2.0)


## Phase 9.54 — Wormbound peace event-broadcast. Called externally when the
## peace is made.
func broadcast_wormbound_peace() -> void:
	if NpcLifecycle == null:
		return
	NpcLifecycle.set_flag(&"wormbound_peace_made", true)
	var delay: float = 1.5
	for npc_id in GameState.arrived_npcs.keys():
		if not GameState.arrived_npcs[npc_id]:
			continue
		var line: String = _line_for(npc_id, &"wormbound_peace")
		if line == "":
			line = _line_for(npc_id, &"_generic")
		if line != "":
			_schedule(line, delay)
			delay += 2.5


func _line_for(npc_id: StringName, context: StringName) -> String:
	var table: Dictionary = REACTIONS.get(npc_id, {})
	if table.is_empty():
		return ""
	return table.get(context, table.get(&"_generic", ""))


func _schedule(line: String, delay_seconds: float) -> void:
	var t := get_tree().create_timer(delay_seconds)
	t.timeout.connect(func() -> void:
		EventBus.ui_toast.emit(line, 3.5)
	)


# Save round-trip — we only persist what would be confusing to lose (the
# Cantor death-count lines used).
func dump_state() -> Dictionary:
	var used: Dictionary = {}
	for k in _cantor_lines_used.keys():
		used[String(k)] = bool(_cantor_lines_used[k])
	return { "respawn_count": _respawn_count, "cantor_lines_used": used }


func restore_state(d: Dictionary) -> void:
	_respawn_count = int(d.get("respawn_count", 0))
	_cantor_lines_used.clear()
	var used: Dictionary = d.get("cantor_lines_used", {})
	for k in used.keys():
		_cantor_lines_used[int(k)] = bool(used[k])
