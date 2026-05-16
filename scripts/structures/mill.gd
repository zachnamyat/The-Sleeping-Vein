extends Workstation
class_name Mill

## Phase 8.29 — Grain mill. Converts bloat_oat → flour. Pairs with the Oven
## (8.30) to make bread.

func _ready() -> void:
	station_id = &"mill"
	display_name = "Mill"
	super._ready()
	add_to_group("mill")
