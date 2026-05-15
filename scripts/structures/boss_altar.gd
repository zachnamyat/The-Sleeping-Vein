extends Area2D
class_name BossAltar

## Phase 4.54 — re-fight summon tile. Interact while the player has defeated
## `boss_id` to re-summon it for a rematch (drops scale down to discourage
## farming — handled later by BossDirector). Pre-placed by WorldGen in deep-
## biome chambers.

@export var boss_id: StringName = &"glaur_em"
@export var cost_item_id: StringName = &"aphelion_fragment"
@export var cost_count: int = 1

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("boss_altar")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_try_summon()


func _try_summon() -> void:
	if not GameState.has_defeated_boss(boss_id):
		EventBus.ui_toast.emit("The altar refuses you. (Defeat %s first.)" % String(boss_id), 2.5)
		return
	if Inventory.count_of(cost_item_id) < cost_count:
		EventBus.ui_toast.emit("Altar wants %d %s." % [cost_count, String(cost_item_id)], 2.0)
		return
	Inventory.try_remove(cost_item_id, cost_count)
	EventBus.ui_toast.emit("The altar wakes. %s rises again." % String(boss_id), 3.0)
	if BossDirector and BossDirector.has_method("respawn_boss"):
		BossDirector.respawn_boss(boss_id, global_position)
	else:
		EventBus.boss_engaged.emit(boss_id)
	if AudioBus:
		AudioBus.play_sfx(&"boss_summon")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if GameState.has_defeated_boss(boss_id):
			EventBus.ui_toast.emit("[E] Re-summon %s" % String(boss_id), 1.5)
		else:
			EventBus.ui_toast.emit("Altar dormant.", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
