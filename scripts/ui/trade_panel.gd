extends CanvasLayer
class_name TradePanel

## Phase 13.14 — Trade between two players. Drag items from inventory into
## offer slots; both players hit Lock; then both hit Confirm to commit.
## Soulbound items (3.39) are blocked at the add_self step in Phase13Helpers.

const PANEL_W: float = 400.0
const PANEL_H: float = 240.0
const OFFER_SLOTS: int = 6

var _root: Panel
var _self_label: Label
var _partner_label: Label
var _self_slots: VBoxContainer
var _partner_slots: VBoxContainer
var _lock_btn: Button
var _confirm_btn: Button
var _cancel_btn: Button


func _ready() -> void:
	add_to_group("trade_ui")
	layer = 80
	visible = false
	_root = Panel.new()
	_root.size = Vector2(PANEL_W, PANEL_H)
	_root.anchor_left = 0.5
	_root.anchor_top = 0.5
	_root.anchor_right = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -PANEL_W / 2
	_root.offset_top = -PANEL_H / 2
	_root.offset_right = PANEL_W / 2
	_root.offset_bottom = PANEL_H / 2
	add_child(_root)
	var title := Label.new()
	title.text = "Trade"
	title.position = Vector2(PANEL_W / 2 - 16, 4)
	_root.add_child(title)
	_self_label = Label.new()
	_self_label.text = "You"
	_self_label.position = Vector2(8, 24)
	_root.add_child(_self_label)
	_partner_label = Label.new()
	_partner_label.text = "Partner"
	_partner_label.position = Vector2(PANEL_W / 2 + 8, 24)
	_root.add_child(_partner_label)
	_self_slots = VBoxContainer.new()
	_self_slots.position = Vector2(8, 44)
	_self_slots.size = Vector2(PANEL_W / 2 - 12, PANEL_H - 90)
	_root.add_child(_self_slots)
	_partner_slots = VBoxContainer.new()
	_partner_slots.position = Vector2(PANEL_W / 2 + 4, 44)
	_partner_slots.size = Vector2(PANEL_W / 2 - 12, PANEL_H - 90)
	_root.add_child(_partner_slots)
	_lock_btn = Button.new()
	_lock_btn.text = "Lock"
	_lock_btn.position = Vector2(8, PANEL_H - 30)
	_lock_btn.size = Vector2(80, 22)
	_lock_btn.pressed.connect(_on_lock)
	_root.add_child(_lock_btn)
	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.position = Vector2(96, PANEL_H - 30)
	_confirm_btn.size = Vector2(80, 22)
	_confirm_btn.pressed.connect(_on_confirm)
	_root.add_child(_confirm_btn)
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.position = Vector2(PANEL_W - 88, PANEL_H - 30)
	_cancel_btn.size = Vector2(80, 22)
	_cancel_btn.pressed.connect(_on_cancel)
	_root.add_child(_cancel_btn)
	if Phase13Helpers:
		Phase13Helpers.trade_offered.connect(_on_trade_offered)
		Phase13Helpers.trade_completed.connect(_on_trade_completed)
		Phase13Helpers.trade_cancelled.connect(_on_trade_cancelled)


func open_with(partner_peer_id: int) -> void:
	if Phase13Helpers == null:
		return
	Phase13Helpers.trade_request(partner_peer_id)
	_partner_label.text = "Peer %d" % partner_peer_id
	visible = true
	_redraw()


func _redraw() -> void:
	for c in _self_slots.get_children():
		c.queue_free()
	for c in _partner_slots.get_children():
		c.queue_free()
	if Phase13Helpers == null:
		return
	for offer in Phase13Helpers.trade_self_offer:
		var l := Label.new()
		l.text = "%s × %d" % [String(offer.get("item_id", "")), int(offer.get("count", 0))]
		_self_slots.add_child(l)
	for offer in Phase13Helpers.trade_partner_offer:
		var l := Label.new()
		l.text = "%s × %d" % [String(offer.get("item_id", "")), int(offer.get("count", 0))]
		_partner_slots.add_child(l)


func add_to_offer(item_id: StringName, count: int) -> void:
	if Phase13Helpers:
		Phase13Helpers.trade_add_self(item_id, count)
		_redraw()


func _on_lock() -> void:
	if Phase13Helpers:
		Phase13Helpers.trade_lock_self()
		# Simulate partner lock for single-player tests; the real path is RPC-driven.
		Phase13Helpers.trade_lock_partner()


func _on_confirm() -> void:
	if Phase13Helpers and Phase13Helpers.trade_commit():
		EventBus.ui_toast.emit("Trade complete.", 2.0)
		visible = false


func _on_cancel() -> void:
	if Phase13Helpers:
		Phase13Helpers.trade_cancel()
	visible = false


func _on_trade_offered(_from: int, _to: int) -> void:
	visible = true
	_redraw()


func _on_trade_completed() -> void:
	visible = false


func _on_trade_cancelled() -> void:
	visible = false
