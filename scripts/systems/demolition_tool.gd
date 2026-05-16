extends Node
class_name DemolitionTool

## Phase 14.28 — Helper. Triggers a Phase14Helpers.demolish_area at the cursor.

static func demolish_at(world_pos: Vector2, radius: float = 0.0) -> int:
	if Phase14Helpers == null:
		return 0
	var use_radius: float = radius if radius > 0.0 else Phase14Helpers.DEMOLITION_RADIUS_PX
	return Phase14Helpers.demolish_area(world_pos, use_radius)
