extends Workstation
class_name DryingRack

## Phase 8.23/8.35 — Drying rack: converts raw_meat → dried_meat at this
## workstation. (Food spoilage is a Phase 15 polish ticket — the design
## decision today is that meat doesn't actively spoil; the rack exists so
## the food preservation chain is in-place when spoilage lands.)

func _ready() -> void:
	station_id = &"drying_rack"
	display_name = "Drying Rack"
	super._ready()
	add_to_group("drying_rack")
