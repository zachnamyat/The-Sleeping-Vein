extends CanvasLayer
class_name AuctioneerPanel

## Phase 14.30 — Auctioneer UI. Two tabs:
##   Sell — list any item with a price (Ancient Coins).
##   Browse — view live listings; one click claims.
##
## Behaviour is fully data-driven; the panel only needs Phase14Helpers calls.

signal closed


func _ready() -> void:
	add_to_group("auctioneer_ui")
	visible = false


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	## Repopulate the browse + sell tabs. UI binding left to the .tscn.
	pass


func list_for_sale(item_id: StringName, count: int, price: int) -> int:
	if NetSystem == null:
		return -1
	var seller_peer: int = NetSystem.local_peer_id() if NetSystem.has_method("local_peer_id") else 1
	return Phase14Helpers.list_for_sale(seller_peer, item_id, count, price)


func claim(listing_id: int) -> bool:
	if NetSystem == null:
		return false
	var buyer_peer: int = NetSystem.local_peer_id() if NetSystem.has_method("local_peer_id") else 1
	return Phase14Helpers.claim_listing(listing_id, buyer_peer)


func active_listings() -> Array:
	return Phase14Helpers.active_listings()
