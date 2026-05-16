extends Area2D
class_name QuicksandPatch

## Phase 11.19 — Quicksand patch (Salt Wastes). Registers itself with
## Phase11Helpers on _ready so the player loses speed + accumulates damage
## while standing on top.

func _ready() -> void:
	add_to_group("quicksand_patch")
	if Phase11Helpers:
		Phase11Helpers.register_quicksand(global_position)
