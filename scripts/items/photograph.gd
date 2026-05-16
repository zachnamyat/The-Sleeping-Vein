extends Node

## Phase 2.34 — mob scan / photograph. The Mote-Lens Photograph is a tool the
## player carries in the hotbar. Click to snapshot whichever mob is closest
## to the aimed cursor within `scan_radius_px`; success unlocks the bestiary
## entry without requiring a kill.
##
## Wired through player_combat._try_consume() id-dispatch: when the held item
## resolves to `photograph` the combat layer calls into Photograph.try_scan
## instead of swinging.

const SCAN_RADIUS_PX: float = 120.0
const COOLDOWN_SECONDS: float = 0.8

var _last_scan_t: float = -999.0


static var instance: Node


func _ready() -> void:
	instance = self


func try_scan(from: Vector2, toward: Vector2) -> bool:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_scan_t < COOLDOWN_SECONDS:
		return false
	# Walk all mobs+bosses; pick the one closest to the ray `from→toward`.
	var best: Node = null
	var best_score: float = INF
	var dir: Vector2 = (toward - from).normalized()
	for candidate in _scan_candidates():
		if not (candidate is Node2D):
			continue
		var node: Node2D = candidate
		var to_target: Vector2 = node.global_position - from
		var distance: float = to_target.length()
		if distance > SCAN_RADIUS_PX:
			continue
		# Reject targets behind the cursor: dot product against dir.
		if dir.length() > 0.01 and to_target.dot(dir) < 0.0:
			continue
		# Score = distance penalized by cone deviation.
		var lateral: float = max(0.001, to_target.length() - to_target.dot(dir))
		var score: float = distance + lateral * 0.5
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		EventBus.ui_toast.emit("No mob in frame.", 1.5)
		return false
	_last_scan_t = now
	_capture(best)
	return true


func _scan_candidates() -> Array:
	var result: Array = []
	result.append_array(get_tree().get_nodes_in_group("mob"))
	result.append_array(get_tree().get_nodes_in_group("boss"))
	return result


func _capture(target: Node) -> void:
	var defn: MobDef = target.get("mob_def") as MobDef
	var id: StringName
	var display: String = "mob"
	if defn:
		id = defn.id
		display = defn.display_name
	elif target.has_method("get") and target.get("boss_id") != null:
		id = target.get("boss_id")
		display = String(id)
	else:
		EventBus.ui_toast.emit("Subject too blurred. Try again.", 1.5)
		return
	var entry: StringName = StringName("bestiary_%s" % String(id))
	var already_unlocked: bool = GameState.unlocked_compendium.get(entry, false)
	if Compendium:
		Compendium.unlock(entry)
	if AudioBus:
		AudioBus.play_sfx(&"photograph_click")
	if already_unlocked:
		EventBus.ui_toast.emit("Captured %s — already known." % display, 2.0)
	else:
		EventBus.ui_toast.emit("Compendium: %s photographed." % display, 2.5)
		# Phase 2.34 — small Skill XP grant for the first photograph of each.
		EventBus.skill_xp_gained.emit(&"skill_explorer", 8)
