extends StaticBody2D
class_name DecorStatic

## Phase 9.33-9.37 — Shared script for non-interactive decoration placeables
## (fence, pillar, banner, carpet, window block, wallpaper). Each variant just
## sets its own group + collision profile in the .tscn. The shared script is
## here so NpcLifecycle._scan_room_for_objects can count nodes uniformly and
## the save round-trip is consistent.
##
## "blocking" decor (fence, pillar, window block when closed) keeps walls layer
## collision; flat decor (carpet, wallpaper, banner) clears collision_layer in
## the scene.

@export var decor_group: StringName = &"decor"


func _ready() -> void:
	add_to_group("placed_decor")
	if decor_group != &"":
		add_to_group(String(decor_group))
