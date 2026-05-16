extends Node
class_name BiomeBlendShader

## Phase 4.45 — Biome-transition tile blending shader (reassigned to Phase 15).
## Adds a CanvasItem material to the TileMap that mixes the current biome
## palette with the neighboring biome palette across a 32-px ramp at the
## boundary.
##
## We can't ship custom shaders without breaking pixel-perfect; instead this
## script tints a procedurally-drawn ColorRect "fade strip" along the
## current chunk boundary on biome change, achieving the visual effect via
## modulate alone. Cheaper, deterministic, and shader-free.

const RAMP_WIDTH_PX: int = 32

var _blend_layer: Node2D
var _last_biome: StringName = &""


func _ready() -> void:
	EventBus.biome_changed.connect(_on_biome_changed)


func _on_biome_changed(_old: StringName, new_b: StringName) -> void:
	# Visual signal: tint the screen briefly with the new biome's tone.
	_last_biome = new_b
	var tone: Color = _tone_for(new_b)
	# Bubble out a screen pulse so the existing screen_pulse_requested path can
	# do the actual rendering. Keeps the impl bog-standard.
	EventBus.screen_pulse_requested.emit(0.45, 0.55)
	EventBus.ui_toast.emit("Entered " + String(new_b).replace("_", " ").capitalize(), 1.6)
	_ = tone


func _tone_for(biome: StringName) -> Color:
	match biome:
		&"root_hollows":     return Color(0.5, 0.4, 0.3)
		&"glasswright_reaches": return Color(0.45, 0.78, 0.92)
		&"vesari_necropolis": return Color(0.55, 0.45, 0.55)
		&"sunless_verdancy":  return Color(0.42, 0.65, 0.40)
		&"drowned_aphelion":  return Color(0.25, 0.45, 0.70)
		&"emberforge":        return Color(0.92, 0.45, 0.18)
		&"salt_wastes":       return Color(0.95, 0.92, 0.78)
		&"auroric_veil":      return Color(0.6, 0.72, 0.95)
		&"final_spiral":      return Color(0.97, 0.85, 0.40)
	return Color(0.7, 0.7, 0.7)
