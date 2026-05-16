extends Area2D
class_name ElisionTablet

## Phase 12.5 + 12.30 — Elision-Script tablet. Picking one up calls
## Phase12Helpers.collect_elision_fragment(). Four are scattered across the
## Final Spiral; collecting all four spells the elided name:
##   VAEL · IOR · RI · ON
##
## Each tablet shows its syllable on proximity even before pickup, so the
## player can "preview" the puzzle. Interaction marks the tablet collected
## and frees the scene.

@export var syllable_index: int = 0   ## 0..3

var _collected: bool = false


func _ready() -> void:
	add_to_group("elision_tablet")
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _collected:
		return
	_collected = true
	if Phase12Helpers:
		Phase12Helpers.collect_elision_fragment()
	Inventory.try_add(&"elision_script_fragment", 1)
	queue_free()


func dump_state() -> Dictionary:
	return {"syllable_index": syllable_index, "collected": _collected}
