extends Area2D
class_name VerdantSoil

## Phase 10.23 — placeable Verdancy-only planter. Functions like tilled soil
## but applies a 1.5× growth multiplier read by FarmingSystem.crop_grow_factor.
## Only accepts Verdancy-class seeds (memory_root, glow_cap, heart_berry).
## Returns growth_multiplier so FarmingSystem can apply it to any plant on top.

const GROWTH_MULTIPLIER: float = 1.5

@export var crop_id: StringName = &""
@export var growth_seconds: float = 0.0


func _ready() -> void:
	add_to_group("verdant_soil")


func growth_factor() -> float:
	return GROWTH_MULTIPLIER


func dump_state() -> Dictionary:
	return {"crop_id": String(crop_id), "growth_seconds": growth_seconds}


func restore_state(d: Dictionary) -> void:
	crop_id = StringName(String(d.get("crop_id", "")))
	growth_seconds = float(d.get("growth_seconds", 0.0))
