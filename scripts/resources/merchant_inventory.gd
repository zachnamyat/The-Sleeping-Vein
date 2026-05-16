extends Resource
class_name MerchantInventory

## A merchant's stock. `sell_items` is what the merchant offers to the player
## (price = Ancient Coins). `buy_prices` is what the merchant will pay the
## player per item, by `item_id`. Items not listed in buy_prices are unsellable.
##
## Phase 9 expansions:
##   9.10 — restock timer (30..45 min) is per-NPC, configurable in the .tres
##   9.30 — `seasonal_extras`: phase-id → array of bonus sell rows. CookingSystem
##           exposes the current Aphelion phase; when matched, extras are merged
##           into the offered list.
##   9.57/9.61 — `discount_thresholds`: ordered list of {mood, percent} pairs.
##           MerchantPanel multiplies offer/sell prices by the matching factor.
##   9.27 — `repair_fee_per_point`: coins per durability point restored. 0 = no
##           repair service.
##   9.28 — `identify_fee`: coins to reveal a reforged item's hidden affix. 0
##           = no identify service.
##   9.29 — `teleport_options`: list of {label, world_pos: Vector2, fee: int}.
##   9.32 — `is_random_spawn`: marks NPC as wandering merchant (re-spawn logic).
##   9.44 — `preferred_biome`: NPC mood softly bumped when at the Anchor biome.
##   9.65 — `theme_music`: id of a soft per-NPC music layer to crossfade when
##           the player is close (handled by AudioBus).

@export var sell_items: Array[Dictionary] = []   ## [{ "item_id", "price", "stock" (-1 = unlimited) }, ...]
@export var buy_prices: Dictionary = {}          ## { item_id (StringName) -> coins (int) }
@export var restock_minutes: float = 30.0
@export var seasonal_extras: Dictionary = {}     ## { phase_id (StringName) -> Array[Dictionary] }
@export var discount_thresholds: Array[Dictionary] = []  ## sorted high-mood-first: [{mood:int, percent:float}]
@export var repair_fee_per_point: int = 0
@export var identify_fee: int = 0
@export var teleport_options: Array[Dictionary] = []
@export var is_random_spawn: bool = false
@export var preferred_biome: StringName = &""
@export var theme_music: StringName = &""

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
	# Phase 9.30 — seasonal extras share the stock dictionary.
	for phase_key in seasonal_extras.keys():
		for entry in (seasonal_extras[phase_key] as Array):
			var item_id: StringName = StringName(entry.get("item_id", ""))
			var stock: int = int(entry.get("stock", -1))
			if not _runtime_stock.has(item_id):
				_runtime_stock[item_id] = 9999 if stock < 0 else stock


func price_to_buy(item_id: StringName) -> int:
	for entry in sell_items:
		if StringName(entry.get("item_id", "")) == item_id:
			return int(entry.get("price", 0))
	for phase_key in seasonal_extras.keys():
		for entry in (seasonal_extras[phase_key] as Array):
			if StringName(entry.get("item_id", "")) == item_id:
				return int(entry.get("price", 0))
	return 0


func price_to_sell(item_id: StringName) -> int:
	return int(buy_prices.get(item_id, 0))


## Phase 9.30 — return sell list expanded with the current Aphelion phase's
## seasonal extras. `phase_id` may be empty → returns base list only.
func sell_items_for_phase(phase_id: StringName) -> Array:
	var out: Array = sell_items.duplicate()
	if phase_id != &"" and seasonal_extras.has(phase_id):
		for entry in (seasonal_extras[phase_id] as Array):
			out.append(entry)
	return out


## Phase 9.57 — discount multiplier given an NPC mood (0..100). Tables are
## expected to be sorted by mood DESC; the first row whose `mood` <= current is
## applied. `percent` is positive = discount, negative = markup. If the mood is
## below every threshold, the lowest bracket applies (typical use: a -10% row
## at mood 20 keeps applying down to 0).
func price_multiplier_for_mood(mood: int) -> float:
	for row in discount_thresholds:
		if mood >= int(row.get("mood", 0)):
			return 1.0 - float(row.get("percent", 0.0)) / 100.0
	if not discount_thresholds.is_empty():
		var fallback: Dictionary = discount_thresholds[discount_thresholds.size() - 1]
		return 1.0 - float(fallback.get("percent", 0.0)) / 100.0
	return 1.0
