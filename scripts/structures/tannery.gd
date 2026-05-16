extends Workstation
class_name Tannery

## Phase 3.31 (reassigned to Phase 8) — Tannery workstation. Cures Raw Hide
## into Leather. The hide drop comes from animal mobs (stone_hopper loot table
## adds it via Phase 8 hide-drop pass); leather is a reagent the Phase 11+
## armour recipes consume.

func _ready() -> void:
	station_id = &"tannery"
	display_name = "Tannery"
	super._ready()
	add_to_group("tannery")
