class_name AmberRules
extends RefCounted
## Hive amber: the resin the bugs make, which the railroad's board mines in
## secret (it burns hotter than coal and sets harder than iron). Pure rules and
## numbers, no nodes, so they can be unit-tested; the `Amber` autoload keeps the
## run's state (blueprints, favours) and AmberTurret / Bug apply the effects.
##
##   The item       `amber`: canyon-floor loot only (raid sites), weight 4 in the
##                  backpack, PERSONAL (each cliff's own pile, like chitin).
##   Lucky Moreau   a fence on the airship who takes nothing but amber.
##   The turrets    Amber Kiln, Queen's Bell, Mandible Lance: crafted at the
##                  Workshop from amber and rare parts once their blueprint is
##                  known; the team fields one of each at a time.

const ITEM := &"amber"
const WEIGHT := 4
const NAME := "Hive Amber"
const COLOR := Color("#E08A1C")
const GLOW := Color("#FFB838")
const DEEP := Color("#9A4A0E")

const KILN := &"amber_kiln"
const BELL := &"queens_bell"
const LANCE := &"mandible_lance"
const IDS: Array[StringName] = [KILN, BELL, LANCE]

## What crafting one takes (amber plus one mount, one barrel and one load).
const RECIPES: Dictionary = {
	KILN: {&"amber": 10, &"part_tripod": 1, &"part_cannon": 1, &"part_fire": 1},
	BELL: {&"amber": 12, &"part_post": 1, &"part_nozzle": 1, &"part_explosive": 1},
	LANCE: {&"amber": 14, &"part_tripod": 1, &"part_rifle": 1, &"part_acid": 1},
}

## Blueprint names (what the story and Lucky hand over).
const BLUEPRINTS: Dictionary = {
	KILN: "Blueprint: Amber Kiln",
	BELL: "Blueprint: Queen's Bell",
	LANCE: "Blueprint: Mandible Lance",
}
## Where the story finds each (for the Field Guide and the workshop's hint).
const FOUND_IN: Dictionary = {
	KILN: "the railroad strongroom (Story chapter 7)",
	BELL: "the board's ledger (Story chapter 9)",
	LANCE: "the Iron Mandible wreck (Story chapter 10)",
}


static func is_amber(id: StringName) -> bool:
	return IDS.has(id)


static func recipe(id: StringName) -> Dictionary:
	return (RECIPES.get(id, {}) as Dictionary).duplicate()


static func amber_cost(id: StringName) -> int:
	return int((RECIPES.get(id, {}) as Dictionary).get(ITEM, 0))


# ------------------------------------------------------------------ one of each

## The team fields at most one of each amber turret: built on any cliff plus
## the ready-made items waiting in any stockpile.
static func fielded(placed: int, held: int) -> int:
	return maxi(placed, 0) + maxi(held, 0)


## May one more be crafted?
static func can_craft_another(placed: int, held: int) -> bool:
	return fielded(placed, held) == 0


## May a held one be placed? (Nothing of its kind standing yet.)
static func can_place(placed: int) -> bool:
	return placed == 0


static func limit_text(id: StringName) -> String:
	return "The team can field only one %s at a time." % name_of(id)


static func name_of(id: StringName) -> String:
	match id:
		KILN:
			return "Amber Kiln"
		BELL:
			return "Queen's Bell"
		LANCE:
			return "Mandible Lance"
	return String(id)


# ------------------------------------------------------------------ floor loot

## Amber at a raid site after a refill: [chance, min, max] per site kind
## (SitePlan.Kind order: mouth, bone yard, camp, nest, wreck). Nests and wrecks
## are richer; a few more chips as the waves climb.
const SITE_AMBER: Array = [[0.35, 1, 2], [0.45, 1, 3], [0.3, 1, 2], [0.8, 2, 4], [0.65, 2, 3]]


## Units of amber a site holds this refill (0 = none), from its rng.
static func site_amber(site_kind: int, wave: int, rng: RandomNumberGenerator) -> int:
	var row: Array = SITE_AMBER[clampi(site_kind, 0, SITE_AMBER.size() - 1)]
	if rng.randf() >= float(row[0]):
		return 0
	return rng.randi_range(int(row[1]), int(row[2])) + (1 if wave >= 12 else 0)


# ------------------------------------------------------------------ Lucky Moreau

## Lucky turns up on the airship once the story is past chapter 4 (playing
## chapter 5 or later) or, in a normal run, from this wave.
const LUCKY_WAVE := 8
const LUCKY_CHAPTER := 5
const LUCKY_GREETING := "I hear the railroad lost a strongbox. Got anything shiny?"


## Is Lucky's stall open? `chapter_number` is the story chapter being played
## (0 = a normal run).
static func lucky_open(chapter_number: int, wave: int) -> bool:
	if chapter_number > 0:
		return chapter_number >= LUCKY_CHAPTER
	return wave >= LUCKY_WAVE


## Lucky's stock. kind: gun (a Lucky finish on one of the gunsmith's irons),
## look (an exclusive wardrobe option), favour (one night), blueprint.
const STOCK: Array[Dictionary] = [
	{"id": "gun:revolver", "kind": "gun", "gun": &"revolver", "price": 6},
	{"id": "gun:lever_rifle", "kind": "gun", "gun": &"lever_rifle", "price": 8},
	{"id": "gun:coach_shotgun", "kind": "gun", "gun": &"coach_shotgun", "price": 8},
	{"id": "gun:elephant_gun", "kind": "gun", "gun": &"elephant_gun", "price": 10},
	{"id": "look:paint:amber", "kind": "look", "slot": "paint", "option": "amber", "price": 5,
		"name": "Amber Lacquer", "desc": "Your dummy dipped in hive amber and polished to a glow. Nobody else on the frontier has it. Nobody honest, anyway."},
	{"id": "favour:supply", "kind": "favour", "favour": &"supply", "price": 4},
	{"id": "favour:bounty", "kind": "favour", "favour": &"bounty", "price": 5},
	{"id": "blueprint:amber_kiln", "kind": "blueprint", "turret": KILN, "price": 30},
	{"id": "blueprint:queens_bell", "kind": "blueprint", "turret": BELL, "price": 35},
	{"id": "blueprint:mandible_lance", "kind": "blueprint", "turret": LANCE, "price": 40},
]


static func stock_item(id: String) -> Dictionary:
	for s: Dictionary in STOCK:
		if str(s["id"]) == id:
			return s
	return {}


## One-night favours: paid now, delivered at the next dawn (the build phase
## after the next wave is held).
const FAVOURS: Dictionary = {
	&"supply": {"name": "Airship Supply Drop", "desc": "Next dawn the Lucky Mandible's crew kicks a crate off the deck for you: 8 water, 30 chitin, an upgrade token and corn seed.",
		"gives": {&"water": 8, &"chitin": 30, &"upgrade_token": 1, &"seed_corn": 3}},
	&"bounty": {"name": "Scrap Bounty Top-Up", "desc": "Lucky leans on the town council: next dawn's bounty pays the team pot an extra 250 scrap.",
		"gives": {&"scrap": 250}},
}


# ------------------------------------------------------------------ Lucky's gun finishes

## Bit 9 of a weapon's code (WeaponMods: bits 0-1 level, 2-4 mods, 5 the
## golden whip, 6-8 the Dino Rifle's glass): Lucky's finish.
const LUCKY_BIT := 1 << 9

## Each finish: a name and the fx it adds on top of the gun's own mods.
const FINISHES: Dictionary = {
	&"revolver": {"name": "Engraved Peacemaker", "desc": "Scrollwork, ivory grips and an amber-lacquered cylinder that never binds: +40% damage, reloads twice as fast, two more rounds.",
		"fx": {"damage": 1.4, "reload": 0.5, "mag": 2}},
	&"lever_rifle": {"name": "Amberstock Winchester", "desc": "A stock of solid hive amber and a hand-lapped bore: +35% damage, pierces armour, carries a third further.",
		"fx": {"damage": 1.35, "pierce": true, "range": 1.3}},
	&"coach_shotgun": {"name": "Gilded Coach Gun", "desc": "Gold-washed barrels, amber-set triggers: four more pellets and a quicker second barrel.",
		"fx": {"pellets": 4, "fire_interval": 0.7}},
	&"elephant_gun": {"name": "Maharaja's Express", "desc": "Engraved locks and amber-tipped rounds: +35% damage, reloads 30% faster.",
		"fx": {"damage": 1.35, "reload": 0.7}},
}


static func has_finish(id: StringName) -> bool:
	return FINISHES.has(id)


static func is_lucky(code: int) -> bool:
	return code & LUCKY_BIT != 0


static func with_lucky(code: int) -> int:
	return code | LUCKY_BIT


## The finish's multiplier for one fx key (1.0 when the gun has none).
static func finish_mult(id: StringName, code: int, key: String) -> float:
	if not is_lucky(code) or not FINISHES.has(id):
		return 1.0
	return float(((FINISHES[id] as Dictionary)["fx"] as Dictionary).get(key, 1.0))


static func finish_add(id: StringName, code: int, key: String) -> int:
	if not is_lucky(code) or not FINISHES.has(id):
		return 0
	var v: Variant = ((FINISHES[id] as Dictionary)["fx"] as Dictionary).get(key, 0)
	return int(v) if not v is bool else 0


static func finish_flag(id: StringName, code: int, key: String) -> bool:
	if not is_lucky(code) or not FINISHES.has(id):
		return false
	return bool(((FINISHES[id] as Dictionary)["fx"] as Dictionary).get(key, false))


## "Engraved Peacemaker" for a finished revolver, else "".
static func finish_name(id: StringName, code: int) -> String:
	if not is_lucky(code) or not FINISHES.has(id):
		return ""
	return str((FINISHES[id] as Dictionary)["name"])


# ------------------------------------------------------------------ Amber Kiln

## A bug the kiln's molten amber leaves below this share of its health is
## entombed (bosses never: they're slowed while the amber sets).
const ENTOMB_BELOW := 0.5
## How long a statue holds before the bug suffocates inside and it crumbles.
const STATUE_TIME := 24.0
## Bosses in the splash crawl at this speed for this long.
const BOSS_SET_SLOW := 0.3
const BOSS_SET_TIME := 4.0
## A shattered statue pays this on top of the kill: scrap per bug size, chitin.
const SHATTER_SCRAP_PER_SIZE := 4
const SHATTER_CHITIN := 2
## Crowd weight of a statue: nothing shoves it, everything is shoved off it
## (BugCrowd.STATUE_WEIGHT).


static func should_entomb(is_boss: bool, alive: bool, hp_fraction: float) -> bool:
	return alive and not is_boss and hp_fraction < ENTOMB_BELOW


static func shatter_loot(size: float) -> Dictionary:
	return {&"scrap": maxi(roundi(SHATTER_SCRAP_PER_SIZE * maxf(size, 0.5)), 1), &"chitin": SHATTER_CHITIN}


# ------------------------------------------------------------------ Queen's Bell

## Each toll: ordinary bugs in range turn on their neighbours this long,
## bosses are stunned this long, fliers drop out of the air.
const FRENZY_TIME := 6.0
const BOSS_STUN := 2.0
## A frenzied bug goes for anything within this reach (m) of it on the wall.
const FRENZY_REACH := 6.0
## Bite damage per second of a frenzied bug: its breach bite, at least this.
const FRENZY_MIN_DPS := 10.0
const FRENZY_DPS_MULT := 1.5
## A dropped flier: the fall takes this share of its health plus a flat bit,
## then it lies stunned this long.
const DROP_FRACTION := 0.45
const DROP_FLAT := 20.0
const DROP_STUN := 3.5


static func frenzy_dps(breach_dps: float, size: float) -> float:
	return maxf(breach_dps * FRENZY_DPS_MULT, FRENZY_MIN_DPS) * maxf(sqrt(maxf(size, 0.1)), 0.6)


static func drop_damage(max_hp: float) -> float:
	return max_hp * DROP_FRACTION + DROP_FLAT


## The bug a frenzied one goes for: the nearest other within FRENZY_REACH
## (positions on the wall, lane_z / climb_y). -1 when nobody's near.
static func frenzy_target(me: Vector2, others: Array[Vector2]) -> int:
	var best := -1
	var best_d := FRENZY_REACH
	for i in others.size():
		var d := me.distance_to(others[i])
		if d < best_d and d > 0.001:
			best_d = d
			best = i
	return best


# ------------------------------------------------------------------ Mandible Lance

## Seconds of beam before it overheats, then seconds of venting.
const LANCE_HOT := 8.0
const LANCE_VENT := 10.0
## Idle, the heat bleeds off this many seconds' worth per second.
const LANCE_COOL := 1.0
## How fast the beam's spot drags across the far wall (m/s): what it crosses burns.
const LANCE_DRAG := 9.0
## Bugs within this of the beam's spot, or of the beam line, are in it.
const LANCE_SPOT := 1.8
const LANCE_LINE := 0.9
## A burning patch every this many metres the spot moves (and every TRAIL_TIME s).
const TRAIL_STEP := 1.6
const TRAIL_TIME := 0.35
const TRAIL_RADIUS := 1.5
const TRAIL_SECONDS := 4.0
## Trail burn as a share of the beam's damage per second.
const TRAIL_SHARE := 0.2


## One step of the lance's heat: [heat, venting]. Firing adds heat; past
## LANCE_HOT it vents for LANCE_VENT (no fire) and comes back cold.
static func lance_heat(heat: float, venting: bool, firing: bool, delta: float) -> Array:
	if venting:
		heat -= delta * (LANCE_HOT / LANCE_VENT)
		if heat <= 0.0:
			return [0.0, false]
		return [heat, true]
	if firing:
		heat += delta
		if heat >= LANCE_HOT:
			return [LANCE_HOT, true]
		return [heat, false]
	return [maxf(heat - delta * LANCE_COOL, 0.0), false]


## Distance from point p to the segment a-b.
static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
