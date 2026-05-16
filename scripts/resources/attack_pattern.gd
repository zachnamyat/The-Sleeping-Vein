extends Resource
class_name AttackPattern

## Phase 6.48 — data-driven boss attack-pattern. A pattern is a list of attack
## entries; the BossAttackCycler advances through them in order, then loops.
## Entries are dictionaries keyed by:
##   - id          (StringName)   — unique tag, used for telegraph + audio
##   - kind        (StringName)   — "slam" / "ranged_arc" / "summon" / "dash"
##   - telegraph_seconds (float)  — pre-attack warning duration
##   - cooldown_seconds  (float)  — post-attack pause before the next entry
##   - radius_pixels     (float)  — AoE radius (for slam) or projectile range
##   - damage           (int)     — base damage applied by the attack
##   - damage_type     (StringName) — physical / fire / lightning ...
##   - speed           (float)    — projectile speed (ranged_arc / dash)
##
## Example: a 3-step cycle for Glaur-em — slam → projectile fan → minion summon.

@export var pattern_id: StringName = &"boss_pattern_default"
@export var entries: Array[Dictionary] = []
@export var loop: bool = true
@export var phase_index: int = 0  ## 0 = phase 1, 1 = phase 2 ...


static func entry(id: StringName, kind: StringName, telegraph: float, cooldown: float, radius: float = 32.0, damage: int = 8, damage_type: StringName = &"physical", speed: float = 0.0) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"telegraph_seconds": telegraph,
		"cooldown_seconds": cooldown,
		"radius_pixels": radius,
		"damage": damage,
		"damage_type": damage_type,
		"speed": speed,
	}
