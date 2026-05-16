extends Area2D
class_name PetBowl

## Phase 9.15 — Pet feeding bowl. Holds up to 5 stacks of food. Each Aphelion-day
## tick, the active pet eats one stack and gains friendship if the food is its
## favorite. When the bowl runs dry, the pet's mood ticks down.

const MAX_STACK_COUNT: int = 5

@export var food_stacks: Array[Dictionary] = []  ## [{ "item_id", "count" }, ...]

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("pet_bowl")
	add_to_group("placed_decor")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if NpcLifecycle:
		NpcLifecycle.daily_reset.connect(_on_daily_reset)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_deposit_selected()


func _deposit_selected() -> void:
	# Read player's selected hotbar slot; if it's food, deposit 1.
	var hotbar_nodes := get_tree().get_nodes_in_group("hotbar")
	if hotbar_nodes.is_empty():
		return
	var idx: int = int(hotbar_nodes[0].get("selected_index"))
	var iid: StringName = Inventory.get_hotbar_item(idx)
	if iid == &"":
		return
	var defn: ItemDef = ItemRegistry.get_def(iid)
	if defn == null or defn.hunger_restore <= 0:
		EventBus.ui_toast.emit("That's not food.", 1.5)
		return
	if food_stacks.size() >= MAX_STACK_COUNT:
		EventBus.ui_toast.emit("Bowl is full.", 1.5)
		return
	if Inventory.try_remove(iid, 1) <= 0:
		return
	food_stacks.append({ "item_id": String(iid), "count": 1 })
	EventBus.ui_toast.emit("Deposited 1 %s." % defn.display_name, 1.5)


func _on_daily_reset(_new_day: int) -> void:
	if Pets == null:
		return
	var active_pet: StringName = StringName(Inventory.equipment.get(&"pet", &""))
	if active_pet == &"":
		return
	if food_stacks.is_empty():
		# Phase 9.15 — bowl empty: pet's mood drops slightly.
		var rec: Dictionary = Pets.pets.get(active_pet, {})
		if rec.is_empty():
			return
		rec["mood"] = clampi(int(rec.get("mood", 50)) - 5, 0, 100)
		Pets.pets[active_pet] = rec
		return
	# Pet eats one stack.
	var entry: Dictionary = food_stacks[0]
	food_stacks.pop_front()
	var food_id: StringName = StringName(String(entry.get("item_id", "")))
	if food_id != &"":
		Pets.feed(active_pet, food_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Deposit food (%d/%d stacks)" % [food_stacks.size(), MAX_STACK_COUNT], 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func dump_state() -> Dictionary:
	return { "food_stacks": food_stacks.duplicate(true) }


func restore_state(d: Dictionary) -> void:
	food_stacks = (d.get("food_stacks", []) as Array).duplicate(true)
