class_name Defs
extends RefCounted
## Registry of every data definition, looked up by id.

const BUGS: Dictionary = {
	&"dust_mite": preload("res://data/bugs/dust_mite.tres"),
	&"wolf_spider": preload("res://data/bugs/wolf_spider.tres"),
	&"rattler_beetle": preload("res://data/bugs/rattler_beetle.tres"),
	&"spitter_scorpion": preload("res://data/bugs/spitter_scorpion.tres"),
	&"brood_mother": preload("res://data/bugs/brood_mother.tres"),
	&"spiderling": preload("res://data/bugs/spiderling.tres"),
	&"burrow_tick": preload("res://data/bugs/burrow_tick.tres"),
	&"dragonfly_bandit": preload("res://data/bugs/dragonfly_bandit.tres"),
	&"crop_weevil": preload("res://data/bugs/crop_weevil.tres"),
	&"iron_tumble": preload("res://data/bugs/iron_tumble.tres"),
}

const TURRETS: Dictionary = {
	&"gatling_post": preload("res://data/turrets/gatling_post.tres"),
	&"buffalo_rifle": preload("res://data/turrets/buffalo_rifle.tres"),
	&"water_cannon": preload("res://data/turrets/water_cannon.tres"),
	&"chili_mortar": preload("res://data/turrets/chili_mortar.tres"),
	&"dynamite_lobber": preload("res://data/turrets/dynamite_lobber.tres"),
	&"lasso_harpoon": preload("res://data/turrets/lasso_harpoon.tres"),
	&"scattergun_post": preload("res://data/turrets/scattergun_post.tres"),
	&"sharpshooter_tower": preload("res://data/turrets/sharpshooter_tower.tres"),
}

const STRUCTURES: Dictionary = {
	&"barbed_wire": preload("res://data/structures/barbed_wire.tres"),
	&"bear_trap": preload("res://data/structures/bear_trap.tres"),
	&"dynamite_crate": preload("res://data/structures/dynamite_crate.tres"),
	&"palisade": preload("res://data/structures/palisade.tres"),
	&"lantern_post": preload("res://data/structures/lantern_post.tres"),
	&"rain_catcher": preload("res://data/structures/rain_catcher.tres"),
	&"farm_plot": preload("res://data/structures/farm_plot.tres"),
	&"scaffold": preload("res://data/structures/scaffold.tres"),
}

const CROPS: Dictionary = {
	&"corn": preload("res://data/crops/corn.tres"),
	&"prickly_pear": preload("res://data/crops/prickly_pear.tres"),
	&"firecracker_chili": preload("res://data/crops/firecracker_chili.tres"),
	&"herbs": preload("res://data/crops/herbs.tres"),
}

## Build menu order: number keys 1-9 and 0, mouse wheel cycles through all.
const BUILD_ORDER: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon",
	&"chili_mortar", &"dynamite_lobber", &"lasso_harpoon", &"scaffold", &"scattergun_post", &"sharpshooter_tower", &"barbed_wire", &"bear_trap",
	&"dynamite_crate", &"palisade", &"lantern_post", &"rain_catcher", &"farm_plot"]

## Build menu (B) categories, in tab order.
const BUILD_CATEGORIES: Array[Dictionary] = [
	{"name": "Farming", "items": [&"farm_plot", &"rain_catcher"]},
	{"name": "Cliff Turrets", "items": [&"gatling_post", &"buffalo_rifle", &"water_cannon", &"chili_mortar",
		&"dynamite_lobber", &"lasso_harpoon", &"scaffold"]},
	{"name": "Tactical", "items": [&"barbed_wire", &"bear_trap", &"dynamite_crate", &"palisade", &"lantern_post"]},
	{"name": "Last Resorts", "items": [&"scattergun_post", &"sharpshooter_tower"]},
]

## Chitin cost of turret upgrade tiers 1, 2, 3.
const UPGRADE_COSTS: Array[int] = [10, 25, 50]

const WAVE_CONFIG: WaveConfig = preload("res://data/wave_config.tres")


static func bug(id: StringName) -> BugDef:
	return BUGS.get(id) as BugDef


static func turret(id: StringName) -> TurretDef:
	return TURRETS.get(id) as TurretDef


static func structure(id: StringName) -> StructureDef:
	return STRUCTURES.get(id) as StructureDef


static func crop(id: StringName) -> CropDef:
	return CROPS.get(id) as CropDef


static func is_turret(id: StringName) -> bool:
	return TURRETS.has(id)


static func cost_of(id: StringName) -> int:
	if TURRETS.has(id):
		return turret(id).cost_scrap
	if STRUCTURES.has(id):
		return structure(id).cost_scrap
	return 0


static func name_of(id: StringName) -> String:
	if TURRETS.has(id):
		return turret(id).display_name
	if STRUCTURES.has(id):
		return structure(id).display_name
	return String(id)
