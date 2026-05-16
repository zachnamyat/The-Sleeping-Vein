extends Node2D
class_name WirelessRelay

## Phase 14.36 — Combined transmit + receive relay on a single hex tile.
## Forwards any pulse on its input_wire to a frequency, AND any pulse it
## receives on that frequency to its output_wire. Useful for cross-base bridge.

@export var frequency: int = 1
@export var input_wire: int = 0
@export var output_wire: int = 0
@export var range_pixels: float = 384.0

var _tx_id: int = -1
var _rx_id: int = -1
var _last_input: bool = false


func _ready() -> void:
	add_to_group("wireless_relay")
	add_to_group("demolishable")
	_tx_id = Phase14Helpers.register_transmitter(frequency, global_position, range_pixels)
	_rx_id = Phase14Helpers.register_receiver(frequency, global_position, output_wire)
	if Phase14Helpers:
		Phase14Helpers.wire_signal_changed.connect(_on_signal_changed)


func _on_signal_changed(wire: int, value: bool) -> void:
	if wire != input_wire:
		return
	if value and not _last_input:
		Phase14Helpers.pulse_transmitter(_tx_id)
	_last_input = value


func get_refund_meta() -> Dictionary:
	return { "item_id": "wireless_relay_placeable", "count": 1 }
