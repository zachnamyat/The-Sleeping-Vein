extends Node2D
class_name TimerBlock

## Phase 14.15 — Timer block. When its input wire goes high, it waits
## `delay_beats` Aphelion-Beats and then pulses its output wire for one beat.

@export var input_wire: int = 0
@export var output_wire: int = 0
@export var delay_beats: int = 3

var _timer_id: int = -1


func _ready() -> void:
	add_to_group("timer_block")
	add_to_group("demolishable")
	_timer_id = Phase14Helpers.register_timer(input_wire, output_wire, delay_beats)


func get_refund_meta() -> Dictionary:
	return { "item_id": "timer_block_placeable", "count": 1 }
