class_name Waterworks
extends RefCounted
## The homestead waterworks, as pure rules (unit-tested): every cliff has a well
## (a pump jack, MechWell, belted to the generator), a small generator with a big
## circuit-breaker lever, and a water tower, grouped together on the same side of
## the yard.
##
## Ready-up is physical: each player throws their own generator's lever (E there;
## the ready_up key still throws it from anywhere, unadvertised). Once every human's lever is thrown (CPU teammates throw
## theirs when they're done), the short countdown runs, the generators crank up,
## the well's pump jack runs and the wave comes. Pull your lever back during the
## countdown to call it off. When the wave ends the levers drop and the pumps stop.
##
## While its pump runs a water tower fills at FILL_PER_MIN up to TANK_MAX; its tap
## fills a bucket (TAP water) from what's stored.

## Water a tower gains per minute while its pump runs (tunable).
const FILL_PER_MIN := 5.0
## The most a tower holds.
const TANK_MAX := 100.0
## Water one bucket takes from the tap.
const TAP := 5
## Once the pumps are running the ground rumbles this long (light screen shake,
## dust out of every tunnel), then the bugs come out of the holes this much later.
## Together they are the warning phase ("Dust on the horizon").
const RUMBLE_TIME := 3.5
const EMERGE_DELAY := 2.5

## GameState.Phase values (kept here so this stays pure and loads without autoloads).
const PHASE_BUILD := 1
const PHASE_WARNING := 2
const PHASE_WAVE := 3

## Each cliff's waterworks look different (well and tower designs), in cliff order.
const STYLES: Array[StringName] = [&"timber", &"steel", &"adobe", &"trestle"]
const STYLE_NAMES := {&"timber": "Timber", &"steel": "Steel", &"adobe": "Adobe", &"trestle": "Trestle"}


static func style_of(cliff_id: int) -> StringName:
	return STYLES[posmod(cliff_id, STYLES.size())]


## A tower's level after `seconds` (scale: GameState.growth_scale for test runs).
static func fill(level: float, seconds: float, pump_on: bool, scale: float = 1.0) -> float:
	if not pump_on or seconds <= 0.0:
		return clampf(level, 0.0, TANK_MAX)
	return clampf(level + FILL_PER_MIN / 60.0 * seconds * scale, 0.0, TANK_MAX)


## How much a bucket gets from a tower holding `level` (whole units only).
static func tap_amount(level: float, want: int = TAP) -> int:
	return clampi(int(floorf(level + 0.0001)), 0, maxi(want, 0))


## Are the generators (and so the well pumps) running? From the wave's
## countdown until the wave is over.
static func pumps_on(phase: int, countdown: float) -> bool:
	if phase == PHASE_WARNING or phase == PHASE_WAVE:
		return true
	return phase == PHASE_BUILD and countdown >= 0.0


## Seconds of the warning phase (rumble + the pause before the bugs), and of the
## rumble itself. `time_scale` is GameState's (0.15 on --fast test runs, which are
## shortened but never below half).
static func warning_time(time_scale: float = 1.0) -> float:
	return (RUMBLE_TIME + EMERGE_DELAY) * maxf(time_scale, 0.5)


static func rumble_time(time_scale: float = 1.0) -> float:
	return RUMBLE_TIME * maxf(time_scale, 0.5)


## How hard the screen shakes `t` seconds into a rumble of `seconds` (0..peak):
## ramps in, holds, ramps out.
static func rumble_shake(t: float, seconds: float, peak: float = 0.32) -> float:
	if t < 0.0 or t > seconds or seconds <= 0.0:
		return 0.0
	var ramp := minf(seconds * 0.3, 1.0)
	return peak * minf(minf(t / ramp, (seconds - t) / ramp), 1.0)


## Every human has thrown their lever (CPU teammates never hold the wave up).
static func all_thrown(humans: Array, thrown: Dictionary) -> bool:
	if humans.is_empty():
		return false
	for id: Variant in humans:
		if not thrown.has(id):
			return false
	return true


## Which cliffs' levers are thrown, one per cliff:
##   thrown_peers  humans who have thrown theirs (peer ids)
##   cliff_of      peer id -> cliff
##   cpu_thrown    cliff -> true for CPU teammates that have thrown theirs
##   all_ready     every human is in (the levers of cliffs nobody holds follow it)
##   held          cliff -> true for cliffs a human or a CPU holds
static func levers(count: int, thrown_peers: Array, cliff_of: Dictionary, cpu_thrown: Dictionary,
		all_ready: bool, held: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	for cid in count:
		out.append(bool(cpu_thrown.get(cid, false)) or (all_ready and not held.has(cid)))
	for id: Variant in thrown_peers:
		var cid := int(cliff_of.get(id, -1))
		if cid >= 0 and cid < count:
			out[cid] = true
	return out


## Save data for one cliff's waterworks, cleaned up (older saves have none).
static func normalize_saved(raw: Variant, count: int) -> Dictionary:
	var out := {}
	var d: Dictionary = raw if raw is Dictionary else {}
	for cid in count:
		var c: Variant = d.get(str(cid), d.get(cid, {}))
		var cd: Dictionary = c if c is Dictionary else {}
		out[cid] = {"tank": clampf(float(cd.get("tank", 0.0)), 0.0, TANK_MAX), "lever": bool(cd.get("lever", false))}
	return out
