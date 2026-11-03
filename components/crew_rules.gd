class_name CrewRules
extends RefCounted
## Crewed: the numbers and pure maths behind the four crewed guns (CrewedTurret):
## half power when nobody's in the seat, Big Bertha's spin-up and barrel heat, the
## Whaler's reel and drop, Thunder Mule's salvo pattern and shell arc, and the Sky
## Hound's proximity fuse. Kept free of nodes so the tests can check it.

## Left unmanned, a crewed gun fires at this fraction of its rate and damage.
const UNMANNED_MULT := 0.5

# ---------------------------------------------------------------- Big Bertha
## Seconds of holding the trigger to reach full spin.
const SPIN_UP_TIME := 0.9
## Seconds for the barrels to wind down from full spin.
const SPIN_DOWN_TIME := 1.4
## She starts firing once the barrels are this fast (fire rate scales with spin).
const SPIN_FIRE_MIN := 0.25
## Heat added per round (about 5 s of steady fire to overheat).
const HEAT_PER_SHOT := 0.012
## Heat lost per second when not firing, and while overheated.
const COOL_RATE := 0.3
const COOL_RATE_OVERHEATED := 0.45
## Overheated barrels must cool below this before she fires again.
const RESUME_HEAT := 0.3


## Barrel spin after `delta` seconds with the trigger held or not (0..1).
static func spin_step(spin: float, held: bool, delta: float) -> float:
	if held:
		return minf(spin + delta / SPIN_UP_TIME, 1.0)
	return maxf(spin - delta / SPIN_DOWN_TIME, 0.0)


## Seconds between rounds at this spin (no fire below SPIN_FIRE_MIN: returns INF).
static func spin_interval(base_interval: float, spin: float) -> float:
	if spin < SPIN_FIRE_MIN:
		return INF
	return base_interval / spin


## Heat after firing `rounds` rounds over `delta` (`firing`: the trigger is held
## and she's shooting, so no cooling). Returns [heat, overheated]: hitting 1.0
## overheats; overheated clears once the barrels cool to RESUME_HEAT.
static func heat_step(heat: float, overheated: bool, rounds: int, firing: bool, delta: float) -> Array:
	heat += HEAT_PER_SHOT * rounds
	if heat >= 1.0:
		heat = 1.0
		overheated = true
	if not firing or overheated:
		heat = maxf(heat - (COOL_RATE_OVERHEATED if overheated else COOL_RATE) * delta, 0.0)
	if overheated and heat <= RESUME_HEAT:
		overheated = false
	return [heat, overheated]


# ---------------------------------------------------------------- The Whaler
## Metres per second the reel drags a chained bug down the wall.
const REEL_SPEED := 3.0
## Damage per metre dragged, dealt when the chain lets go and the bug drops.
const DROP_DAMAGE_PER_M := 8.0


## Fall damage for a bug dragged `metres` down the wall at upgrade `tier`.
static func drop_damage(metres: float, tier: int) -> float:
	return maxf(metres, 0.0) * DROP_DAMAGE_PER_M * TurretDef.TIER_DAMAGE[clampi(tier, 0, TurretDef.MAX_TIER)]


## How far the reel pulls this tick: never below the canyon floor.
static func reel_step(climb_y: float, delta: float) -> float:
	return clampf(REEL_SPEED * delta, 0.0, maxf(climb_y, 0.0))


# ---------------------------------------------------------------- Thunder Mule
const SALVO := 3
## Seconds between the three shells leaving the tubes.
const SALVO_GAP := 0.18
## How far the shells scatter from the aim point, metres (along the wall, up the wall).
const SALVO_SPREAD := Vector2(2.6, 1.6)


## Where each shell of salvo number `seed_value` lands, as (along-wall, up-wall)
## offsets from the aim point. The first shell goes dead centre; the others
## land either side. Same answer on every peer for the same seed.
static func salvo_offsets(seed_value: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var out: Array[Vector2] = [Vector2.ZERO]
	for i in SALVO - 1:
		var side := -1.0 if i == 0 else 1.0
		out.append(Vector2(side * SALVO_SPREAD.x * rng.randf_range(0.7, 1.0), SALVO_SPREAD.y * rng.randf_range(-1.0, 1.0)))
	return out


## Top of a shell's arc (matches VfxPool.lob, so the preview line and the shell agree).
static func lob_peak(from: Vector3, to: Vector3) -> Vector3:
	return (from + to) * 0.5 + Vector3.UP * (6.0 + from.distance_to(to) * 0.1)


## Point `t` (0..1) along a shell's arc.
static func lob_point(from: Vector3, to: Vector3, t: float) -> Vector3:
	var peak := lob_peak(from, to)
	return from.lerp(peak, t).lerp(peak.lerp(to, t), t)


## Seconds in the air: a touch longer for far shots.
static func lob_time(distance: float) -> float:
	return clampf(0.9 + distance / 80.0, 1.0, 2.6)


## Tube elevation for a shot this far (degrees above horizontal), for the look.
static func lob_pitch_deg(distance: float, max_range: float) -> float:
	return lerpf(40.0, 62.0, clampf(distance / maxf(max_range, 1.0), 0.0, 1.0))


# ---------------------------------------------------------------- Sky Hound
## A shell bursts beside the first flier within this many metres of its path.
const FUSE_RADIUS := 4.5
## Seconds the black flak cloud hangs, how often it stings, and how hard (of a burst).
const CLOUD_TIME := 1.6
const CLOUD_TICK := 0.4
const CLOUD_DAMAGE := 0.15


## Index of the flier a shell from `origin` along `dir` would burst beside: the
## nearest one along the path within FUSE_RADIUS of it and within `max_range`.
## -1 if none.
static func fuse_index(origin: Vector3, dir: Vector3, fliers: Array, max_range: float) -> int:
	var best := -1
	var best_along := INF
	var d := dir.normalized()
	for i in fliers.size():
		var to: Vector3 = fliers[i] - origin
		var along := to.dot(d)
		if along <= 1.0 or along > max_range:
			continue
		if (to - d * along).length() <= FUSE_RADIUS and along < best_along:
			best_along = along
			best = i
	return best


# ---------------------------------------------------------------- aiming
## Clamp a manned aim (yaw relative to straight across, pitch above horizontal,
## both radians) to the gun's arcs: yaw within +-arc, pitch between -down and +up (degrees).
static func clamp_aim(rel_yaw: float, pitch: float, arc_deg: float, down_deg: float, up_deg: float) -> Vector2:
	var arc := deg_to_rad(arc_deg)
	return Vector2(clampf(wrapf(rel_yaw, -PI, PI), -arc, arc), clampf(pitch, -deg_to_rad(down_deg), deg_to_rad(up_deg)))
