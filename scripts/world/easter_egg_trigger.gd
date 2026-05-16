extends Area2D
class_name EasterEggTrigger

## Phase 15.57 — Easter-egg / hidden-room trigger.
## Drop into a hidden room at world-gen time. When the player enters the
## area, Phase15Helpers.discover_easter_egg(egg_id) fires. Achievement /
## toast follow automatically.

@export var egg_id: StringName = &"egg_unknown"
@export var grant_item: StringName = &""   # optional reward item id
@export var grant_count: int = 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if Phase15Helpers == null:
		return
	var was_new: bool = Phase15Helpers.discover_easter_egg(egg_id)
	if was_new:
		if grant_item != &"" and Inventory:
			Inventory.try_add(grant_item, grant_count)
		queue_free()
