extends Node

## Global event bus.
## All cross-system signals fire through this autoload.
## Subscribers connect on _ready in their own scripts.

# --- World / generation ---
signal world_seeded(seed_value: int)
signal chunk_generated(chunk_coord: Vector2i)
signal tile_changed(tile_coord: Vector2i, old_id: int, new_id: int)

# --- Player ---
signal player_spawned(player: Node)
signal player_died(player: Node)
signal player_respawned(player: Node, slivers_remaining: int)
signal player_health_changed(current: int, maximum: int)
signal player_mana_changed(current: int, maximum: int)
signal player_hunger_changed(current: float, maximum: float)

# --- Combat ---
signal damage_dealt(source: Node, target: Node, amount: int, type: StringName)
signal damage_floated(world_pos: Vector2, amount: int, is_crit: bool, type: StringName)
signal entity_killed(entity: Node, killer: Node)
signal camera_shake_requested(intensity: float, duration: float)
signal hit_pause_requested(duration: float)
signal screen_pulse_requested(strength: float, duration: float)
signal letterbox_requested(enabled: bool, fade_seconds: float)

# --- Inventory / crafting ---
signal item_picked_up(item_id: StringName, count: int)
signal inventory_changed
signal recipe_unlocked(recipe_id: StringName)
signal item_crafted(item_id: StringName, count: int)

# --- Skills ---
signal skill_xp_gained(skill_id: StringName, amount: int)
signal skill_leveled_up(skill_id: StringName, new_level: int)
signal talent_unlocked(skill_id: StringName, talent_id: StringName)

# --- Boss / progression ---
signal boss_engaged(boss_id: StringName)
signal boss_defeated(boss_id: StringName)
signal sovereign_defeated(sovereign_id: StringName, fragment_id: StringName)
signal aphelion_dimmed(slivers_remaining: int)

# --- NPC ---
signal npc_arrived(npc_id: StringName)
signal npc_dialogue_opened(npc_id: StringName)

# --- UI ---
signal ui_toast(text: String, duration: float)
signal ui_compendium_entry_unlocked(entry_id: StringName)
