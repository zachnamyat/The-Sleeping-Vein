extends Boss
class_name SythrennBoss

## Phase 10.11 — Sythrenn the Toxic Bloom. Three-phase fight; at phase 3 the
## player chooses to attack the *outer* body (kill, standard drops) or the
## *inner* body (mercy-kill, drops Sythrenn's Last Petal). The choice is made
## by the FIRST hit landed during phase 3:
##   - hit registers within `mercy_kill_radius_px` of boss center  -> mercy kill
##   - otherwise -> standard kill
## Phase 10.48 — at phase 2 the boss spawns three rotating spore-zone tiles.

const MERCY_HIT_RADIUS_PX: float = 18.0

var mercy_killed: bool = false
var _choice_locked: bool = false


func _ready() -> void:
	boss_id = &"boss_sythrenn"
	boss_music_id = &"boss_sythrenn_theme"
	trinket_item_id = &"sythrenn_trinket"
	shell_item_id = &"glow_cap"
	shell_drop_count = 8
	fragment_item_id = &"sovereign_name_fragment_4"
	pulse_item_id = &"verdant_heart"
	telegraph_radius_px = 40.0
	enrage_after_seconds = 360.0
	super._ready()
	if health:
		health.damaged.connect(_on_damaged_during_phase)


func _on_damaged_during_phase(_amount: int, source: Node, _type: StringName) -> void:
	if current_phase < 2 or _choice_locked:
		return
	if source == null or not (source is Node2D):
		return
	var dist: float = (source as Node2D).global_position.distance_to(global_position)
	mercy_killed = dist <= MERCY_HIT_RADIUS_PX
	_choice_locked = true
	if mercy_killed:
		EventBus.ui_toast.emit("You strike the inner bloom — a mercy kill.", 3.0)
		EventBus.screen_pulse_requested.emit(0.4, 0.6)
	else:
		EventBus.ui_toast.emit("You strike the outer body — Sythrenn dies hard.", 2.5)


func _drop_boss_loot() -> void:
	if not mercy_killed:
		super._drop_boss_loot()
		return
	# Phase 10.11 mercy-kill loot: Last Petal instead of Verdant Heart relic.
	# Verdant Heart still drops because the second Loom power-up is a critical-
	# path requirement, but Sythrenn's Last Petal accompanies it as the choice
	# token (read by `is_alt_kill_active` in Compendium).
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn == null:
		return
	var drops: Array[Dictionary] = [
		{"id": pulse_item_id, "count": 1},  # Verdant Heart
		{"id": fragment_item_id, "count": 1},
		{"id": &"sythrenn_last_petal", "count": 1},  # mercy token
		{"id": &"ancient_coin", "count": int(round(randf_range(40.0, 65.0)))},
	]
	if trinket_item_id != &"":
		drops.append({"id": trinket_item_id, "count": 1})
	for d in drops:
		var item_id: StringName = d["id"]
		if item_id == &"":
			continue
		var drop := scn.instantiate() as ItemDrop
		drop.item_id = item_id
		drop.count = int(d["count"])
		drop.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
		get_tree().current_scene.add_child(drop)
	# Set a flag for late-game dialogue to read.
	GameState.collected_relics[&"sythrenn_mercy_killed"] = true
