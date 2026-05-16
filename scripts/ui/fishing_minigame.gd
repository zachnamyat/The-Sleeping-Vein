extends CanvasLayer
class_name FishingMinigame

## Phase 8.10 — Minigame HUD overlay. Shows three stages of the fishing cycle
## (CAST waiting → HOOK window → REEL bar) and disappears between sessions.
## Visuals only — input + state live in FishingSystem.

@onready var root: Panel = $Root
@onready var label: Label = $Root/Stage
@onready var bar: ProgressBar = $Root/Bar


func _ready() -> void:
	add_to_group("fishing_minigame")
	visible = false
	if FishingSystem:
		FishingSystem.cast_started.connect(_on_cast_started)
		FishingSystem.bite_started.connect(_on_bite_started)
		FishingSystem.reel_started.connect(_on_reel_started)
		FishingSystem.cast_resolved.connect(_on_resolve)
		FishingSystem.cast_failed.connect(_on_resolve_failed)
		FishingSystem.minigame_state.connect(_on_state)


func _on_cast_started(_seconds: float) -> void:
	visible = true
	label.text = "Cast — wait for bite"
	bar.value = 0.0
	bar.modulate = Color(0.8, 0.8, 0.85)


func _on_bite_started(_window: float) -> void:
	label.text = "BITE! Click to hook"
	bar.modulate = Color(1.0, 0.6, 0.2)


func _on_reel_started(_target: float) -> void:
	label.text = "Reel — hold inside the bar"
	bar.modulate = Color(0.5, 0.9, 0.4)


func _on_state(_stage: int, t01: float) -> void:
	bar.value = clampf(t01 * 100.0, 0.0, 100.0)


func _on_resolve(_caught: StringName) -> void:
	label.text = "Caught!"
	bar.modulate = Color(0.5, 0.9, 0.4)
	await get_tree().create_timer(0.6).timeout
	visible = false


func _on_resolve_failed(reason: String) -> void:
	label.text = reason
	bar.modulate = Color(0.85, 0.4, 0.3)
	await get_tree().create_timer(0.6).timeout
	visible = false
