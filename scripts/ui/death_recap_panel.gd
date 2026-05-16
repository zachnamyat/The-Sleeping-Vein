extends CanvasLayer
class_name DeathRecapPanel

## Ticket 2.26 — Death recap UI. Surfaces last damage source + total run
## stats (playtime / depth / sliver toll) when the player dies.

var _root: Control
var _content: VBoxContainer


func _ready() -> void:
	layer = 25
	add_to_group("death_recap_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)


func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -200
	_root.offset_right = 200
	_root.offset_top = -120
	_root.offset_bottom = 120
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.94)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)
	var t := Label.new()
	t.text = "you have fallen"
	t.offset_left = 12
	t.offset_top = 8
	t.add_theme_color_override("font_color", Color(0.85, 0.30, 0.20))
	_root.add_child(t)
	_content = VBoxContainer.new()
	_content.offset_left = 12
	_content.offset_top = 36
	_content.offset_right = -12
	_content.offset_bottom = -12
	_content.anchor_right = 1
	_content.anchor_bottom = 1
	_content.add_theme_constant_override("separation", 2)
	_root.add_child(_content)


func _on_player_died(_p: Node) -> void:
	call_deferred("_show")


func _show() -> void:
	for c in _content.get_children():
		c.queue_free()
	visible = true
	if Phase15Helpers == null:
		return
	var src: String = Phase15Helpers.last_damage_source
	if src == "":
		src = "the cold of the deep"
	_add_row("Last touched by", src)
	_add_row("Slivers remaining", str(GameState.aphelion_slivers_remaining))
	var pt: int = Phase15Helpers.current_run_playtime_seconds
	_add_row("Run playtime", "%02d:%02d:%02d" % [pt / 3600, (pt / 60) % 60, pt % 60])
	_add_row("Deaths this run", str(Phase15Helpers.current_run_deaths))
	_add_row("Combo high", str(Phase15Helpers.combo_max))


func _add_row(label: String, value: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(160, 0)
	l.modulate = Color(0.9, 0.86, 0.7)
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.modulate = Color(0.97, 0.85, 0.5)
	h.add_child(v)
	_content.add_child(h)


func _on_player_respawned(_p: Node, _slivers: int) -> void:
	visible = false
