extends Area2D
class_name TradingBlock

## Phase 9.47 — Player-to-player trading block. In singleplayer it acts as a
## marketplace: drop an item onto it with a coin price, and (optionally) another
## player picks it up by paying the coins. In singleplayer mode it auto-fills
## from the player's offered slot when the player interacts; the player can
## then "sell" or "cancel".

@export var offered_item: StringName = &""
@export var offered_count: int = 0
@export var price_coins: int = 0
@export var owner_label: String = ""

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("trading_block")
	add_to_group("placed_decor")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open_panel()


func _open_panel() -> void:
	if offered_item == &"" or offered_count <= 0:
		EventBus.ui_toast.emit("(empty trading block — Drop an item to set offer)", 3.0)
		return
	# Phase 9.47 — single-player buy path. Check coins, transfer.
	if Inventory.count_of(&"ancient_coin") < price_coins:
		EventBus.ui_toast.emit("Need %d coins." % price_coins, 2.0)
		return
	if Inventory.try_add(offered_item, offered_count):
		Inventory.try_remove(&"ancient_coin", price_coins)
		offered_item = &""
		offered_count = 0
		price_coins = 0
		EventBus.ui_toast.emit("Trade complete.", 2.0)


## Multiplayer hook: another player calls this to drop their offer in.
func set_offer(item_id: StringName, count: int, price: int, owner: String = "") -> bool:
	if offered_item != &"" and offered_count > 0:
		return false
	offered_item = item_id
	offered_count = count
	price_coins = price
	owner_label = owner
	return true


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if offered_item != &"":
			EventBus.ui_toast.emit("[E] Buy %d %s (%dc)" % [offered_count, String(offered_item), price_coins], 2.0)
		else:
			EventBus.ui_toast.emit("[E] Trading Block (empty)", 2.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func dump_state() -> Dictionary:
	return {
		"offered_item": String(offered_item),
		"offered_count": offered_count,
		"price_coins": price_coins,
		"owner_label": owner_label,
	}


func restore_state(d: Dictionary) -> void:
	offered_item = StringName(String(d.get("offered_item", "")))
	offered_count = int(d.get("offered_count", 0))
	price_coins = int(d.get("price_coins", 0))
	owner_label = String(d.get("owner_label", ""))
