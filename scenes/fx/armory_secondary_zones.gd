extends Node
## Host only: the secondaries' lasting effects (ArmorySecondaryRules), ticked
## each physics frame and freed when nothing is left:
##   drifts   one bug shoved for a while (scream scatter, concussion knock-back)
##   berserk  a frenzied bug off the wall (pepper): it goes for the nearest bug
##   lures    a glow-worm grub pulling bugs toward it
##   caltrops iron spikes that bite and slow every bug crossing them
##   fires    a phosphor fire that burns bugs and pushes them out round its edge
## Also holds the pure rules (who is a wall / ground / flying bug, cone and line
## picks, how far a push goes) so the tests can check them without the game.
## Bugs are untyped here (Object): the tests drive it with stand-ins.

# ------------------------------------------------------------------ bug kinds

## Mirrors Bug.State (checked by a test against bug.gd).
const ST_CLIMBING := 0
const ST_CRESTING := 1
const ST_BREACHING := 2
const ST_DEAD := 3
const ST_BURROWED := 4
const ST_FLYING := 5
const ST_CROSSING := 6
const ST_SLEEPING := 7
const ST_HUNTING := 8

## Where a bug is, for pushing it about.
enum Where { NONE, WALL, GROUND, AIR }

## Lane positions a climber may be pushed to (LaneClimber._wander's limit).
const LANE_HALF := WorldLayout.PLATEAU_WIDTH * 0.5 - 2.0
## Highest a pushed climber may be put (just under the lip).
const WALL_TOP := WorldLayout.CLIFF_HEIGHT - 0.5

# ------------------------------------------------------------------ tuning

## Lures: climbers slide along the wall this fast (m/s) toward the grub, up or down this fast.
const LURE_WALL_SPEED := 2.6
const LURE_WALL_CLIMB := 1.2
## Lures: ground bugs and fliers walk / fly to it this fast, and mill about this close.
const LURE_GROUND_SPEED := 3.6
const LURE_AIR_SPEED := 4.5
const LURE_STOP := 1.6
## Lured bugs' own movement is slowed to this (so the pull wins).
const LURE_SLOW := 0.45
## Caltrops: one step of damage every this many seconds, and the slow it leaves.
const CALTROP_STEP := 0.5
const CALTROP_SLOW := 0.6
const CALTROP_SLOW_TIME := 0.8
## Caltrops: how thick the patch is along its surface normal (a flattened disc).
const CALTROP_THICK := 1.8
## Caltrops: most patches one shooter may have down at once.
const CALTROP_MAX := 2
## Phosphor: burn applied each tick to bugs inside (seconds it lingers after).
const FIRE_TICK := 0.25
const FIRE_LINGER := 1.0
## Phosphor: bugs inside (or this close to the edge) are pushed out this fast (m/s).
const FIRE_EDGE := 1.5
const FIRE_PUSH := 3.0
## Pepper (off the wall): bite reach on top of the two bodies, and the walk speed share.
const BERSERK_REACH := 0.9
const BERSERK_WALK := 0.8
const BERSERK_SLOW := 0.25
## Pepper (off the wall): how far it looks for something to bite.
const BERSERK_LOOK := 12.0
## Bugs fewer than this many metres apart count as one spot (no direction to push).
const EPS := 0.05

## Callables the game fills in (ArmorySecondaryRules.zones): the lane (metres
## along the cliff) of a world point on cliff c, and keeping a plateau bug on its plateau.
static var lane_of: Callable = func(_c: int, p: Vector3) -> float: return p.z
static var keep_on_plateau: Callable = func(_b: Object, p: Vector3) -> Vector3: return p

var drifts: Array[Dictionary] = [] # {bug, wall: Vector2, move: Vector3, t}
var berserk: Array[Dictionary] = [] # {bug, dps, t, source, cliff, prey, look}
var lures: Array[Dictionary] = [] # {pos, radius, t}
var caltrops: Array[Dictionary] = [] # {pos, normal, radius, dmg, t, step, owner, source, cliff, id}
var fires: Array[Dictionary] = [] # {pos, normal, radius, dps, t, tick, source, cliff}


## Where a bug is: on the wall, on the ground (plateau or floor), in the air,
## or somewhere it can't be pushed (cresting the lip, underground, dead, a statue).
static func where(b: Object) -> int:
	if not is_instance_valid(b) or not bool(b.call("is_alive")) or bool(b.call("is_hidden")):
		return Where.NONE
	if b.get("latched") == true or _num(b.get("entombed")) > 0.0:
		return Where.NONE
	match int(b.get("state")):
		ST_CLIMBING:
			return Where.WALL
		ST_BREACHING, ST_CROSSING, ST_SLEEPING, ST_HUNTING:
			return Where.GROUND
		ST_FLYING:
			return Where.AIR
	return Where.NONE


static func _num(v: Variant) -> float:
	return float(v) if v != null else 0.0


static func is_boss(b: Object) -> bool:
	return b.get("boss") != null


static func is_heavy(b: Object) -> bool:
	return TurretDef.is_heavy(b.get("def") as BugDef)


## Can this bug be hit at all (alive, above ground)?
static func hittable(b: Object) -> bool:
	return is_instance_valid(b) and bool(b.call("is_alive")) and not bool(b.call("is_hidden"))


static func pos_of(b: Object) -> Vector3:
	return b.get("global_position") as Vector3


## The bugs within `radius` metres of `center`.
static func in_radius(bugs: Array, center: Vector3, radius: float) -> Array:
	return bugs.filter(func(b: Object) -> bool:
		return hittable(b) and pos_of(b).distance_to(center) <= radius)


## The bugs inside the cone from `origin` along `dir` (unit).
static func in_cone(bugs: Array, origin: Vector3, dir: Vector3, half_angle: float, reach: float) -> Array:
	return bugs.filter(func(b: Object) -> bool:
		return hittable(b) and SpecialShotRules.in_cone(origin, dir, pos_of(b), half_angle, reach))


## Up to `count` bugs along the line from `origin` along `dir` (unit), no further
## than `reach`, within `width` metres of it (plus their body), nearest first,
## leaving out `skip`.
static func along_line(bugs: Array, origin: Vector3, dir: Vector3, reach: float, width: float, count: int,
		skip: Array = []) -> Array:
	var found: Array = []
	for b: Object in bugs:
		if not hittable(b) or skip.has(b):
			continue
		var to := pos_of(b) - origin
		var t := to.dot(dir)
		if t <= 0.0 or t > reach:
			continue
		var off := (to - dir * t).length()
		if off <= width + _num(b.get("crowd_r")):
			found.append([t, b])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return found.slice(0, count).map(func(x: Array) -> Object: return x[1])


## Is `p` on the caltrop patch at `center` (a disc `radius` wide and CALTROP_THICK
## deep along `normal`)? Works on the wall, the plateau and the floor alike.
static func on_patch(p: Vector3, center: Vector3, normal: Vector3, radius: float) -> bool:
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var off := p - center
	var along := off.dot(n)
	return absf(along) <= CALTROP_THICK and (off - n * along).length() <= radius


## The way to push a bug standing at `p` away from `from`, on the ground
## (horizontal, unit). Right on top of it: a random way.
static func away_flat(p: Vector3, from: Vector3) -> Vector3:
	var d := Vector3(p.x - from.x, 0.0, p.z - from.z)
	if d.length() < EPS:
		var a := randf() * TAU
		return Vector3(cos(a), 0.0, sin(a))
	return d.normalized()


## Which way along the wall (+1 / -1) a climber at lane `lane` flees from lane
## `from`. Dead level with it: `tie` (0: a random way).
static func away_lane(lane: float, from: float, tie: float = 0.0) -> float:
	if absf(lane - from) < EPS:
		if tie != 0.0:
			return signf(tie)
		return 1.0 if randf() < 0.5 else -1.0
	return signf(lane - from)


# ------------------------------------------------------------------ pushing bugs

## Moves a climber along the wall by `d` (lane, up), and keeps its own climbing
## brain from steering straight back (its target lane follows).
static func shift_wall(b: Object, d: Vector2) -> void:
	var lane := clampf(float(b.get("lane_z")) + d.x, -LANE_HALF, LANE_HALF)
	b.set("lane_z", lane)
	b.set("climb_y", clampf(float(b.get("climb_y")) + d.y, 0.0, WALL_TOP))
	var climber: Variant = b.get("_climber")
	if climber is Object and climber != null:
		(climber as Object).set("target_z", lane)


## Moves a ground bug or flier by `d` (fliers keep at least `min_y`).
static func shift_ground(b: Object, d: Vector3) -> void:
	var p: Vector3 = (b.get("ground_pos") as Vector3) + d
	if int(b.get("state")) == ST_BREACHING:
		p = keep_on_plateau.call(b, p)
	b.set("ground_pos", p)


## Host: shove a bug for `seconds`: `wall` (m/s along the lane, up) on the
## cliff face, `move` (m/s, world) on the ground or in the air.
func add_drift(b: Object, wall: Vector2, move: Vector3, seconds: float) -> void:
	drifts.append({"bug": b, "wall": wall, "move": move, "t": seconds})


## Host: a frenzied bug off the wall bites the nearest bug for `seconds`.
func add_berserk(b: Object, dps: float, seconds: float, source: String, cliff: int) -> void:
	for e in berserk:
		if e["bug"] == b:
			e["t"] = maxf(float(e["t"]), seconds)
			return
	berserk.append({"bug": b, "dps": dps, "t": seconds, "source": source, "cliff": cliff, "prey": null, "look": 0.0})


func add_lure(at: Vector3, radius: float, seconds: float) -> void:
	lures.append({"pos": at, "radius": radius, "t": seconds})


## Host: a caltrop patch. A shooter's oldest patch is lifted once it has
## `max_patches` down (CALTROP_MAX plus any mod); returns the centres of the patches lifted (their visuals go).
func add_caltrops(at: Vector3, normal: Vector3, radius: float, dmg: float, seconds: float, owner: int,
		source: String, cliff: int, max_patches: int = CALTROP_MAX) -> Array[Vector3]:
	var lifted: Array[Vector3] = []
	var mine := caltrops.filter(func(c: Dictionary) -> bool: return int(c["owner"]) == owner)
	while mine.size() >= maxi(max_patches, 1):
		var oldest: Dictionary = mine.pop_front()
		caltrops.erase(oldest)
		lifted.append(oldest["pos"] as Vector3)
	caltrops.append({"pos": at, "normal": normal, "radius": radius, "dmg": dmg, "t": seconds, "step": 0.0,
			"owner": owner, "source": source, "cliff": cliff})
	return lifted


func add_fire(at: Vector3, normal: Vector3, radius: float, dps: float, seconds: float, source: String,
		cliff: int) -> void:
	fires.append({"pos": at, "normal": normal, "radius": radius, "dps": dps, "t": seconds, "tick": 0.0,
			"source": source, "cliff": cliff})


func idle() -> bool:
	return drifts.is_empty() and berserk.is_empty() and lures.is_empty() and caltrops.is_empty() and fires.is_empty()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		queue_free()
		return
	step(delta, get_tree().get_nodes_in_group("bugs"))
	if idle():
		queue_free()


## One tick of every effect over `bugs` (the tests call this directly).
func step(delta: float, bugs: Array) -> void:
	_step_drifts(delta)
	_step_berserk(delta, bugs)
	if not lures.is_empty():
		_step_lures(delta, bugs)
	if not caltrops.is_empty():
		_step_caltrops(delta, bugs)
	if not fires.is_empty():
		_step_fires(delta, bugs)


func _step_drifts(delta: float) -> void:
	for e in drifts:
		e["t"] = float(e["t"]) - delta
		if not is_instance_valid(e["bug"]):
			continue
		var b: Object = e["bug"]
		match where(b):
			Where.WALL:
				shift_wall(b, (e["wall"] as Vector2) * delta)
			Where.GROUND, Where.AIR:
				shift_ground(b, (e["move"] as Vector3) * delta)
	drifts = drifts.filter(func(e: Dictionary) -> bool: return float(e["t"]) > 0.0 and is_instance_valid(e["bug"]))


func _step_berserk(delta: float, bugs: Array) -> void:
	for e in berserk:
		e["t"] = float(e["t"]) - delta
		if not is_instance_valid(e["bug"]):
			continue
		var b: Object = e["bug"]
		var w := where(b)
		if w != Where.GROUND and w != Where.AIR:
			e["t"] = 0.0
			continue
		e["look"] = float(e["look"]) - delta
		if float(e["look"]) <= 0.0 or not is_instance_valid(e["prey"]) or not hittable(e["prey"]):
			e["look"] = 0.5
			e["prey"] = nearest_other(b, bugs, BERSERK_LOOK)
		if not is_instance_valid(e["prey"]):
			continue
		var target: Object = e["prey"]
		var to := pos_of(target) - pos_of(b)
		to.y = 0.0 if w == Where.GROUND else to.y
		var reach := _num(b.get("crowd_r")) + _num(target.get("crowd_r")) + BERSERK_REACH
		if to.length() > reach:
			var walk := maxf((b.get("def") as BugDef).walk_speed, 1.5) * BERSERK_WALK
			shift_ground(b, to.normalized() * minf(walk * delta, to.length()))
		else:
			(target.get("health") as Object).call("take_damage", float(e["dps"]) * delta, str(e["source"]), int(e["cliff"]))
	berserk = berserk.filter(func(e: Dictionary) -> bool: return float(e["t"]) > 0.0 and is_instance_valid(e["bug"]))


## The nearest other living bug to `b` within `limit` metres (null: none).
static func nearest_other(b: Object, bugs: Array, limit: float) -> Object:
	var best: Object = null
	var best_d := limit
	var at := pos_of(b)
	for o: Object in bugs:
		if o == b or not hittable(o):
			continue
		var d := pos_of(o).distance_to(at)
		if d < best_d:
			best_d = d
			best = o
	return best


func _step_lures(delta: float, bugs: Array) -> void:
	for l in lures:
		l["t"] = float(l["t"]) - delta
		var at: Vector3 = l["pos"]
		for b: Object in in_radius(bugs, at, float(l["radius"])):
			if is_boss(b):
				continue # bosses ignore it
			lure_pull(b, at, delta)
	lures = lures.filter(func(l: Dictionary) -> bool: return float(l["t"]) > 0.0)


## One tick of a lure at `at` pulling bug `b` toward it.
static func lure_pull(b: Object, at: Vector3, delta: float) -> void:
	var w := where(b)
	if w == Where.NONE:
		return
	(b.get("status") as Object).call("slow", LURE_SLOW, 0.3)
	match w:
		Where.WALL:
			var lane := float(lane_of.call(int(b.get("cliff_id")), at))
			var dz := lane - float(b.get("lane_z"))
			var dy := at.y - float(b.get("climb_y"))
			shift_wall(b, Vector2(signf(dz) * minf(absf(dz), LURE_WALL_SPEED * delta),
					signf(dy) * minf(absf(dy), LURE_WALL_CLIMB * delta)))
		Where.GROUND:
			var to := at - (b.get("ground_pos") as Vector3)
			to.y = 0.0
			if to.length() > LURE_STOP:
				shift_ground(b, to.normalized() * minf(LURE_GROUND_SPEED * delta, to.length() - LURE_STOP))
		Where.AIR:
			var to := at + Vector3.UP * 1.5 - (b.get("ground_pos") as Vector3)
			if to.length() > LURE_STOP:
				shift_ground(b, to.normalized() * minf(LURE_AIR_SPEED * delta, to.length() - LURE_STOP))


func _step_caltrops(delta: float, bugs: Array) -> void:
	for c in caltrops:
		c["t"] = float(c["t"]) - delta
		c["step"] = float(c["step"]) - delta
		if float(c["step"]) > 0.0:
			continue
		c["step"] = CALTROP_STEP
		for b: Object in bugs:
			if not hittable(b) or int(b.get("state")) == ST_FLYING:
				continue # fliers sail over them
			var p := pos_of(b)
			if not on_patch(p, c["pos"], c["normal"], float(c["radius"])):
				continue
			b.call("receive_hit", float(c["dmg"]), p, Vector3.DOWN, false, 1.0, str(c["source"]), int(c["cliff"]))
			(b.get("status") as Object).call("slow", CALTROP_SLOW, CALTROP_SLOW_TIME)
	caltrops = caltrops.filter(func(c: Dictionary) -> bool: return float(c["t"]) > 0.0)


func _step_fires(delta: float, bugs: Array) -> void:
	for f in fires:
		f["t"] = float(f["t"]) - delta
		f["tick"] = float(f["tick"]) - delta
		var burn_now := float(f["tick"]) <= 0.0
		if burn_now:
			f["tick"] = FIRE_TICK
		var at: Vector3 = f["pos"]
		var r := float(f["radius"])
		for b: Object in in_radius(bugs, at, r + FIRE_EDGE):
			var inside := pos_of(b).distance_to(at) <= r
			if inside and burn_now:
				(b.get("status") as Object).call("burn", fire_dps(float(f["dps"]), b), FIRE_LINGER, str(f["source"]), int(f["cliff"]))
			if not is_boss(b):
				fire_push(b, at, delta)
	fires = fires.filter(func(f: Dictionary) -> bool: return float(f["t"]) > 0.0)


## Phosphor: heavies take half the burn.
static func fire_dps(dps: float, b: Object) -> float:
	return dps * (0.5 if is_heavy(b) or is_boss(b) else 1.0)


## Phosphor: a bug in or at the edge of the fire steps out of it: climbers sideways
## along the wall (they climb on round it), ground bugs and fliers straight out.
static func fire_push(b: Object, at: Vector3, delta: float) -> void:
	match where(b):
		Where.WALL:
			var lane := float(lane_of.call(int(b.get("cliff_id")), at))
			var tie := 1.0 if b.get_instance_id() % 2 == 0 else -1.0 # the same way every tick
			shift_wall(b, Vector2(away_lane(float(b.get("lane_z")), lane, tie) * FIRE_PUSH * delta, 0.0))
		Where.GROUND, Where.AIR:
			shift_ground(b, away_flat(pos_of(b), at) * FIRE_PUSH * delta)
