extends Area2D
class_name WishingWell

## Phase 4.40 — placeable wishing well. Player interacts (E) once per Aphelion
## Beat to receive a random reward from `reward_table`. Costs 1 ancient_coin per
## use; consumed before rolling. Cooldown prevents farming.

const COIN_COST: int = 1

@export var reward_table: Array[Dictionary] = [
	{"item_id": &"shaleseed", "min": 2, "max": 6, "weight": 30},
	{"item_id": &"loambeetle", "min": 1, "max": 3, "weight": 20},
	{"item_id": &"ancient_coin", "min": 2, "max": 5, "weight": 25},
	{"item_id": &"aphelion_fragment", "min": 1, "max": 1, "weight": 5},
	{"item_id": &"glow_tube", "min": 1, "max": 2, "weight": 10},
	{"item_id": &"bound_compass", "min": 1, "max": 1, "weight": 3},
	{"item_id": &"world_scanner", "min": 1, "max": 1, "weight": 2},
]

var _player_in_range: bool = false
var _last_use_phase: int = -1


func _ready() -> void:
	add_to_group("wishing_well")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_attempt_wish()


func _attempt_wish() -> void:
	var phase: int = AudioBus.current_phase() if AudioBus else 0
	if phase == _last_use_phase:
		EventBus.ui_toast.emit("The well is silent. Wait for the next Beat.", 1.5)
		return
	if Inventory.count_of(&"ancient_coin") < COIN_COST:
		EventBus.ui_toast.emit("The well wants a coin you do not have.", 2.0)
		return
	Inventory.try_remove(&"ancient_coin", COIN_COST)
	_last_use_phase = phase
	var roll := _roll_reward()
	if roll.is_empty():
		EventBus.ui_toast.emit("The coin sinks. Nothing answers.", 2.0)
		return
	var amount: int = randi_range(int(roll.get("min", 1)), int(roll.get("max", 1)))
	Inventory.try_add(StringName(roll["item_id"]), amount)
	EventBus.ui_toast.emit("The well coughs back %d %s." % [amount, String(roll["item_id"])], 2.0)


func _roll_reward() -> Dictionary:
	var total: int = 0
	for entry in reward_table:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return {}
	var pick: int = randi_range(0, total - 1)
	for entry in reward_table:
		pick -= int(entry.get("weight", 0))
		if pick < 0:
			return entry
	return {}


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Toss a coin (1)", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
