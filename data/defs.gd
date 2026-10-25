class_name Defs
extends RefCounted
## Registry of every data definition, looked up by id.

const BUGS: Dictionary = {
	&"dust_mite": preload("res://data/bugs/dust_mite.tres"),
	&"wolf_spider": preload("res://data/bugs/wolf_spider.tres"),
	&"rattler_beetle": preload("res://data/bugs/rattler_beetle.tres"),
	&"spitter_scorpion": preload("res://data/bugs/spitter_scorpion.tres"),
}

const TURRETS: Dictionary = {
	&"gatling_post": preload("res://data/turrets/gatling_post.tres"),
	&"buffalo_rifle": preload("res://data/turrets/buffalo_rifle.tres"),
}

## Build menu order (number keys 1, 2, ...).
const TURRET_ORDER: Array[StringName] = [&"gatling_post", &"buffalo_rifle"]

const WAVE_CONFIG: WaveConfig = preload("res://data/wave_config.tres")


static func bug(id: StringName) -> BugDef:
	return BUGS.get(id) as BugDef


static func turret(id: StringName) -> TurretDef:
	return TURRETS.get(id) as TurretDef
