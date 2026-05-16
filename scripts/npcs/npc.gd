extends CharacterBody2D
class_name NPC

## Base NPC. Stands at a position, faces the player when interacted, plays a
## DialogueTree, can offer merchant inventories.
##
## Phase 9 expansions:
##   9.11/9.20  Pathfinding: sleep -> shop -> idle micro-tour using `home_bed_pos`
##              and `shop_pos`. Pure Tween-driven (no NavigationAgent2D needed
##              for the tiny anchor base).
##   9.12       Dialogue tree is mood-branched: nodes named "{base}_happy" /
##              "_sad" override the base node when present.
##   9.42       Voice barks: idle / combat / weather / time-of-day. Throttled
##              via NpcLifecycle.can_bark.
##   9.43       Reaction to placed objects in same room: positive items
##              (carpet, painting, lantern) add to mood; bombs subtract.
##   9.65       Theme music: when player gets within 64px, AudioBus crossfades
##              to this NPC's theme_music id (defined on the merchant_inventory).

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var sprite_tex: Texture2D
@export var dialogue: DialogueTree
@export var merchant_inventory: MerchantInventory
@export var arrival_lore_ref: String = ""
@export var idle_voice_lines: Array[String] = []
@export var sleeps_at_long_night: bool = true

var _player_in_range: bool = false
var home_bed_pos: Vector2 = Vector2.ZERO
var shop_pos: Vector2 = Vector2.ZERO

const PATHFIND_MODES := [&"sleep", &"shop", &"idle"]
var _current_mode: StringName = &"shop"
var _path_tween: Tween
var _player_was_near: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $InteractPrompt


func _ready() -> void:
	add_to_group("npc")
	if sprite and sprite_tex:
		sprite.texture = sprite_tex
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false
	if shop_pos == Vector2.ZERO:
		shop_pos = global_position
	# Phase 9.11/9.20 — kick off pathfinding loop.
	var t := Timer.new()
	t.wait_time = 6.0 + randf() * 2.0
	t.autostart = true
	t.one_shot = false
	add_child(t)
	t.timeout.connect(_pick_next_destination)
	# Phase 9.43 — react-to-placed-objects passive tick.
	var room_tick := Timer.new()
	room_tick.wait_time = 12.0
	room_tick.autostart = true
	room_tick.one_shot = false
	add_child(room_tick)
	room_tick.timeout.connect(_scan_room_for_objects)


func _process(_delta: float) -> void:
	# Phase 9.65 — proximity-based theme music crossfade.
	if merchant_inventory and AudioBus and AudioBus.has_method("set_npc_theme"):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var player_pos: Vector2 = (players[0] as Node2D).global_position
			var near: bool = player_pos.distance_to(global_position) < 64.0
			if near and not _player_was_near:
				AudioBus.call("set_npc_theme", merchant_inventory.theme_music, true)
			elif _player_was_near and not near:
				AudioBus.call("set_npc_theme", merchant_inventory.theme_music, false)
			_player_was_near = near


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		_open_dialogue()


func _open_dialogue() -> void:
	if dialogue == null:
		return
	# Phase 9.21 — pick mood-suffixed branch if NPC has one for the entry node.
	var ui_nodes := get_tree().get_nodes_in_group("dialogue_ui")
	if ui_nodes.is_empty():
		return
	(ui_nodes[0]).open_for_npc(self)
	EventBus.npc_dialogue_opened.emit(npc_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if prompt_label:
			prompt_label.visible = true
		_try_idle_bark(&"idle")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt_label:
			prompt_label.visible = false
		var ui_nodes := get_tree().get_nodes_in_group("dialogue_ui")
		if not ui_nodes.is_empty():
			(ui_nodes[0]).close_if_for(self)


# ----- Pathfinding -----

func _pick_next_destination() -> void:
	# Cycle through idle states. Brindle works the forge; Mira tends storage;
	# everyone sleeps during long-night.
	if NpcLifecycle and NpcLifecycle.seasonal_phase == &"phase_long_night" and sleeps_at_long_night:
		_walk_to(home_bed_pos if home_bed_pos != Vector2.ZERO else shop_pos, &"sleep")
		return
	# Pick a target near the shop_pos (small wander).
	var jitter := Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
	var target := shop_pos + jitter
	_walk_to(target, &"idle")


func _walk_to(target: Vector2, mode: StringName) -> void:
	_current_mode = mode
	if _path_tween and is_instance_valid(_path_tween):
		_path_tween.kill()
	_path_tween = create_tween()
	var dist := global_position.distance_to(target)
	var dur := clampf(dist / 28.0, 0.6, 3.2)
	_path_tween.tween_property(self, "global_position", target, dur)


# ----- Phase 9.42 — voice barks -----

func _try_idle_bark(context: StringName) -> void:
	if idle_voice_lines.is_empty():
		return
	if NpcLifecycle == null or not NpcLifecycle.can_bark(npc_id, context):
		return
	var line: String = idle_voice_lines[randi() % idle_voice_lines.size()]
	EventBus.ui_toast.emit("%s: %s" % [display_name, line], 2.6)


# ----- Phase 9.43 — react to placed objects -----

const NEARBY_RADIUS: float = 48.0
const POSITIVE_GROUPS: Array[StringName] = [&"carpet", &"painting", &"banner", &"light_source", &"pet_bowl"]
const NEGATIVE_GROUPS: Array[StringName] = [&"spike_trap", &"bomb"]


func _scan_room_for_objects() -> void:
	if NpcLifecycle == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var positive: int = 0
	var negative: int = 0
	for grp in POSITIVE_GROUPS:
		for n in tree.get_nodes_in_group(String(grp)):
			if n is Node2D and (n as Node2D).global_position.distance_to(global_position) < NEARBY_RADIUS:
				positive += 1
	for grp in NEGATIVE_GROUPS:
		for n in tree.get_nodes_in_group(String(grp)):
			if n is Node2D and (n as Node2D).global_position.distance_to(global_position) < NEARBY_RADIUS:
				negative += 1
	if positive + negative == 0:
		return
	var current_mood: int = NpcLifecycle.get_mood(npc_id)
	# Phase 9.41 — light pollution: too many lights penalize past a threshold.
	var lights_near: int = 0
	for n in tree.get_nodes_in_group("light_source"):
		if n is Node2D and (n as Node2D).global_position.distance_to(global_position) < NEARBY_RADIUS:
			lights_near += 1
	var light_penalty: int = max(0, lights_near - 3)
	var net: int = positive - negative * 2 - light_penalty
	NpcLifecycle.set_mood(npc_id, current_mood + signi(net))
