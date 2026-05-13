extends CanvasLayer
class_name BossHpBar

## Single boss HP bar at the top of the screen. Listens for `boss_engaged` and
## shows the bar for that boss. Hides on boss death.

@onready var name_label: Label = $Root/Name
@onready var hp_bar: ProgressBar = $Root/HpBar
@onready var phase_label: Label = $Root/Phase

var _tracked_boss: Node = null
var _hp_component: HealthComponent
var _boss_node: Node


func _ready() -> void:
	add_to_group("boss_hp_bar")
	visible = false
	EventBus.boss_engaged.connect(_on_boss_engaged)


func _process(_delta: float) -> void:
	if _tracked_boss == null or not is_instance_valid(_tracked_boss):
		visible = false
		return


func _on_boss_engaged(boss_id: StringName) -> void:
	# Find the boss node in the scene by group, match by boss_id property.
	var bosses := get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if b.has_method("get") and b.get("boss_id") == boss_id:
			_track(b, boss_id)
			return


func _track(boss: Node, boss_id: StringName) -> void:
	_tracked_boss = boss
	_boss_node = boss
	_hp_component = boss.get_node_or_null("HealthComponent") as HealthComponent
	if _hp_component == null:
		return
	if not _hp_component.health_changed.is_connected(_on_hp_changed):
		_hp_component.health_changed.connect(_on_hp_changed)
	if not _hp_component.died.is_connected(_on_died):
		_hp_component.died.connect(_on_died)
	var defn: MobDef = boss.get("mob_def") as MobDef
	name_label.text = defn.display_name if defn else String(boss_id)
	hp_bar.max_value = _hp_component.max_health
	hp_bar.value = _hp_component.current_health
	phase_label.text = ""
	visible = true
	# Connect phase signal if the boss has one
	if boss.has_signal("phase_advanced") and not boss.phase_advanced.is_connected(_on_phase_advanced):
		boss.phase_advanced.connect(_on_phase_advanced)


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current


func _on_phase_advanced(phase: int) -> void:
	phase_label.text = "PHASE %d" % (phase + 1)


func _on_died(_killer: Node) -> void:
	visible = false
	_tracked_boss = null
