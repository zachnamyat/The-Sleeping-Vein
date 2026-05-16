extends Node

## Phase 5.15 — first-time onboarding director. Surfaces a small queue of
## skippable hint toasts triggered by gameplay milestones. Each hint fires at
## most once per save (state on GameState.tutorial_seen).
##
## Hints are tagged on EventBus signals so we don't poll. Skippable from the
## pause-menu / settings panel (when wired) by setting Settings.set_value
## "tutorial_enabled" to false.

const HINTS: Dictionary = {
	&"first_step": {
		"trigger": &"player_spawned",
		"text": "WASD to walk. The Loom behind you is your anchor.",
	},
	&"first_mine": {
		"trigger": &"first_tile_mined",
		"text": "Equipped tools mine matching tiles. Pickaxe first.",
	},
	&"first_kill": {
		"trigger": &"entity_killed",
		"text": "Drops glow. Walk over them. Each kill teaches a skill.",
	},
	&"first_recipe": {
		"trigger": &"recipe_unlocked",
		"text": "Open crafting with C. Some recipes need a workbench.",
	},
	&"first_boss_engaged": {
		"trigger": &"boss_engaged",
		"text": "Boss music plays. The gate seals — fight through it.",
	},
	&"first_relic": {
		"trigger": &"sovereign_defeated",
		"text": "Insert the relic into the Loom to unlock the next stratum.",
	},
}


var _seen: Dictionary = {}


func _ready() -> void:
	if Settings and Settings.get_value("tutorial_seen", null) is Dictionary:
		_seen = Settings.get_value("tutorial_seen", {})
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.recipe_unlocked.connect(_on_recipe_unlocked)
	EventBus.boss_engaged.connect(_on_boss_engaged)
	EventBus.sovereign_defeated.connect(_on_sovereign_defeated)


func _tutorial_enabled() -> bool:
	if Settings == null:
		return true
	var v: Variant = Settings.get_value("tutorial_enabled", true)
	if v is bool:
		return v
	return true


func _maybe_fire(key: StringName) -> void:
	if not _tutorial_enabled():
		return
	if _seen.get(key, false):
		return
	var hint: Dictionary = HINTS.get(key, {})
	if hint.is_empty():
		return
	_seen[key] = true
	if Settings:
		Settings.set_value("tutorial_seen", _seen)
	EventBus.ui_toast.emit("Tip: %s" % hint["text"], 5.0)


func _on_player_spawned(_p: Node) -> void:
	_maybe_fire(&"first_step")


func _on_entity_killed(_e: Node, _killer: Node) -> void:
	_maybe_fire(&"first_kill")


func _on_recipe_unlocked(_r: StringName) -> void:
	_maybe_fire(&"first_recipe")


func _on_boss_engaged(_b: StringName) -> void:
	_maybe_fire(&"first_boss_engaged")


func _on_sovereign_defeated(_b: StringName, _f: StringName) -> void:
	_maybe_fire(&"first_relic")


## Phase 5.40 — opening-sequence hooks this to manually emit a hint that
## isn't tied to a normal signal (the world clock's first beat).
func fire_named(key: StringName) -> void:
	_maybe_fire(key)


func reset_tutorial() -> void:
	_seen.clear()
	if Settings:
		Settings.set_value("tutorial_seen", _seen)
