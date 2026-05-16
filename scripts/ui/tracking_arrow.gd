extends CanvasLayer
class_name TrackingArrow

## Phase 13.26 — Off-screen player tracking arrows. Reads Phase13Helpers
## `tracking_arrow_targets` each frame and draws colored chevrons at the
## viewport edge for each off-screen peer.

const EDGE_PAD: float = 22.0


var _arrows: Dictionary = {}     # peer_id -> Control


func _ready() -> void:
	add_to_group("tracking_arrows")
	layer = 60
	set_process(true)


func _process(_delta: float) -> void:
	if Phase13Helpers == null:
		return
	if NetSystem == null or not NetSystem.is_party_active():
		_clear()
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = vp_size * 0.5
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_clear()
		return
	var local := players[0] as Node2D
	if local == null:
		return
	var targets: Array[Dictionary] = Phase13Helpers.tracking_arrow_targets(local.global_position, half)
	# Garbage-collect arrows for peers no longer needed.
	var seen: Dictionary = {}
	for t in targets:
		seen[int(t.get("peer_id", 0))] = true
	for k in _arrows.keys():
		if not seen.has(int(k)):
			(_arrows[k] as Control).queue_free()
			_arrows.erase(k)
	# Place / update each arrow on the viewport edge.
	for t in targets:
		var peer_id: int = int(t.get("peer_id", 0))
		var dir: Vector2 = t.get("direction", Vector2.RIGHT)
		var dist: float = float(t.get("distance", 0.0))
		var prof: Dictionary = NetSystem.profile_for(peer_id)
		var pos_screen: Vector2 = half + dir * (half - Vector2.ONE * EDGE_PAD)
		pos_screen.x = clampf(pos_screen.x, EDGE_PAD, vp_size.x - EDGE_PAD)
		pos_screen.y = clampf(pos_screen.y, EDGE_PAD, vp_size.y - EDGE_PAD)
		if not _arrows.has(peer_id):
			var ctrl := Control.new()
			var dot := ColorRect.new()
			dot.size = Vector2(10, 10)
			dot.position = Vector2(-5, -5)
			dot.color = prof.get("color", Color.WHITE)
			ctrl.add_child(dot)
			var name_lbl := Label.new()
			name_lbl.text = String(prof.get("name", "P%d" % peer_id))
			name_lbl.position = Vector2(6, -6)
			ctrl.add_child(name_lbl)
			var dist_lbl := Label.new()
			dist_lbl.position = Vector2(6, 4)
			dist_lbl.add_to_group("arrow_dist_label")
			ctrl.add_child(dist_lbl)
			add_child(ctrl)
			_arrows[peer_id] = ctrl
		var node := _arrows[peer_id] as Control
		node.position = pos_screen
		for child in node.get_children():
			if child is Label and child.is_in_group("arrow_dist_label"):
				(child as Label).text = "%dpx" % int(dist)


func _clear() -> void:
	for k in _arrows.keys():
		(_arrows[k] as Control).queue_free()
	_arrows.clear()
