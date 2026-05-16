extends Boss
class_name VolthaarBoss

## Phase 10.13 — Vol'thaar with release-or-kill choice. The fight has 4 HP-band
## phases (1.0, 0.6, 0.3, 0.05). At phase 4 the boss freezes, speaks the line
## "I asked for the long quiet" via a UI toast, and the player can either:
##   - keep attacking → kill → standard drops + Sovereign Name Fragment 6.
##   - drop weapon (Q to put away) for 5 seconds → release → Vol'thaar's Promise
##     summon item drops in place. Act-6 dialogue branches consult the
##     `volthaar_released` GameState flag.

const RELEASE_WINDOW_SECONDS: float = 5.0
const RELEASE_HP_FRACTION: float = 0.05

var released: bool = false
var _release_window_open: bool = false
var _release_accum: float = 0.0


func _ready() -> void:
	boss_id = &"boss_volthaar"
	boss_music_id = &"boss_volthaar_theme"
	trinket_item_id = &"volthaar_trinket"
	shell_item_id = &"drowned_pearl"
	shell_drop_count = 5
	fragment_item_id = &"sovereign_name_fragment_6"
	pulse_item_id = &"tideglass_shard"
	phase_thresholds = [1.0, 0.6, 0.3, 0.05]
	telegraph_radius_px = 56.0
	enrage_after_seconds = 360.0
	super._ready()


func _apply_phase() -> void:
	super._apply_phase()
	if current_phase == 3 and not _release_window_open:
		_open_release_window()


func _open_release_window() -> void:
	_release_window_open = true
	EventBus.ui_toast.emit("Vol'thaar: \"I asked for the long quiet.\" — drop your weapon to release.", 5.5)
	EventBus.screen_pulse_requested.emit(0.3, 1.0)
	if AudioBus:
		AudioBus.play_sfx(&"volthaar_voice")
	# Pause attack cycler while the player decides.
	if _attack_cycler:
		_attack_cycler.stop()


func _physics_process(delta: float) -> void:
	if _release_window_open and not released:
		_release_accum += delta
		velocity = Vector2.ZERO
		move_and_slide()
		var player_holds_weapon: bool = _player_has_weapon_equipped()
		if not player_holds_weapon:
			released = true
			_resolve_release()
			return
		if _release_accum >= RELEASE_WINDOW_SECONDS:
			# Window closed — resume combat at phase 4 intensity.
			_release_window_open = false
			if _attack_cycler:
				_attack_cycler.start()
		return
	super._physics_process(delta)


func _player_has_weapon_equipped() -> bool:
	var hotbar_nodes := get_tree().get_nodes_in_group("hotbar")
	if hotbar_nodes.is_empty():
		return false
	var hotbar := hotbar_nodes[0]
	var idx: int = int(hotbar.get("selected_index"))
	var iid: StringName = Inventory.get_hotbar_item(idx)
	if iid == &"":
		return false
	var defn: ItemDef = ItemRegistry.get_def(iid)
	if defn == null:
		return false
	return defn.weapon_class != &""


func _resolve_release() -> void:
	# Vol'thaar fades into the deep; no death animation.
	EventBus.ui_toast.emit("Vol'thaar dissolves into the dark.", 4.0)
	if AudioBus:
		AudioBus.play_sfx(&"volthaar_release")
	GameState.collected_relics[&"volthaar_released"] = true
	GameState.mark_boss_defeated(boss_id)
	# Drop Vol'thaar's Promise — alt-summon item.
	var scn := load("res://scenes/items/item_drop.tscn") as PackedScene
	if scn:
		var drop := scn.instantiate() as ItemDrop
		drop.item_id = &"volthaar_promise"
		drop.count = 1
		drop.global_position = global_position
		get_tree().current_scene.add_child(drop)
		var coin := scn.instantiate() as ItemDrop
		coin.item_id = &"ancient_coin"
		coin.count = 50
		coin.global_position = global_position + Vector2(8, 0)
		get_tree().current_scene.add_child(coin)
	# Phase-4 lock-out
	if _attack_cycler:
		_attack_cycler.stop()
	queue_free()
