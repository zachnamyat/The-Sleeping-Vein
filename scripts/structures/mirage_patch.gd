extends Area2D
class_name MiragePatch

## Phase 11.19 — Mirage patch (Salt Wastes). Registers itself with
## Phase11Helpers on _ready so the player's flavor toast triggers within
## proximity. Cheap visual: a translucent shimmering rectangle.

func _ready() -> void:
	add_to_group("mirage_patch")
	if Phase11Helpers:
		Phase11Helpers.register_mirage(global_position)
