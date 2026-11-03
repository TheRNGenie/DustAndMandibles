class_name TierRules
extends RefCounted
## Tiers: the pure maths behind the Mid / Late turrets' specials (Hornet's Nest
## ricochets, Elephant Battery pierce, Rail Spike Driver lines) and the CPU's
## newest-tier-first pick. No autoloads, so the tests can call it headless.
## TurretEffects applies the results to real bugs.


## The unlocked ones of `ids` on `wave`, newest tier first (Late, Mid, Early),
## keeping the listed order within a tier.
static func best_first(ids: Array, wave: int) -> Array:
	var out: Array = []
	for t in range(TurretDef.ERA_NAMES.size() - 1, -1, -1):
		for id: StringName in ids:
			if Defs.tier_of(id) == t and Defs.is_unlocked(id, wave):
				out.append(id)
	return out


## Ricochet: from `start`, hop to the nearest point not hit yet within `reach`
## metres of the last one, `hops` times at most. Returns indices into `points`
## in hop order.
static func chain_path(start: Vector3, points: PackedVector3Array, hops: int, reach: float) -> Array[int]:
	var path: Array[int] = []
	var at := start
	for k in hops:
		var best := -1
		var best_d := reach
		for i in points.size():
			if path.has(i):
				continue
			var dd := at.distance_to(points[i])
			if dd <= best_d:
				best_d = dd
				best = i
		if best < 0:
			break
		path.append(best)
		at = points[best]
	return path


## Pierce: the points a round carries on into after its target, nearest first:
## within `radius` of the line from `from` through `aim`, up to 10 m past the
## target, at most `count` of them. Returns indices into `points`.
static func pierce_line(from: Vector3, aim: Vector3, points: PackedVector3Array, count: int, radius: float) -> Array[int]:
	var dir := (aim - from).normalized()
	var reach := from.distance_to(aim) + 10.0
	var hits: Array = []
	for i in points.size():
		var off := points[i] - from
		var along := off.dot(dir)
		if along <= 0.0 or along > reach or (off - dir * along).length() > radius:
			continue
		hits.append(Vector2(along, i))
	hits.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var out: Array[int] = []
	for h: Vector2 in hits.slice(0, count):
		out.append(int(h.y))
	return out


## Rail spike: every point in a line down the wall from the target. The line
## runs the way the shot was going, flattened onto the wall (straight down when
## the shot hits the wall head on, bent downward when it was rising), out to
## SPIKE_REACH; `radius` is how close to it a bug must be. Nearest first, as
## indices into `points`.
const SPIKE_REACH := 30.0
static func spike_line(aim: Vector3, dir: Vector3, wall_normal: Vector3, points: PackedVector3Array, radius: float) -> Array[int]:
	var run := spike_run(dir, wall_normal)
	var n := wall_normal.normalized()
	var hits: Array = []
	for i in points.size():
		var off := points[i] - aim
		var flat := off - n * off.dot(n)
		var along := flat.dot(run)
		if along <= 0.0 or along > SPIKE_REACH or (flat - run * along).length() > radius:
			continue
		hits.append(Vector2(along, i))
	hits.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
	var out: Array[int] = []
	for h: Vector2 in hits:
		out.append(int(h.y))
	return out


## The direction a rail spike runs along the wall (unit, in the wall's plane).
static func spike_run(dir: Vector3, wall_normal: Vector3) -> Vector3:
	var n := wall_normal.normalized()
	var run := dir - n * dir.dot(n)
	var down := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	if run.length() < 0.25:
		run = down
	elif run.y > 0.0:
		run = run.normalized().lerp(down.normalized(), 0.5)
	return run.normalized()
