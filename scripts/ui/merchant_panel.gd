extends CanvasLayer
class_name MerchantPanel

## Buy/sell UI. Two columns:
##   Left  — merchant inventory ("Buy" — costs Ancient Coins).
##   Right — player inventory items the merchant accepts ("Sell" — gains coins).
##
## Coins are tracked as a regular item: `ancient_coin`.
##
## Phase 9 features:
##   9.3   — Buy/Sell are explicit tabs.
##   9.10  — Restock countdown displayed at the top.
##   9.30  — Seasonal extras are merged via NpcLifecycle.seasonal_phase.
##   9.57  — Mood-based price multiplier dims/brightens prices.
##   9.58  — Veiled Buyer variable-price negotiation: prices jitter on open.
##   9.61  — Faction reputation adjusts prices.

const COIN_ID: StringName = &"ancient_coin"

@onready var title: Label = $Root/Title
@onready var coin_label: Label = $Root/Coins
@onready var buy_list: VBoxContainer = $Root/Cols/BuyCol/Scroll/List
@onready var sell_list: VBoxContainer = $Root/Cols/SellCol/Scroll/List
@onready var buy_label_node: Label = $Root/Cols/BuyCol/BuyLabel
@onready var sell_label_node: Label = $Root/Cols/SellCol/SellLabel

var _current_npc: NPC
var _inventory: MerchantInventory
var _show_buy: bool = true
var _veiled_buyer_jitter: float = 1.0


func _ready() -> void:
	add_to_group("merchant_ui")
	visible = false
	EventBus.inventory_changed.connect(_refresh_coins)
	EventBus.inventory_changed.connect(_rebuild_sell_list)
	# Phase 9.3 — make labels clickable as tab toggles.
	if buy_label_node:
		buy_label_node.gui_input.connect(_on_tab_input.bind("buy"))
		buy_label_node.mouse_filter = Control.MOUSE_FILTER_STOP
	if sell_label_node:
		sell_label_node.gui_input.connect(_on_tab_input.bind("sell"))
		sell_label_node.mouse_filter = Control.MOUSE_FILTER_STOP


func open_for_npc(npc: NPC) -> void:
	_current_npc = npc
	_inventory = npc.merchant_inventory
	if _inventory == null:
		visible = false
		return
	# Phase 9.10 — try a restock when the player opens the panel.
	_inventory.try_restock(int(Time.get_unix_time_from_system()))
	# Phase 9.58 — Veiled Buyer: re-roll a jitter factor each open.
	if String(npc.npc_id) == "npc_veiled_buyer":
		_veiled_buyer_jitter = randf_range(0.75, 1.4)
	else:
		_veiled_buyer_jitter = 1.0
	_refresh_title()
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


func _on_tab_input(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_show_buy = (which == "buy")
		_refresh_visibility()


func _refresh_visibility() -> void:
	$Root/Cols/BuyCol.visible = _show_buy
	$Root/Cols/SellCol.visible = not _show_buy


func _refresh_title() -> void:
	if title == null:
		return
	var name_text: String = _current_npc.display_name
	# Phase 9.10 — show restock countdown.
	var secs: int = _inventory.seconds_to_restock(int(Time.get_unix_time_from_system())) if _inventory else 0
	var minutes: int = secs / 60
	title.text = "%s — Trade (restock in %dm)" % [name_text, minutes] if minutes > 0 else "%s — Trade (stocked)" % name_text


func _refresh_coins() -> void:
	if coin_label:
		coin_label.text = "Ancient Coins: %d" % Inventory.count_of(COIN_ID)


func _price_multiplier() -> float:
	var mult: float = _veiled_buyer_jitter
	if NpcLifecycle and _current_npc:
		var mood: int = NpcLifecycle.get_mood(_current_npc.npc_id)
		mult *= _inventory.price_multiplier_for_mood(mood)
		var faction: StringName = NpcLifecycle.NPC_FACTIONS.get(_current_npc.npc_id, &"")
		if faction != &"":
			mult *= NpcLifecycle.price_multiplier_for_reputation(faction)
	return clampf(mult, 0.35, 2.0)


func _rebuild_buy_list() -> void:
	if buy_list == null or _inventory == null:
		return
	for child in buy_list.get_children():
		child.queue_free()
	var phase: StringName = NpcLifecycle.seasonal_phase if NpcLifecycle else &""
	var entries: Array = _inventory.sell_items_for_phase(phase) if _inventory.has_method("sell_items_for_phase") else _inventory.sell_items
	var mult: float = _price_multiplier()
	for entry in entries:
		var item_id: StringName = StringName(entry.get("item_id", ""))
		if item_id == &"":
			continue
		var defn: ItemDef = ItemRegistry.get_def(item_id)
		var label_text: String = defn.display_name if defn else String(item_id)
		var base_price: int = int(entry.get("price", 0))
		var price: int = maxi(1, int(round(float(base_price) * mult)))
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
	var mult: float = _price_multiplier()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var item_id: StringName = StringName(slot["item_id"])
		var base_price: int = _inventory.price_to_sell(item_id)
		if base_price <= 0:
			continue
		var price: int = maxi(1, int(round(float(base_price) * mult)))
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
	# Mood bumps slightly per purchase (Phase 9.16/9.57 feedback loop).
	if NpcLifecycle and _current_npc:
		NpcLifecycle.set_mood(_current_npc.npc_id, NpcLifecycle.get_mood(_current_npc.npc_id) + 2)
		NpcLifecycle.add_friendship(_current_npc.npc_id, 1)
	_rebuild_buy_list()
	EventBus.ui_toast.emit("Bought 1.", 1.0)


func _sell(item_id: StringName, price: int) -> void:
	if Inventory.try_remove(item_id, 1) <= 0:
		return
	Inventory.try_add(COIN_ID, price)
	EventBus.ui_toast.emit("Sold 1 (+%dc)." % price, 1.0)
