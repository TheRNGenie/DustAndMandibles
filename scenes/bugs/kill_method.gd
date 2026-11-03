extends RefCounted
## Sorts a damage source ("Logan's Chili Mortar", a player's name, "Lightning")
## into the kill method it counts as. Kill tallies and variant weaknesses are
## keyed by these. Load with preload("res://scenes/bugs/kill_method.gd").

const BULLET := &"bullet"
const FIRE := &"fire"
const BLAST := &"blast"
const TRAP := &"trap"
const OTHER := &"other"
## How each method reads to players.
const WORDS := {BULLET: "bullets", FIRE: "fire", BLAST: "explosives", TRAP: "traps", OTHER: "other means"}

static var _cache: Dictionary = {}


## The kill method a damage source counts as (cached: sources repeat a lot).
static func of(source: String) -> StringName:
	var known: Variant = _cache.get(source)
	if known != null:
		return known
	var m := classify(source)
	if _cache.size() > 256:
		_cache.clear()
	_cache[source] = m
	return m


static func classify(source: String) -> StringName:
	if source == "" or source == "test" or source == "debug" or source == "Lightning":
		return OTHER
	var low := source.to_lower()
	if low.ends_with("bear trap"):
		return TRAP
	if low.ends_with("dynamite crate"):
		return BLAST
	for id: StringName in Defs.TURRETS:
		var t := Defs.turret(id)
		if source.ends_with(t.display_name):
			match t.effect:
				TurretDef.Effect.HITSCAN:
					return BULLET
				TurretDef.Effect.BURN:
					return FIRE
				TurretDef.Effect.SPLASH:
					return BLAST
				TurretDef.Effect.PIN:
					return TRAP
			return OTHER
	# Crafted turrets ("Logan's Swivel Brush Peppergun"): by their effect.
	if source.contains("Long Tom") or source.contains("Peppergun") or source.contains("Thumper") or source.contains("Hose"):
		if source.contains("Brush"):
			return FIRE
		if source.contains("Dynamite") or source.contains("Thumper"):
			return BLAST
		return BULLET
	# Players' guns and whips carry the player's own name.
	return BULLET
