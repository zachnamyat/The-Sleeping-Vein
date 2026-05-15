extends CanvasLayer
class_name LoomPanel

## Resonance Loom interaction UI.
##   - Header shows the player's current Aphelion sliver budget (lore §1.7) and
##     the active respawn point.
##   - Phase 4.5 "Set Respawn Here" button binds the player's respawn target to
##     the Loom's world position — defaults to (0,0) for the world's first Loom,
##     but Phase 9 will let the player place additional Looms elsewhere.
##   - Lists every boss relic, with its insertion status.
##   - If the player has the relic in inventory, shows an "Insert" button that
##     consumes it and marks the next stratum descent as unlocked in GameState.

const RELICS: Array[Dictionary] = [
	{ "item_id": &"stone_fathers_pulse",       "stratum_unlocks": 2, "label": "Stone-Father's Pulse" },
	{ "item_id": &"vorrkells_lantern",         "stratum_unlocks": 3, "label": "Vorr'kell's Lantern" },
	{ "item_id": &"coral_veil",                "stratum_unlocks": 4, "label": "Coral Veil" },
	{ "item_id": &"verdant_heart",             "stratum_unlocks": 5, "label": "Verdant Heart" },
	{ "item_id": &"tide_heart",                "stratum_unlocks": 6, "label": "Tide-Heart" },
	{ "item_id": &"skoldurs_hammer",           "stratum_unlocks": 7, "label": "Skoldur's Hammer" },
	{ "item_id": &"naerens_salt_crown",        "stratum_unlocks": 8, "label": "Naeren's Salt-Crown" },
	{ "item_id": &"choirs_resonance",          "stratum_unlocks": 9, "label": "Choir's Resonance" },
	{ "item_id": &"shattered_diadem",          "stratum_unlocks": 99, "label": "Shattered Diadem" },
]

@onready var list_root: VBoxContainer = $Root/Scroll/List
@onready var title: Label = $Root/Title
@onready var hint: Label = $Root/Hint
@onready var slivers_label: Label = $Root/SliversLabel
@onready var set_respawn_btn: Button = $Root/SetRespawnButton

var _active_loom_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("loom_panel")
	visible = false
	if set_respawn_btn:
		set_respawn_btn.pressed.connect(_on_set_respawn_pressed)
	EventBus.aphelion_dimmed.connect(_on_slivers_changed)


func open(loom_pos: Vector2 = Vector2.ZERO) -> void:
	_active_loom_position = loom_pos
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_inventory"):
		close()


func _refresh() -> void:
	for child in list_root.get_children():
		child.queue_free()
	var inserted_count: int = 0
	for entry in RELICS:
		var row := _build_row(entry)
		list_root.add_child(row)
		if GameState.collected_relics.get(entry.item_id, false):
			inserted_count += 1
	hint.text = "Inserted: %d / %d   ·   Threads: %d" % [inserted_count, RELICS.size(), GameState.sovereign_threads]
	_refresh_slivers_label()
	_refresh_respawn_button()


func _refresh_slivers_label() -> void:
	if slivers_label == null:
		return
	# Phase 4.5 — the player consults the Loom both to spend slivers (respawn
	# cost) and to gauge how many runs of "die-and-pop-back" they still have.
	var pct: float = float(GameState.aphelion_slivers_remaining) / float(GameState.APHELION_STARTING_SLIVERS) * 100.0
	slivers_label.text = "Aphelion Slivers: %d  (%.0f%%)" % [GameState.aphelion_slivers_remaining, pct]


func _refresh_respawn_button() -> void:
	if set_respawn_btn == null:
		return
	var is_active: bool = GameState.respawn_point.distance_to(_active_loom_position) < 1.0
	if is_active:
		set_respawn_btn.text = "Respawn Bound (Here)"
		set_respawn_btn.disabled = true
	else:
		set_respawn_btn.text = "Set Respawn Here"
		set_respawn_btn.disabled = false


func _on_set_respawn_pressed() -> void:
	GameState.set_respawn_point(_active_loom_position)
	# Player's respawn position is consulted on death; mirror to the live
	# PlayerController so a death between now and the next scene reload also
	# returns to this Loom.
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("set_respawn_position"):
			p.call("set_respawn_position", _active_loom_position)
	EventBus.ui_toast.emit("The Loom binds your thread. You will wake here.", 2.5)
	if AudioBus:
		AudioBus.play_sfx(&"loom_bind")
	_refresh_respawn_button()


func _on_slivers_changed(_slivers: int) -> void:
	if visible:
		_refresh_slivers_label()


func _build_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(420, 22)
	var label := Label.new()
	var item_id: StringName = entry.item_id
	var inserted: bool = GameState.collected_relics.get(item_id, false)
	var have_count: int = Inventory.count_of(item_id)
	var status: String = "[INSERTED]" if inserted else ("(in pouch)" if have_count > 0 else "(missing)")
	label.text = "%s  %s" % [entry.label, status]
	label.custom_minimum_size = Vector2(280, 22)
	if inserted:
		label.modulate = Color(0.7, 1.0, 0.6, 1)
	elif have_count > 0:
		label.modulate = Color(0.97, 0.85, 0.5, 1)
	else:
		label.modulate = Color(0.55, 0.5, 0.42, 1)
	row.add_child(label)

	if not inserted and have_count > 0:
		var btn := Button.new()
		btn.text = "Insert"
		btn.custom_minimum_size = Vector2(80, 18)
		btn.pressed.connect(_insert_relic.bind(entry))
		row.add_child(btn)
	return row


func _insert_relic(entry: Dictionary) -> void:
	var item_id: StringName = entry.item_id
	var removed: int = Inventory.try_remove(item_id, 1)
	if removed <= 0:
		EventBus.ui_toast.emit("No %s in pouch." % entry.label, 1.5)
		return
	GameState.collected_relics[item_id] = true
	EventBus.ui_toast.emit("The Loom drinks the %s. Stratum %d unlocks." % [entry.label, entry.stratum_unlocks], 3.5)
	_refresh()
