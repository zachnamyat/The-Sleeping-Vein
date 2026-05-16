extends Area2D
class_name Door

## Phase 9.14 / 9.38 — Player-built door.
##   - Auto-opens when the player approaches (or anything in mask 2).
##   - Closes again after 1s without contact.
##   - Tier upgrade path: wood -> metal -> reinforced. Higher tiers block more
##     mob types (basic mobs blocked by all; bosses only blocked by reinforced).
##   - Belongs to group "door" so Housing.validate_room can count it.

@export var tier: int = 1  ## 1 = wood, 2 = metal, 3 = reinforced
@export var auto_open: bool = true
@export var open_tex: Texture2D
@export var closed_tex: Texture2D
@export var open_radius: float = 24.0

var _is_open: bool = false
var _close_timer: float = 0.0
const CLOSE_DELAY: float = 1.0


func _ready() -> void:
	add_to_group("door")
	add_to_group("door_tier_%d" % tier)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 8  # walls layer for path-cost integration
	collision_mask = 2
	_apply_state()


func _process(delta: float) -> void:
	if _is_open and _close_timer > 0.0:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_close()


func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	_is_open = true
	$CollisionShape2D.disabled = true
	_apply_state()
	if AudioBus and AudioBus.has_method("play_sfx"):
		AudioBus.play_sfx(&"door_open")


func _close() -> void:
	_is_open = false
	$CollisionShape2D.disabled = false
	_apply_state()
	if AudioBus and AudioBus.has_method("play_sfx"):
		AudioBus.play_sfx(&"door_close")


func _apply_state() -> void:
	if $Sprite2D:
		# Tint when open as a visual cue when both textures are the same.
		($Sprite2D as Sprite2D).modulate = Color(1, 1, 1, 0.6) if _is_open else Color(1, 1, 1, 1)
		if _is_open and open_tex:
			($Sprite2D as Sprite2D).texture = open_tex
		elif not _is_open and closed_tex:
			($Sprite2D as Sprite2D).texture = closed_tex


func _on_body_entered(body: Node) -> void:
	if not auto_open:
		return
	if body.is_in_group("player"):
		_open()
		_close_timer = CLOSE_DELAY
		return
	# Mob filtering by tier: tier 2 stops weak mobs, tier 3 stops all non-bosses.
	if body.is_in_group("mob"):
		if tier == 1 and body.has_method("is_door_blocker_weak"):
			return  # weak mobs already blocked
		if tier >= 2:
			# Don't auto-open for mobs at tier 2+.
			return
		_open()
		_close_timer = CLOSE_DELAY


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and _is_open:
		_close_timer = CLOSE_DELAY
