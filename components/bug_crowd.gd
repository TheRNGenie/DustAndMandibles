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
## Hive amber: an Amber Kiln statue weighs this. Nothing shoves it, nothing
## crawls over it: a bug that runs into one is pushed straight back off it
## (and must step round it or wait).
const STATUE_WEIGHT := 1.0e9


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
	var r := resolve_packed(PackedVector2Array(pos), PackedFloat32Array(radius), PackedFloat32Array(wt))
	var out: Array[Vector2] = []
	out.assign(Array(r["push"]))
	var crouch: Array[float] = []
	crouch.assign(Array(r["crouch"]))
	var ride: Array[float] = []
	ride.assign(Array(r["ride"]))
	return {"push": out, "crouch": crouch, "ride": ride}


## resolve() on packed arrays (what BugManager uses: no per-bug allocations).
## Returns {"push": PackedVector2Array, "crouch"/"ride": PackedFloat32Array}.
static func resolve_packed(pos: PackedVector2Array, radius: PackedFloat32Array, wt: PackedFloat32Array) -> Dictionary:
	var n := pos.size()
	var out := PackedVector2Array()
	out.resize(n)
	out.fill(Vector2.ZERO)
	var crouch := PackedFloat32Array()
	crouch.resize(n)
	crouch.fill(0.0)
	var ride := PackedFloat32Array()
	ride.resize(n)
	ride.fill(0.0)
	var blocked := PackedByteArray() # hive amber: pushed back off a statue
	blocked.resize(n)
	blocked.fill(0)
	# Bucket the discs into CELL-sized cells (a native sort on cell key, so no
	# per-disc containers), then visit each pair of neighbouring cells once
	# (half the 3x3 stencil), so every close pair is checked exactly once:
	# hundreds of bugs stay cheap.
	var keyed := PackedInt64Array()
	keyed.resize(n)
	for i in n:
		var p := pos[i]
		keyed[i] = (_cell_key(p) << 16) | i
	keyed.sort()
	var idx := PackedInt32Array()
	idx.resize(n)
	var runs: Dictionary = {} # cell key -> start * 65536 + end in idx
	var run_keys := PackedInt64Array()
	var k := 0
	while k < n:
		var cell := keyed[k] >> 16
		var s := k
		while k < n and (keyed[k] >> 16) == cell:
			idx[k] = keyed[k] & 0xFFFF
			k += 1
		runs[cell] = s * 65536 + k
		run_keys.append(cell)
	for cell: int in run_keys:
		var se: int = runs[cell]
		var s0 := se >> 16
		var e0 := se & 0xFFFF
		for a_i in range(s0, e0):
			var i := idx[a_i]
			var pi := pos[i]
			var ri := radius[i]
			for b_i in range(a_i + 1, e0):
				var j := idx[b_i]
				var r := ri + radius[j]
				if pi.distance_squared_to(pos[j]) < r * r:
					_pair_packed(mini(i, j), maxi(i, j), pos, radius, wt, out, crouch, ride, blocked)
		for off: int in _HALF_STENCIL_KEYS:
			var other: Variant = runs.get(cell + off)
			if other == null:
				continue
			var s1: int = int(other) >> 16
			var e1: int = int(other) & 0xFFFF
			for a_i in range(s0, e0):
				var i := idx[a_i]
				var pi := pos[i]
				var ri := radius[i]
				for b_i in range(s1, e1):
					var j := idx[b_i]
					var r := ri + radius[j]
					if pi.distance_squared_to(pos[j]) < r * r:
						_pair_packed(mini(i, j), maxi(i, j), pos, radius, wt, out, crouch, ride, blocked)
	return {"push": out, "crouch": crouch, "ride": ride, "blocked": blocked}


## The neighbouring cells visited from each cell (the other four are visited from them).
const HALF_STENCIL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## HALF_STENCIL as offsets of _cell_key (x is the high part, y the low).
const _KEY_SPAN := 1 << 20
const _HALF_STENCIL_KEYS: Array[int] = [_KEY_SPAN, -_KEY_SPAN + 1, 1, _KEY_SPAN + 1]


## One int per CELL-sized cell (cells within +-2^19 of the origin, i.e. any map).
static func _cell_key(p: Vector2) -> int:
	return (floori(p.x / CELL) + (_KEY_SPAN >> 1)) * _KEY_SPAN + (floori(p.y / CELL) + (_KEY_SPAN >> 1))


## _pair() on packed arrays (they're passed by reference, so results land in the caller's).
static func _pair_packed(i: int, j: int, pos: PackedVector2Array, radius: PackedFloat32Array, wt: PackedFloat32Array,
		out: PackedVector2Array, crouch: PackedFloat32Array, ride: PackedFloat32Array, blocked: PackedByteArray = PackedByteArray()) -> void:
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
	if wt[big] >= STATUE_WEIGHT:
		# A statue: the other bug is put right back outside it (two statues stay put).
		if wt[small] < STATUE_WEIGHT:
			out[small] += (n if small == j else -n) * (min_d - dist)
			if blocked.size() > small:
				blocked[small] = 1
		return
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
