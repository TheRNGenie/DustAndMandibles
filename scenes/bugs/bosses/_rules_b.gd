extends RefCounted
## Pure rules shared by bosses 6-10 (no autoloads, so the headless tests can load it).

const COLLECTOR_GROW_STEP := 0.02
const COLLECTOR_MAX_GROW := 1.35


## Hive Wagon: how many drones a burst lets out: `want`, but never past `cap` alive.
static func burst_size(alive: int, want: int, cap: int) -> int:
	return clampi(cap - alive, 0, want)


## Stilt Strider: is it this turret's turn to shoot a knee? Half the turrets at a
## time, swapping every 3 s.
static func knee_turn(from: Vector3, t: float) -> bool:
	return (absi(int(from.x * 7.0) + int(from.z * 13.0)) + int(t / 3.0)) % 2 == 0


## Thunder Cicada: the middle of the tightest bunch of `points`: the point with
## the most others within `radius`, averaged with those neighbours.
static func densest(points: Array[Vector3], radius: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var best := 0
	var best_n := -1
	for i in points.size():
		var n := 0
		for j in points.size():
			if points[i].distance_to(points[j]) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = i
	var sum := Vector3.ZERO
	var c := 0
	for p in points:
		if p.distance_to(points[best]) <= radius:
			sum += p
			c += 1
	return sum / float(c)


## Bone Collector: its size after one more meal.
static func grown(g: float) -> float:
	return minf(g + COLLECTOR_GROW_STEP, COLLECTOR_MAX_GROW)
