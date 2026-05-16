extends CanvasLayer
class_name ManifestoReaderPanel

## Phase 12.14 — illuminated-wall-text reader UI. Opens when the Walker passes
## a Diadem manifesto plate. Shows the inscription in gold script. Closes on
## Esc / movement input. Tracks which manifestos have been read; surfaces a
## Tab navigation through previously-read manifestos (read-only).

@onready var root: Panel = $Root
@onready var title_label: Label = $Root/Title
@onready var body_label: RichTextLabel = $Root/Body
@onready var next_button: Button = $Root/Footer/Next
@onready var prev_button: Button = $Root/Footer/Prev
@onready var close_button: Button = $Root/Footer/Close
@onready var progress_label: Label = $Root/Footer/Progress

var _current_index: int = -1


func _ready() -> void:
	add_to_group("manifesto_reader_ui")
	visible = false
	next_button.pressed.connect(_on_next)
	prev_button.pressed.connect(_on_prev)
	close_button.pressed.connect(close)


func open_with(index: int, text: String) -> void:
	_current_index = index
	title_label.text = "Manifesto %d / 8" % (index + 1)
	body_label.text = "[i]" + text + "[/i]"
	progress_label.text = "Read: %d / 8" % _read_count()
	visible = true
	_update_nav_buttons()


func close() -> void:
	visible = false


func _on_next() -> void:
	# Navigate to the next manifesto the player HAS read (read-only view).
	if Phase12Helpers == null:
		return
	var idx: int = _current_index + 1
	while idx < 8:
		if Phase12Helpers.manifestos_read.get(idx, false):
			_show_inscription(idx)
			return
		idx += 1


func _on_prev() -> void:
	if Phase12Helpers == null:
		return
	var idx: int = _current_index - 1
	while idx >= 0:
		if Phase12Helpers.manifestos_read.get(idx, false):
			_show_inscription(idx)
			return
		idx -= 1


func _show_inscription(idx: int) -> void:
	var texts: Array = preload("res://scripts/structures/diadem_manifesto.gd").MANIFESTO_TEXTS
	var text: String = texts[idx]
	if idx == texts.size() - 1 and Phase12Helpers and Phase12Helpers.bearer_child_tablet_read:
		text += "\n\n\"Forgive me. — Joren-of-the-Lattice\""
	open_with(idx, text)


func _update_nav_buttons() -> void:
	if Phase12Helpers == null:
		prev_button.disabled = true
		next_button.disabled = true
		return
	var read_indices: Array = []
	for i in range(8):
		if Phase12Helpers.manifestos_read.get(i, false):
			read_indices.append(i)
	prev_button.disabled = read_indices.is_empty() or _current_index <= read_indices.min()
	next_button.disabled = read_indices.is_empty() or _current_index >= read_indices.max()


func _read_count() -> int:
	if Phase12Helpers == null:
		return 0
	return Phase12Helpers.manifestos_read_count()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
