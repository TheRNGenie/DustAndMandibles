class_name StructureDef
extends Resource
## A non-turret buildable: traps for breachers and survival structures.
## Placed on your own plateau behind the turret line.

enum Kind { BARBED_WIRE, BEAR_TRAP, DYNAMITE_CRATE, PALISADE, LANTERN, RAIN_CATCHER, FARM_PLOT }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: Kind = Kind.BARBED_WIRE
@export var cost_scrap: int = 10
@export var max_hp: float = 100.0
## Radius of effect (slow, root, blast, light), in metres.
@export var radius: float = 1.5
