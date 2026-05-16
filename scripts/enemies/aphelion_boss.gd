extends Boss
class_name AphelionBoss

## Phase 12.10 — The Aphelion (optional, Break ending only).
##
## A bullet-hell fight inside the Sphere itself. The Aphelion has no body —
## the "boss" renders as a featureless gold sphere icon and the actual
## challenge is the pattern, not the strike. The Walker does not die here;
## "death" warps them back to the Loom. The fight ends when the Aphelion
## chooses to crack (its resistance reaches zero); narrative gate, not
## damage gate.
##
## When the fight resolves, Phase12Helpers.reveal_aphelion_apology fires,
## surfacing the translated apology phrase (12.27) and dropping the final
## Sovereign-Name Fragment XII.

const RESISTANCE_DECAY_PER_TICK: float = 0.012  ## per 0.5s; ~40s to crack at full pressure
const RESISTANCE_TICK_PERIOD: float = 0.5

var aphelion_resistance: float = 1.0
var _res_accum: float = 0.0
var _cracked: bool = false


func _ready() -> void:
	boss_id = &"boss_aphelion"
	boss_music_id = &"boss_aphelion_theme"
	trinket_item_id = &""
	shell_item_id = &"aphelion_shard"
	shell_drop_count = 5
	fragment_item_id = &"sovereign_name_fragment_12"
	pulse_item_id = &""
	phase_thresholds = [1.0, 0.5]
	telegraph_radius_px = 96.0
	enrage_after_seconds = 0.0  ## no enrage; this fight has its own clock
	super._ready()


func _physics_process(delta: float) -> void:
	# 12.10 — the Aphelion does not move; bullet-hell relies on the cycler.
	if _cracked:
		return
	# Engagement still required for cycler to start.
	super._physics_process(delta)
	# The Walker's hits reduce resistance, but only at the cycler-paced cadence.
	_res_accum += delta
	if _res_accum < RESISTANCE_TICK_PERIOD:
		return
	_res_accum = 0.0
	if _engaged and not _cracked:
		# Each tick the boss accepts a bit of the pressure if the player has
		# survived this far. Damage dealt this tick further accelerates.
		aphelion_resistance = clampf(aphelion_resistance - RESISTANCE_DECAY_PER_TICK, 0.0, 1.0)
		# Sync to the Boss HP bar; the bar reads `current_health` as a fraction.
		if health:
			health.current_health = int(round(float(health.max_health) * aphelion_resistance))
			health.health_changed.emit(health.current_health, health.max_health)
		if aphelion_resistance <= 0.0:
			_resolve_crack()


func _resolve_crack() -> void:
	if _cracked:
		return
	_cracked = true
	EventBus.letterbox_requested.emit(true, 1.2)
	EventBus.ui_toast.emit("The Aphelion's resistance ends. The Sphere cracks.", 6.0)
	if AudioBus:
		AudioBus.play_sfx(&"aphelion_crack")
	# 12.27 — apology reveal.
	if Phase12Helpers:
		Phase12Helpers.reveal_aphelion_apology()
	# Trigger the standard boss death path so the loot drops.
	if health:
		health.current_health = 0
		health.died.emit(self)


func _drop_boss_loot() -> void:
	super._drop_boss_loot()
	# 12.10 — Aphelion drops 5 shards + Sovereign Fragment XII.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	for i in range(5):
		var drop := scn.instantiate() as ItemDrop
		if drop == null:
			continue
		drop.item_id = &"aphelion_shard"
		drop.count = 1
		var angle: float = TAU * float(i) / 5.0
		drop.global_position = global_position + Vector2(cos(angle), sin(angle)) * 24.0
		get_tree().current_scene.add_child(drop)
