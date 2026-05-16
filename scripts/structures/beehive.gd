extends Area2D
class_name Beehive

## Phase 8.18/8.39 — Hive that produces honey every `produce_every_beats` if at
## least one flower (heart_berry plant or pale_cap plant in bloom) is within
## the flower_radius. Visit the hive and press E to harvest.

@export var produce_every_beats: int = 8
@export var flower_radius: float = 96.0

var _beats: int = 0
var stored_honey: int = 0
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("beehive")
	monitoring = true
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beats += 1
	if _beats < produce_every_beats:
		return
	_beats = 0
	if not _has_flowers():
		return
	stored_honey += 1
	if AudioBus:
		AudioBus.play_sfx(&"bee_buzz", global_position)


func _has_flowers() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	const FLOWER_CROPS := [&"heart_berry", &"pale_cap", &"glow_cap"]
	for c in tree.get_nodes_in_group("planted_crop"):
		var crop: PlantedCrop = c
		if crop == null:
			continue
		if not (crop.crop_id in FLOWER_CROPS):
			continue
		if crop.global_position.distance_to(global_position) <= flower_radius:
			return true
	return false


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Beehive (%d honey)" % stored_honey, 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact"):
		return
	if stored_honey <= 0:
		EventBus.ui_toast.emit("No honey yet.", 1.5)
		return
	Inventory.try_add(&"honey", stored_honey)
	EventBus.skill_xp_gained.emit(&"skill_gardening", stored_honey)
	stored_honey = 0
	EventBus.ui_toast.emit("Harvested honey.", 1.5)


func dump_state() -> Dictionary:
	return { "stored_honey": stored_honey }


func restore_state(data: Dictionary) -> void:
	stored_honey = int(data.get("stored_honey", 0))
