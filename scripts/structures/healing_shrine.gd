extends Area2D
class_name HealingShrine

## Phase 5.22 — placeable healing tile. While the player stands on it they
## regenerate HP at a configurable rate. Each charge tick consumes one of the
## shrine's `charges_remaining`; once depleted it goes dormant until restocked
## by `glow_tube` interaction (placeholder until item-cost UI lands).

@export var heal_per_tick: int = 3
@export var tick_seconds: float = 0.6
@export var charges_remaining: int = 30
@export var restock_item_id: StringName = &"glow_tube"
@export var restock_count: int = 1
@export var restock_charges: int = 30

var _player_on_tile: Node = null
var _accum: float = 0.0
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("healing_shrine")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	set_process(true)


func _process(delta: float) -> void:
	if _player_on_tile == null:
		return
	if charges_remaining <= 0:
		return
	_accum += delta
	if _accum < tick_seconds:
		return
	_accum = 0.0
	var hc := _player_on_tile.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.is_dead():
		return
	if hc.current_health >= hc.max_health:
		return
	hc.heal(heal_per_tick, self)
	charges_remaining -= 1
	if charges_remaining <= 0:
		modulate = Color(0.5, 0.5, 0.55, 0.6)
		EventBus.ui_toast.emit("The shrine's thread has unraveled.", 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or charges_remaining > 0:
		return
	if event.is_action_pressed("interact"):
		_try_restock()


func _try_restock() -> void:
	if Inventory.count_of(restock_item_id) < restock_count:
		EventBus.ui_toast.emit("Restock needs %d %s." % [restock_count, String(restock_item_id)], 2.0)
		return
	Inventory.try_remove(restock_item_id, restock_count)
	charges_remaining = restock_charges
	modulate = Color.WHITE
	EventBus.ui_toast.emit("Thread restored. Shrine ready.", 2.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_tile = body
		_player_in_range = true
		if charges_remaining <= 0:
			EventBus.ui_toast.emit("[E] Restock shrine (%d %s)" % [restock_count, String(restock_item_id)], 1.5)


func _on_body_exited(body: Node) -> void:
	if body == _player_on_tile:
		_player_on_tile = null
		_player_in_range = false
		_accum = 0.0
