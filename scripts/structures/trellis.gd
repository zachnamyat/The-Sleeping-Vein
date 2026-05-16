extends Node2D
class_name Trellis

## Phase 8.32 — A trellis for vertical-growing crops. Like PotPlanter, but
## occupies a slimmer footprint and accepts only crops in TRELLIS_CROPS.

const TilledSoilScene := preload("res://scenes/farming/tilled_soil.tscn")

const TRELLIS_CROPS := [&"bloat_oat", &"heart_berry"]

var _soil: Node2D = null


func _ready() -> void:
	add_to_group("trellis")
	_soil = TilledSoilScene.instantiate()
	if _soil:
		_soil.set("trellis", true)
		_soil.global_position = global_position
		add_child(_soil)
		if _soil.has_method("set_moist"):
			_soil.call("set_moist", true)


func has_crop() -> bool:
	return _soil != null and _soil.has_method("has_crop") and _soil.call("has_crop")


func attach_crop(crop: PlantedCrop) -> void:
	if not (crop.crop_id in TRELLIS_CROPS):
		EventBus.ui_toast.emit("Trellis only accepts vine crops.", 1.5)
		return
	if _soil and _soil.has_method("attach_crop"):
		_soil.call("attach_crop", crop)
