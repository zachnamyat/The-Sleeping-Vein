extends Control
class_name SaveSlotPanel

## Phase 1 ticket 1.19. Lists save slots under user://saves/ and lets the user
## load or delete each. Used from the title screen. Multi-slot save layer.

var list_root: VBoxContainer
var status_label: Label
var back_btn: Button


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.offset_left = -140.0
	col.offset_right = 140.0
	col.offset_top = 28.0
	col.offset_bottom = 240.0
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	var title := Label.new()
	title.text = "Load Save"
	title.modulate = Color(0.97, 0.85, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 140)
	col.add_child(scroll)
	list_root = VBoxContainer.new()
	list_root.add_theme_constant_override("separation", 2)
	scroll.add_child(list_root)

	status_label = Label.new()
	status_label.modulate = Color(0.85, 0.75, 0.5)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status_label)

	back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(close)
	col.add_child(back_btn)


func open() -> void:
	_rebuild()
	visible = true
	UIAudio.play_panel_open()
	UIAudio.wire_button_sfx(self)


func close() -> void:
	visible = false
	UIAudio.play_panel_close()


func _rebuild() -> void:
	for child in list_root.get_children():
		child.queue_free()
	var slots := _discover_slots()
	if slots.is_empty():
		var empty := Label.new()
		empty.text = "(no saves yet)"
		empty.modulate = Color(0.5, 0.45, 0.35)
		list_root.add_child(empty)
		return
	for slot in slots:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var lbl := Label.new()
		lbl.text = "%s — %s" % [slot, _read_slot_summary(slot)]
		lbl.custom_minimum_size = Vector2(160, 16)
		row.add_child(lbl)
		var load_b := Button.new()
		load_b.text = "Load"
		load_b.pressed.connect(_on_load.bind(slot))
		row.add_child(load_b)
		var del_b := Button.new()
		del_b.text = "Delete"
		del_b.pressed.connect(_on_delete.bind(slot))
		row.add_child(del_b)
		list_root.add_child(row)


func _discover_slots() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("user://saves/")
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _read_slot_summary(slot: String) -> String:
	var meta_path := "user://saves/%s/meta.json" % slot
	if not FileAccess.file_exists(meta_path):
		return "?"
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return "?"
	var txt := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(txt) != OK:
		return "?"
	var data: Dictionary = json.data
	return "v%s · %s" % [str(data.get("save_version", "")), str(data.get("saved_at", ""))]


func _on_load(slot: String) -> void:
	var err: int = SaveSystem.load_from_slot(slot)
	if err != OK:
		status_label.text = "Load failed: %s" % error_string(err)
		return
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")


func _on_delete(slot: String) -> void:
	var dir_path := "user://saves/%s" % slot
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in ["meta.json", "state.json"]:
		dir.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))
	_rebuild()
