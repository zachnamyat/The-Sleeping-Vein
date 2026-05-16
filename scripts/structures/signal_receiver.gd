extends Node2D
class_name SignalReceiver

## Phase 14.20 / 14.36 — Wireless signal receiver. Listens for transmitters on
## the same `frequency` and writes their pulses to `output_wire`.

@export var frequency: int = 0
@export var output_wire: int = 0

var _rx_id: int = -1


func _ready() -> void:
	add_to_group("signal_receiver")
	add_to_group("demolishable")
	_rx_id = Phase14Helpers.register_receiver(frequency, global_position, output_wire)


func get_refund_meta() -> Dictionary:
	return { "item_id": "signal_receiver_placeable", "count": 1 }
