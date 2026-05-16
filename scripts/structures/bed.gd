extends Area2D
class_name Bed

## Phase 5.13 — bed placeable. Interacting (E) calls the player's
## try_sleep_in_bed flow which:
##   - aborts if hostiles are within ~200px (Phase 4.64)
##   - fades to black via letterbox, skips ~8 minutes of world clock
##   - heals 25% of max HP on wake
## Also binds the player's respawn point to this bed when set as primary.
##
## Phase 9 additions:
##   9.1/9.2 — When placed, the bed offers itself to the next pending NPC
##             arrival (housing validation gate).
##   9.62  —  Sleeping in a bed (after the world-clock skip) has a 1-in-4
##             chance to play a dream-vision sequence (lore flash).

@export var binds_respawn: bool = true

var _player_in_range: bool = false
var _bound_npc_id: StringName = &""


func _ready() -> void:
	add_to_group("bed")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	# Phase 9.1/9.2 — register this bed and try to bind an NPC if one is pending.
	call_deferred("_offer_for_npc_arrival")


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_use_bed()


func _use_bed() -> void:
	if binds_respawn:
		GameState.set_respawn_point(global_position)
		for p in get_tree().get_nodes_in_group("player"):
			if p.has_method("set_respawn_position"):
				p.call("set_respawn_position", global_position)
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("try_sleep_in_bed"):
			p.call("try_sleep_in_bed")
	# Phase 9.62 — dream vision flash on a 25% roll after sleeping.
	if randf() < 0.25:
		_play_dream_vision()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Rest", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _offer_for_npc_arrival() -> void:
	if NpcDirector == null:
		return
	NpcDirector.try_assign_bed(self)


func get_bound_npc_id() -> StringName:
	return _bound_npc_id


func set_bound_npc(npc_id: StringName) -> void:
	_bound_npc_id = npc_id


# Phase 9.62 — short letterbox + lore-toast triple. Lore is randomized from a
# small table; deliberately oblique. Each line consumes one Aphelion sliver
# (lore: dreams cost the Walker).
const DREAM_FRAGMENTS: Array[String] = [
	"A diadem turns its face toward you. The face is yours.",
	"A child with no name pushes a stone uphill. The hill is the world.",
	"The Aphelion looks back. It is younger than you remembered.",
	"Five bells rang once. You forgot the fifth before you woke.",
	"You name yourself. The Sovereigns hear it. Nothing answers.",
]


func _play_dream_vision() -> void:
	EventBus.letterbox_requested.emit(true, 0.4)
	var fragment: String = DREAM_FRAGMENTS[randi() % DREAM_FRAGMENTS.size()]
	EventBus.ui_toast.emit(fragment, 5.0)
	GameState.consume_sliver()
	var t := get_tree().create_timer(4.5)
	t.timeout.connect(func() -> void:
		EventBus.letterbox_requested.emit(false, 0.6)
	)
