class_name BugCrowd
extends RefCounted
## Keeps bugs from overlapping. Each tick (host only) every pair of bugs that
## share a surface (the same cliff face, or the plateau and air) and overlap is
## pushed apart. Heavier bugs move less: a bug moves by the overlap times the
## OTHER bug's share of their combined weight, so a beetle shoulders a mite
## aside while barely moving itself. Pure maths on plain positions so it can be
## unit-tested; BugManager.separate() applies it to the bugs.

const CELL := 4.0
## Overlap is resolved this fraction per tick (soft, so crowds don't jitter).
const STIFFNESS := 0.6


## Weight from a bug's size; the boss counts extra.
static func weight(size: float, is_boss: bool = false) -> float:
	return size * size * size * (4.0 if is_boss else 1.0)


## Pushes for a set of discs: pos (Vector2), radius, weight. Returns the
## per-disc offsets that separate them (in the same 2D space).
static func pushes(pos: Array[Vector2], radius: Array[float], wt: Array[float]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.resize(pos.size())
	out.fill(Vector2.ZERO)
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
					var total := wt[i] + wt[j]
					out[i] -= n * overlap * (wt[j] / total)
					out[j] += n * overlap * (wt[i] / total)
	return out
