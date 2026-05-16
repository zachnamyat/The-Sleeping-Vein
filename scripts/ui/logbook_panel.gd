extends CanvasLayer
class_name LogbookPanel

## Phase 15.16 — Logbook / journal screen.
## Separate from Bestiary + Tablets — this is the Walker's running journal:
## boss-kill notes, NPC arrival entries, ending-choice memorial, and an "in
## the world I have done" cumulative summary. Acts like a save-flavor diary.

const ENTRY_TYPES: Array[StringName] = [
	&"boss", &"npc", &"ending", &"discovery", &"quest", &"misc",
]

var _open: bool = false
var _entries: Array[Dictionary] = []   # {type, when_iso, title, body}

var _root: Control
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 25
	add_to_group("logbook_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.npc_arrived.connect(_on_npc_arrived)


func toggle() -> void:
	_open = not _open
	visible = _open
	if _open:
		_refresh()


func add_entry(type: StringName, title: String, body: String) -> void:
	_entries.append({
		"type": String(type),
		"when_iso": Time.get_datetime_string_from_system(),
		"title": title,
		"body": body,
	})
	if visible:
		_refresh()


func _on_boss_defeated(boss_id: StringName) -> void:
	add_entry(&"boss", "Sovereign Quieted", "The %s no longer walks." % String(boss_id).replace("boss_", "").replace("_", " "))


func _on_npc_arrived(npc_id: StringName) -> void:
	add_entry(&"npc", "An Arrival", "%s reached the Anchor." % String(npc_id).replace("_", " "))


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -360
	_root.offset_right = 360
	_root.offset_top = -240
	_root.offset_bottom = 240
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var title := Label.new()
	title.text = "Logbook"
	title.offset_left = 16
	title.offset_top = 8
	title.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	_root.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.offset_left = 16
	_scroll.offset_top = 40
	_scroll.offset_right = -16
	_scroll.offset_bottom = -16
	_scroll.anchor_right = 1
	_scroll.anchor_bottom = 1
	_root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _entries.is_empty():
		var l := Label.new()
		l.text = "(no entries yet — your acts will write themselves here)"
		l.modulate = Color(0.7, 0.65, 0.55)
		_list.add_child(l)
		return
	for entry in _entries:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var h := Label.new()
		h.text = "%s · %s" % [String(entry["title"]), String(entry["when_iso"])]
		h.add_theme_color_override("font_color", Color(0.97, 0.85, 0.5))
		v.add_child(h)
		var body := Label.new()
		body.text = String(entry["body"])
		body.modulate = Color(0.9, 0.86, 0.7)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(body)
		_list.add_child(v)


# ---------- Save round-trip ----------

func dump_state() -> Dictionary:
	return {"entries": _entries.duplicate(true)}


func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	_entries.clear()
	for e in d.get("entries", []):
		if e is Dictionary:
			_entries.append(e.duplicate(true))
