class_name GunRules
extends RefCounted
## The frontier guns' specials (WeaponDef.special), as plain rules: what a
## harpoon does to what it hits, how long a flare marks a bug and how much a
## turret wants it, how far rock salt knocks a climber down the wall, who the
## Bee Smoker's cloud makes drowsy, Telescope Rifle crits, the Punt Gun's kick
## and the smoker's self-refilling fuel. Host-side effects are applied by
## PlayerNet; everything here is typed loosely (any object with Bug's fields and
## methods) so tests run it on stand-in bugs.

# ------------------------------------------------------------------ held model

## Guns whose model steps out of view while you look through their glass.
const SCOPED: Array[StringName] = [&"elephant_gun", &"dino_rifle", &"telescope_rifle"]


## Is the model of the last gun drawn showing? Not while an item or empty hands
## are out (Gun.holding), nor while you look through its glass.
static func model_shown(holding: StringName, scoped: bool) -> bool:
	return holding == &"" and not scoped


# ------------------------------------------------------------------ harpoon

enum Harpoon { NONE, REEL, PULL }

## Ground and flying bugs reeled in stop this far in front of you.
const REEL_STOP := 2.5
## Reeled bugs hang on the line (rooted) this long.
const REEL_HOLD := 1.0


## What a harpoon does: a small bug is reeled in to you (yanked off a wall); a
## heavy bug, a boss or rock pulls YOU to it (the grapple's pull); a miss does nothing.
static func harpoon_action(hit_bug: bool, hit_world: bool, heavy: bool = false, boss: bool = false) -> int:
	if hit_bug:
		return Harpoon.PULL if heavy or boss else Harpoon.REEL
	return Harpoon.PULL if hit_world else Harpoon.NONE


## The harpoon decision for a bug (its kind decides: TurretDef.is_heavy, or a boss).
static func harpoon_for_bug(b: Object) -> int:
	return harpoon_action(true, false, TurretDef.is_heavy(b.get("def") as BugDef), b.get("boss") != null)


## Where a reeled-in bug on the ground (or in the air) ends up: REEL_STOP short
## of the shooter along the line, never pushed further away than it was.
static func reel_point(bug_pos: Vector3, shooter_pos: Vector3) -> Vector3:
	var off := bug_pos - shooter_pos
	if off.length() <= REEL_STOP:
		return bug_pos
	return shooter_pos + off.normalized() * REEL_STOP


# ------------------------------------------------------------------ signal flare

## Seconds a flare marks a bug (and burns where it lands).
const MARK_TIME := 6.0
## Added to a marked bug's turret score: bigger than any climb-height score, so
## every turret that may shoot it does, before anything else.
const MARK_BONUS := 100000.0
## How far a burning flare lights the dark (turrets see through dust and night there).
const FLARE_LIGHT_RADIUS := 16.0


static func mark_bonus(marked: bool) -> float:
	return MARK_BONUS if marked else 0.0


# ------------------------------------------------------------------ rock salt

## Metres a climber slides down the wall per salt shot (heavy bugs less; bosses
## only BOSS_SLIP and at most once per the shared water-slip gap).
const SALT_SLIP := 3.5
const SALT_HEAVY_SLIP := 1.5
## The flinch: a moment stuck before it finds its grip again.
const SALT_FLINCH := 0.35


## Host: one salt shot hit this bug (once per shot, however many grains landed).
## Returns the metres it slid.
static func salt_hit(b: Object) -> float:
	if not bool(b.call("is_climbing")):
		return 0.0
	var boss := b.get("boss") != null
	var slip := 0.0
	if boss:
		slip = SpecialShotRules.slip_for(b, SALT_HEAVY_SLIP)
	elif TurretDef.is_heavy(b.get("def") as BugDef):
		slip = SALT_HEAVY_SLIP
	else:
		slip = SALT_SLIP
	var y := float(b.get("climb_y"))
	slip = minf(slip, y)
	b.set("climb_y", y - slip)
	if not boss:
		b.get("status").call("root", SALT_FLINCH)
	return slip


# ------------------------------------------------------------------ bee smoke

## The cloud: a cone this wide reaching this far from the spout.
const SMOKE_REACH := 10.0
const SMOKE_HALF_ANGLE := 24.0
## Drowsy bugs move at this share of their speed (bosses shrug most of it off).
const SMOKE_SLOW := 0.3
const SMOKE_BOSS_SLOW := 0.75
## Seconds a puff keeps them drowsy, plus this much per upgrade level.
const SMOKE_TIME := 2.5
const SMOKE_TIME_PER_LEVEL := 0.75
## Drowsy fliers sink this many metres a second.
const DROWSY_SINK := 2.5
## Spiders (and the hive's bees, who know what smoke means).
const SMOKE_KINDS: Array[StringName] = [&"wolf_spider", &"spiderling", &"brood_mother", &"queen_spider", &"hive_drone"]


## Does smoke get to this kind of bug? Fliers and spiders do; beetles don't care.
static func smokeable(def: BugDef) -> bool:
	return def != null and (def.behavior == BugDef.Behavior.FLIER or SMOKE_KINDS.has(def.id))


static func in_smoke(muzzle: Vector3, axis: Vector3, p: Vector3, reach: float = SMOKE_REACH) -> bool:
	return SpecialShotRules.in_cone(muzzle, axis.normalized(), p, SMOKE_HALF_ANGLE, reach)


## Host: a puff reached this bug. Returns true if it went drowsy.
static func smoke_hit(b: Object, level: int = 0) -> bool:
	if not smokeable(b.get("def") as BugDef):
		return false
	var factor := SMOKE_BOSS_SLOW if b.get("boss") != null else SMOKE_SLOW
	b.get("status").call("smoke", factor, SMOKE_TIME + SMOKE_TIME_PER_LEVEL * level)
	return true


## Bee Smoker fuel (0..max): it smoulders back up once you stop puffing.
const FUEL_DELAY := 0.6
const FUEL_REFILL := 22.0


static func refill(fuel: float, idle: float, delta: float, level: int, max_fuel: float) -> float:
	if idle < FUEL_DELAY:
		return fuel
	return minf(fuel + FUEL_REFILL * (1.0 + 0.25 * level) * delta, max_fuel)


# ------------------------------------------------------------------ crits and kick

## Damage multiplier on top of the weak spot's own for a gun's weak-spot hit.
static func crit_mult(weak_bonus: float, weak: bool) -> float:
	return weak_bonus if weak and weak_bonus > 1.0 else 1.0


## The Punt Gun's shove: back along the shot, mostly flat, with a little lift
## so it carries you instead of grinding you into the ground.
static func kick_velocity(aim_dir: Vector3, kickback: float) -> Vector3:
	if kickback <= 0.0:
		return Vector3.ZERO
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
	var back := -flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	# Shooting straight down blows you up; straight up pushes you down a little.
	return back * kickback * (0.35 + 0.65 * flat.length()) + Vector3.UP * (2.0 - aim_dir.y * kickback * 0.4)


# ------------------------------------------------------------------ Repeating Crossbow

## Bleed (Nov 10 primary weapons evaluation): each bolt that sticks bleeds
## BLEED_DPS for BLEED_TIME s, stacking up to BLEED_STACKS (Barbed Heads: more).
const BLEED_DPS := 3.0
const BLEED_TIME := 4.0
const BLEED_STACKS := 5
## Hollow Bolts: direct damage on a bug that's already bleeding.
const HOLLOW_MULT := 1.6


static func bleed_stacks(id: StringName, code: int) -> int:
	return BLEED_STACKS + WeaponMods.add(id, code, "stacks")


## The Hollow Bolts multiplier for a hit (1 unless the gun has the mod and the bug bleeds).
static func hollow_mult(def: WeaponDef, code: int, hit: Dictionary) -> float:
	if def.special != &"bleed" or hit.is_empty() or not WeaponMods.flag(def.id, code, "hollow"):
		return 1.0
	var hb := hit.get("collider") as Hitbox
	var bug: Variant = hb.target if hb != null else null
	if bug == null or not is_instance_valid(bug) or bug.get("status") == null:
		return 1.0
	return HOLLOW_MULT if bug.status.poison_stacks() > 0 else 1.0


# ------------------------------------------------------------------ Coach Shotgun slugs

## The Coach Shotgun's slug mode (Nov 10 primary weapons evaluation): hold R to
## switch. A code bit, so the shot carries it to the host (PlayerNet trusts it:
## a sidegrade, not a buff to check).
const SLUG_BIT := 1 << 11
const SLUG_DAMAGE := 90.0
const SLUG_RANGE := 100.0


static func is_slug(id: StringName, code: int) -> bool:
	return id == &"coach_shotgun" and code & SLUG_BIT != 0


static func toggle_slug(code: int) -> int:
	return code ^ SLUG_BIT

