class_name CropDef
extends Resource
## A crop: planted on a plot, watered once, then grows while watered.
## Unwatered crops pause; they never die.

@export var id: StringName = &""
@export var display_name: String = ""
## Seconds of (watered) growth from seed to ripe.
@export var grow_time: float = 180.0
## Water used when watering.
@export var water_cost: int = 1
## What a harvest adds to the stockpile, e.g. {&"food": 2}.
@export var harvest: Dictionary = {}
@export var color: Color = Color.WHITE
