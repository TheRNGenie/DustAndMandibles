class_name ReckoningRules
extends RefCounted
## Story chapter 10, The Reckoning: pure rules (unit-tested). The Iron
## Mandible's route and pace along the canyon floor, its amber furnace (how
## tough, how far its smoke drives the swarm mad, how fast), and the beats of
## the Hive Mother fight that Silas Kettle's last charge lands on. The set piece
## is IronMandible; the Hive Mother's own rules are in _rules_mother.gd.

## The furnace: health for one rider, and this much more per extra rider.
const FURNACE_HP := 1800.0
const FURNACE_HP_PER_RIDER := 0.6
## Shots into the open firebox door do this much more.
const DOOR_MULT := 2.0
## While the furnace burns, bugs within this many metres of it (flat) move faster.
const FRENZY_RADIUS := 44.0
const FRENZY_SPEED := 1.35
## The train: metres a second rolling in (the build phase) and crawling (the wave).
const ARRIVE_SPEED := 6.0
const CRAWL_SPEED := 1.1
## Canyon: the route starts this far down the canyon (past the play area) and
## the train waits for dark with its nose here.
const CANYON_START_Z := 330.0
const CANYON_HOLD_Z := 84.0
## It stops with its nose this far past the main tunnel's mouth.
const STOP_PAST_MOUTH := 3.0
## The swarm that turns on the wreck once the furnace blows.
const WRECK_SWARM := 12
## The Hive Mother: radio beats as her health falls past these, and Silas's
## charge goes off at SEAL_AT (she's pinned while his fuse burns).
const MOTHER_BEATS: Array = [[0.5, "mother_half"], [0.25, "mother_set"]]
const SEAL_AT := 0.1
const SEAL_FUSE := 3.5
## The second blast (Vane's charges on their timer): seconds into the build
## phase after the train night.
const SECOND_BLAST_AFTER := 4.0


static func furnace_hp(riders: int) -> float:
	return FURNACE_HP * (1.0 + FURNACE_HP_PER_RIDER * float(maxi(riders, 1) - 1))


## Speed multiplier for a bug `flat_dist` metres from a burning furnace.
static func frenzy(flat_dist: float, lit: bool) -> float:
	return FRENZY_SPEED if lit and flat_dist <= FRENZY_RADIUS else 1.0


## A route along the canyon floor from z0 to z1, a point every `step` metres;
## `cx` gives the canyon's centre x at a z (CliffBuilder.center_x), `fy` the
## floor height at (x, z). Pure apart from the two callables.
static func line_route(z0: float, z1: float, step: float, cx: Callable, fy: Callable) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(int(absf(z1 - z0) / step), 1)
	for i in n + 1:
		var z := lerpf(z0, z1, float(i) / float(n))
		var x := float(cx.call(z))
		out.append(Vector3(x, float(fy.call(x, z)), z))
	return out


## A route round a ring map's middle: an arc of `sweep` radians ending at
## angle `a_end`, radius `r`. Heights from `fy`.
static func arc_route(center: Vector3, r: float, a_end: float, sweep: float, step: float, fy: Callable) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(int(absf(sweep) * r / step), 1)
	for i in n + 1:
		var a := a_end - sweep + sweep * float(i) / float(n)
		var p := center + Vector3(cos(a), 0.0, sin(a)) * r
		out.append(Vector3(p.x, float(fy.call(p.x, p.z)), p.z))
	return out


static func length_of(route: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, route.size()):
		l += route[i].distance_to(route[i - 1])
	return l


## The point `s` metres along the route (clamped to its ends).
static func point_at(route: PackedVector3Array, s: float) -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	if s <= 0.0:
		return route[0]
	var left := s
	for i in range(1, route.size()):
		var seg := route[i].distance_to(route[i - 1])
		if left <= seg:
			return route[i - 1].lerp(route[i], left / maxf(seg, 0.0001))
		left -= seg
	return route[route.size() - 1]


## The way the route runs at `s` (flat, normalised).
static func dir_at(route: PackedVector3Array, s: float) -> Vector3:
	var a := point_at(route, s - 1.5)
	var b := point_at(route, s + 1.5)
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


## Metres along the route of the point nearest `p` (flat).
static func s_nearest(route: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	var best_s := 0.0
	var acc := 0.0
	for i in route.size():
		if i > 0:
			acc += route[i].distance_to(route[i - 1])
		var d := Vector2(route[i].x - p.x, route[i].z - p.z).length()
		if d < best:
			best = d
			best_s = acc
	return best_s


## Where the nose is after `dt` more seconds: rolling in toward `hold` (build),
## or crawling on toward `stop` (the wave); never backwards.
static func advance(s: float, dt: float, crawling: bool, hold: float, stop: float) -> float:
	if crawling:
		return minf(s + CRAWL_SPEED * dt, stop) if s < stop else s
	return minf(s + ARRIVE_SPEED * dt, hold) if s < hold else s


## The Hive Mother's radio beat as her health fell from `before` to `now` ("" for none).
static func mother_beat(before: float, now: float) -> String:
	var out := ""
	for b: Array in MOTHER_BEATS:
		if before > float(b[0]) and now <= float(b[0]):
			out = str(b[1])
	return out


## Is she low enough for Silas's charge?
static func seal_due(hp_frac: float) -> bool:
	return hp_frac <= SEAL_AT
