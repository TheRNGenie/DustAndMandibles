class_name WeaponDef
extends Resource
## A player weapon. Bought (and upgraded) with chitin at the gun shop.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var damage: float = 25.0
@export var mag_size: int = 6
@export var fire_interval: float = 0.3
@export var reload_time: float = 1.4
## Shotguns fire several pellets, each a separate hitscan ray.
@export var pellets: int = 1
@export var spread_deg: float = 0.0
@export var range: float = 250.0
@export var pierce_armor: bool = false
## Chitin to buy it (0 = you start with it).
@export var price_chitin: int = 0
## Chitin per upgrade level (each: +25% damage, 15% faster reload).
@export var upgrade_costs: PackedInt32Array = PackedInt32Array([10, 25])
@export var shake: float = 0.15
## Hold the trigger to keep firing (the Crank Gatling).
@export var automatic: bool = false
## Seconds of cranking before an automatic weapon starts firing.
@export var spin_up: float = 0.0
@export var sound: StringName = &"revolver"

@export_group("Role feel")
## View kick per shot (degrees up, plus up to this much sideways at random).
## It eases back down over `recoil_recover` seconds.
@export var recoil_deg: float = 1.0
@export var recoil_yaw_deg: float = 0.2
@export var recoil_recover: float = 0.25
## Damage falloff: full damage up to falloff_start metres, easing to
## falloff_min x damage at falloff_end. Shotguns fall off fast; the rifle never does.
@export var falloff_start: float = 1000.0
@export var falloff_end: float = 1000.0
@export var falloff_min: float = 1.0
## Suppression: each hit slows the bug to this speed for `suppress_time` s (1 = none).
@export var suppress_slow: float = 1.0
@export var suppress_time: float = 0.0
## One-word job shown in the field guide and gun shop.
@export var role: String = ""


## Damage multiplier for a hit `dist` metres away.
func falloff(dist: float) -> float:
	if dist <= falloff_start or falloff_end <= falloff_start:
		return 1.0
	return lerpf(1.0, falloff_min, clampf((dist - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))
