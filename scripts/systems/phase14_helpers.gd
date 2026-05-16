extends Node

## Phase 14 — Automation, electricity, liquids, blueprints, paint.
##
## This autoload coordinates every Phase 14 system not big enough to deserve
## its own file:
##
##   14.1  Conveyor belt (lives in conveyor.gd, this helper owns the rotation grid)
##   14.2  Drill power consumption + tier gating
##   14.3  Robotic-arm pickup-and-place cycle (per-Beat scheduler)
##   14.4  Aphelion-tap power source — power_sources dict + power_budget tracker
##   14.5  Wire graph + circuit propagation
##   14.6  Sensor / pressure-plate / button signal emission
##   14.7  Logic gate evaluation (AND/OR/NOT/NAND)
##   14.8  Storage container piping (per-Beat item flow)
##   14.9  Auto-farms (sprinkler + harvester registry)
##   14.10 Auto-furnace / auto-smelter recipe matcher
##   14.11 Item filters on conveyors
##   14.12 Switches, buttons, pressure plates
##   14.13 Battery / energy storage cells
##   14.14 Power-cable visual sync (active/overload colour state)
##   14.15 Timer block delay propagation
##   14.16 Splitter / merger conveyor blocks
##   14.17 Recipe / blueprint sharing between bases
##   14.18 Auto-stocker / hopper item insert from storage
##   14.19 Mob farm (kill-zone for material drops)
##   14.20 Wireless signal (line-of-sight)
##   14.21 Tile painting (tile_paint dict)
##   14.22 Multi-block structure detection (room scoring)
##   14.23 Wallpaper covering existing tile surface
##   14.24 Bucket-of-X tile placement
##   14.25 Mob-proof glass / placeable transparent barrier
##   14.26 Fence-gate
##   14.27 Building blueprint save / load (per-room / per-area)
##   14.28 Demolition tool (faster un-place / area demolish)
##   14.29 Place-on-grid snap toggle
##   14.30 Auctioneer / mailbox economy node
##   14.36 Wireless redstone-equivalent (RF / signal transmitter)
##   14.37 Auto-cooking pot recipe-input bus
##   14.38 Auto-fishing rig
##   14.39 Robotic-arm crafting-input chain
##   14.40 Place-and-rotate (4 rotations per object)
##   14.41 Color wheel for tile painting / banner pigments
##   14.42 Pattern paint tool
##   3.34  Bucket item carries liquid in inventory
##   3.35  Place liquid back as tile
##   4.27  Liquid pumping / piping
##   4.35  Liquid mixing rules
##   4.36  Tile-conversion rules

# --- Signals ---------------------------------------------------------------
signal power_node_registered(node_id: int, kind: StringName)
signal power_node_unregistered(node_id: int)
signal power_state_changed(node_id: int, powered: bool, demand: float)
signal wire_signal_changed(wire_id: int, signal_value: bool)
signal wire_overload(wire_id: int, draw: float)
signal liquid_placed(world_pos: Vector2, liquid_id: StringName)
signal liquid_mixed(world_pos: Vector2, result_tile_id: StringName)
signal tile_painted(world_pos: Vector2, paint_color: Color)
signal blueprint_saved(blueprint_id: StringName, footprint: Vector2i)
signal blueprint_loaded(blueprint_id: StringName, world_origin: Vector2)
signal robotic_arm_cycled(arm_id: int, picked: StringName, count: int)
signal auctioneer_listed(seller_peer: int, item_id: StringName, count: int, price: int)
signal auctioneer_sold(buyer_peer: int, listing_id: int)
signal mob_farm_triggered(farm_id: int, killed_mob_id: StringName)
signal mod_loaded(mod_id: StringName, version: String)
signal mod_unloaded(mod_id: StringName)
signal mod_conflict_detected(mod_a: StringName, mod_b: StringName, key: String)

# --- Power graph (14.4 / 14.13 / 14.14) ----------------------------------
##
## Each power node has: id (int), kind (StringName), supply (float watts) or
## demand (float watts), wire_group (int — same group ids are wired together),
## stored_energy (float for batteries), max_capacity (float for batteries),
## active (bool).
const POWER_OVERLOAD_RATIO: float = 1.1   # if demand > 1.1 × supply → overload
const POWER_BATTERY_DRAIN_PER_BEAT: float = 5.0  # default battery release
const POWER_BATTERY_FILL_PER_BEAT: float = 5.0   # default battery store
var power_nodes: Dictionary = {}     # id (int) -> record
var _next_power_id: int = 1


## Register a power source (Aphelion-tap) or a power sink (drill, arm, furnace).
## kind = "source" or "sink" or "battery". wire_group ids that match
## are considered in the same circuit. Returns the assigned id.
func register_power_node(kind: StringName, wire_group: int, supply: float = 0.0, demand: float = 0.0, capacity: float = 0.0) -> int:
	var id: int = _next_power_id
	_next_power_id += 1
	power_nodes[id] = {
		"id": id,
		"kind": String(kind),
		"wire_group": wire_group,
		"supply": float(supply),
		"demand": float(demand),
		"stored_energy": 0.0,
		"max_capacity": float(capacity),
		"active": true,
	}
	power_node_registered.emit(id, kind)
	return id


func unregister_power_node(id: int) -> void:
	if not power_nodes.has(id):
		return
	power_nodes.erase(id)
	power_node_unregistered.emit(id)


## Sum supply + demand for a wire group; battery storage handles deltas.
## Returns true if all nodes in the group are powered. Per-beat call from
## audio_bus.aphelion_beat tick.
func resolve_power_for_group(wire_group: int) -> bool:
	var total_supply: float = 0.0
	var total_demand: float = 0.0
	var batteries: Array = []
	for id in power_nodes.keys():
		var rec: Dictionary = power_nodes[id]
		if int(rec.get("wire_group", -1)) != wire_group:
			continue
		if not bool(rec.get("active", true)):
			continue
		match String(rec.get("kind", "")):
			"source":
				total_supply += float(rec.get("supply", 0.0))
			"sink":
				total_demand += float(rec.get("demand", 0.0))
			"battery":
				batteries.append(rec)
	# If supply meets demand, sinks run, batteries top up.
	if total_supply >= total_demand:
		var leftover: float = total_supply - total_demand
		for b in batteries:
			var cap: float = float(b.get("max_capacity", 0.0))
			var stored: float = float(b.get("stored_energy", 0.0))
			var room: float = max(0.0, cap - stored)
			var fill: float = min(room, POWER_BATTERY_FILL_PER_BEAT)
			fill = min(fill, leftover)
			b["stored_energy"] = stored + fill
			leftover -= fill
		_emit_state_for_group(wire_group, true, total_demand)
		return true
	# Shortfall: pull from batteries.
	var deficit: float = total_demand - total_supply
	for b in batteries:
		var stored: float = float(b.get("stored_energy", 0.0))
		var drain: float = min(stored, POWER_BATTERY_DRAIN_PER_BEAT)
		drain = min(drain, deficit)
		b["stored_energy"] = stored - drain
		deficit -= drain
		if deficit <= 0.0:
			break
	var powered: bool = deficit <= 0.0
	if total_demand > total_supply * POWER_OVERLOAD_RATIO and total_supply > 0.0:
		wire_overload.emit(wire_group, total_demand)
	_emit_state_for_group(wire_group, powered, total_demand)
	return powered


func _emit_state_for_group(wire_group: int, powered: bool, demand: float) -> void:
	for id in power_nodes.keys():
		var rec: Dictionary = power_nodes[id]
		if int(rec.get("wire_group", -1)) != wire_group:
			continue
		power_state_changed.emit(id, powered, demand)


## Phase 14.13 — Read battery charge fraction (0..1).
func battery_charge_fraction(id: int) -> float:
	if not power_nodes.has(id):
		return 0.0
	var rec: Dictionary = power_nodes[id]
	if String(rec.get("kind", "")) != "battery":
		return 0.0
	var cap: float = float(rec.get("max_capacity", 0.0))
	if cap <= 0.0:
		return 0.0
	return clamp(float(rec.get("stored_energy", 0.0)) / cap, 0.0, 1.0)


# --- Wire graph (14.5 / 14.14 / 14.20 / 14.36) ----------------------------
##
## Wires carry a binary signal per tick. Distinct from the power graph: a wire
## group can be the *trigger* for whether a machine activates, while the
## power graph determines whether it has the watts to run. Most machines wire
## both groups identically.
var wire_signals: Dictionary = {}     # wire_id (int) -> bool current signal
var wire_signal_history: Dictionary = {}  # wire_id -> previous-tick value


func set_wire_signal(wire_id: int, value: bool) -> void:
	var prev: bool = bool(wire_signals.get(wire_id, false))
	wire_signals[wire_id] = value
	wire_signal_history[wire_id] = prev
	if prev != value:
		wire_signal_changed.emit(wire_id, value)


func read_wire_signal(wire_id: int) -> bool:
	return bool(wire_signals.get(wire_id, false))


## Phase 14.5 — Propagate a pulse from `source_wire` to all wires sharing the
## propagation_table. Mostly used for the visualiser; logic is direct lookups.
var wire_links: Dictionary = {}    # wire_id -> Array[int] of connected wires
func link_wires(a: int, b: int) -> void:
	var arr_a: Array = wire_links.get(a, [])
	if not arr_a.has(b):
		arr_a.append(b)
		wire_links[a] = arr_a
	var arr_b: Array = wire_links.get(b, [])
	if not arr_b.has(a):
		arr_b.append(a)
		wire_links[b] = arr_b


func propagate_signal(source_wire: int, value: bool) -> int:
	## BFS through `wire_links`; returns count of wires that flipped state.
	var changed: int = 0
	var visited: Dictionary = {}
	var stack: Array = [source_wire]
	while not stack.is_empty():
		var w: int = stack.pop_back()
		if visited.has(w):
			continue
		visited[w] = true
		if bool(wire_signals.get(w, not value)) != value:
			set_wire_signal(w, value)
			changed += 1
		for nb in wire_links.get(w, []):
			if not visited.has(nb):
				stack.append(nb)
	return changed


# --- Logic gates (14.7) ---------------------------------------------------
##
## Each gate has: id, kind ("and"/"or"/"not"/"nand"/"xor"), input_wires (Array),
## output_wire (int). Evaluated each tick via eval_gates.
var logic_gates: Dictionary = {}   # gate_id -> record
var _next_gate_id: int = 1


func register_gate(kind: StringName, input_wires: Array, output_wire: int) -> int:
	var id: int = _next_gate_id
	_next_gate_id += 1
	logic_gates[id] = {
		"id": id,
		"kind": String(kind),
		"input_wires": input_wires.duplicate(),
		"output_wire": output_wire,
	}
	return id


func unregister_gate(gate_id: int) -> void:
	logic_gates.erase(gate_id)


func eval_gate(gate_id: int) -> bool:
	if not logic_gates.has(gate_id):
		return false
	var g: Dictionary = logic_gates[gate_id]
	var inputs: Array = []
	for w in g.get("input_wires", []):
		inputs.append(read_wire_signal(int(w)))
	var out: bool = false
	match String(g.get("kind", "")):
		"and":
			out = true
			for i in inputs:
				if not i:
					out = false
					break
		"or":
			for i in inputs:
				if i:
					out = true
					break
		"not":
			out = inputs.is_empty() or not inputs[0]
		"nand":
			out = true
			for i in inputs:
				if not i:
					out = false
					break
			out = not out
		"xor":
			var trues: int = 0
			for i in inputs:
				if i:
					trues += 1
			out = (trues % 2) == 1
	set_wire_signal(int(g.get("output_wire", -1)), out)
	return out


func eval_all_gates() -> void:
	for gid in logic_gates.keys():
		eval_gate(gid)


# --- Timer blocks (14.15) -------------------------------------------------
##
## Timer block: when its input wire goes high, it waits N beats then pulses
## the output wire high for 1 beat, then back low.
var timer_blocks: Dictionary = {}    # timer_id -> { input_wire, output_wire, delay_beats, countdown, firing }
var _next_timer_id: int = 1


func register_timer(input_wire: int, output_wire: int, delay_beats: int = 3) -> int:
	var id: int = _next_timer_id
	_next_timer_id += 1
	timer_blocks[id] = {
		"id": id,
		"input_wire": input_wire,
		"output_wire": output_wire,
		"delay_beats": int(delay_beats),
		"countdown": -1,
		"firing": false,
	}
	return id


func tick_timers() -> void:
	for tid in timer_blocks.keys():
		var t: Dictionary = timer_blocks[tid]
		var input_high: bool = read_wire_signal(int(t.get("input_wire", -1)))
		var input_was_high: bool = bool(t.get("input_was_high", false))
		# Clear the previous beat's pulse, if any.
		if bool(t.get("firing", false)):
			t["firing"] = false
			set_wire_signal(int(t.get("output_wire", -1)), false)
		# Rising edge → arm the countdown.
		if input_high and not input_was_high:
			t["countdown"] = int(t.get("delay_beats", 3))
		# Decrement.
		if int(t.get("countdown", -1)) > 0:
			t["countdown"] = int(t["countdown"]) - 1
			if int(t["countdown"]) == 0:
				t["countdown"] = -1
				t["firing"] = true
				set_wire_signal(int(t.get("output_wire", -1)), true)
		t["input_was_high"] = input_high


# --- Liquid system (3.34 / 3.35 / 4.27 / 4.35 / 4.36 / 14.24) -------------
##
## Bucket carries `liquid_id` in inventory. The bucket item def stores the
## current liquid as an affix entry; we mirror that on the inventory entry so
## the player can stack multiple kinds. Empty bucket and a tile of liquid is
## what gives a full bucket.
const LIQUIDS: Array[StringName] = [&"water", &"lava", &"slime", &"acid"]
const LIQUID_TILE_FOR: Dictionary = {
	&"water": &"tile_water",
	&"lava": &"tile_lava",
	&"slime": &"tile_slime",
	&"acid": &"tile_acid",
}

## Liquid mixing rules (4.35).
## Key: sorted-pair "a+b" -> result_tile_id (StringName).
const LIQUID_MIX_RULES: Dictionary = {
	"lava+water": &"tile_stone_obsidian",
	"acid+water": &"tile_acid_diluted",
	"lava+slime": &"tile_slime_charred",
	"slime+water": &"tile_water_brackish",
}

## Tile conversion rules (4.36). Key: "tile_a+liquid_b" -> result_tile_id.
const TILE_CONVERT_RULES: Dictionary = {
	"tile_sand+water": &"tile_mud",
	"tile_dirt+water": &"tile_mud",
	"tile_ash+water": &"tile_sludge",
	"tile_dust+water": &"tile_mud",
	"tile_root_floor+slime": &"tile_root_slick",
	"tile_clearstone_floor+lava": &"tile_clearstone_charred",
}


func liquid_mix_result(a: StringName, b: StringName) -> StringName:
	if a == b:
		return &""
	var pair: String = "+".join([String(a), String(b)])
	if LIQUID_MIX_RULES.has(pair):
		return LIQUID_MIX_RULES[pair]
	# Try reverse order
	var pair_rev: String = "+".join([String(b), String(a)])
	return LIQUID_MIX_RULES.get(pair_rev, &"")


func tile_convert_result(tile_a: StringName, liquid_b: StringName) -> StringName:
	var key: String = "+".join([String(tile_a), String(liquid_b)])
	return TILE_CONVERT_RULES.get(key, &"")


## Bucket affix: stash the carried liquid on the player's bucket inventory
## entry. Returns true if the bucket was filled.
func fill_bucket_from_tile(slot_index: int, tile_liquid_id: StringName) -> bool:
	if not LIQUIDS.has(tile_liquid_id):
		return false
	if Inventory == null or slot_index < 0 or slot_index >= Inventory.slots.size():
		return false
	var s: Dictionary = Inventory.slots[slot_index]
	if s == null or s.is_empty():
		return false
	if String(s.get("item_id", "")) != "bucket_empty":
		return false
	# Swap to bucket_full of the matching liquid (item ids land in resources).
	var new_id: StringName = StringName("bucket_full_%s" % String(tile_liquid_id))
	Inventory.slots[slot_index] = { "item_id": new_id, "count": int(s.get("count", 1)) }
	Inventory.slot_changed.emit(slot_index, new_id, int(s.get("count", 1)))
	EventBus.inventory_changed.emit()
	return true


## 3.35 — Place bucket liquid back as a tile.
func empty_bucket_to_tile(slot_index: int, world_pos: Vector2) -> StringName:
	if Inventory == null or slot_index < 0 or slot_index >= Inventory.slots.size():
		return &""
	var s: Dictionary = Inventory.slots[slot_index]
	if s == null or s.is_empty():
		return &""
	var item_id: String = String(s.get("item_id", ""))
	if not item_id.begins_with("bucket_full_"):
		return &""
	var liquid_id: StringName = StringName(item_id.replace("bucket_full_", ""))
	liquid_placed.emit(world_pos, liquid_id)
	Inventory.slots[slot_index] = { "item_id": &"bucket_empty", "count": int(s.get("count", 1)) }
	Inventory.slot_changed.emit(slot_index, &"bucket_empty", int(s.get("count", 1)))
	EventBus.inventory_changed.emit()
	return liquid_id


# --- Tile painting (14.21 / 14.41 / 14.42) -------------------------------
##
## Players can tint placed wall/floor tiles cosmetically with the Paint Brush
## item. The tint is stored per world tile coord. Banner pigments + pattern
## paint use the same colour wheel.
var tile_paint: Dictionary = {}    # "x,y" -> Color hex string
const PAINT_COLOR_WHEEL: Array[Color] = [
	Color(1.00, 0.96, 0.78), # warm white
	Color(0.95, 0.45, 0.30), # amber
	Color(0.80, 0.15, 0.20), # crimson
	Color(0.20, 0.55, 0.95), # azure
	Color(0.25, 0.78, 0.40), # verdancy green
	Color(0.55, 0.25, 0.80), # echo violet
	Color(0.95, 0.85, 0.20), # diadem gold
	Color(0.20, 0.20, 0.25), # iron grey
]


func paint_tile(coord: Vector2i, color: Color) -> void:
	var key: String = "%d,%d" % [coord.x, coord.y]
	tile_paint[key] = "#%02x%02x%02x" % [
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
	]
	tile_painted.emit(Vector2(coord) * 16.0 + Vector2(8, 8), color)


func paint_for(coord: Vector2i) -> Color:
	var key: String = "%d,%d" % [coord.x, coord.y]
	if not tile_paint.has(key):
		return Color(1, 1, 1, 1)
	# Stored as "#rrggbb" hex; Color() accepts that directly.
	return Color(str(tile_paint[key]))


## 14.42 — Pattern paint: stamp a 3×3 pattern of colour indices onto a coord.
const PATTERNS: Dictionary = {
	"checker": [
		[0, 1, 0],
		[1, 0, 1],
		[0, 1, 0],
	],
	"stripes": [
		[2, 2, 2],
		[1, 1, 1],
		[2, 2, 2],
	],
	"diamond": [
		[0, 4, 0],
		[4, 4, 4],
		[0, 4, 0],
	],
}


func stamp_pattern(coord: Vector2i, pattern_id: StringName, color_a: Color, color_b: Color) -> int:
	var p: Array = PATTERNS.get(String(pattern_id), [])
	if p.is_empty():
		return 0
	var stamped: int = 0
	for r in range(p.size()):
		var row: Array = p[r]
		for c in range(row.size()):
			var pick: int = int(row[c])
			var use: Color = color_a if pick == 0 else color_b
			paint_tile(Vector2i(coord.x + c - 1, coord.y + r - 1), use)
			stamped += 1
	return stamped


# --- Tile rotation (14.40) -----------------------------------------------
##
## Most placeables (conveyors, arms, sensors) accept a `rotation_step` 0..3.
## Multiply by 90° at apply-time.
const ROTATION_DEGREES: Array[int] = [0, 90, 180, 270]


func rotation_for_step(step: int) -> int:
	return ROTATION_DEGREES[clampi(step % 4, 0, 3)]


# --- Place-on-grid snap toggle (14.29) ---------------------------------
##
## Grid snap is global; user toggles. When off, placement is free-form.
var grid_snap_enabled: bool = true


func toggle_grid_snap() -> bool:
	grid_snap_enabled = not grid_snap_enabled
	return grid_snap_enabled


func snap_to_grid(world_pos: Vector2) -> Vector2:
	if not grid_snap_enabled:
		return world_pos
	var tile: Vector2i = Vector2i(world_pos / 16.0)
	return Vector2(tile) * 16.0 + Vector2(8, 8)


# --- Blueprint save/load (14.27) ----------------------------------------
##
## A blueprint snapshots a rectangle of the world: which structure scene is
## placed at each offset, what rotation it has, and what paint color it has.
## Reloadable at any world coord. Persists in save file.
var blueprints: Dictionary = {}    # blueprint_id (StringName) -> { footprint, tiles: [{ offset, structure_id, rotation_step, paint }] }


func save_blueprint(blueprint_id: StringName, origin: Vector2, footprint: Vector2i, tiles: Array) -> void:
	var rec: Dictionary = {
		"id": String(blueprint_id),
		"origin_x": origin.x,
		"origin_y": origin.y,
		"footprint_w": footprint.x,
		"footprint_h": footprint.y,
		"tiles": tiles.duplicate(true),
		"saved_at_unix": Time.get_unix_time_from_system(),
	}
	blueprints[blueprint_id] = rec
	blueprint_saved.emit(blueprint_id, footprint)


func load_blueprint(blueprint_id: StringName, world_origin: Vector2) -> Array:
	if not blueprints.has(blueprint_id):
		return []
	var rec: Dictionary = blueprints[blueprint_id]
	blueprint_loaded.emit(blueprint_id, world_origin)
	# Caller is responsible for actually instantiating each tile entry.
	return rec.get("tiles", [])


func list_blueprints() -> Array:
	var out: Array = []
	for k in blueprints.keys():
		var rec: Dictionary = blueprints[k]
		out.append({
			"id": String(k),
			"footprint": Vector2i(int(rec.get("footprint_w", 0)), int(rec.get("footprint_h", 0))),
			"saved_at_unix": rec.get("saved_at_unix", 0.0),
		})
	return out


# --- Storage piping / hopper (14.8 / 14.18) ----------------------------
##
## Storage pipes connect chest-like nodes to machine inputs. Per Beat, each
## active pipe attempts to move one item from source -> dest. The pipe defines
## an optional filter (whitelist of item_ids).
var storage_pipes: Dictionary = {}    # pipe_id -> { source_node, dest_node, filter (Array[StringName]), active }
var _next_pipe_id: int = 1


func register_pipe(source_path: NodePath, dest_path: NodePath, filter_ids: Array = []) -> int:
	var id: int = _next_pipe_id
	_next_pipe_id += 1
	storage_pipes[id] = {
		"id": id,
		"source_path": source_path,
		"dest_path": dest_path,
		"filter": filter_ids.duplicate(),
		"active": true,
	}
	return id


func unregister_pipe(id: int) -> void:
	storage_pipes.erase(id)


func tick_pipes() -> int:
	## Returns the number of items moved this beat. Pipes are advisory; the
	## actual mutation happens via chest.transfer_one_to(dest).
	var moved: int = 0
	for pid in storage_pipes.keys():
		var rec: Dictionary = storage_pipes[pid]
		if not bool(rec.get("active", true)):
			continue
		var tree := get_tree()
		if tree == null:
			continue
		var source := tree.current_scene.get_node_or_null(rec.get("source_path"))
		var dest := tree.current_scene.get_node_or_null(rec.get("dest_path"))
		if source == null or dest == null:
			continue
		if source.has_method("transfer_one_to"):
			var ok: bool = source.call("transfer_one_to", dest, rec.get("filter", []))
			if ok:
				moved += 1
	return moved


# --- Conveyor filters (14.11) -------------------------------------------
##
## Per-conveyor filter sets, keyed by the conveyor's instance id.
var conveyor_filters: Dictionary = {}    # instance_id -> Array[StringName] (whitelist; empty = allow all)


func set_conveyor_filter(conv_inst_id: int, filter: Array) -> void:
	if filter.is_empty():
		conveyor_filters.erase(conv_inst_id)
	else:
		conveyor_filters[conv_inst_id] = filter.duplicate()


func conveyor_allows(conv_inst_id: int, item_id: StringName) -> bool:
	if not conveyor_filters.has(conv_inst_id):
		return true
	var f: Array = conveyor_filters[conv_inst_id]
	return f.has(item_id) or f.has(String(item_id))


# --- Splitter / merger conveyors (14.16) --------------------------------
##
## Splitters round-robin per item; mergers accept from N inputs.
var splitter_cursors: Dictionary = {}    # splitter_id (int) -> last-output-index (int)


func splitter_next_output(splitter_id: int, output_count: int) -> int:
	var cur: int = int(splitter_cursors.get(splitter_id, -1))
	var next: int = (cur + 1) % max(1, output_count)
	splitter_cursors[splitter_id] = next
	return next


# --- Robotic-arm cycle (14.3 / 14.39) -----------------------------------
##
## Arms have a source tile and a target tile. Each Beat the arm tries to
## pick up an ItemDrop near source and place it on target.
const ROBOTIC_ARM_PERIOD_BEATS: int = 2
var robotic_arms: Dictionary = {}    # arm_id -> { source_pos, target_pos, beats_since_cycle, active }
var _next_arm_id: int = 1


func register_arm(source_pos: Vector2, target_pos: Vector2) -> int:
	var id: int = _next_arm_id
	_next_arm_id += 1
	robotic_arms[id] = {
		"id": id,
		"source_pos": source_pos,
		"target_pos": target_pos,
		"beats_since_cycle": 0,
		"active": true,
	}
	return id


func unregister_arm(id: int) -> void:
	robotic_arms.erase(id)


func tick_robotic_arms() -> int:
	## Schedules a cycle; the actual pickup runs in robotic_arm.gd's process.
	## Returns the number of arms that fired this beat.
	var fired: int = 0
	for aid in robotic_arms.keys():
		var arm: Dictionary = robotic_arms[aid]
		if not bool(arm.get("active", true)):
			continue
		arm["beats_since_cycle"] = int(arm.get("beats_since_cycle", 0)) + 1
		if int(arm["beats_since_cycle"]) >= ROBOTIC_ARM_PERIOD_BEATS:
			arm["beats_since_cycle"] = 0
			fired += 1
			robotic_arm_cycled.emit(aid, StringName(""), 0)
	return fired


# --- Auto-cooker / auto-fishing (14.37 / 14.38) -------------------------
##
## Auto-cooker holds a recipe id; each beat it consumes inputs from a fed chest
## and emits an output via storage piping. Auto-fishing rig hooks every N
## beats with a configurable bait + rod tier.
var auto_cookers: Dictionary = {}     # cooker_id -> { recipe_id, source_path, dest_path, beats_remaining }
var auto_fishing_rigs: Dictionary = {}    # rig_id -> { rod_tier, bait_id, beats_remaining, dest_path }
const AUTO_COOK_PERIOD_BEATS: int = 8
const AUTO_FISH_PERIOD_BEATS: int = 12
var _next_cooker_id: int = 1
var _next_rig_id: int = 1


func register_auto_cooker(recipe_id: StringName, source_path: NodePath, dest_path: NodePath) -> int:
	var id: int = _next_cooker_id
	_next_cooker_id += 1
	auto_cookers[id] = {
		"id": id,
		"recipe_id": recipe_id,
		"source_path": source_path,
		"dest_path": dest_path,
		"beats_remaining": AUTO_COOK_PERIOD_BEATS,
	}
	return id


func register_auto_fishing_rig(rod_tier: int, bait_id: StringName, dest_path: NodePath) -> int:
	var id: int = _next_rig_id
	_next_rig_id += 1
	auto_fishing_rigs[id] = {
		"id": id,
		"rod_tier": rod_tier,
		"bait_id": bait_id,
		"beats_remaining": AUTO_FISH_PERIOD_BEATS,
		"dest_path": dest_path,
	}
	return id


func tick_auto_cookers() -> int:
	var fired: int = 0
	for cid in auto_cookers.keys():
		var c: Dictionary = auto_cookers[cid]
		c["beats_remaining"] = int(c.get("beats_remaining", AUTO_COOK_PERIOD_BEATS)) - 1
		if c["beats_remaining"] <= 0:
			c["beats_remaining"] = AUTO_COOK_PERIOD_BEATS
			fired += 1
	return fired


func tick_auto_fishing_rigs() -> int:
	var fired: int = 0
	for rid in auto_fishing_rigs.keys():
		var r: Dictionary = auto_fishing_rigs[rid]
		r["beats_remaining"] = int(r.get("beats_remaining", AUTO_FISH_PERIOD_BEATS)) - 1
		if r["beats_remaining"] <= 0:
			r["beats_remaining"] = AUTO_FISH_PERIOD_BEATS
			fired += 1
	return fired


# --- Mob farm (14.19) ----------------------------------------------------
##
## A mob farm is a registered kill-zone — any mob death inside the AABB drops
## its loot at the centerpoint chest so the player doesn't have to walk it.
var mob_farms: Dictionary = {}    # farm_id -> { aabb_min, aabb_max, sink_pos }
var _next_farm_id: int = 1


func register_mob_farm(aabb_min: Vector2, aabb_max: Vector2, sink_pos: Vector2) -> int:
	var id: int = _next_farm_id
	_next_farm_id += 1
	mob_farms[id] = {
		"id": id,
		"aabb_min": aabb_min,
		"aabb_max": aabb_max,
		"sink_pos": sink_pos,
	}
	return id


func farm_for_position(world_pos: Vector2) -> int:
	for fid in mob_farms.keys():
		var f: Dictionary = mob_farms[fid]
		var mn: Vector2 = f.get("aabb_min", Vector2.ZERO)
		var mx: Vector2 = f.get("aabb_max", Vector2.ZERO)
		if world_pos.x >= mn.x and world_pos.x <= mx.x and world_pos.y >= mn.y and world_pos.y <= mx.y:
			return fid
	return -1


# --- Auctioneer / mailbox economy (14.30) -------------------------------
##
## Each listing has: id, seller_peer, item_id, count, price, claimed_by_peer (-1
## while live). Buyer hits "Buy" → listing flips to claimed + auto-mails the
## item via mailbox.
var auctioneer_listings: Dictionary = {}    # listing_id -> record
var _next_listing_id: int = 1


func list_for_sale(seller_peer: int, item_id: StringName, count: int, price: int) -> int:
	if count <= 0 or price < 0:
		return -1
	var id: int = _next_listing_id
	_next_listing_id += 1
	auctioneer_listings[id] = {
		"id": id,
		"seller_peer": seller_peer,
		"item_id": String(item_id),
		"count": count,
		"price": price,
		"claimed_by_peer": -1,
		"posted_at_unix": Time.get_unix_time_from_system(),
	}
	auctioneer_listed.emit(seller_peer, item_id, count, price)
	return id


func claim_listing(listing_id: int, buyer_peer: int) -> bool:
	if not auctioneer_listings.has(listing_id):
		return false
	var rec: Dictionary = auctioneer_listings[listing_id]
	if int(rec.get("claimed_by_peer", -1)) != -1:
		return false
	rec["claimed_by_peer"] = buyer_peer
	auctioneer_sold.emit(buyer_peer, listing_id)
	return true


func active_listings() -> Array:
	var out: Array = []
	for k in auctioneer_listings.keys():
		var rec: Dictionary = auctioneer_listings[k]
		if int(rec.get("claimed_by_peer", -1)) == -1:
			out.append(rec.duplicate())
	return out


# --- Multiblock detection / room scoring (14.22) ------------------------
##
## A multi-block is a contiguous region of stations/structures that together
## form a recipe-eligible room (e.g. forge + furnace + sawmill = "industrial
## quarter"). Score = number of station kinds in the room.
##
## MVP: when the player opens a workstation, scan within 96 px for other
## workstations and return the unique kinds. The full BFS with wall detection
## is forward-compatible with Phase 9 housing.validate_room.
const MULTIBLOCK_SCAN_RADIUS: float = 96.0


func score_multiblock(world_pos: Vector2) -> int:
	var kinds: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return 0
	for ws in tree.get_nodes_in_group("workstation"):
		var node := ws as Node2D
		if node == null:
			continue
		if node.global_position.distance_to(world_pos) <= MULTIBLOCK_SCAN_RADIUS:
			var sid: String = String(node.get("station_id"))
			if sid != "":
				kinds[sid] = true
	return kinds.size()


# --- Wireless signal (14.20 / 14.36) ------------------------------------
##
## Wireless transmitters emit on a frequency. Receivers on the same frequency
## within range receive the signal; LOS is required (14.20).
var wireless_transmitters: Dictionary = {}    # tx_id -> { frequency, world_pos, active, range_px }
var wireless_receivers: Dictionary = {}       # rx_id -> { frequency, world_pos, output_wire }
var _next_tx_id: int = 1
var _next_rx_id: int = 1


func register_transmitter(frequency: int, world_pos: Vector2, range_px: float = 256.0) -> int:
	var id: int = _next_tx_id
	_next_tx_id += 1
	wireless_transmitters[id] = {
		"id": id,
		"frequency": frequency,
		"world_pos": world_pos,
		"active": false,
		"range_px": range_px,
	}
	return id


func register_receiver(frequency: int, world_pos: Vector2, output_wire: int) -> int:
	var id: int = _next_rx_id
	_next_rx_id += 1
	wireless_receivers[id] = {
		"id": id,
		"frequency": frequency,
		"world_pos": world_pos,
		"output_wire": output_wire,
	}
	return id


func pulse_transmitter(tx_id: int) -> int:
	## Returns number of receivers that flipped on.
	var fired: int = 0
	if not wireless_transmitters.has(tx_id):
		return 0
	var tx: Dictionary = wireless_transmitters[tx_id]
	tx["active"] = true
	for rid in wireless_receivers.keys():
		var rx: Dictionary = wireless_receivers[rid]
		if int(rx.get("frequency", 0)) != int(tx.get("frequency", 0)):
			continue
		var dist: float = (rx.get("world_pos", Vector2.ZERO) as Vector2).distance_to(tx.get("world_pos", Vector2.ZERO))
		if dist > float(tx.get("range_px", 0.0)):
			continue
		set_wire_signal(int(rx.get("output_wire", -1)), true)
		fired += 1
	return fired


# --- Demolition tool (14.28) ---------------------------------------------
##
## When the demolition tool is active, the player can right-click an area to
## remove every placeable in radius for half the resource refund.
const DEMOLITION_REFUND_FRACTION: float = 0.5
const DEMOLITION_RADIUS_PX: float = 32.0


func demolish_area(world_pos: Vector2, radius: float = DEMOLITION_RADIUS_PX) -> int:
	## Removes every node in the "demolishable" group within radius. Returns
	## count removed.
	var removed: int = 0
	var tree := get_tree()
	if tree == null:
		return 0
	for n in tree.get_nodes_in_group("demolishable"):
		var node := n as Node2D
		if node == null:
			continue
		if node.global_position.distance_to(world_pos) > radius:
			continue
		# Refund half. Each demolishable should expose `refund_item_id` and
		# `refund_count`.
		if node.has_method("get_refund_meta"):
			var meta: Dictionary = node.call("get_refund_meta")
			var iid: StringName = StringName(String(meta.get("item_id", "")))
			var c: int = int(meta.get("count", 0))
			if iid != &"" and c > 0:
				Inventory.try_add(iid, max(1, int(round(float(c) * DEMOLITION_REFUND_FRACTION))))
		node.queue_free()
		removed += 1
	return removed


# --- Persistence (save format v12) ---------------------------------------


func dump_state() -> Dictionary:
	return {
		"power_nodes": _serialize_power_nodes(),
		"_next_power_id": _next_power_id,
		"wire_signals": _stringify_keys(wire_signals),
		"wire_links": _stringify_keys(wire_links),
		"logic_gates": _stringify_keys(logic_gates),
		"_next_gate_id": _next_gate_id,
		"timer_blocks": _stringify_keys(timer_blocks),
		"_next_timer_id": _next_timer_id,
		"tile_paint": tile_paint.duplicate(),
		"grid_snap_enabled": grid_snap_enabled,
		"blueprints": _serialize_blueprints(),
		"conveyor_filters": _stringify_keys(conveyor_filters),
		"storage_pipes": _stringify_keys(storage_pipes),
		"_next_pipe_id": _next_pipe_id,
		"robotic_arms": _stringify_keys(robotic_arms),
		"_next_arm_id": _next_arm_id,
		"auto_cookers": _stringify_keys(auto_cookers),
		"_next_cooker_id": _next_cooker_id,
		"auto_fishing_rigs": _stringify_keys(auto_fishing_rigs),
		"_next_rig_id": _next_rig_id,
		"mob_farms": _stringify_keys(mob_farms),
		"_next_farm_id": _next_farm_id,
		"auctioneer_listings": _stringify_keys(auctioneer_listings),
		"_next_listing_id": _next_listing_id,
		"wireless_transmitters": _stringify_keys(wireless_transmitters),
		"wireless_receivers": _stringify_keys(wireless_receivers),
		"_next_tx_id": _next_tx_id,
		"_next_rx_id": _next_rx_id,
	}


func restore_state(state: Dictionary) -> void:
	power_nodes = _restore_int_keyed(state.get("power_nodes", {}))
	_next_power_id = int(state.get("_next_power_id", 1))
	wire_signals = _restore_int_keyed(state.get("wire_signals", {}))
	wire_links = _restore_int_keyed(state.get("wire_links", {}))
	logic_gates = _restore_int_keyed(state.get("logic_gates", {}))
	_next_gate_id = int(state.get("_next_gate_id", 1))
	timer_blocks = _restore_int_keyed(state.get("timer_blocks", {}))
	_next_timer_id = int(state.get("_next_timer_id", 1))
	tile_paint = state.get("tile_paint", {})
	grid_snap_enabled = bool(state.get("grid_snap_enabled", true))
	blueprints = _restore_string_name_keyed(state.get("blueprints", {}))
	conveyor_filters = _restore_int_keyed(state.get("conveyor_filters", {}))
	storage_pipes = _restore_int_keyed(state.get("storage_pipes", {}))
	_next_pipe_id = int(state.get("_next_pipe_id", 1))
	robotic_arms = _restore_int_keyed(state.get("robotic_arms", {}))
	_next_arm_id = int(state.get("_next_arm_id", 1))
	auto_cookers = _restore_int_keyed(state.get("auto_cookers", {}))
	_next_cooker_id = int(state.get("_next_cooker_id", 1))
	auto_fishing_rigs = _restore_int_keyed(state.get("auto_fishing_rigs", {}))
	_next_rig_id = int(state.get("_next_rig_id", 1))
	mob_farms = _restore_int_keyed(state.get("mob_farms", {}))
	_next_farm_id = int(state.get("_next_farm_id", 1))
	auctioneer_listings = _restore_int_keyed(state.get("auctioneer_listings", {}))
	_next_listing_id = int(state.get("_next_listing_id", 1))
	wireless_transmitters = _restore_int_keyed(state.get("wireless_transmitters", {}))
	wireless_receivers = _restore_int_keyed(state.get("wireless_receivers", {}))
	_next_tx_id = int(state.get("_next_tx_id", 1))
	_next_rx_id = int(state.get("_next_rx_id", 1))


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[str(k)] = d[k]
	return out


func _restore_int_keyed(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		var key_int: int = int(str(k))
		out[key_int] = d[k]
	return out


func _restore_string_name_keyed(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(str(k))] = d[k]
	return out


func _serialize_power_nodes() -> Dictionary:
	var out: Dictionary = {}
	for k in power_nodes.keys():
		out[str(k)] = power_nodes[k].duplicate()
	return out


func _serialize_blueprints() -> Dictionary:
	var out: Dictionary = {}
	for k in blueprints.keys():
		out[str(k)] = blueprints[k].duplicate(true)
	return out


# --- Per-Beat tick driver ------------------------------------------------
##
## AudioBus.aphelion_beat fires every 23s. Phase14Helpers consolidates the
## sub-system ticks so they don't each hook the signal separately.


func _ready() -> void:
	if AudioBus and AudioBus.has_signal("aphelion_beat"):
		AudioBus.aphelion_beat.connect(_on_beat)


func _on_beat() -> void:
	# Snapshot the active wire groups + tick everything in dependency order.
	var groups: Dictionary = {}
	for id in power_nodes.keys():
		groups[int(power_nodes[id].get("wire_group", -1))] = true
	for g in groups.keys():
		resolve_power_for_group(int(g))
	eval_all_gates()
	tick_timers()
	tick_robotic_arms()
	tick_pipes()
	tick_auto_cookers()
	tick_auto_fishing_rigs()
