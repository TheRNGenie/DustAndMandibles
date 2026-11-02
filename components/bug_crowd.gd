class_name BugCrowd
extends RefCounted
## Keeps bugs from overlapping. Each tick (host only) every pair of bugs that
## share a surface (the same cliff face, or the plateau and air) and overlap is
## pushed apart. Heavier bugs move less: a bug moves by the overlap times the
## OTHER bug's share of their combined weight, so a beetle shoulders a mite
## aside while barely moving itself. Pure maths on plain positions so it can be
## unit-tested; BugManager.separate() applies it to the bugs.
## When one bug is much heavier (OVER_RATIO or more), they don't shove at all:
## the small one yields (ducks flat and edges aside a little) and the big one
## crawls right over it.

const CELL := 4.0
## Overlap is resolved this fraction per tick (soft, so crowds don't jitter).
const STIFFNESS := 0.6
## A bug this many times heavier climbs over the smaller one instead of shoving.
const OVER_RATIO := 3.0
## How much the yielding bug still edges aside (fraction of a normal push).
const YIELD_PUSH := 0.25


## Weight from a bug's size; the boss counts extra.
static func weight(size: float, is_boss: bool = false) -> float:
	return size * size * size * (4.0 if is_boss else 1.0)


## Pushes for a set of discs: pos (Vector2), radius, weight. Returns the
## per-disc offsets that separate them (in the same 2D space).
static func pushes(pos: Array[Vector2], radius: Array[float], wt: Array[float]) -> Array[Vector2]:
	return resolve(pos, radius, wt)["push"]


## As pushes(), plus who's crawling over whom: {"push": per-disc offsets,
## "crouch": 0..1 how flat each small bug should duck, "ride": how high each big
## bug rides up as it crosses one (in the same units as the radii)}.
static func resolve(pos: Array[Vector2], radius: Array[float], wt: Array[float]) -> Dictionary:
	var out: Array[Vector2] = []
	out.resize(pos.size())
	out.fill(Vector2.ZERO)
	var crouch: Array[float] = []
	crouch.resize(pos.size())
	crouch.fill(0.0)
	var ride: Array[float] = []
	ride.resize(pos.size())
	ride.fill(0.0)
	# Bucket the discs into CELL-sized cells, then visit each pair of
	# neighbouring cells once (half the 3x3 stencil), so every close pair is
	# checked exactly once: hundreds of bugs stay cheap.
	var grid: Dictionary = {}
	for i in pos.size():
		var key := Vector2i(floori(pos[i].x / CELL), floori(pos[i].y / CELL))
		var cell: Variant = grid.get(key)
		if cell == null:
			grid[key] = [i]
		else:
			(cell as Array).append(i)
	for key: Vector2i in grid:
		var here: Array = grid[key]
		var nh := here.size()
		for a_i in nh:
			var i: int = here[a_i]
			var pi := pos[i]
			var ri := radius[i]
			for b_i in range(a_i + 1, nh):
				var j: int = here[b_i]
				var r := ri + radius[j]
				if pi.distance_squared_to(pos[j]) < r * r:
					_pair(mini(i, j), maxi(i, j), pos, radius, wt, out, crouch, ride)
		for off: Vector2i in HALF_STENCIL:
			var other: Variant = grid.get(key + off)
			if other == null:
				continue
			for i: int in here:
				var pi := pos[i]
				var ri := radius[i]
				for j: int in (other as Array):
					var r := ri + radius[j]
					if pi.distance_squared_to(pos[j]) < r * r:
						_pair(mini(i, j), maxi(i, j), pos, radius, wt, out, crouch, ride)
	return {"push": out, "crouch": crouch, "ride": ride}


## The neighbouring cells visited from each cell (the other four are visited from them).
const HALF_STENCIL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


## One pair (i < j): push apart by weight, or the small one ducks under the big one.
static func _pair(i: int, j: int, pos: Array[Vector2], radius: Array[float], wt: Array[float],
		out: Array[Vector2], crouch: Array[float], ride: Array[float]) -> void:
	var d := pos[j] - pos[i]
	var min_d := radius[i] + radius[j]
	var dist2 := d.length_squared()
	if dist2 >= min_d * min_d:
		return
	var dist := sqrt(dist2)
	var n := d / dist if dist > 0.001 else Vector2(1, 0).rotated(float(i * 7 + j))
	var overlap := (min_d - dist) * STIFFNESS
	var big := i if wt[i] >= wt[j] else j
	var small := j if big == i else i
	if wt[big] >= wt[small] * OVER_RATIO:
		# Over the top: the small one ducks and edges aside, the big one rides up.
		var depth := clampf(1.0 - dist / min_d, 0.0, 1.0)
		var k := smoothstep(0.0, 0.25, depth)
		crouch[small] = maxf(crouch[small], k)
		ride[big] = maxf(ride[big], radius[small] * 1.1 * k)
		var away := n if small == j else -n
		out[small] += away * overlap * YIELD_PUSH
		return
	var total := wt[i] + wt[j]
	out[i] -= n * overlap * (wt[j] / total)
	out[j] += n * overlap * (wt[i] / total)
