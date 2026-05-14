extends Control
class_name InventoryPanel

## Full inventory grid (3 rows x 10 cols by default). Toggled by `open_inventory`
## action. Slots subscribe to Inventory.slot_changed.
## Phase 3 extras: hosts the equipment subpanel (3.4), search box (3.60),
## sort buttons (3.26 / 3.45), trash slot (3.25), and Loot All / Quick Stack
## buttons (3.13 / 3.14).

@export var rows: int = 3
@export var cols: int = 10
@export var slot_size: Vector2 = Vector2(20, 20)
@export var slot_spacing: float = 2.0

var _slot_uis: Array[InventorySlotUI] = []
var _slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot_ui.tscn")
var _search_filter: String = ""


func _ready() -> void:
	add_to_group("inventory_ui")
	visible = false
	# Stop mouse events from passing through the panel while it's open so the
	# player can't accidentally swing through inventory UI. When invisible,
	# Godot still skips gui_input but unhandled_input fires regardless.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_grid()
	Inventory.slot_changed.connect(_on_slot_changed)
	for i in range(Inventory.slots.size()):
		var s := Inventory.get_slot(i)
		if s.is_empty():
			_set_slot_visual(i, &"", 0)
		else:
			_set_slot_visual(i, StringName(s["item_id"]), int(s["count"]))
	_wire_controls()


func _build_grid() -> void:
	var container := $Panel/Grid
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	_slot_uis.clear()
	for r in range(rows):
		for c in range(cols):
			var idx: int = r * cols + c
			var slot_ui: InventorySlotUI = _slot_scene.instantiate()
			slot_ui.slot_index = idx
			slot_ui.position = Vector2((slot_size.x + slot_spacing) * c, (slot_size.y + slot_spacing) * r)
			container.add_child(slot_ui)
			_slot_uis.append(slot_ui)


func _wire_controls() -> void:
	# Phase 3.60 — live filter as the player types.
	var search := $Panel/SearchBox as LineEdit
	if search:
		search.text_changed.connect(_on_search_changed)
	var sort_rarity := $Panel/SortRarity as Button
	if sort_rarity:
		sort_rarity.pressed.connect(func() -> void: Inventory.sort_storage("rarity"))
	var sort_name := $Panel/SortName as Button
	if sort_name:
		sort_name.pressed.connect(func() -> void: Inventory.sort_storage("name"))
	var sort_type := $Panel/SortType as Button
	if sort_type:
		sort_type.pressed.connect(func() -> void: Inventory.sort_storage("type"))
	var sort_recent := $Panel/SortRecent as Button
	if sort_recent:
		sort_recent.pressed.connect(func() -> void: Inventory.sort_storage_recency())
	var loot_all := $Panel/LootAll as Button
	if loot_all:
		loot_all.pressed.connect(_on_loot_all)
	var quick_stack := $Panel/QuickStack as Button
	if quick_stack:
		quick_stack.pressed.connect(_on_quick_stack)
	var auto_equip := $Panel/AutoEquip as Button
	if auto_equip:
		auto_equip.pressed.connect(_on_auto_equip)
	var trash := $Panel/Trash as TrashSlot
	if trash == null:
		# Older scene without explicit trash slot — create one programmatically.
		var tslot := TrashSlot.new()
		tslot.position = Vector2(218, 88)
		tslot.size = Vector2(20, 20)
		tslot.name = "Trash"
		$Panel.add_child(tslot)


## Called by external openers (e.g. ChestPanel.open_for_chest) so the player
## can see and drag from their pouch as soon as a container opens. Idempotent.
func force_open() -> void:
	if visible:
		return
	visible = true
	UIAudio.play_panel_open()


func _on_search_changed(text: String) -> void:
	_search_filter = text.strip_edges().to_lower()
	_apply_search_filter()


func _apply_search_filter() -> void:
	# Phase 3.60 — visually highlight matches; clear is full opacity, miss is dim.
	for slot in _slot_uis:
		if slot == null:
			continue
		if _search_filter == "":
			slot.modulate = Color.WHITE
			continue
		if slot.current_item_id == &"":
			slot.modulate = Color(0.6, 0.6, 0.6, 0.6)
			continue
		var defn: ItemDef = ItemRegistry.get_def(slot.current_item_id)
		var name: String = defn.display_name.to_lower() if defn else String(slot.current_item_id).to_lower()
		if name.find(_search_filter) >= 0:
			slot.modulate = Color(1, 1, 0.6, 1)
		else:
			slot.modulate = Color(0.4, 0.4, 0.4, 0.6)


func _on_auto_equip() -> void:
	# Phase 3.33 — equip the highest-armor piece in inventory for each slot.
	var n: int = Inventory.auto_equip_best()
	if n > 0:
		EventBus.ui_toast.emit("Equipped %d pieces." % n, 1.5)
	else:
		EventBus.ui_toast.emit("Nothing better to wear.", 1.2)


func _on_quick_stack() -> void:
	# Phase 3.13 — deposit player items into the nearest chest if it already
	# contains that item type. Starter items stay put.
	# Phase 3.15 — prefer the last-used container if still in range.
	var chest := _last_or_nearest_chest()
	if chest == null:
		EventBus.ui_toast.emit("No chest in range.", 1.2)
		return
	var moved: int = 0
	for i in range(Inventory.HOTBAR_SIZE, Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s == null:
			continue
		var iid := StringName(s.get("item_id", ""))
		var have: int = int(s.get("count", 0))
		# Only quick-stack if the chest already has at least one of this id.
		var deposited: int = 0
		for j in range(chest.SLOT_COUNT):
			var cs = chest.slots[j]
			if cs != null and StringName(cs.get("item_id", "")) == iid:
				deposited = chest.deposit(iid, have)
				break
		if deposited > 0:
			Inventory.try_remove(iid, deposited)
			moved += deposited
	if moved > 0:
		EventBus.ui_toast.emit("Quick-stacked %d items." % moved, 1.5)
	else:
		EventBus.ui_toast.emit("Nothing to quick-stack.", 1.2)


func _on_loot_all() -> void:
	# Phase 3.14 — grab everything within a generous radius around the player.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if player == null:
		return
	var radius: float = 64.0
	var drops := get_tree().get_nodes_in_group("item_drop")
	var picked: int = 0
	for d in drops:
		if not is_instance_valid(d):
			continue
		var drop := d as ItemDrop
		if drop == null:
			continue
		if drop.global_position.distance_to(player.global_position) > radius:
			continue
		if drop.try_force_pickup():
			picked += 1
	if picked > 0:
		EventBus.ui_toast.emit("Looted %d nearby." % picked, 1.2)
	else:
		EventBus.ui_toast.emit("Nothing nearby.", 1.0)


func _nearest_chest() -> Node:
	var chests := get_tree().get_nodes_in_group("chest")
	if chests.is_empty():
		return null
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return chests[0]
	var player := players[0] as Node2D
	var nearest: Node = null
	var nearest_dist: float = INF
	for c in chests:
		var n := c as Node2D
		if n == null:
			continue
		var d: float = n.global_position.distance_to(player.global_position)
		if d < nearest_dist and d < 64.0:
			nearest = c
			nearest_dist = d
	return nearest


## Phase 3.15 — auto-deposit prefers the last-used chest if it's still nearby,
## then falls back to whichever chest is closest. Lets the player open a chest,
## stash a few items, then bind a "QuickStack" hotkey to keep dumping into it
## while running back to it.
func _last_or_nearest_chest() -> Node:
	if Inventory.last_used_container != null and is_instance_valid(Inventory.last_used_container):
		var luc := Inventory.last_used_container as Node2D
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and luc != null:
			var p := players[0] as Node2D
			if p and luc.global_position.distance_to(p.global_position) < 64.0:
				return Inventory.last_used_container
	return _nearest_chest()


func _input(event: InputEvent) -> void:
	# Use _input (highest-priority phase) instead of _unhandled_input so the
	# Tab key beats Godot's built-in ui_focus_next handler, and so a focused
	# Button elsewhere on screen can't swallow the I keypress.
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	# If the search line edit is focused, let it consume typing.
	var search := $Panel/SearchBox as LineEdit
	if search and search.has_focus():
		return
	var match_action: bool = event.is_action_pressed("open_inventory")
	var match_key: bool = key.physical_keycode == KEY_I or key.physical_keycode == KEY_TAB \
		or key.keycode == KEY_I or key.keycode == KEY_TAB
	if not match_action and not match_key:
		return
	visible = not visible
	if visible:
		UIAudio.play_panel_open()
		# 480×270 viewport can't host inventory + crafting + chest at once.
		# Hide them so the inventory grid is readable; the chest auto-reopens
		# when you press E next to it again, and crafting same.
		for n in get_tree().get_nodes_in_group("crafting_ui"):
			n.visible = false
		for n in get_tree().get_nodes_in_group("chest_ui"):
			n.visible = false
	else:
		UIAudio.play_panel_close()
	get_viewport().set_input_as_handled()


## Called by ChestPanel + CraftingPanel when they need to swap us off-screen.
func force_close() -> void:
	if visible:
		visible = false
		UIAudio.play_panel_close()


func _on_slot_changed(slot_index: int, item_id: StringName, count: int) -> void:
	_set_slot_visual(slot_index, item_id, count)
	if _search_filter != "":
		_apply_search_filter()


func _set_slot_visual(idx: int, item_id: StringName, count: int) -> void:
	if idx < 0 or idx >= _slot_uis.size():
		return
	_slot_uis[idx].set_slot(item_id, count)
