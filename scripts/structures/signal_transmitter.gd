extends Node2D
class_name SignalTransmitter

## Phase 14.20 / 14.36 — Wireless signal transmitter. Pulses every receiver on
## the same frequency within range. Drives a "RF" tx_id that the receiver
## resolves through Phase14Helpers.pulse_transmitter.

@export var frequency: int = 0
@export var input_wire: int = 0
@export var range_pixels: float = 256.0

var _tx_id: int = -1
var _last_input: bool = false


func _ready() -> void:
	add_to_group("signal_transmitter")
	add_to_group("demolishable")
	_tx_id = Phase14Helpers.register_transmitter(frequency, global_position, range_pixels)
	if Phase14Helpers:
		Phase14Helpers.wire_signal_changed.connect(_on_signal_changed)


func _on_signal_changed(wire: int, value: bool) -> void:
	if wire != input_wire:
		return
	if value and not _last_input:
		Phase14Helpers.pulse_transmitter(_tx_id)
	_last_input = value


func get_refund_meta() -> Dictionary:
	return { "item_id": "signal_transmitter_placeable", "count": 1 }
