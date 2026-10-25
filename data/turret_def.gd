class_name TurretDef
extends Resource
## One turret type. Turrets sit on your own cliff edge and only fire at the far cliff.

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
