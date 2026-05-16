extends Node2D
class_name PotPlanter

## Phase 8.22 — A single-tile indoor planter that behaves like TilledSoil but
## doesn't dry out (no moisture decay). FarmingSystem treats it as soil for
## plant_seed lookups.

const TilledSoilScene := preload("res://scenes/farming/tilled_soil.tscn")

var _soil: Node2D = null


func _ready() -> void:
	add_to_group("pot_planter")
	# Spawn a TilledSoil at our position so the same plant_seed path works.
	_soil = TilledSoilScene.instantiate()
	if _soil:
		_soil.set("indoor", true)
		_soil.global_position = global_position
		add_child(_soil)
		# Always moist — pots are watered by the planter itself.
		if _soil.has_method("set_moist"):
			_soil.call("set_moist", true)


func has_crop() -> bool:
	return _soil != null and _soil.has_method("has_crop") and _soil.call("has_crop")


func attach_crop(crop: PlantedCrop) -> void:
	if _soil and _soil.has_method("attach_crop"):
		_soil.call("attach_crop", crop)
