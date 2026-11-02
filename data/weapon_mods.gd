class_name WeaponMods
extends RefCounted
## Gunsmith mods: three one-off workshop jobs per weapon, on top of the
## +25%-damage level upgrades. Each changes how the gun handles, not just how
## hard it hits. A weapon's state travels as one int "code": bits 0-1 are its
## level (0-2), bits 2-4 the mods it carries, so a dropped, stored or picked-up
## gun keeps everything done to it, and the host can check every shot from it.
##
## fx keys: damage, fire_interval, reload, spread, range, spin_up, zoom, reach,
## stun (all multipliers), mag, pellets (added), pierce (bool). The whip uses
## the same scheme: every player carries one, with its own level and mods.

## Chitin per whip level.
const WHIP_LEVEL_COSTS: Array[int] = [10, 25]

const MODS: Dictionary = {
	&"revolver": [
		{"name": "Hair trigger", "desc": "Filed sear and a lighter spring: fires a third faster.", "cost": 15, "fx": {"fire_interval": 0.66}},
		{"name": "Speed loader", "desc": "Rounds go in nearly twice as fast.", "cost": 15, "fx": {"reload": 0.55}},
		{"name": "Hollow points", "desc": "+20% damage, and they crack beetle armour.", "cost": 25, "fx": {"damage": 1.2, "pierce": true}},
	],
	&"lever_rifle": [
		{"name": "Long barrel", "desc": "+15% damage and half again the range.", "cost": 20, "fx": {"damage": 1.15, "range": 1.5}},
		{"name": "Magazine tube extension", "desc": "Holds four more rounds.", "cost": 15, "fx": {"mag": 4}},
		{"name": "Brass scope", "desc": "Aiming zooms in much further.", "cost": 20, "fx": {"zoom": 1.8}},
	],
	&"coach_shotgun": [
		{"name": "Full choke", "desc": "Tighter pattern that carries a third further.", "cost": 15, "fx": {"spread": 0.6, "range": 1.35}},
		{"name": "Heavy buckshot", "desc": "Three more pellets in every shell.", "cost": 20, "fx": {"pellets": 3}},
		{"name": "Sawn-off barrels", "desc": "Quicker second barrel and reloads, but a wider spray.", "cost": 15, "fx": {"fire_interval": 0.6, "reload": 0.75, "spread": 1.35}},
	],
	&"blunderbuss": [
		{"name": "Nail charge", "desc": "Six more pieces of scrap in every load.", "cost": 20, "fx": {"pellets": 6}},
		{"name": "Flared bell", "desc": "+20% damage, wider blast.", "cost": 20, "fx": {"damage": 1.2, "spread": 1.25}},
		{"name": "Paper cartridges", "desc": "Pre-measured charges: reloads 40% faster.", "cost": 25, "fx": {"reload": 0.6}},
	],
	&"whip": [
		{"name": "Long lash", "desc": "Four more feet of plaited hide: reaches 40% further.", "cost": 15, "fx": {"reach": 1.4}},
		{"name": "Barbed popper", "desc": "A wire-wrapped tip: +50% damage.", "cost": 20, "fx": {"damage": 1.5}},
		{"name": "Snakeskin grip", "desc": "Lash again 40% sooner, and stuns last twice as long.", "cost": 20, "fx": {"fire_interval": 0.6, "stun": 2.0}},
	],
	&"crank_gatling": [
		{"name": "Greased gears", "desc": "Winds up in less than half the time.", "cost": 20, "fx": {"spin_up": 0.4}},
		{"name": "Big drum", "desc": "Forty more rounds per drum.", "cost": 25, "fx": {"mag": 40}},
		{"name": "Water jacket", "desc": "Cooler barrels: fires 25% faster and tighter.", "cost": 30, "fx": {"fire_interval": 0.8, "spread": 0.7}},
	],
}


static func level(code: int) -> int:
	return code & 3


static func has_mod(code: int, i: int) -> bool:
	return (code >> (2 + i)) & 1 == 1


static func with_mod(code: int, i: int) -> int:
	return code | (1 << (2 + i))


static func count(code: int) -> int:
	var n := 0
	for i in 3:
		if has_mod(code, i):
			n += 1
	return n


static func list(id: StringName) -> Array:
	return MODS.get(id, [])


## Combined multiplier (or bonus) of every mod fitted, for one fx key.
static func mult(id: StringName, code: int, key: String) -> float:
	var m := 1.0
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i) and (mods[i]["fx"] as Dictionary).has(key):
			m *= float(mods[i]["fx"][key])
	return m


static func add(id: StringName, code: int, key: String) -> int:
	var a := 0
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i) and (mods[i]["fx"] as Dictionary).has(key):
			a += int(mods[i]["fx"][key])
	return a


static func flag(id: StringName, code: int, key: String) -> bool:
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i) and bool((mods[i]["fx"] as Dictionary).get(key, false)):
			return true
	return false


## Short text for the mods fitted, e.g. "Hair trigger, Speed loader".
static func names(id: StringName, code: int) -> String:
	var out: PackedStringArray = []
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i):
			out.append(str(mods[i]["name"]))
	return ", ".join(out)
