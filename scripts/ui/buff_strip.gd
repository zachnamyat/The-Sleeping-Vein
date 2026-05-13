extends Control
class_name BuffStrip

## Player's active buff/debuff strip below the mana bar. Subscribes to the player's
## StatusEffects component once the player spawns.

@onready var icons_root: HBoxContainer = $Icons

const ICON_TEXTURES: Dictionary = {
	&"burn": "res://assets/sprites/vfx/status_burn.png",
	&"poison": "res://assets/sprites/vfx/status_poison.png",
	&"cold": "res://assets/sprites/vfx/status_cold.png",
	&"freeze": "res://assets/sprites/vfx/status_freeze.png",
	&"stun": "res://assets/sprites/vfx/status_stun.png",
}

var _icons: Dictionary = {}
var _player_status: StatusEffects


func _ready() -> void:
	EventBus.player_spawned.connect(_on_player_spawned)


func _on_player_spawned(player: Node) -> void:
	_player_status = player.get_node_or_null("StatusEffects") as StatusEffects
	if _player_status:
		_player_status.effect_applied.connect(_on_effect_applied)
		_player_status.effect_expired.connect(_on_effect_expired)


func _on_effect_applied(effect_id: StringName, _duration: float) -> void:
	if _icons.has(effect_id):
		return
	var tex_path: String = ICON_TEXTURES.get(effect_id, "")
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		return
	var icon := TextureRect.new()
	icon.texture = load(tex_path)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icons_root.add_child(icon)
	_icons[effect_id] = icon


func _on_effect_expired(effect_id: StringName) -> void:
	if _icons.has(effect_id):
		_icons[effect_id].queue_free()
		_icons.erase(effect_id)
