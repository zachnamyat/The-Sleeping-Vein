extends Area2D
class_name NetTrap

## Phase 8.21 — A passive fishing trap. Every `produce_every_beats` Aphelion
## Beats it rolls a tier-1/2 catch via FishingSystem.net_trap_roll and stashes
## it. Walk up and press E to collect.

@export var produce_every_beats: int = 12

var _beats: int = 0
var stored: Array = []
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("net_trap")
	monitorable = false
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
	# Identify which biome we sit in.
	var biome_id: StringName = &"root_hollows"
	var tree := get_tree()
	if tree and tree.current_scene:
		var wg := tree.current_scene.get_node_or_null("WorldGen")
		if wg and wg.has_method("biome_at"):
			var b: BiomeDef = wg.biome_at(global_position) as BiomeDef
			if b:
				biome_id = b.id
	var caught: StringName = FishingSystem.net_trap_roll(biome_id)
	if caught != &"":
		stored.append(caught)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Net Trap (%d fish)" % stored.size(), 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact"):
		return
	if stored.is_empty():
		EventBus.ui_toast.emit("Net empty.", 1.5)
		return
	for f in stored:
		Inventory.try_add(StringName(f), 1)
	EventBus.skill_xp_gained.emit(&"skill_fishing", stored.size())
	EventBus.ui_toast.emit("Collected %d fish." % stored.size(), 1.5)
	stored.clear()


func dump_state() -> Dictionary:
	return { "stored": stored.duplicate(true) }


func restore_state(data: Dictionary) -> void:
	stored = data.get("stored", []).duplicate(true) as Array
