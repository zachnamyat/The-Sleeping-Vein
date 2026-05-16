extends CanvasLayer
class_name AnvilPanel

## Phase 3.29 — Anvil Reforge UI.
##
## Lists every reforgeable item in the player's inventory. Each row shows the
## item name, its current affix (if any), and a "Reforge (8 coins)" button.
##
## Opens via the same Workstation.interacted signal-chain that CraftingPanel
## uses — Workstation.station_id == &"anvil" triggers `open_for_anvil`.

@onready var root_panel: Panel = $Root
@onready var list_container: VBoxContainer = $Root/List


func _ready() -> void:
	add_to_group("anvil_ui")
	visible = false
	# Listen for Workstation.interacted globally and open if the station is an anvil.
	for ws in get_tree().get_nodes_in_group("workstation"):
		if ws.has_signal("interacted") and not ws.interacted.is_connected(_on_station_interacted):
			ws.interacted.connect(_on_station_interacted)
	# New workstations that appear later (placed anvils) hook in via signal-bus
	# fallback: every time an inventory item is placed we re-scan.
	EventBus.inventory_changed.connect(_rescan_workstations)


func _rescan_workstations() -> void:
	for ws in get_tree().get_nodes_in_group("workstation"):
		if ws.has_signal("interacted") and not ws.interacted.is_connected(_on_station_interacted):
			ws.interacted.connect(_on_station_interacted)


func _on_station_interacted(station: Node) -> void:
	if station == null:
		return
	var sid: StringName = station.get("station_id")
	if sid == &"anvil":
		open()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()


func open() -> void:
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _rebuild() -> void:
	if list_container == null:
		return
	for c in list_container.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Anvil — Reforge for %d Ancient Coins (you have %d)" % [
		Reforge.REFORGE_COST_ANCIENT_COIN, Inventory.count_of(&"ancient_coin")
	]
	title.modulate = Color(0.95, 0.85, 0.5)
	list_container.add_child(title)
	var any: bool = false
	for i in range(Inventory.slots.size()):
		var entry = Inventory.slots[i]
		if entry == null:
			continue
		if not Reforge.can_reforge(i):
			continue
		any = true
		list_container.add_child(_build_row(i, entry))
	if not any:
		var none := Label.new()
		none.text = "No reforgeable items, or not enough coins."
		none.modulate = Color(0.7, 0.7, 0.6)
		list_container.add_child(none)
	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(close)
	list_container.add_child(close_btn)


func _build_row(slot_index: int, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var iid := StringName(entry.get("item_id", ""))
	var defn: ItemDef = ItemRegistry.get_def(iid)
	var name_lbl := Label.new()
	name_lbl.text = defn.display_name if defn else String(iid)
	name_lbl.custom_minimum_size = Vector2(160, 14)
	row.add_child(name_lbl)
	var affix: Dictionary = entry.get("affix", {})
	var affix_lbl := Label.new()
	if affix.is_empty():
		affix_lbl.text = "(no affix)"
		affix_lbl.modulate = Color(0.55, 0.55, 0.55)
	else:
		affix_lbl.text = "[%s]" % String(affix.get("name", ""))
		affix_lbl.modulate = Color(0.7, 1.0, 0.7)
	affix_lbl.custom_minimum_size = Vector2(120, 14)
	row.add_child(affix_lbl)
	var btn := Button.new()
	btn.text = "Reforge"
	var idx: int = slot_index
	btn.pressed.connect(func() -> void:
		Reforge.try_reforge(idx)
		_rebuild()
	)
	row.add_child(btn)
	return row
