extends Workstation
class_name Oven

## Phase 8.30 — Oven / Bakery. Pairs with the Mill for bread + berry pies.

func _ready() -> void:
	station_id = &"oven"
	display_name = "Oven"
	super._ready()
	add_to_group("oven")
