extends Node
class_name PaintBrushTool

## Phase 14.21 / 14.41 — Helper to apply a chosen palette color to the tile
## under the cursor. Stateless — instantiated by player_combat when the held
## item is `paint_brush`.

static func paint_at(world_pos: Vector2, palette_index: int) -> void:
	if Phase14Helpers == null:
		return
	var idx: int = clampi(palette_index, 0, Phase14Helpers.PAINT_COLOR_WHEEL.size() - 1)
	var color: Color = Phase14Helpers.PAINT_COLOR_WHEEL[idx]
	var coord: Vector2i = Vector2i(world_pos / 16.0)
	Phase14Helpers.paint_tile(coord, color)


static func stamp_pattern(world_pos: Vector2, pattern_id: StringName, color_a: int, color_b: int) -> int:
	if Phase14Helpers == null:
		return 0
	var ca: Color = Phase14Helpers.PAINT_COLOR_WHEEL[clampi(color_a, 0, Phase14Helpers.PAINT_COLOR_WHEEL.size() - 1)]
	var cb: Color = Phase14Helpers.PAINT_COLOR_WHEEL[clampi(color_b, 0, Phase14Helpers.PAINT_COLOR_WHEEL.size() - 1)]
	var coord: Vector2i = Vector2i(world_pos / 16.0)
	return Phase14Helpers.stamp_pattern(coord, pattern_id, ca, cb)
