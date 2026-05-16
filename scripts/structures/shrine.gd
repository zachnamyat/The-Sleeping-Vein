extends Area2D
class_name Shrine

## Phase 5.14 — worship statue / shrine buff station. Interact once per beat
## window to gain a short buff drawn from a small palette tied to the world's
## current Aphelion phase (Buffs autoload tracks duration).
##   - Phase 0 (early morning): Vigil — +mining_speed
##   - Phase 1 (midday):        Hearth — +max_hp regen
##   - Phase 2 (evening):       Resolve — +melee_damage
##   - Phase 3 (deep night):    Mote — +visibility

@export var buff_duration_seconds: float = 90.0
@export var cooldown_beats: int = 4

var _player_in_range: bool = false
var _last_use_beat: int = -999999


func _ready() -> void:
	add_to_group("shrine")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_offer()


func _offer() -> void:
	var phase: int = AudioBus.current_phase() if AudioBus else 0
	if AudioBus and abs(phase - _last_use_beat) < cooldown_beats and _last_use_beat != -999999:
		EventBus.ui_toast.emit("The shrine waits. Return after a few Beats.", 2.0)
		return
	_last_use_beat = phase
	var buff_id: StringName = _buff_for_phase(phase)
	if Buffs:
		Buffs.apply(buff_id, buff_duration_seconds)
	EventBus.ui_toast.emit("Shrine grants: %s" % String(buff_id).replace("buff_", "").capitalize(), 2.5)
	if AudioBus:
		AudioBus.play_sfx(&"shrine_blessing")


func _buff_for_phase(phase: int) -> StringName:
	match phase:
		0: return &"buff_vigil"
		1: return &"buff_hearth"
		2: return &"buff_resolve"
		3: return &"buff_mote"
		_: return &"buff_vigil"


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		EventBus.ui_toast.emit("[E] Offer to the shrine", 1.5)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
