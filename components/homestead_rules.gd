class_name HomesteadRules
extends RefCounted
## Story chapter 9, The Dry Gulch Families: pure rules (unit-tested). Where the
## ruined homesteads and the amber crew's camp stand on the canyon floor, what
## the families' papers and the board's ledger weigh, and when the job's done.
## The set piece itself is DryGulchFamilies.

## The four families the 1889 blast drove off the floor: [id, name on the gate].
const FAMILIES: Array = [["haldane", "Haldane"], ["ortega", "Ortega"], ["brannigan", "Brannigan"], ["lindqvist", "Lindqvist"]]
const PAPERS := &"family_papers"
const LEDGER := &"harvest_ledger"
## Homesteads stand this far apart, and this far from any rope foot.
const MIN_SEP := 15.0
const MIN_FROM_FEET := 24.0
## The camp stands at least this far from every homestead.
const CAMP_SEP := 16.0
## Taking the ledger out of the strongbox is loud (the hasp, the lid): metres.
const LEDGER_NOISE := 40.0
## Bundle states.
enum Papers { HOME, PACKED, DROPPED, UP }


static func family_name(i: int) -> String:
	return str(FAMILIES[i % FAMILIES.size()][1])


static func family_id(i: int) -> String:
	return str(FAMILIES[i % FAMILIES.size()][0])


## Floor spots to try on the canyon: across the floor and down its far half
## (away from the rope winches at the south corners of the yards). Pure.
static func canyon_candidates() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var z := 22.0
	while z <= 86.0:
		var x := -14.0
		while x <= 14.0:
			out.append(Vector3(x, 0.0, z))
			x += 3.5
		z += 3.5
	return out


## Floor spots to try on a ring map (the Mesa's basin, the Buttes' lake): rings
## round its middle. Pure.
static func ring_candidates(center: Vector3, ring_radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r: float in [ring_radius * 0.3, ring_radius * 0.45, ring_radius * 0.58]:
		for k in 24:
			var a := TAU * float(k) / 24.0
			out.append(center + Vector3(cos(a), 0.0, sin(a)) * r)
	return out


## Picks `count` spots from `candidates`: the furthest from every rope foot
## first, each at least `sep` from the ones already picked and from `avoid`,
## skipping any `blocked` says no to (a raid site's ground). Pure.
static func pick_spots(candidates: Array[Vector3], feet: Array[Vector3], count: int, sep: float,
		avoid: Array[Vector3] = [], blocked: Callable = Callable()) -> Array[Vector3]:
	var scored: Array = []
	for c in candidates:
		if blocked.is_valid() and bool(blocked.call(c)):
			continue
		var d := _nearest(c, feet)
		if d < MIN_FROM_FEET and not feet.is_empty():
			continue
		scored.append([d, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array[Vector3] = []
	for s: Array in scored:
		var c: Vector3 = s[1]
		if _nearest(c, out) < sep or _nearest(c, avoid) < sep:
			continue
		out.append(c)
		if out.size() >= count:
			break
	return out


static func _nearest(p: Vector3, list: Array[Vector3]) -> float:
	var best := INF
	for q in list:
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


## How many bundles are up out of the canyon.
static func papers_up(states: Array) -> int:
	var n := 0
	for s: Variant in states:
		if int(s) == Papers.UP:
			n += 1
	return n


## The job: every family's papers and the ledger up out of the canyon.
static func done(states: Array, ledger_state: int) -> bool:
	return not states.is_empty() and papers_up(states) >= states.size() and ledger_state == Papers.UP


## The bundles a peer's pack carries up: [index, ...] of those it holds (host
## bookkeeping: which family's papers are in whose pack).
static func carried_by(states: Array, holders: Array, peer: int) -> Array[int]:
	var out: Array[int] = []
	for i in states.size():
		if int(states[i]) == Papers.PACKED and int(holders[i]) == peer:
			out.append(i)
	return out
