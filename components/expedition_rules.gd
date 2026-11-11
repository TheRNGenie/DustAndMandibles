class_name ExpeditionRules
extends RefCounted
## Canyon Expeditions: the rules in one place, with no nodes or networking, so
## they can be unit-tested. The Expedition autoload, GameState's levers, the
## turrets and the rope anchors all ask here.

## Seconds on the rope, either way.
const RIDE_TIME := 8.0
## The airship's fare for hauling you up (chitin, out of your stockpile).
const AIRSHIP_FARE := 5
## Seconds between hailing the airship and its hook reaching you, then the lift.
const HAIL_WAIT := 3.0
const HAUL_TIME := 4.0
## Risk clock (seconds down this build phase, plus noise): the ground starts to
## rumble at RUMBLE_AT, and from HUNT_AT awake bugs come out of the nearest tunnel.
const RUMBLE_AT := 45.0
const HUNT_AT := 80.0
## Seconds between rumbles, and between packs of hunters.
const RUMBLE_EVERY := 9.0
const HUNT_EVERY := 20.0
## Most hunters after one player at once.
const MAX_HUNTERS := 6
## A gunshot near you on the floor adds this much to your risk clock (capped).
const SHOT_HEAT := 4.0
const MAX_HEAT := 40.0
## How far a gunshot carries (m) by default, and for the loud ones.
const GUN_NOISE := 45.0
const LOUD_GUN_NOISE := 70.0
## Hunter bugs: what comes out, and how fast they run (x their walk speed).
const HUNTER_BUGS: Array[StringName] = [&"wolf_spider", &"dust_mite", &"dust_mite"]
const HUNTER_SPEED := 1.3
## How close a hunter gets before it bites.
const HUNTER_REACH := 1.6


## Can `peer` throw their lever? Not while they're down in the canyon.
static func can_throw_lever(peer: int, down: Dictionary) -> bool:
	return not down.has(peer)


## May the ready countdown start (or keep running)? Not while anyone is down.
static func countdown_allowed(down: Dictionary) -> bool:
	return down.is_empty()


## How far a shot from this gun carries. The Bee Smoker only hisses.
static func gun_noise(special: StringName, kickback: float, pellets: int) -> float:
	if special == &"smoke" or special == &"bleed": # (the Repeating Crossbow is near silent)
		return 0.0
	if kickback > 0.0 or pellets > 4:
		return LOUD_GUN_NOISE
	return GUN_NOISE


## 0 quiet, 1 the ground rumbles, 2 hunters come.
static func risk_stage(risk_secs: float) -> int:
	if risk_secs >= HUNT_AT:
		return 2
	if risk_secs >= RUMBLE_AT:
		return 1
	return 0


## How many hunters the next pack brings (more the longer you stay), never
## past MAX_HUNTERS alive.
static func hunters_to_send(risk_secs: float, alive: int) -> int:
	if risk_stage(risk_secs) < 2:
		return 0
	var want := 2 + int((risk_secs - HUNT_AT) / 40.0)
	return clampi(want, 0, maxi(MAX_HUNTERS - alive, 0))


## Extra risk seconds after a gunshot of `radius` at `dist` metres.
static func shot_heat(dist: float, radius: float, heat_now: float, heat: float = SHOT_HEAT) -> float:
	if radius <= 0.0 or dist > radius:
		return 0.0
	return clampf(heat, 0.0, maxf(MAX_HEAT - heat_now, 0.0))


## A dropped sack stays until the wave after the one it was dropped before ends.
static func sack_expired(drop_wave: int, wave_now: int) -> bool:
	return wave_now > drop_wave


## What was taken from `offer` when `left` stayed behind ({item: units}).
static func taken(offer: Dictionary, left: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in offer:
		var n := int(offer[k]) - int(left.get(k, 0))
		if n > 0:
			out[k] = n
	return out


## Story: [ordinary items, story items] of a backpack's contents.
static func split_story(items: Dictionary, story: Array) -> Array:
	var plain := {}
	var kept := {}
	for k: Variant in items:
		if story.has(StringName(k)):
			kept[StringName(k)] = int(items[k])
		else:
			plain[k] = items[k]
	return [plain, kept]


## Title Case item name for the HUD ("prickly_pear" -> "Prickly Pear").
static func item_name(item: StringName) -> String:
	if item == &"amber":
		return "Hive Amber" # AmberRules.NAME
	return ResNames.of(item).capitalize() # the two currencies under their player-facing names


## "12 Chitin, 3 Scrap".
static func describe(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: Variant in items:
		parts.append("%d %s" % [int(items[k]), item_name(StringName(k))])
	return ", ".join(parts)


## Rope ride position 0..1 (0 top) with a gentle start and stop.
static func ride_ease(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
