class_name TurretDef
extends Resource
## One turret type. Turrets sit on your own cliff edge and only fire at the far cliff.

enum Effect { HITSCAN, KNOCKBACK, BURN, SPLASH, PIN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost_scrap: int = 40
@export var max_hp: float = 150.0
@export var range: float = 80.0
## Seconds between shots.
@export var fire_interval: float = 0.15
@export var damage: float = 6.0
@export var armor_pierce: bool = false
## Furthest the barrel can aim below horizontal, in degrees.
@export var pitch_limit_deg: float = 30.0
## Degrees per second.
@export var turn_speed: float = 180.0
## Random aim error in degrees (cosmetic tracer spread; hits are rolled with hit_chance).
@export var spread_deg: float = 1.5
@export var hit_chance: float = 0.85
## What a hit does: plain damage, knock off the cliff, burning patch, splash, or pin in place.
@export var effect: Effect = Effect.HITSCAN
## Lobbed shots (mortar, dynamite) travel this long; 0 = instant hitscan.
@export var flight_time: float = 0.0
## Radius of splash / burning patch, or pin duration in seconds for PIN.
@export var effect_size: float = 0.0
## Last-line turret: shoots only bugs that made it onto YOUR plateau (breachers,
## surfaced ticks, bandits overhead), never anything on a cliff face.
@export var guards_plateau: bool = false
## House turret: mounts on the Homestead (porch, balcony, roof deck) and only shoots
## bugs on your plateau within Homestead.GUARD_RADIUS of the house.
@export var guards_house: bool = false
## Resources spent per shot from the owner's stockpile, e.g. {&"water": 2}.
@export var ammo_cost: Dictionary = {}
