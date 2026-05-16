extends Workstation
class_name Composter

## Phase 8.16/8.40 — A workstation that turns refuse (loambeetle / pale_cap /
## bloat_oat scraps) into fertilizer through recipes filed under
## stations=[&"composter"]. The Workstation parent already wires interaction
## + recipe filtering; this subclass exists so future ticks (Verdant compost
## from spore residue, Salt-fert from salt) can hang off here.

func _ready() -> void:
	station_id = &"composter"
	display_name = "Composter"
	super._ready()
	add_to_group("composter")
