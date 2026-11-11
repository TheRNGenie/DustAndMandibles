class_name WeaponMods
extends RefCounted
## Gunsmith mods: three one-off workshop jobs per weapon, on top of the
## +25%-damage level upgrades. Each changes how the gun handles, not just how
## hard it hits. A weapon's state travels as one int "code": bits 0-1 are its
## level (0-2), bits 2-4 the mods it carries, so a dropped, stored or picked-up
## gun keeps everything done to it, and the host can check every shot from it.
##
## fx keys: damage, fire_interval, reload, spread, range, spin_up, zoom, reach,
## stun, radius (all multipliers), mag, pellets (added), pierce, burn (bool). The whip uses
## the same scheme: every player carries one, with its own level and mods.

## Chitin per whip level.
const WHIP_LEVEL_COSTS: Array[int] = [10, 25]
## The whip's capstone: once it has both levels and all three mods, the
## gunsmith can gild it. Bit 5 of the code.
const GOLDEN_BIT := 1 << 5
const GOLDEN_COST := 60


static func is_golden(code: int) -> bool:
	return code & GOLDEN_BIT != 0


## Everything else on the whip is done, so it can be gilded.
static func can_gild(code: int) -> bool:
	return level(code) >= WHIP_LEVEL_COSTS.size() and count(code) >= 3 and not is_golden(code)

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
	# Coach Shotgun (Slug Toggle, Nov 10): one mod for slugs, one for buckshot, one for switching.
	&"coach_shotgun": [
		{"name": "Rifled bore", "desc": "Slugs: +25% damage and half again the range.", "cost": 15, "fx": {"slug_damage": 1.25, "slug_range": 1.5}},
		{"name": "Heavy buckshot", "desc": "Three more pellets in every buckshot shell.", "cost": 20, "fx": {"pellets": 3}},
		{"name": "Express loader", "desc": "Switch buckshot and slugs without losing the shells in it, and reload 25% faster.", "cost": 15, "fx": {"express": true, "reload": 0.75}},
	],
	&"elephant_gun": [
		{"name": "Ground glass", "desc": "A finer lens: aiming zooms in much further.", "cost": 30, "fx": {"zoom": 1.5}},
		{"name": "Cordite loads", "desc": "+20% damage.", "cost": 40, "fx": {"damage": 1.2}},
		{"name": "Ejector springs", "desc": "Spent cases pop out: reloads 30% faster.", "cost": 35, "fx": {"reload": 0.7}},
	],
	&"dino_rifle": [
		{"name": "Fresh twine", "desc": "Re-tied tight: the glass zooms in a third further.", "cost": 15, "fx": {"zoom": 1.3}},
		{"name": "Rhino loads", "desc": "+20% damage.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Stripper clip", "desc": "All four barrels load in one push: reloads 35% faster.", "cost": 25, "fx": {"reload": 0.65}},
	],
	# Nov 10 primary weapons evaluation.
	&"concussion_mortar": [
		{"name": "Packed powder", "desc": "A bigger charge: the blast reaches 40% wider.", "cost": 20, "fx": {"radius": 1.4}},
		{"name": "Brass casing", "desc": "Pre-loaded brass shells: reloads 35% faster.", "cost": 20, "fx": {"reload": 0.65}},
		{"name": "Incendiary filler", "desc": "Whatever the blast catches burns: 12 damage a second for 3 s.", "cost": 30, "fx": {"burn": true}},
	],
	&"repeating_crossbow": [
		{"name": "Barbed heads", "desc": "Bleed stacks up to 8 times, not 5.", "cost": 15, "fx": {"stacks": 3}},
		{"name": "Oiled ratchet", "desc": "Cycles bolts a quarter faster.", "cost": 15, "fx": {"fire_interval": 0.75}},
		{"name": "Hollow bolts", "desc": "+60% damage to a bug that's already bleeding.", "cost": 20, "fx": {"hollow": true}},
	],
	&"blunderbuss": [
		{"name": "Nail charge", "desc": "Six more pieces of scrap in every load.", "cost": 20, "fx": {"pellets": 6}},
		{"name": "Flared bell", "desc": "+20% damage, wider blast.", "cost": 20, "fx": {"damage": 1.2, "spread": 1.25}},
		{"name": "Paper cartridges", "desc": "Pre-measured charges: reloads 40% faster.", "cost": 25, "fx": {"reload": 0.6}},
	],
	# Frontier guns.
	&"derringer_pair": [
		{"name": "Hideout holsters", "desc": "Sleeve rigs: draws even faster and reloads 30% quicker.", "cost": 10, "fx": {"reload": 0.7}},
		{"name": "Rimfire magnums", "desc": "+25% damage.", "cost": 15, "fx": {"damage": 1.25}},
		{"name": "Longer barrels", "desc": "Shoot 10% harder and carry half again as far.", "cost": 15, "fx": {"damage": 1.1, "range": 1.5}},
	],
	&"pepperbox": [
		{"name": "Ground cones", "desc": "The cluster turns faster: fires 25% quicker.", "cost": 15, "fx": {"fire_interval": 0.75}},
		{"name": "Loading block", "desc": "All six charges at once: reloads 35% faster.", "cost": 15, "fx": {"reload": 0.65}},
		{"name": "Bored-true barrels", "desc": "Spread a third tighter.", "cost": 20, "fx": {"spread": 0.65}},
	],
	&"salt_shotgun": [
		{"name": "Coarse salt", "desc": "Three more grains in every shell.", "cost": 15, "fx": {"pellets": 3}},
		{"name": "Extended tube", "desc": "Holds two more shells.", "cost": 15, "fx": {"mag": 2}},
		{"name": "Slick pump", "desc": "Racks 30% faster.", "cost": 20, "fx": {"fire_interval": 0.7}},
	],
	&"harpoon_pistol": [
		{"name": "Whaler's line", "desc": "Half again as much line: reaches 50% further.", "cost": 20, "fx": {"range": 1.5}},
		{"name": "Stiffer spring", "desc": "+40% damage.", "cost": 15, "fx": {"damage": 1.4}},
		{"name": "Quick-load darts", "desc": "Reloads 40% faster.", "cost": 20, "fx": {"reload": 0.6}},
	],
	&"bee_smoker": [
		{"name": "Wider spout", "desc": "The cloud reaches 30% further.", "cost": 15, "fx": {"range": 1.3}},
		{"name": "Big can", "desc": "Fifty more puffs of fuel.", "cost": 15, "fx": {"mag": 50}},
		{"name": "Strong bellows", "desc": "Puffs 25% faster.", "cost": 20, "fx": {"fire_interval": 0.75}},
	],
	&"flare_gun": [
		{"name": "Magnesium flares", "desc": "+60% damage on the flare's strike.", "cost": 15, "fx": {"damage": 1.6}},
		{"name": "Quick breech", "desc": "Reloads 40% faster.", "cost": 20, "fx": {"reload": 0.6}},
		{"name": "Rifled bore", "desc": "Carries half again as far.", "cost": 15, "fx": {"range": 1.5}},
	],
	&"punt_gun": [
		{"name": "Swan shot", "desc": "Ten more pellets in the shell.", "cost": 25, "fx": {"pellets": 10}},
		{"name": "Brass shell", "desc": "Pre-loaded brass: reloads 35% faster.", "cost": 30, "fx": {"reload": 0.65}},
		{"name": "Choke ring", "desc": "A tighter cone that carries a third further.", "cost": 25, "fx": {"spread": 0.7, "range": 1.35}},
	],
	&"telescope_rifle": [
		{"name": "Ground lenses", "desc": "The spyglass zooms in a third further.", "cost": 20, "fx": {"zoom": 1.35}},
		{"name": "Match rounds", "desc": "+20% damage.", "cost": 30, "fx": {"damage": 1.2}},
		{"name": "Slick bolt", "desc": "Works the bolt 30% faster.", "cost": 30, "fx": {"fire_interval": 0.7}},
	],
	&"whip": [
		{"name": "Long lash", "desc": "Four more feet of plaited hide: reaches 40% further.", "cost": 15, "fx": {"reach": 1.4}},
		{"name": "Barbed popper", "desc": "A wire-wrapped tip: +50% damage.", "cost": 20, "fx": {"damage": 1.5}},
		{"name": "Snakeskin grip", "desc": "Lash again 40% sooner, and stuns last twice as long.", "cost": 20, "fx": {"fire_interval": 0.6, "stun": 2.0}},
	],
	# The grapple's dynamite (DynamiteRules): level 1 is the Powder Satchel.
	&"dynamite": [
		{"name": "Bigger Blast", "desc": "Fatter sticks, packed loose: the blast reaches 40% further.", "cost": 20, "fx": {"radius": 1.4}},
		{"name": "Heavier Charge", "desc": "Blasting gelatine instead of black powder: +40% damage.", "cost": 25, "fx": {"damage": 1.4}},
		{"name": "Coal Oil", "desc": "A rag soaked in coal oil round the sticks: whatever lives through the blast goes up in flames.", "cost": 25, "fx": {"burn": true}},
	],
	&"crank_gatling": [
		{"name": "Greased gears", "desc": "Winds up in less than half the time.", "cost": 20, "fx": {"spin_up": 0.4}},
		{"name": "Big drum", "desc": "Forty more rounds per drum.", "cost": 25, "fx": {"mag": 40}},
		{"name": "Water jacket", "desc": "Cooler barrels: fires 25% faster and tighter.", "cost": 30, "fx": {"fire_interval": 0.8, "spread": 0.7}},
	],
	# ---------------------------------------------------------------- Weapon Slots: primaries
	&"volcanic_repeater": [
		{"name": "Long tube", "desc": "Five more rounds in the magazine.", "cost": 20, "fx": {"mag": 5}},
		{"name": "Rocket balls", "desc": "Hotter loads: +20% damage.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Loading gate", "desc": "A side gate: reloads 35% faster.", "cost": 25, "fx": {"reload": 0.65}},
	],
	&"mares_leg": [
		{"name": "Big loop", "desc": "A loop you can spin: cycles 25% faster.", "cost": 20, "fx": {"fire_interval": 0.75}},
		{"name": "Heavy lead", "desc": "+20% damage.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Saddle scabbard", "desc": "Rides close to hand: reloads 25% faster.", "cost": 20, "fx": {"reload": 0.75}},
	],
	&"double_rifle": [
		{"name": "Express loads", "desc": "+20% damage.", "cost": 30, "fx": {"damage": 1.2}},
		{"name": "Auto ejectors", "desc": "The empties kick themselves out: reloads 30% faster.", "cost": 30, "fx": {"reload": 0.7}},
		{"name": "Regulated barrels", "desc": "Both barrels shoot to the same point: reaches a third further.", "cost": 25, "fx": {"range": 1.35}},
	],
	&"trench_broom": [
		{"name": "Buckshot", "desc": "Two more pellets in every shell.", "cost": 20, "fx": {"pellets": 2}},
		{"name": "Extended tube", "desc": "Two more shells in the tube.", "cost": 25, "fx": {"mag": 2}},
		{"name": "Slam fire", "desc": "Racks 25% faster.", "cost": 25, "fx": {"fire_interval": 0.75}},
	],
	&"ricochet_rifle": [
		{"name": "Hardened tips", "desc": "+20% damage, bounce or not.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Billiard sights", "desc": "Reaches a third further.", "cost": 20, "fx": {"range": 1.35}},
		{"name": "Showman's lever", "desc": "Cycles 25% faster.", "cost": 25, "fx": {"fire_interval": 0.75}},
	],
	&"howdah_pistol": [
		{"name": "Tiger's bite", "desc": "+20% damage.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Quick break", "desc": "Reloads 30% faster.", "cost": 25, "fx": {"reload": 0.7}},
		{"name": "Long barrels", "desc": "Reaches half again as far.", "cost": 20, "fx": {"range": 1.5}},
	],
	&"sharps_carbine": [
		{"name": "Paper cartridges", "desc": "Reloads 30% faster.", "cost": 20, "fx": {"reload": 0.7}},
		{"name": "Big Fifty loads", "desc": "+25% damage.", "cost": 25, "fx": {"damage": 1.25}},
		{"name": "Vernier sight", "desc": "Reaches a third further.", "cost": 20, "fx": {"range": 1.35}},
	],
	&"trapdoor_springfield": [
		{"name": "Heavy bullet", "desc": "+20% damage to every bug in the line.", "cost": 25, "fx": {"damage": 1.2}},
		{"name": "Quick latch", "desc": "Reloads 30% faster.", "cost": 25, "fx": {"reload": 0.7}},
		{"name": "Buckhorn sight", "desc": "Reaches a third further.", "cost": 20, "fx": {"range": 1.35}},
	],
	# ---------------------------------------------------------------- Weapon Slots: heavies
	&"swivel_gun": [
		{"name": "Grapeshot", "desc": "Ten more pellets in the charge.", "cost": 30, "fx": {"pellets": 10}},
		{"name": "Choke", "desc": "A 30% tighter cone that carries further.", "cost": 25, "fx": {"spread": 0.7, "range": 1.3}},
		{"name": "Powder horn", "desc": "Reloads 30% faster.", "cost": 30, "fx": {"reload": 0.7}},
	],
	# ---------------------------------------------------------------- Special weapons (slot 2; design doc numbers)
	&"crop_duster": [
		{"name": "Wider barrel", "desc": "+15 degrees of cone, 3 m less reach.", "cost": 10, "fx": {"spread": 1.43, "range": 0.7}},
		{"name": "Bigger canister", "desc": "Six more puffs (18).", "cost": 10, "fx": {"mag": 6}},
		{"name": "Finer grind", "desc": "+50% damage; the crop lasts a little longer.", "cost": 15, "fx": {"damage": 1.5, "linger": 1.25}},
	],
	&"barb_sling": [
		{"name": "Extra barbs", "desc": "Two more barbs a throw (7), a wider spread.", "cost": 10, "fx": {"pellets": 2, "spread": 1.3}},
		{"name": "Hardened tips", "desc": "+50% damage a barb.", "cost": 15, "fx": {"damage": 1.5}},
		{"name": "Quick pouch", "desc": "Reloads 30% faster.", "cost": 10, "fx": {"reload": 0.7}},
	],
	&"signal_flare": [
		{"name": "Magnesium core", "desc": "Burns 9 s instead of 6, and 30% hotter.", "cost": 15, "fx": {"burn_time": 1.5, "burn_dps": 1.3}},
		{"name": "Quick breech", "desc": "Reloads 35% faster.", "cost": 15, "fx": {"reload": 0.65}},
		{"name": "Tracer flare", "desc": "Half again the range.", "cost": 20, "fx": {"range": 1.5}},
	],
	&"crop_syringe": [
		{"name": "Concentrated dose", "desc": "The bug carries the crop 8 s, at 1.5x strength.", "cost": 15, "fx": {"carrier": 1.6, "dose": 1.5}},
		{"name": "Bigger reservoir", "desc": "Six needles a load.", "cost": 15, "fx": {"mag": 2}},
		{"name": "Pressurized chamber", "desc": "Half again the range; reloads 20% faster.", "cost": 20, "fx": {"range": 1.5, "reload": 0.8}},
	],
	&"smoke_bellows": [
		{"name": "Bigger can", "desc": "Fifty more puffs of fuel (150).", "cost": 10, "fx": {"mag": 50}},
		{"name": "Wider spout", "desc": "The cloud spreads 1.5 m wider (5.5 m).", "cost": 15, "fx": {"radius": 1.375}},
		{"name": "Dense smoke", "desc": "The cloud hangs 6 s, and bugs in it crawl at 40% speed.", "cost": 15, "fx": {"effect": 1.5, "slow": 0.8}},
	],
	&"bramble_pistol": [
		{"name": "Extra bounce", "desc": "One more bounce (4) and 5 m more reach.", "cost": 15, "fx": {"bounces": 1, "range": 1.167}},
		{"name": "Heavier thorns", "desc": "+50% damage a bounce, 0.5 m wider.", "cost": 15, "fx": {"damage": 1.5, "radius": 1.25}},
		{"name": "Quick load", "desc": "Eight balls a load; reloads 25% faster.", "cost": 10, "fx": {"mag": 2, "reload": 0.75}},
	],
	&"spore_launcher": [
		{"name": "Bigger pods", "desc": "Bursts 1 m wider (4 m), 30% harder.", "cost": 15, "fx": {"radius": 1.333, "damage": 1.3}},
		{"name": "Sticky coating", "desc": "Pods stick to bugs and ride into the crowd.", "cost": 10, "fx": {"sticky": true}},
		{"name": "Quick tube", "desc": "Reloads 30% faster and holds four pods.", "cost": 15, "fx": {"reload": 0.7, "mag": 1}},
	],
	&"venom_needle": [
		{"name": "Hollow needle", "desc": "The crop lasts half again as long.", "cost": 15, "fx": {"linger": 1.5}},
		{"name": "Bigger reservoir", "desc": "Two needles before a reload.", "cost": 15, "fx": {"mag": 1}},
		{"name": "Coated tip", "desc": "The crop at 3x strength instead of 2x.", "cost": 20, "fx": {"dose": 1.5}},
	],
	&"trip_wire_gun": [
		{"name": "Reinforced wire", "desc": "Eight triggers instead of five; lasts 20 s.", "cost": 15, "fx": {"triggers": 3, "effect": 1.333}},
		{"name": "Barbed line", "desc": "+60% damage a trigger, and bugs it trips are slowed.", "cost": 15, "fx": {"damage": 1.6, "barbed": true}},
		{"name": "Quick anchors", "desc": "Reloads 30% faster; anchors 0.25 s apart.", "cost": 10, "fx": {"reload": 0.7, "fire_interval": 0.625}},
	],
	&"spark_pistol": [
		{"name": "Bigger coil", "desc": "Chains to 3 bugs instead of 2, 2 m further (7 m).", "cost": 20, "fx": {"chains": 1, "radius": 1.4}},
		{"name": "Overcharge", "desc": "+40% damage, and the chain hits as hard as the bolt.", "cost": 15, "fx": {"damage": 1.4, "chain_full": true}},
		{"name": "Rapid discharge", "desc": "Fires every 0.4 s; two more shots (10).", "cost": 15, "fx": {"fire_interval": 0.667, "mag": 2}},
	],
}


## Level (gun rarity, GunRarity: 0 Common .. 4 Legendary; the whip and the
## dynamite use 0-2). Bits 0-1, with bit 10 as the high bit for Legendary.
const LEVEL_HIGH_BIT := 1 << 10


static func level(code: int) -> int:
	return (code & 3) | (4 if code & LEVEL_HIGH_BIT != 0 else 0)


## `code` with its level set to `n`, everything else kept.
static func with_level(code: int, n: int) -> int:
	return (code & ~3 & ~LEVEL_HIGH_BIT) | (n & 3) | (LEVEL_HIGH_BIT if n & 4 != 0 else 0)


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
	return MODS.get(id, HeavyRules.MODS.get(id, [])) # (the universal heavies keep theirs in HeavyRules)


## Combined multiplier (or bonus) of every mod fitted, for one fx key.
static func mult(id: StringName, code: int, key: String) -> float:
	var m := AmberRules.finish_mult(id, code, key) # Hive amber: Lucky Moreau's finish (code bit 9)
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i) and (mods[i]["fx"] as Dictionary).has(key):
			m *= float(mods[i]["fx"][key])
	return m


static func add(id: StringName, code: int, key: String) -> int:
	var a := AmberRules.finish_add(id, code, key) # Lucky's finish
	var mods := list(id)
	for i in mods.size():
		if has_mod(code, i) and (mods[i]["fx"] as Dictionary).has(key):
			a += int(mods[i]["fx"][key])
	return a


static func flag(id: StringName, code: int, key: String) -> bool:
	if AmberRules.finish_flag(id, code, key): # Lucky's finish
		return true
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
