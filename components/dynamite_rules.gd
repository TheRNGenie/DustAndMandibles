class_name DynamiteRules
extends RefCounted
## The grapple's dynamite (Logan's request): the rules in one place, with no
## nodes or networking, so they can be unit-tested. Dynamite (the hand and the
## throw), DynamiteBundle (the lit bundle in flight), the gunsmith and the HUD
## all ask here.
##
## The gunsmith's "Powder Satchel" upgrade for the grapple hook unlocks it: with
## the launcher out, R raises a bundle of three sticks in the left hand, R again
## strikes it on the match strip down the launcher's side and lobs it at the
## reticle. The state travels as a WeaponMods code under WeaponMods `&"dynamite"`
## (level 1 = the satchel is bought; bits 2-4 the three workshop mods).

const ID := &"dynamite"
## Chitin for the Powder Satchel (a mid-price gun: the flare gun is 40, the
## blunderbuss 45); the satchel holds MAX_BUNDLES.
const SATCHEL_COST := 50
const MAX_BUNDLES := 3
## Bundles come back one at a time while you're up top (not down on the canyon
## floor), and the satchel is topped up whenever a wave is held.
const RESTOCK_SECS := 40.0

## The blast: full damage at the centre falling to EDGE_FRACTION at the rim.
## Moderate-to-high: a Dynamite Lobber shell is 45 in 3.5 m; a lever rifle round
## is 48. A bundle kills a wolf spider anywhere short of the rim and a rattler
## beetle near the middle, and cracks armour.
const DAMAGE := 160.0
const RADIUS := 6.5
const EDGE_FRACTION := 0.35
## Players (the thrower too) inside the blast are blown about, never hurt:
## player explosives don't harm players or structures, like every turret's
## splash. At the middle it's KNOCK rocks' worth of shove (a thrown rock is 1:
## Player.bonk), falling off to a third of that at the rim, with a short small
## ragdoll: STAGGER seconds of barely-answering legs, the view tumbling.
const KNOCK := 3.0
const STAGGER := 0.9

## The throw: lands where you aim, out to THROW_RANGE (far enough to reach the
## far wall across the Canyon's 45 m gap from your lip); further than that, it's
## lobbed THROW_RANGE along your aim and keeps falling. Flight time grows with
## distance so a long throw arcs high.
const THROW_RANGE := 60.0
const GRAVITY := 18.0
const MIN_FLIGHT := 0.55
const FLIGHT_PER_M := 0.022
## After it lands, the fuse burns this much longer before it goes up; a bundle
## that never lands goes up when the whole fuse is gone.
const SETTLE_FUSE := 0.35
const MAX_FUSE := 4.5
## Hand timing (seconds): raise, the strike along the strip, the wind-up to the
## release, and the beat before the next bundle can come up.
const RAISE_TIME := 0.32
const STRIKE_TIME := 0.34
const WINDUP_TIME := 0.3
const COOLDOWN := 0.9

## Noise (Canyon Expeditions): the loudest thing in the game by far (gunshots
## carry 45 m, kickers 70 m, a booby trap 40 m), and it lands hard on the risk
## clock of anyone down there who hears it.
const NOISE := 150.0
const NOISE_HEAT := 15.0
## Sleepers it wakes come to look where it went off (they still keep to their
## leash); seconds they go on looking before giving up.
const LURE_SECS := 12.0
## On the cliffs: climbers this close to the blast who live through it are
## shaken off their line for a moment (stunned).
const CLIMBER_STUN := 0.8

## The three workshop mods (WeaponMods `&"dynamite"` lists them).
const MOD_BIGGER := 0
const MOD_HEAVIER := 1
const MOD_COAL_OIL := 2
## Coal Oil: what survives the blast burns, this much a second for this long.
const BURN_DPS := 14.0
const BURN_SECS := 5.0


## Has this code got the Powder Satchel?
static func unlocked(code: int) -> bool:
	return WeaponMods.level(code) >= 1


static func radius_for(code: int) -> float:
	return RADIUS * WeaponMods.mult(ID, code, "radius")


static func damage_for(code: int) -> float:
	return DAMAGE * WeaponMods.mult(ID, code, "damage")


## Damage to something `dist` metres from the centre (0 outside the blast).
## `body` is the bug's own radius, so a big bug's flank inside the blast counts.
static func damage_at(code: int, dist: float, body: float = 0.0) -> float:
	var r := radius_for(code)
	var d := maxf(dist - body, 0.0)
	if d > r:
		return 0.0
	return damage_for(code) * lerpf(1.0, EDGE_FRACTION, d / r)


static func burns(code: int) -> bool:
	return WeaponMods.flag(ID, code, "burn")


## Bundles after `secs` of restocking from `have` (with `carry` the clock's
## leftover): returns [bundles, leftover clock].
static func restock(have: int, carry: float, secs: float) -> Array:
	if have >= MAX_BUNDLES:
		return [MAX_BUNDLES, 0.0]
	var t := carry + secs
	while t >= RESTOCK_SECS and have < MAX_BUNDLES:
		t -= RESTOCK_SECS
		have += 1
	return [have, t if have < MAX_BUNDLES else 0.0]


## Where the throw goes: `hit` is where the aim ray meets something (null if it
## doesn't within THROW_RANGE); else a point THROW_RANGE along the aim.
static func throw_target(origin: Vector3, aim: Vector3, hit: Variant) -> Vector3:
	if hit is Vector3 and origin.distance_to(hit) <= THROW_RANGE:
		return hit
	return origin + aim.normalized() * THROW_RANGE


static func flight_time(origin: Vector3, target: Vector3) -> float:
	return MIN_FLIGHT + origin.distance_to(target) * FLIGHT_PER_M


## Launch velocity that carries a bundle from `origin` to `target` in `t`
## seconds under GRAVITY (a lob: it rises and drops onto the spot).
static func launch_velocity(origin: Vector3, target: Vector3, t: float) -> Vector3:
	t = maxf(t, 0.05)
	var v := (target - origin) / t
	v.y += 0.5 * GRAVITY * t
	return v


## Position of a bundle `t` seconds after leaving `origin` at `vel`.
static func arc_point(origin: Vector3, vel: Vector3, t: float) -> Vector3:
	return origin + vel * t + Vector3.DOWN * 0.5 * GRAVITY * t * t


## A throw request is believable: the origin is near where the host sees the
## thrower, and no faster than a hard throw.
static func valid_throw(origin: Vector3, player_pos: Vector3, vel: Vector3) -> bool:
	if origin.distance_to(player_pos + Vector3.UP * 1.5) > 4.0:
		return false
	return vel.length() <= max_throw_speed()


static func max_throw_speed() -> float:
	# The longest, highest lob: THROW_RANGE straight up/out in its flight time,
	# plus room for a throw from a fast swing.
	var t := MIN_FLIGHT + THROW_RANGE * FLIGHT_PER_M
	return THROW_RANGE / t + 0.5 * GRAVITY * t + 30.0


## How hard a player `dist` metres from the blast is knocked (0..1; 0 outside it).
static func knock_strength(dist: float, radius: float) -> float:
	if dist >= radius:
		return 0.0
	return lerpf(1.0, 0.33, clampf(dist / maxf(radius, 0.01), 0.0, 1.0))


## Extra risk seconds for someone `dist` metres from a blast (0 out of earshot),
## within the risk clock's cap (ExpeditionRules.MAX_HEAT).
static func noise_heat(dist: float, heat_now: float) -> float:
	if dist > NOISE:
		return 0.0
	return clampf(NOISE_HEAT, 0.0, maxf(ExpeditionRules.MAX_HEAT - heat_now, 0.0))
