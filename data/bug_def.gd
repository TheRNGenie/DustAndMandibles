class_name BugDef
extends Resource
## One bug type. Adding a bug = a new .tres plus a body in BugBuilder, no core code.

enum Behavior { SWARM, TANK, LEAPER, SPITTER, BROOD, BURROWER, FLIER, CROP_EATER, BOSS }

@export var id: StringName = &""
@export var display_name: String = ""
@export var behavior: Behavior = Behavior.SWARM
@export var max_hp: float = 50.0
## Metres per second up the cliff face.
@export var climb_speed: float = 1.4
## Metres per second once it breaches onto a plateau.
@export var walk_speed: float = 2.5
## Threat-budget cost of ONE bug (a group costs cost * group_size).
@export var cost: int = 1
@export var group_size: int = 1
## Damage reduction (0..1) for shots that hit the outward-facing armour plate.
@export var front_armor: float = 0.0
@export var scrap_drop: int = 1
@export var chitin_drop: int = 0
## Damage per second dealt to structures, the Homestead or players once breached.
@export var breach_dps: float = 8.0
## Overall scale of the generated body.
@export var size: float = 1.0
@export var shell_color: Color = Color.WHITE
## First wave this bug can appear in.
@export var first_wave: int = 1
## The one learnable way to beat this bug (shown in the Field Guide).
@export_multiline var counter: String = ""
## Kill-method variants only: the bug this one is a variant of, and how much
## damage it takes from each kill method (&"bullet", &"fire", &"blast"; 1 = normal).
@export var variant_of: StringName = &""
@export var damage_taken: Dictionary = {}
## Bosses only: the one-line warning in the kill feed when it shows up (what it
## does and what beats it), and the crime under WANTED on its poster.
@export var boss_tip: String = ""
@export var wanted_for: String = ""
## Bosses only: met in Story mode only (the Hive Queen), never picked for a
## run's boss wave.
@export var story_only: bool = false


## The plain bug type this is (itself, or the bug a variant is based on).
func base_id() -> StringName:
	return variant_of if variant_of != &"" else id


func is_variant() -> bool:
	return variant_of != &""


## Damage multiplier for a kill method (1 for every plain bug).
func damage_mult(method: StringName) -> float:
	return float(damage_taken.get(method, 1.0)) if not damage_taken.is_empty() else 1.0
