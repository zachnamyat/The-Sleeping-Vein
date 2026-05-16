extends Node2D
class_name PlayerNameplate

## Phase 1.23 + 13.36 + 13.49 — Player nameplate above the Walker's head.
## Includes the slot color swatch, current name, peer ID, and a death-flicker
## pulse when the local Walker dies (lore §7.10). Resonance-pulse hand-flicker
## handles the proximity-based glow inside the player_controller; this node
## owns the textual nameplate.

const FLICKER_PERIOD_SECONDS: float = 0.12

@export var peer_id: int = 1

var _label: Label
var _swatch: ColorRect
var _flickering: bool = false
var _flicker_accum: float = 0.0


func _ready() -> void:
	add_to_group("player_nameplate")
	z_index = 25
	position = Vector2(0, -28)
	_swatch = ColorRect.new()
	_swatch.size = Vector2(6, 6)
	_swatch.position = Vector2(-3, -8)
	add_child(_swatch)
	_label = Label.new()
	_label.position = Vector2(-22, 0)
	add_child(_label)
	if Phase13Helpers:
		Phase13Helpers.nameplate_visibility_changed.connect(_on_visibility_changed)
	refresh()
	if EventBus.has_signal("net_party_player_count_changed"):
		EventBus.net_party_player_count_changed.connect(_on_party_count_changed)
	if EventBus.has_signal("player_died"):
		EventBus.player_died.connect(_on_player_died)


func _on_party_count_changed(_count: int) -> void:
	refresh()


func _on_visibility_changed(active: bool) -> void:
	visible = active


func _on_player_died(p: Node) -> void:
	if p == get_parent():
		_flickering = true
		_flicker_accum = 0.0


func _process(delta: float) -> void:
	if _flickering:
		_flicker_accum += delta
		modulate.a = 0.5 + 0.5 * sin(_flicker_accum / FLICKER_PERIOD_SECONDS * TAU)
		if _flicker_accum > 2.0:
			_flickering = false
			modulate.a = 1.0


func refresh() -> void:
	if NetSystem == null:
		_swatch.color = Color.WHITE
		_label.text = String(GameState.character_name)
		visible = (Phase13Helpers.nameplate_visible if Phase13Helpers else true)
		return
	# Visibility: only show plates in multiplayer or when nameplate_visible is set.
	if Phase13Helpers and not Phase13Helpers.nameplate_visible:
		visible = false
		return
	if not NetSystem.is_party_active() and peer_id == NetSystem.local_peer_id():
		# Solo: still allow if user enabled it explicitly.
		visible = Phase13Helpers.nameplate_visible if Phase13Helpers else true
	else:
		visible = true
	var prof: Dictionary = NetSystem.profile_for(peer_id)
	_swatch.color = prof.get("color", Color.WHITE)
	_label.text = String(prof.get("name", "Walker"))
