extends Node2D
class_name GlowShroom

## Phase 4.53 — placeable light-source crop. Sits on the floor_deco layer and
## emits a soft cyan PointLight2D. No interaction; purely cosmetic + tactical
## (Phase 4.51 spawn-suppression uses light-source proximity).

func _ready() -> void:
	add_to_group("light_source")
