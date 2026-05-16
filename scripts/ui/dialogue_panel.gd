extends Control
class_name DialoguePanel

## Tree-driven dialogue UI. Shows NPC name, current node text, and clickable responses.
## Walker is mute — the player only chooses gesture-responses.
##
## Phase 9 features:
##   9.12 — Branching: responses can carry require_flag / forbid_flag /
##           require_friendship / require_quest_state. Filtered before render.
##   9.19 — "Give a gift" response routes to gift_panel.
##   9.21 — Mood-based dialogue text via DialogueTree.resolve_node.
##   9.45 — pause-and-comment lines reveal when NpcLifecycle.get_flag matches.
##   9.64 — Brindle-specific Pyrenkin accent toggle is applied through a
##           node-level "accent_pyrenkin" flag handled here.

@onready var name_label: Label = $Panel/Name
@onready var text_label: RichTextLabel = $Panel/Body
@onready var responses_box: VBoxContainer = $Panel/Responses

var _current_npc: NPC
var _current_node_id: String = ""


func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false


func open_for_npc(npc: NPC) -> void:
	_current_npc = npc
	if npc.dialogue == null:
		return
	visible = true
	_show_node(npc.dialogue.entry_node_id)


func close_if_for(npc: NPC) -> void:
	if _current_npc == npc:
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		visible = false


func _show_node(node_id: String) -> void:
	_current_node_id = node_id
	if _current_npc == null:
		return
	var mood := ""
	if NpcLifecycle:
		mood = String(NpcLifecycle.mood_category(_current_npc.npc_id))
	var data: Dictionary = _current_npc.dialogue.resolve_node(node_id, mood) \
		if _current_npc.dialogue.has_method("resolve_node") \
		else _current_npc.dialogue.get_node_data(node_id)
	if data.is_empty():
		visible = false
		return
	name_label.text = data.get("speaker", _current_npc.display_name)
	var raw_text: String = data.get("text", "...")
	# Phase 9.64 — Brindle accent: replace contractions/words when flag set.
	if String(_current_npc.npc_id) == "npc_brindle":
		raw_text = _apply_pyrenkin_accent(raw_text)
	text_label.text = raw_text
	# Apply node-level side-effects (set_flag / add_friendship / unlock_recipe / open_shop).
	_apply_node_effects(data)
	for child in responses_box.get_children():
		child.queue_free()
	var responses: Array = data.get("responses", [])
	if responses.is_empty():
		_add_response("(silently nod)", "")
	else:
		for r in responses:
			if not _response_visible(r):
				continue
			_add_response(r.get("label", "..."), r.get("goto", ""), r)


func _response_visible(r: Dictionary) -> bool:
	if NpcLifecycle == null:
		return true
	if r.has("require_flag") and not NpcLifecycle.get_flag(StringName(String(r["require_flag"]))):
		return false
	if r.has("forbid_flag") and NpcLifecycle.get_flag(StringName(String(r["forbid_flag"]))):
		return false
	if r.has("require_friendship"):
		if NpcLifecycle.get_friendship(_current_npc.npc_id) < int(r["require_friendship"]):
			return false
	if r.has("require_quest_state"):
		var q := String(r["require_quest_state"])
		var parts := q.split(":")
		if parts.size() == 2:
			if String(NpcLifecycle.quest_states.get(StringName(parts[0]), "")) != parts[1]:
				return false
	if r.has("event_flag") and not NpcLifecycle.get_flag(StringName(String(r["event_flag"]))):
		return false
	return true


func _apply_node_effects(data: Dictionary) -> void:
	if NpcLifecycle == null:
		return
	if data.has("set_flag"):
		NpcLifecycle.set_flag(StringName(String(data["set_flag"])), true)
	if data.has("clear_flag"):
		NpcLifecycle.set_flag(StringName(String(data["clear_flag"])), false)
	if data.has("add_friendship"):
		NpcLifecycle.add_friendship(_current_npc.npc_id, int(data["add_friendship"]))
	if data.has("unlock_recipe"):
		var rid: StringName = StringName(String(data["unlock_recipe"]))
		if not GameState.unlocked_recipes.has(rid):
			GameState.unlocked_recipes[rid] = true
			EventBus.recipe_unlocked.emit(rid)


func _add_response(label: String, goto: String, raw: Dictionary = {}) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(220, 18)
	b.pressed.connect(func() -> void:
		if String(raw.get("action", "")) == "open_shop":
			_open_shop_for(_current_npc)
			visible = false
			return
		if String(raw.get("action", "")) == "open_gift":
			_open_gift_for(_current_npc)
			visible = false
			return
		if String(raw.get("action", "")) == "open_repair":
			_open_repair_for(_current_npc)
			visible = false
			return
		if String(raw.get("action", "")) == "open_identify":
			_open_identify_for(_current_npc)
			visible = false
			return
		if String(raw.get("action", "")) == "open_teleport":
			_open_teleport_for(_current_npc)
			visible = false
			return
		if String(raw.get("action", "")) == "open_quest_log":
			var qls := get_tree().get_nodes_in_group("quest_log_ui")
			if not qls.is_empty():
				(qls[0]).call("show_log")
			visible = false
			return
		if goto == "" or goto == "end":
			visible = false
		else:
			_show_node(goto)
	)
	responses_box.add_child(b)


func _open_shop_for(npc: NPC) -> void:
	var ms := get_tree().get_nodes_in_group("merchant_ui")
	if ms.is_empty():
		return
	(ms[0]).open_for_npc(npc)


func _open_gift_for(npc: NPC) -> void:
	var gs := get_tree().get_nodes_in_group("gift_ui")
	if gs.is_empty():
		# Fallback: show inventory hint.
		EventBus.ui_toast.emit("Drop a gift in their hand (E).", 2.0)
		return
	(gs[0]).call("open_for_npc", npc)


func _open_repair_for(npc: NPC) -> void:
	var rs := get_tree().get_nodes_in_group("repair_ui")
	if rs.is_empty():
		EventBus.ui_toast.emit("No items in need of repair.", 2.0)
		return
	(rs[0]).call("open_for_npc_repair", npc)


func _open_identify_for(npc: NPC) -> void:
	var rs := get_tree().get_nodes_in_group("identify_ui")
	if rs.is_empty():
		EventBus.ui_toast.emit("Nothing to identify.", 2.0)
		return
	(rs[0]).call("open_for_npc_identify", npc)


func _open_teleport_for(npc: NPC) -> void:
	var ts := get_tree().get_nodes_in_group("teleport_ui")
	if ts.is_empty():
		EventBus.ui_toast.emit("No destinations yet.", 2.0)
		return
	(ts[0]).call("open_for_npc_teleport", npc)


# Phase 9.64 — Brindle Pyrenkin accent text-replacement. Simple table-driven
# transform; toggleable via NpcLifecycle flag "brindle_pyrenkin_accent".
const PYRENKIN_REPLACEMENTS: Dictionary = {
	"the ": "th' ",
	"The ": "Th' ",
	"you ": "yer ",
	"You ": "Yer ",
	"my ": "me ",
	"My ": "Me ",
	"forge": "smelt-pit",
	"sword": "blade",
}


func _apply_pyrenkin_accent(text: String) -> String:
	if NpcLifecycle == null or not NpcLifecycle.get_flag(&"brindle_pyrenkin_accent"):
		return text
	var out := text
	for k in PYRENKIN_REPLACEMENTS.keys():
		out = out.replace(k, PYRENKIN_REPLACEMENTS[k])
	return out
