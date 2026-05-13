extends CanvasLayer
class_name MerchantPanel

## Buy/sell UI. Two columns:
##   Left  — merchant inventory ("Buy" — costs Ancient Coins).
##   Right — player inventory items the merchant accepts ("Sell" — gains coins).
##
## Coins are tracked as a regular item: `ancient_coin`.

const COIN_ID: StringName = &"ancient_coin"

@onready var title: Label = $Root/Title
@onready var coin_label: Label = $Root/Coins
@onready var buy_list: VBoxContainer = $Root/Cols/BuyCol/Scroll/List
@onready var sell_list: VBoxContainer = $Root/Cols/SellCol/Scroll/List

var _current_npc: NPC
var _inventory: MerchantInventory


func _ready() -> void:
	add_to_group("merchant_ui")
	visible = false
	EventBus.inventory_changed.connect(_refresh_coins)
	EventBus.inventory_changed.connect(_rebuild_sell_list)


func open_for_npc(npc: NPC) -> void:
	_current_npc = npc
	_inventory = npc.merchant_inventory
	if _inventory == null:
		visible = false
		return
	# Phase 9.10 — try a restock when the player opens the panel.
	_inventory.try_restock(int(Time.get_unix_time_from_system()))
	title.text = "%s — Trade" % npc.display_name
	_refresh_coins()
	_rebuild_buy_list()
	_rebuild_sell_list()
	visible = true


func close_if_for(npc: NPC) -> void:
	if _current_npc == npc:
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		visible = false


func _refresh_coins() -> void:
	if coin_label:
		coin_label.text = "Ancient Coins: %d" % Inventory.count_of(COIN_ID)


func _rebuild_buy_list() -> void:
	if buy_list == null or _inventory == null:
		return
	for child in buy_list.get_children():
		child.queue_free()
	for entry in _inventory.sell_items:
		var item_id: StringName = StringName(entry.get("item_id", ""))
		if item_id == &"":
			continue
		var defn: ItemDef = ItemRegistry.get_def(item_id)
		var label_text: String = defn.display_name if defn else String(item_id)
		var price: int = int(entry.get("price", 0))
		var stock_left: int = _inventory.remaining_stock(item_id)
		var stock_suffix: String = " (sold out)" if stock_left <= 0 else (" x%d" % stock_left if stock_left < 100 else "")
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s  (%dc)%s" % [label_text, price, stock_suffix]
		l.custom_minimum_size = Vector2(180, 18)
		if stock_left <= 0:
			l.modulate = Color(0.55, 0.5, 0.42, 1)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(48, 18)
		btn.disabled = stock_left <= 0
		btn.pressed.connect(_buy.bind(item_id, price))
		row.add_child(btn)
		buy_list.add_child(row)


func _rebuild_sell_list() -> void:
	if sell_list == null or _inventory == null:
		return
	for child in sell_list.get_children():
		child.queue_free()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var item_id: StringName = StringName(slot["item_id"])
		var price: int = _inventory.price_to_sell(item_id)
		if price <= 0:
			continue
		var defn: ItemDef = ItemRegistry.get_def(item_id)
		var label_text: String = defn.display_name if defn else String(item_id)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s x%d  (%dc ea)" % [label_text, int(slot["count"]), price]
		l.custom_minimum_size = Vector2(180, 18)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "Sell 1"
		btn.custom_minimum_size = Vector2(48, 18)
		btn.pressed.connect(_sell.bind(item_id, price))
		row.add_child(btn)
		sell_list.add_child(row)


func _buy(item_id: StringName, price: int) -> void:
	if Inventory.count_of(COIN_ID) < price:
		EventBus.ui_toast.emit("Not enough Ancient Coins.", 1.5)
		return
	if _inventory and _inventory.remaining_stock(item_id) <= 0:
		EventBus.ui_toast.emit("Sold out.", 1.0)
		return
	Inventory.try_remove(COIN_ID, price)
	Inventory.try_add(item_id, 1)
	if _inventory:
		_inventory.decrement_stock(item_id)
	_rebuild_buy_list()
	EventBus.ui_toast.emit("Bought 1.", 1.0)


func _sell(item_id: StringName, price: int) -> void:
	if Inventory.try_remove(item_id, 1) <= 0:
		return
	Inventory.try_add(COIN_ID, price)
	EventBus.ui_toast.emit("Sold 1 (+%dc).", 1.0)
