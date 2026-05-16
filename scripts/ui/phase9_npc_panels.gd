extends CanvasLayer
class_name Phase9NpcPanels

## Phase 9 — Lightweight popup panel that hosts gift / repair / identify /
## teleport / sign-edit UIs. Each opens via a small modal that lives in the
## scene's `panel_modes`. Saving a separate scene per panel would be overkill
## for the amount of UI each needs.
##
## Each panel is its own group ("gift_ui", "repair_ui", "identify_ui",
## "teleport_ui", "sign_ui") so the DialoguePanel.dispatch lookups still work.

@onready var root: Panel = $Root
@onready var title_label: Label = $Root/Title
@onready var description_label: RichTextLabel = $Root/Description
@onready var list_box: VBoxContainer = $Root/List

enum Mode { NONE, GIFT, REPAIR, IDENTIFY, TELEPORT, SIGN }
var _mode: Mode = Mode.NONE
var _npc: NPC
var _sign: Node


func _ready() -> void:
	# Register in all four groups so a single instance serves them all.
	add_to_group("gift_ui")
	add_to_group("repair_ui")
	add_to_group("identify_ui")
	add_to_group("teleport_ui")
	add_to_group("sign_ui")
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false


# ----- 9.19 — Gift -----

func open_for_npc(npc: NPC) -> void:
	# This is the gift entry-point; the dialogue panel call (action: open_gift)
	# routes here via the gift_ui group.
	_open_gift(npc)


func _open_gift(npc: NPC) -> void:
	_mode = Mode.GIFT
	_npc = npc
	title_label.text = "Give a gift to %s" % npc.display_name
	description_label.text = "[i]Select an item from your inventory.[/i]"
	_rebuild_inventory_list()
	visible = true


func _rebuild_inventory_list() -> void:
	for child in list_box.get_children():
		child.queue_free()
	for i in range(Inventory.slots.size()):
		var s = Inventory.slots[i]
		if s == null:
			continue
		var iid: StringName = StringName(s["item_id"])
		var defn: ItemDef = ItemRegistry.get_def(iid)
		if defn == null:
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s x%d" % [defn.display_name, int(s["count"])]
		l.custom_minimum_size = Vector2(200, 18)
		row.add_child(l)
		var btn := Button.new()
		match _mode:
			Mode.GIFT:
				btn.text = "Gift"
				btn.pressed.connect(_gift_one.bind(iid))
			Mode.REPAIR:
				if defn.max_durability <= 0:
					continue
				btn.text = "Repair"
				btn.pressed.connect(_repair_one.bind(i, iid))
			Mode.IDENTIFY:
				# Show only entries with an "affix" key.
				if not s.has("affix") or (s["affix"] as Dictionary).is_empty() or bool(s.get("identified", true)):
					continue
				btn.text = "Identify (%dc)" % _identify_fee()
				btn.pressed.connect(_identify_one.bind(i))
			_:
				continue
		btn.custom_minimum_size = Vector2(80, 18)
		row.add_child(btn)
		list_box.add_child(row)


func _gift_one(item_id: StringName) -> void:
	if Inventory.try_remove(item_id, 1) <= 0:
		return
	var delta: int = NpcLifecycle.gift_item(_npc.npc_id, item_id)
	if delta == 0:
		# Already gifted today — refund.
		Inventory.try_add(item_id, 1)
	visible = false


# ----- 9.27 — Repair -----

func open_for_npc_repair(npc: NPC) -> void:
	_mode = Mode.REPAIR
	_npc = npc
	title_label.text = "Repair gear with %s" % npc.display_name
	description_label.text = "[i]Repair fee: %dc per durability point.[/i]" % _repair_fee()
	_rebuild_inventory_list()
	visible = true


func _repair_fee() -> int:
	if _npc and _npc.merchant_inventory:
		return int(_npc.merchant_inventory.repair_fee_per_point)
	return 1


func _repair_one(inv_index: int, item_id: StringName) -> void:
	var defn: ItemDef = ItemRegistry.get_def(item_id)
	if defn == null or defn.max_durability <= 0:
		return
	var entry: Dictionary = Inventory.slots[inv_index]
	var current: int = int(entry.get("durability", defn.max_durability))
	var missing: int = max(0, defn.max_durability - current)
	if missing <= 0:
		EventBus.ui_toast.emit("Already full.", 1.5)
		return
	var fee: int = missing * _repair_fee()
	if Inventory.count_of(&"ancient_coin") < fee:
		EventBus.ui_toast.emit("Need %dc to repair." % fee, 2.0)
		return
	Inventory.try_remove(&"ancient_coin", fee)
	entry["durability"] = defn.max_durability
	Inventory.slot_changed.emit(inv_index, item_id, int(entry.get("count", 1)))
	EventBus.ui_toast.emit("Repaired (+%d)." % missing, 1.5)
	_rebuild_inventory_list()


# ----- 9.28 — Identify -----

func open_for_npc_identify(npc: NPC) -> void:
	_mode = Mode.IDENTIFY
	_npc = npc
	title_label.text = "Identify with %s" % npc.display_name
	description_label.text = "[i]Reveal hidden affixes on reforged items.[/i]"
	_rebuild_inventory_list()
	visible = true


func _identify_fee() -> int:
	if _npc and _npc.merchant_inventory:
		return int(_npc.merchant_inventory.identify_fee)
	return 12


func _identify_one(inv_index: int) -> void:
	var fee: int = _identify_fee()
	if Inventory.count_of(&"ancient_coin") < fee:
		EventBus.ui_toast.emit("Need %dc to identify." % fee, 2.0)
		return
	var entry: Dictionary = Inventory.slots[inv_index]
	if not entry.has("affix") or (entry["affix"] as Dictionary).is_empty():
		return
	Inventory.try_remove(&"ancient_coin", fee)
	entry["identified"] = true
	EventBus.ui_toast.emit("Identified: %s" % JSON.stringify(entry["affix"]), 4.0)
	_rebuild_inventory_list()


# ----- 9.29 — Teleport -----

func open_for_npc_teleport(npc: NPC) -> void:
	_mode = Mode.TELEPORT
	_npc = npc
	title_label.text = "Travel with %s" % npc.display_name
	description_label.text = "[i]Select a destination.[/i]"
	for child in list_box.get_children():
		child.queue_free()
	if npc.merchant_inventory == null:
		visible = false
		return
	for opt in npc.merchant_inventory.teleport_options:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s (%dc)" % [String(opt.get("label", "?")), int(opt.get("fee", 0))]
		l.custom_minimum_size = Vector2(200, 18)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "Go"
		btn.pressed.connect(_teleport_one.bind(opt))
		row.add_child(btn)
		list_box.add_child(row)
	visible = true


func _teleport_one(opt: Dictionary) -> void:
	var fee: int = int(opt.get("fee", 0))
	if Inventory.count_of(&"ancient_coin") < fee:
		EventBus.ui_toast.emit("Need %dc." % fee, 2.0)
		return
	Inventory.try_remove(&"ancient_coin", fee)
	var target := Vector2(float(opt.get("world_pos_x", 0.0)), float(opt.get("world_pos_y", 0.0)))
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D:
			(p as Node2D).global_position = target
	EventBus.ui_toast.emit("Travelled to %s." % String(opt.get("label", "destination")), 2.0)
	visible = false


# ----- 9.13/9.48 — Sign edit -----

func open_for_sign(sign_node: Node) -> void:
	_mode = Mode.SIGN
	_sign = sign_node
	title_label.text = "Sign"
	description_label.text = "[i]Type a short message. Esc to close.[/i]"
	for child in list_box.get_children():
		child.queue_free()
	var edit := LineEdit.new()
	edit.text = String(sign_node.get("sign_text"))
	edit.custom_minimum_size = Vector2(260, 24)
	edit.text_submitted.connect(_sign_submitted)
	list_box.add_child(edit)
	visible = true
	edit.grab_focus()


func _sign_submitted(text: String) -> void:
	if _sign and is_instance_valid(_sign):
		_sign.set("sign_text", text)
	visible = false
