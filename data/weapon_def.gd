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
@export var sound: StringName = &"revolver"
