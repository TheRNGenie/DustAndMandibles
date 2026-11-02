class_name CoverageRules
extends RefCounted
## Pure helpers for turret coverage of a cliff wall (no nodes, unit tested):
## the heat-map colours and how climbing bugs lean toward weak spots.

## Each candidate's noise (0..1) is scaled by this before comparing, so a
## stretch covered by one turret fewer wins most of the time, not always.
const NOISE := 2.0


## Bugs' pick between wander targets: the least-covered one wins after a random
## nudge per candidate. A bias, not a beeline.
static func pick_weakest(cover: Array, noise: Array) -> int:
	var best := 0
	var best_score := INF
	for i in cover.size():
		var s := float(cover[i]) + float(noise[i]) * NOISE
		if s < best_score:
			best_score = s
			best = i
	return best


## Heat map colour for a turret count: none red, one amber, two or more green.
static func heat_color(n: int) -> Color:
	if n <= 0:
		return Color(1.0, 0.12, 0.32) # crimson: reads against the red rock
	if n == 1:
		return Color(1.0, 0.72, 0.18)
	return Color(0.35, 0.9, 0.38)


## How many arcs ([muzzle, pitch_limit_deg, range]) reach `point`.
static func count_covering(arcs: Array, point: Vector3) -> int:
	var k := 0
	for a: Array in arcs:
		if Targeting.in_arc(a[0], point, a[1], a[2]):
			k += 1
	return k
