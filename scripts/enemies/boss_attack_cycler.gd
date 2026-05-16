extends Node
class_name BossAttackCycler

## Phase 6.48 — runtime that walks an AttackPattern. Owned by a Boss as a
## child node. Steps through entries with their declared cooldowns and emits
## EventBus.aoe_indicator_requested + screen_pulse + camera shake for each.
##
## Use:
##   - assign `pattern` (AttackPattern resource).
##   - set `attached_boss` (Node2D) so AoE positions resolve from boss center.
##   - call `start()` on engagement, `stop()` on death.

signal attack_telegraphed(entry: Dictionary)
signal attack_resolved(entry: Dictionary)

@export var pattern: AttackPattern
@export var attached_boss: Node2D
@export var auto_start: bool = false

var _cursor: int = 0
var _accum: float = 0.0
var _running: bool = false
var _state: int = 0  ## 0 = waiting, 1 = telegraphing, 2 = recovering


func _ready() -> void:
	set_process(false)
	if auto_start:
		call_deferred("start")


func start() -> void:
	if pattern == null or pattern.entries.is_empty():
		return
	_running = true
	_cursor = 0
	_accum = 0.0
	_state = 1
	_telegraph_current()
	set_process(true)


func stop() -> void:
	_running = false
	set_process(false)


func _process(delta: float) -> void:
	if not _running or pattern == null:
		return
	_accum += delta
	if _state == 1:
		var ent: Dictionary = pattern.entries[_cursor]
		if _accum >= float(ent.get("telegraph_seconds", 0.5)):
			_resolve_current()
			_accum = 0.0
			_state = 2
	elif _state == 2:
		var ent2: Dictionary = pattern.entries[_cursor]
		if _accum >= float(ent2.get("cooldown_seconds", 1.0)):
			_advance()


func _telegraph_current() -> void:
	var ent: Dictionary = pattern.entries[_cursor]
	if attached_boss == null:
		return
	# AoE warning ring at the boss center.
	var radius: float = float(ent.get("radius_pixels", 32.0))
	var dur: float = float(ent.get("telegraph_seconds", 0.5))
	EventBus.aoe_indicator_requested.emit(attached_boss.global_position, radius, dur, Color(1.0, 0.3, 0.3, 0.55))
	attack_telegraphed.emit(ent)


func _resolve_current() -> void:
	var ent: Dictionary = pattern.entries[_cursor]
	if attached_boss == null:
		return
	# Generic resolution: deal AoE damage to player hurtboxes inside `radius_pixels`.
	var radius: float = float(ent.get("radius_pixels", 32.0))
	var dmg: int = int(ent.get("damage", 8))
	var dtype: StringName = StringName(ent.get("damage_type", &"physical"))
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Node2D
		if p == null:
			continue
		if p.global_position.distance_to(attached_boss.global_position) <= radius:
			var hb := p.get_node_or_null("Hurtbox") as HurtboxComponent
			if hb:
				hb.receive_hit_full(attached_boss, dmg, dtype, &"boss", true)
	# Visual punch.
	EventBus.camera_shake_requested.emit(2.5, 0.18)
	EventBus.screen_pulse_requested.emit(0.35, 0.3)
	attack_resolved.emit(ent)


func _advance() -> void:
	_cursor += 1
	if _cursor >= pattern.entries.size():
		if pattern.loop:
			_cursor = 0
		else:
			stop()
			return
	_state = 1
	_telegraph_current()


## Phase 6.48 — programmatic test entry-point. Returns the upcoming attack id
## without ticking the cycler. Used by GUT tests + boss-prep panel.
func peek_next() -> StringName:
	if pattern == null or pattern.entries.is_empty():
		return &""
	var idx: int = (_cursor + 1) % pattern.entries.size() if pattern.loop else mini(_cursor + 1, pattern.entries.size() - 1)
	return StringName(pattern.entries[idx].get("id", &""))


func current_index() -> int:
	return _cursor
