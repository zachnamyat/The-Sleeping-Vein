extends Area2D
class_name DiademManifesto

## Phase 12.6 + 12.14 + 12.23 + 12.36 — wall manifesto plate in the Final
## Spiral descent corridor. Eight inscriptions in total (indices 0..7).
## Reading the last one (index 7) is signed in Joren-of-the-Lattice (12.23
## reveals it pre-Diadem; 12.36 reveals the full name when 12.32 is done).
##
## On proximity, opens the ManifestoReaderPanel (12.14). Phase12Helpers
## records read-state so a manifesto is dimmer if already seen.

const MANIFESTO_TEXTS: Array = [
	"I. The light is not a sun. It is a hand cupping the world. A hand can let go.",
	"II. They tell you the dark is hostile. I have walked the dark. It is only quieter.",
	"III. The Aphelion does not love you. It cannot. It is a wound that learned to glow.",
	"IV. Every Walker is a delegated apology. I am not sorry. I am decided.",
	"V. The strata are catacombs. Stop dressing the bones in your hope.",
	"VI. You have read the prior plates and felt the pull. Good. Pull harder.",
	"VII. The seal will break itself, eventually. Better us than entropy.",
	"VIII. — Joren-of-the-Lattice. (Once a child. Once afraid. Now: ready.)",
]

@export var manifesto_index: int = 0

var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("diadem_manifesto")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		open_reader()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func open_reader() -> void:
	if manifesto_index < 0 or manifesto_index >= MANIFESTO_TEXTS.size():
		return
	var text: String = MANIFESTO_TEXTS[manifesto_index]
	# 12.36 — final manifesto signed name reveal.
	if manifesto_index == MANIFESTO_TEXTS.size() - 1 and Phase12Helpers and Phase12Helpers.bearer_child_tablet_read:
		text += "\n\n\"Forgive me. — Joren-of-the-Lattice\""
	# Open the reader UI if present, else fall back to a toast.
	var readers := get_tree().get_nodes_in_group("manifesto_reader_ui")
	if readers.size() > 0 and readers[0].has_method("open_with"):
		readers[0].open_with(manifesto_index, text)
	else:
		EventBus.ui_toast.emit(text, 6.0)
	if Phase12Helpers:
		Phase12Helpers.mark_manifesto_read(manifesto_index)


func dump_state() -> Dictionary:
	return {"index": manifesto_index}
