extends Area2D
class_name LoomTwin

## Phase 12.7 — The Resonance Loom's Twin.
##
## A second, broken Resonance Loom in the Final Spiral. Pre-Inversion
## construction. On first interaction:
##   - Phase12Helpers.discover_loom_twin() fires
##   - GameState.collected_relics["loom_twin"] = true
##   - Lore toast: foreshadowing the Become ending (Loom was built; Walker is
##     the builder's tool)
##
## Visual: the same sprite as the canonical Resonance Loom, tinted darker +
## with a shader-cracked overlay (modulate alpha 0.7, color shift to greyer).

@export var discovery_text: String = "Pre-Inversion construction. The Loom is the elided figure's. So are you."

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("loom_twin")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_trigger_discovery()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _trigger_discovery() -> void:
	if Phase12Helpers and not Phase12Helpers.loom_twin_discovered:
		Phase12Helpers.discover_loom_twin()
		EventBus.ui_toast.emit(discovery_text, 6.0)
		EventBus.letterbox_requested.emit(true, 0.5)
		# Quickly fade letterbox back out so it doesn't lock the player.
		var t := create_tween()
		t.tween_interval(3.0)
		t.tween_callback(func() -> void: EventBus.letterbox_requested.emit(false, 0.6))
