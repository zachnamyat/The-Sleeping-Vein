extends Area2D
class_name TilledSoil

## Phase 8.1/8.2/8.13/8.31 — A single tile of farmable soil. Created by the Hoe
## tool, holds moisture + fertilizer state, accepts seeds, and dries out over
## the Aphelion Beat unless re-watered by hand, by a Sprinkler, or by being
## inside a Greenhouse.

const DRY_AFTER_BEATS: int = 6   ## ≈ 138s real time before soil dries again.

@export var indoor: bool = false   ## Pot planter override (ticket 8.22).
@export var trellis: bool = false  ## Trellis variant for vertical crops (8.32).

var _moist: bool = false
var _beats_since_water: int = 0
var _fert_id: StringName = &""
var _fert_data: Dictionary = {}
var _attached_crop: PlantedCrop = null


func _ready() -> void:
	add_to_group("tilled_soil")
	if trellis:
		add_to_group("trellis")
	if indoor:
		add_to_group("pot_planter")
	collision_layer = 0
	collision_mask = 0
	monitorable = false
	monitoring = false
	z_index = -1
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)
	_paint_self()


func _on_beat() -> void:
	if not _moist:
		return
	_beats_since_water += 1
	if _beats_since_water >= DRY_AFTER_BEATS:
		set_moist(false)


func set_moist(state: bool) -> void:
	_moist = state
	if state:
		_beats_since_water = 0
	if _attached_crop and is_instance_valid(_attached_crop):
		if state:
			_attached_crop.water()
	_paint_self()


func is_moist() -> bool:
	return _moist


func set_fertilizer(item_id: StringName, data: Dictionary) -> void:
	_fert_id = item_id
	_fert_data = data
	# Push the data onto any existing crop so it picks up the bonus retroactively.
	if _attached_crop and is_instance_valid(_attached_crop):
		_attached_crop.set_fertilizer_bonus(
			float(data.get("speed_mult", 1.0)),
			float(data.get("bonus_yield_chance", 0.0)),
		)
	_paint_self()


func attach_crop(crop: PlantedCrop) -> void:
	_attached_crop = crop
	if not _fert_data.is_empty():
		crop.set_fertilizer_bonus(
			float(_fert_data.get("speed_mult", 1.0)),
			float(_fert_data.get("bonus_yield_chance", 0.0)),
		)
	if _moist:
		crop.water()
	# Clean up the reference when the crop despawns.
	if not crop.tree_exited.is_connected(_on_crop_freed):
		crop.tree_exited.connect(_on_crop_freed)


func has_crop() -> bool:
	return _attached_crop != null and is_instance_valid(_attached_crop)


func _on_crop_freed() -> void:
	_attached_crop = null


func _paint_self() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	# Procedural placeholder colouring: dark brown when dry, deep wet brown when
	# moist, faint tint when fertilized. Real art lands in Phase 15.
	var base: Color = Color(0.32, 0.22, 0.12)
	if _moist:
		base = Color(0.18, 0.12, 0.08)
	if _fert_id == &"fertilizer_verdant":
		base = base.lerp(Color(0.24, 0.45, 0.18), 0.4)
	elif _fert_id == &"fertilizer_salt":
		base = base.lerp(Color(0.55, 0.55, 0.6), 0.4)
	elif _fert_id == &"fertilizer":
		base = base.lerp(Color(0.4, 0.28, 0.16), 0.4)
	sprite.modulate = base
