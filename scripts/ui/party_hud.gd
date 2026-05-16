extends CanvasLayer
class_name PartyHud

## Phase 13.25 / 13.44 — Party HUD. Shows all up-to-8 players' name + HP bar +
## ping pip + connection-quality icon. Press Y to toggle visibility (also
## auto-shows whenever a remote peer is connected).

const ROW_HEIGHT: float = 18.0
const PANEL_W: float = 168.0

var _root: Panel
var _refresh_timer: Timer


func _ready() -> void:
	add_to_group("party_hud")
	layer = 50
	_root = Panel.new()
	_root.size = Vector2(PANEL_W, ROW_HEIGHT * 8 + 8)
	_root.anchor_left = 1.0
	_root.anchor_top = 0.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 0.0
	_root.offset_left = -PANEL_W - 12.0
	_root.offset_top = 12.0
	_root.offset_right = -12.0
	_root.offset_bottom = 12.0 + ROW_HEIGHT * 8 + 8
	add_child(_root)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)
	_refresh()
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("party_ui"):
		visible = not visible


func _refresh() -> void:
	# Auto-show whenever multiplayer is live so the player can't miss it.
	if NetSystem and NetSystem.is_party_active():
		visible = true
	for c in _root.get_children():
		c.queue_free()
	if Phase13Helpers == null:
		return
	var entries: Array[Dictionary] = Phase13Helpers.party_hud_entries()
	var y: float = 4.0
	for entry in entries:
		var row := HBoxContainer.new()
		row.position = Vector2(4, y)
		row.size = Vector2(PANEL_W - 8, ROW_HEIGHT - 2)
		_root.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = entry.get("color", Color.WHITE)
		swatch.custom_minimum_size = Vector2(8, 8)
		row.add_child(swatch)
		var name_label := Label.new()
		name_label.text = String(entry.get("name", "Walker"))
		name_label.custom_minimum_size = Vector2(72, 12)
		row.add_child(name_label)
		var hp_bar := ProgressBar.new()
		hp_bar.min_value = 0.0
		hp_bar.max_value = 1.0
		hp_bar.value = float(entry.get("hp_fraction", 1.0))
		hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(56, 8)
		row.add_child(hp_bar)
		var ping := Label.new()
		ping.text = "%dms" % int(entry.get("ping_ms", 0))
		ping.custom_minimum_size = Vector2(28, 12)
		row.add_child(ping)
		if bool(entry.get("awaiting_respawn", false)):
			var ghost := Label.new()
			ghost.text = "✦"
			ghost.modulate = Color(0.8, 0.8, 1.0, 1.0)
			row.add_child(ghost)
		y += ROW_HEIGHT
