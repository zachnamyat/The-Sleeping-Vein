extends Node2D
class_name Greenhouse

## Phase 8.17 — A purely passive structure that registers itself in the
## `greenhouse` group. FarmingSystem.greenhouse_multiplier_at reads the group
## to apply a +60% growth multiplier to crops within 64 px.

func _ready() -> void:
	add_to_group("greenhouse")
