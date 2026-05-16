extends Resource
class_name MobDef

## Data-driven mob/enemy definition. Saved as .tres in resources/mobs/.

enum Behavior { IDLE, WANDER, CHASE, RANGED, BOSS_SCRIPTED, CRITTER_FLEE }
enum MobClass { MELEE, RANGED, CASTER, TANK, CRITTER }

@export var id: StringName = &""
@export var display_name: String = ""
@export var sprite: Texture2D
@export var sprite_size: Vector2i = Vector2i(16, 16)
@export var max_health: int = 10
@export var armor: int = 0
@export var contact_damage: int = 5
@export var contact_damage_type: StringName = &"physical"
@export var move_speed: float = 30.0
@export var detection_radius: float = 96.0
## Ticket 2.19/2.28 — distance at which the mob drops aggro and walks back to
## its spawn. 0 disables (mob chases forever once aggro'd).
@export var leash_radius: float = 160.0
@export var behavior: Behavior = Behavior.CHASE
## Ticket 2.31 — informational class for future AI selection + UI tooltips.
@export var mob_class: MobClass = MobClass.MELEE
@export var xp_skill: StringName = &"skill_melee"
@export var xp_value: int = 5
@export var loot_table: LootTable
@export var biome: StringName = &"root_hollows"
@export var lore_ref: String = ""

# Resistances dictionary {StringName: float -1..1}
@export var resistances: Dictionary = {}

## Phase 6.39 — stagger meter. Heavy-attack hits add to the meter; once
## stagger_threshold is reached the mob enters a stunned animation for
## stagger_recovery_seconds. 0 disables stagger entirely (set high for tanks).
@export var stagger_threshold: int = 30
@export var stagger_recovery_seconds: float = 1.0
@export var knockback_resistance: float = 0.0  ## 0..1; bosses set high

## Phase 6.10 — weakness multiplier per damage type. Stacks multiplicatively
## with resistances. Maps StringName damage_type -> float (1.5 = +50% damage).
@export var weaknesses: Dictionary = {}
