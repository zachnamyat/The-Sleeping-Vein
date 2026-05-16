extends Node2D
class_name CrystalSprig

## Phase 8.34 — Crystal propagation (Glasswright). After grow_beats Aphelion
## Beats turns into a full crystal_cluster, which the player can mine for
## Clearstone. Crystal sprigs only thrive in Glasswright Reaches; placed
## elsewhere they grow much slower (3× duration).

@export var grow_beats: int = 32

var _beats: int = 0


func _ready() -> void:
	add_to_group("crystal_sprig")
	if AudioBus:
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	_beats += 1
	var ratio: float = float(_beats) / float(maxi(1, _adjusted_grow_beats()))
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.scale = Vector2(0.4 + 0.6 * ratio, 0.4 + 0.6 * ratio)
		sprite.modulate = Color(0.8, 0.9, 1.0).lerp(Color(0.6, 0.95, 1.0), ratio)
	if _beats >= _adjusted_grow_beats():
		_grow_into_cluster()


func _adjusted_grow_beats() -> int:
	# Glasswright is the native biome — 1×. Elsewhere we triple the duration.
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return grow_beats
	var wg := tree.current_scene.get_node_or_null("WorldGen")
	if wg and wg.has_method("biome_at"):
		var b: BiomeDef = wg.biome_at(global_position) as BiomeDef
		if b and b.id == &"glasswright_reaches":
			return grow_beats
	return grow_beats * 3


func _grow_into_cluster() -> void:
	var scn := load("res://scenes/structures/crystal_cluster.tscn") as PackedScene
	if scn == null:
		queue_free()
		return
	var cluster := scn.instantiate() as Node2D
	if cluster:
		cluster.global_position = global_position
		var tree := get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(cluster)
	queue_free()
