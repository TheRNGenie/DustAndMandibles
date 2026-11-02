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
	var grid: Dictionary = {}
	for i in pos.size():
		var key := Vector2i(floori(pos[i].x / CELL), floori(pos[i].y / CELL))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(i)
	for i in pos.size():
		var key := Vector2i(floori(pos[i].x / CELL), floori(pos[i].y / CELL))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cell: Variant = grid.get(key + Vector2i(dx, dy))
				if cell == null:
					continue
				for j: int in cell:
					if j <= i:
						continue
					var d := pos[j] - pos[i]
					var min_d := radius[i] + radius[j]
					var dist := d.length()
					if dist >= min_d:
						continue
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
						continue
					var total := wt[i] + wt[j]
					out[i] -= n * overlap * (wt[j] / total)
					out[j] += n * overlap * (wt[i] / total)
	return {"push": out, "crouch": crouch, "ride": ride}
