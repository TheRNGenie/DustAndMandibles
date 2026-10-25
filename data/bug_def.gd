class_name BugDef
extends Resource
## One bug type. Adding a bug = a new .tres plus a body in BugBuilder, no core code.

enum Behavior { SWARM, TANK, LEAPER, SPITTER }

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
