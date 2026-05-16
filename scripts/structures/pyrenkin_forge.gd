extends Area2D
class_name PyrenkinForge

## Phase 11.8 — A cold Pyrenkin forge. Three of these scatter across the
## Emberforge biome. The player can relight one if they carry a fuel-pellet;
## relighting all three triggers the Pyrenkin Compact NPC arrival hook.

@export var forge_index: int = 0      ## 0..2

var _player_in_range: bool = false
var _relit: bool = false


func _ready() -> void:
	add_to_group("pyrenkin_forge")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	_refresh_visual()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _relit:
		return
	if event.is_action_pressed("interact"):
		if Inventory.count_of(&"fuel_pellet") <= 0:
			EventBus.ui_toast.emit("This forge is cold. Bring a Pyrenkin fuel-pellet.", 2.5)
			return
		Inventory.try_remove(&"fuel_pellet", 1)
		_relit = true
		_refresh_visual()
		if Phase11Helpers:
			Phase11Helpers.relight_pyrenkin_forge(forge_index)


func _refresh_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if _relit else Color(0.45, 0.45, 0.50, 1.0)


func dump_state() -> Dictionary:
	return { "forge_index": forge_index, "relit": _relit }


func restore_state(d: Dictionary) -> void:
	forge_index = int(d.get("forge_index", forge_index))
	_relit = bool(d.get("relit", false))
	_refresh_visual()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _relit:
			EventBus.ui_toast.emit("Forge %d burns steady." % (forge_index + 1), 1.5)
		else:
			EventBus.ui_toast.emit("[E] Relight cold forge %d." % (forge_index + 1), 2.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
