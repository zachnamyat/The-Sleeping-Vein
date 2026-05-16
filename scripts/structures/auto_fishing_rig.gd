extends Node2D
class_name AutoFishingRig

## Phase 14.38 — Auto-fishing rig. Every AUTO_FISH_PERIOD_BEATS, rolls a fish
## from the current biome's table at the supplied rod_tier and inserts the
## result into `dest_path`. Bait is consumed from the rig's own internal slot;
## must be refilled with `bait_id`.

@export var rod_tier: int = 1
@export var bait_id: StringName = &"bait_basic"
@export var dest_path: NodePath
@export var wire_group: int = 0
@export var demand: float = 4.0

var _rig_id: int = -1
var _power_node_id: int = -1
var bait_stock: int = 0


func _ready() -> void:
	add_to_group("auto_fishing_rig")
	add_to_group("demolishable")
	_rig_id = Phase14Helpers.register_auto_fishing_rig(rod_tier, bait_id, dest_path)
	_power_node_id = Phase14Helpers.register_power_node(&"sink", wire_group, 0.0, demand)
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func add_bait(count: int) -> void:
	bait_stock += max(0, count)


func _on_beat() -> void:
	if bait_stock <= 0:
		return
	if not Phase14Helpers.resolve_power_for_group(wire_group):
		return
	var dest := get_node_or_null(dest_path)
	if dest == null or not dest.has_method("try_insert"):
		return
	if FishingSystem == null or not FishingSystem.has_method("roll_fish"):
		return
	var fish_id: StringName = FishingSystem.call("roll_fish", rod_tier, bait_id)
	if fish_id == &"":
		return
	bait_stock -= 1
	dest.call("try_insert", fish_id, 1)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_power_node(_power_node_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "auto_fishing_rig_placeable", "count": 1 }
