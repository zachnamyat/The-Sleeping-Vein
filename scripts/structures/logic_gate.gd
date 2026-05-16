extends Node2D
class_name LogicGate

## Phase 14.7 — Placed logic gate. Each gate has a `kind` (and/or/not/nand/xor)
## and two wire ids on its inputs (one for NOT), one on its output.

@export var kind: StringName = &"and"
@export var input_wire_a: int = 0
@export var input_wire_b: int = 0
@export var output_wire: int = 0

var _gate_id: int = -1


func _ready() -> void:
	add_to_group("logic_gate")
	add_to_group("demolishable")
	var inputs: Array = [input_wire_a]
	if kind != &"not":
		inputs.append(input_wire_b)
	_gate_id = Phase14Helpers.register_gate(kind, inputs, output_wire)


func _exit_tree() -> void:
	if Phase14Helpers:
		Phase14Helpers.unregister_gate(_gate_id)


func get_refund_meta() -> Dictionary:
	return { "item_id": "logic_gate_%s_placeable" % String(kind), "count": 1 }
