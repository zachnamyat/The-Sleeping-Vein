extends Resource
class_name MerchantInventory

## A merchant's stock. `sell_items` is what the merchant offers to the player
## (price = Ancient Coins). `buy_prices` is what the merchant will pay the
## player per item, by `item_id`. Items not listed in buy_prices are unsellable.

@export var sell_items: Array[Dictionary] = []   ## [{ "item_id", "price", "stock" (-1 = unlimited) }, ...]
@export var buy_prices: Dictionary = {}          ## { item_id (StringName) -> coins (int) }
@export var restock_minutes: float = 30.0

## Per-instance runtime state (not exported). Tracks remaining stock per item.
var _runtime_stock: Dictionary = {}
var _next_restock_unix: int = 0


func remaining_stock(item_id: StringName) -> int:
	if _runtime_stock.is_empty():
		_initialize_stock()
	return int(_runtime_stock.get(item_id, 0))


func decrement_stock(item_id: StringName) -> void:
	if _runtime_stock.is_empty():
		_initialize_stock()
	if _runtime_stock.get(item_id, 0) > 0:
		_runtime_stock[item_id] = int(_runtime_stock[item_id]) - 1


func try_restock(now_unix: int) -> bool:
	if _runtime_stock.is_empty():
		_initialize_stock()
		_next_restock_unix = now_unix + int(restock_minutes * 60.0)
		return true
	if now_unix >= _next_restock_unix:
		_initialize_stock()
		_next_restock_unix = now_unix + int(restock_minutes * 60.0)
		return true
	return false


func seconds_to_restock(now_unix: int) -> int:
	return maxi(0, _next_restock_unix - now_unix)


func _initialize_stock() -> void:
	for entry in sell_items:
		var item_id: StringName = StringName(entry.get("item_id", ""))
		var stock: int = int(entry.get("stock", -1))
		# -1 means infinite — represent as 9999
		_runtime_stock[item_id] = 9999 if stock < 0 else stock


func price_to_buy(item_id: StringName) -> int:
	for entry in sell_items:
		if StringName(entry.get("item_id", "")) == item_id:
			return int(entry.get("price", 0))
	return 0


func price_to_sell(item_id: StringName) -> int:
	return int(buy_prices.get(item_id, 0))
