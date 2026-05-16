extends Area2D
class_name TrialChamber

## Phase 5.31 — trial chamber / proving-ground variant. A self-contained
## room: the player enters, the gates close, three waves of biome-flavored
## mobs spawn, a chest unlocks on clear. Designed as a placeable that
## WorldGen seeds (or the player crafts via a scroll, eventually).

signal trial_started
signal trial_complete

@export var biome_id: StringName = &"root_hollows"
@export var mob_scene_path: String = "res://scenes/enemies/stone_hopper.tscn"
@export var mob_def_path: String = "res://resources/mobs/stone_hopper.tres"
@export var waves: Array[int] = [3, 4, 5]
@export var wave_delay_seconds: float = 1.5
@export var reward_chest_scene_path: String = "res://scenes/structures/treasure_chest.tscn"

var _started: bool = false
var _wave_index: int = 0
var _alive: Array[Node] = []


func _ready() -> void:
	add_to_group("trial_chamber")
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if _started:
		return
	if not body.is_in_group("player"):
		return
	_started = true
	trial_started.emit()
	EventBus.ui_toast.emit("Trial begins. Three waves.", 3.0)
	_run_next_wave()


func _run_next_wave() -> void:
	if _wave_index >= waves.size():
		_finish()
		return
	var count: int = waves[_wave_index]
	var scn := load(mob_scene_path) as PackedScene
	var defn := load(mob_def_path) as MobDef
	if scn == null:
		_finish()
		return
	for i in range(count):
		var mob := scn.instantiate() as Node2D
		if mob == null:
			continue
		if defn and mob.has_method("set"):
			mob.set("mob_def", defn)
		var angle: float = float(i) / max(1.0, float(count)) * TAU
		var radius: float = 36.0
		mob.position = global_position + Vector2(cos(angle), sin(angle)) * radius
		get_tree().current_scene.add_child(mob)
		_alive.append(mob)
		# Track per-mob death without depending on signal availability.
	_wave_index += 1
	set_process(true)


func _process(_delta: float) -> void:
	_alive = _alive.filter(func(n): return is_instance_valid(n))
	if _alive.is_empty():
		set_process(false)
		var t := get_tree().create_timer(wave_delay_seconds)
		t.timeout.connect(_run_next_wave)


func _finish() -> void:
	trial_complete.emit()
	EventBus.ui_toast.emit("Trial passed. The chamber yields its prize.", 4.0)
	if AudioBus:
		AudioBus.play_sfx(&"trial_complete")
	# Spawn a treasure chest at the chamber center.
	var scn := load(reward_chest_scene_path) as PackedScene
	if scn == null:
		return
	var chest := scn.instantiate() as Node2D
	if chest == null:
		return
	chest.position = global_position
	chest.set("unique_id", StringName("trial_reward_%d" % get_instance_id()))
	get_tree().current_scene.add_child(chest)
