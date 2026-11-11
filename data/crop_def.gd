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
## What a harvest adds to the stockpile, e.g. {&"corn": 3}.
@export var harvest: Dictionary = {}
@export var color: Color = Color.WHITE
## The seed item it's planted from (bought at the airship market), e.g. &"seed_corn".
@export var seed_item: StringName = &""
## What this crop is FOR, one short line (field guide, seed shop). Each crop has a job:
## corn is fast cheap scrap, pear is slow but heals, chili is mortar ammo and sells
## for chitin, herbs are medicine.
@export var role: String = ""
## Turret ammo (farming redesign): turret loads one harvest gives. One load arms
## one crop-fed turret (TurretDef.crop_type == id) for a whole wave.
@export var loads_per_harvest: int = 0
## The load item a harvest adds to the stockpile ("corn_load"). Not sold anywhere.
@export var load_item: StringName = &""
## What a sack of this crop does in a crop-fed turret, for prompts ("any crop-fed turret (Ricochet)").
@export var turret_family: String = ""


## What one harvest gives: the raw crops (they go in the harvester's carry,
## PlayerCarry; the ammo workbench turns each into 3 sacks), and the pear's
## water. (Nov 11 playtest fixes: harvests no longer fill ammo sacks;
## loads_per_harvest is unused now.)
func harvest_out() -> Dictionary:
	var out := {}
	for k: Variant in harvest:
		out[k] = int(out.get(k, 0)) + int(harvest[k])
	return out
