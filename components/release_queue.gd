class_name ReleaseQueue
extends RefCounted
## How a wave's pulse comes out (WaveDirector): each planned group is cut into
## chunks of at most CHUNK bugs spread across the five lanes (so a big group
## isn't one column out of one tunnel), and the chunks of every kind are dealt
## out in turn (so the field fills with a mix, not one kind first). Pure.

const CHUNK := 4
## Chunks released per frame at most (the rest wait their turn).
const PER_TICK := 4
const LANES := 5
## Fliers can't queue on the floor: at most this share of the full-bug cap.
const FLIER_SHARE := 0.25


## [[bug, count, cliff, lane, tier], ...] for one group.
static func chunks(bug: StringName, count: int, cliff: int, lane: int, tier: int) -> Array:
	var out: Array = []
	var left := count
	var k := 0
	while left > 0:
		var n := mini(CHUNK, left)
		out.append([bug, n, cliff, (lane + k) % LANES, tier])
		left -= n
		k += 1
	return out


## One chunk from each group in turn until all are dealt.
static func interleave(lists: Array) -> Array:
	var out: Array = []
	var i := 0
	var more := true
	while more:
		more = false
		for l: Array in lists:
			if i < l.size():
				out.append(l[i])
				more = true
		i += 1
	return out
