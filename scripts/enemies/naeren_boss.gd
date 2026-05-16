extends Boss
class_name NaerenBoss

## Phase 11.11 — Naeren the Wandering Salt-Crown.
## Two paths:
##   - Standard combat (split-fight, two phases). Drops Naeren's Salt-Crown.
##   - Wormbound peace path: if the player carries `wormbound_covenant_scroll`
##     on arena entry, Naeren acknowledges the covenant and walks past without
##     fighting. Player receives the Salt-Crown + Wormbound Covenant Scroll
##     plus a peaceful-resolution flag for Phase 12 dialogue branches.
##
## Phase thresholds: 1.0 / 0.5 / 0.2.

var peace_path: bool = false


func _ready() -> void:
	boss_id = &"boss_naeren"
	boss_music_id = &"boss_naeren_theme"
	trinket_item_id = &"naeren_trinket"
	shell_item_id = &"saltbound_steel_ore"
	shell_drop_count = 8
	fragment_item_id = &"sovereign_name_fragment_8"
	pulse_item_id = &"naerens_salt_crown"
	phase_thresholds = [1.0, 0.5, 0.2]
	telegraph_radius_px = 56.0
	enrage_after_seconds = 360.0
	super._ready()


func _on_first_engaged() -> void:
	# 11.11 peace path: if Walker holds the covenant scroll, bypass combat.
	if Inventory.count_of(&"wormbound_covenant_scroll") > 0:
		peace_path = true
		_resolve_peace_path()
		return
	super._on_first_engaged()


func _resolve_peace_path() -> void:
	EventBus.ui_toast.emit("Naeren: \"The covenant holds. Walk past.\"", 4.5)
	if AudioBus:
		AudioBus.play_sfx(&"naeren_voice")
	GameState.collected_relics[&"naeren_peace"] = true
	GameState.mark_boss_defeated(boss_id)
	# Drop salt-crown + Wormbound covenant + 50 coins.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn:
		_spawn_drop(scn, &"naerens_salt_crown", 1, Vector2.ZERO)
		_spawn_drop(scn, &"wormbound_covenant_scroll", 1, Vector2(10, 0))
		_spawn_drop(scn, &"ancient_coin", 50, Vector2(-10, 0))
	if _attack_cycler:
		_attack_cycler.stop()
	queue_free()


func _spawn_drop(scn: PackedScene, item_id: StringName, count: int, offset: Vector2) -> void:
	var drop := scn.instantiate() as ItemDrop
	if drop == null:
		return
	drop.item_id = item_id
	drop.count = count
	drop.global_position = global_position + offset
	get_tree().current_scene.add_child(drop)
