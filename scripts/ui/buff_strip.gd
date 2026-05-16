extends Control
class_name BuffStrip

## Player's active buff/debuff strip below the mana bar. Subscribes to the
## player's StatusEffects component once the player spawns, and to the global
## Buffs autoload (food / shrine buffs).
##
## Phase 6.13 — strip composition: each entry is a small icon swatch + remaining
## seconds in the bottom-right corner. Status icons fall back to a coloured tile
## when no PNG is found so the slot stays visible until art lands.

@onready var icons_root: HBoxContainer = $Icons

const REFRESH: float = 0.25
const TILE_SIZE: int = 14

const ICON_TEXTURES: Dictionary = {
	&"burn":      "res://assets/sprites/vfx/status_burn.png",
	&"poison":    "res://assets/sprites/vfx/status_poison.png",
	&"cold":      "res://assets/sprites/vfx/status_cold.png",
	&"freeze":    "res://assets/sprites/vfx/status_freeze.png",
	&"stun":      "res://assets/sprites/vfx/status_stun.png",
	&"slow":      "res://assets/sprites/vfx/status_slow.png",
	&"bleed":     "res://assets/sprites/vfx/status_bleed.png",
	&"confusion": "res://assets/sprites/vfx/status_confusion.png",
	&"shock":     "res://assets/sprites/vfx/status_shock.png",
}

const FALLBACK_COLORS: Dictionary = {
	&"burn":      Color(1.00, 0.55, 0.18),
	&"poison":    Color(0.55, 0.95, 0.35),
	&"cold":      Color(0.55, 0.85, 1.00),
	&"freeze":    Color(0.40, 0.75, 1.00),
	&"stun":      Color(1.00, 0.92, 0.45),
	&"slow":      Color(0.65, 0.65, 0.85),
	&"bleed":     Color(0.85, 0.18, 0.22),
	&"confusion": Color(0.85, 0.55, 1.00),
	&"shock":     Color(0.92, 0.95, 1.00),
}

var _icons: Dictionary = {}    ## id -> {root: Control, label: Label, kind: "status"|"buff"}
var _player_status: StatusEffects
var _accum: float = 0.0


func _ready() -> void:
	EventBus.player_spawned.connect(_on_player_spawned)
	if Buffs:
		Buffs.buff_applied.connect(_on_buff_applied)
		Buffs.buff_expired.connect(_on_buff_expired)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < REFRESH:
		return
	_accum = 0.0
	# Refresh remaining-seconds labels on existing entries.
	for id in _icons.keys():
		var entry = _icons[id]
		var lbl: Label = entry.get("label")
		if lbl == null:
			continue
		var remain: float = 0.0
		if entry.get("kind", "") == "status" and _player_status:
			remain = _player_status.remaining(StringName(id))
		else:
			remain = Buffs.remaining(StringName(id)) if Buffs else 0.0
		lbl.text = "%ds" % maxi(0, int(round(remain)))


func _on_player_spawned(player: Node) -> void:
	_player_status = player.get_node_or_null("StatusEffects") as StatusEffects
	if _player_status:
		_player_status.effect_applied.connect(_on_status_applied)
		_player_status.effect_expired.connect(_on_status_expired)


func _on_status_applied(effect_id: StringName, _duration: float) -> void:
	_add_icon(effect_id, "status")


func _on_status_expired(effect_id: StringName) -> void:
	_remove_icon(effect_id)


func _on_buff_applied(buff_id: StringName, _duration: float) -> void:
	_add_icon(buff_id, "buff")


func _on_buff_expired(buff_id: StringName) -> void:
	_remove_icon(buff_id)


func _add_icon(id: StringName, kind: String) -> void:
	if _icons.has(id):
		return
	if icons_root == null:
		return
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 8)
	var hb := VBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(hb)
	# Icon (or fallback color rect).
	var tex_path: String = ICON_TEXTURES.get(id, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var icon := TextureRect.new()
		icon.texture = load(tex_path)
		icon.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hb.add_child(icon)
	else:
		var rect := ColorRect.new()
		rect.color = FALLBACK_COLORS.get(id, Color(0.85, 0.85, 0.85))
		rect.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		hb.add_child(rect)
	# Time-remaining label.
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.text = ""
	hb.add_child(lbl)
	icons_root.add_child(root)
	_icons[id] = { "root": root, "label": lbl, "kind": kind }


func _remove_icon(id: StringName) -> void:
	if not _icons.has(id):
		return
	var entry = _icons[id]
	if entry.get("root"):
		entry["root"].queue_free()
	_icons.erase(id)
