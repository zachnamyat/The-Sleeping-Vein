extends Node2D
class_name Sapling

## Phase 8.33 — A planted sapling. Grows for grow_beats Aphelion Beats, then
## replaces itself with a `scenes/world/tree.tscn` instance.

@export var grow_beats: int = 24
var _beats: int = 0


func _ready() -> void:
	add_to_group("sapling")
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beats += 1
	# Visual ramp: scale up as we age.
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var t: float = float(_beats) / float(maxi(1, grow_beats))
		sprite.scale = Vector2(0.4 + 0.6 * t, 0.4 + 0.6 * t)
	if _beats < grow_beats:
		return
	_grow_into_tree()


func _grow_into_tree() -> void:
	var scn := load("res://scenes/world/tree.tscn") as PackedScene
	if scn == null:
		queue_free()
		return
	var tree_node := scn.instantiate() as Node2D
	if tree_node:
		tree_node.global_position = global_position
		var tree := get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(tree_node)
	queue_free()
