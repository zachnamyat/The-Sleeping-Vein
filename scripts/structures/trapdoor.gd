extends Area2D
class_name Trapdoor

## Phase 4.28 — placeable hatch. Walking onto it from above lifts the door and
## reveals what's beneath: spawns the configured drop scene at this position.
## Single-use; consumes itself after triggering.

@export var drop_loot_table_id: StringName = &""
@export var drop_item_id: StringName = &"loambeetle"
@export var drop_count: int = 1

var _triggered: bool = false


func _ready() -> void:
	add_to_group("trapdoor")
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	# Phase 4.28 — drop content. Loot tables (Phase 4.23) will resolve via a
	# table id if set; minimum path just spawns the configured item.
	if drop_item_id != &"" and drop_count > 0:
		Inventory.try_add(drop_item_id, drop_count)
	EventBus.ui_toast.emit("The hatch swings open. +%d %s" % [drop_count, String(drop_item_id)], 2.0)
	if AudioBus:
		AudioBus.play_sfx(&"trapdoor")
	queue_free()
