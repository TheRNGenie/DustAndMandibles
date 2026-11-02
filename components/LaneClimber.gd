class_name LaneClimber
extends RefCounted
## Host-side climbing brain: picks its own wandering way up the cliff face (every
## few metres it heads for a new spot left or right, so no two bugs climb the
## same line), and handles the per-bug quirks:
## Wolf Spiders leap and zigzag, Spitter Scorpions cling partway up and spit acid
## at turrets on the far cliff.

const LEAP_HEIGHT := 4.0
const LEAP_TIME := 0.35
const SPIT_INTERVAL := 3.5
const SPIT_DAMAGE := 10.0
const SPIT_RANGE := 110.0
## Spitters cling this long, then climb on (so a wave can't stall on one out of reach).
const CLING_TIME := 25.0

## Emitted by spitters; the BugManager draws the acid and applies the hit.
static var spit_requested: Callable

var bug: Bug
var target_z: float
var _drift := 0.0
var _leap_cd := 0.0
var _leap_left := 0.0
var _spit_cd := 0.0
var _last_y := 0.0
var _clung := 0.0
## Climb height at which it next picks a new direction.
var _next_turn := 0.0


func _init(b: Bug) -> void:
	bug = b
	target_z = b.lane_z
	_drift = randf() * TAU
	_leap_cd = randf_range(1.5, 3.0)
	_next_turn = b.climb_y + randf_range(2.0, 5.0)
	_spit_cd = randf_range(1.0, SPIT_INTERVAL)


func spit_height() -> float:
	return WorldLayout.CLIFF_HEIGHT * 0.78


func update(delta: float) -> void:
	var d := bug.def
	if d.behavior == BugDef.Behavior.SPITTER and bug.climb_y >= spit_height() and _clung < CLING_TIME:
		_clung += delta
		_spit(delta)
		return
	var speed := d.climb_speed * bug.speed()
	if d.behavior == BugDef.Behavior.LEAPER:
		_leap_cd -= delta
		if _leap_cd <= 0.0 and _leap_left <= 0.0:
			_leap_left = LEAP_TIME
			_leap_cd = randf_range(2.0, 3.5)
		if _leap_left > 0.0:
			_leap_left -= delta
			speed += LEAP_HEIGHT / LEAP_TIME * minf(bug.speed(), 1.0)
	_last_y = bug.climb_y
	bug.climb_y += speed * delta
	_wander(d)
	_drift += delta * (2.5 if d.behavior == BugDef.Behavior.LEAPER else 1.0)
	var wobble := sin(_drift) * (0.9 if d.behavior == BugDef.Behavior.LEAPER else 0.35)
	var side_speed := 2.6 if d.behavior == BugDef.Behavior.LEAPER else 1.3
	bug.lane_z = move_toward(bug.lane_z, target_z + wobble, side_speed * bug.speed() * delta)
	if bug.climb_y >= WorldLayout.CLIFF_HEIGHT:
		bug.begin_crest()


## Every few metres up, head for a new spot to the left or right.
func _wander(d: BugDef) -> void:
	if bug.climb_y < _next_turn:
		return
	var leaper := d.behavior == BugDef.Behavior.LEAPER
	_next_turn = bug.climb_y + (randf_range(2.0, 4.0) if leaper else randf_range(3.0, 7.0))
	var reach := 8.0 if leaper else 5.0
	var half := WorldLayout.PLATEAU_WIDTH * 0.5 - 2.0
	target_z = clampf(bug.lane_z + randf_range(-reach, reach), -half, half)


func _spit(delta: float) -> void:
	_spit_cd -= delta
	if _spit_cd > 0.0:
		return
	_spit_cd = SPIT_INTERVAL
	if spit_requested.is_valid():
		spit_requested.call(bug, SPIT_DAMAGE, SPIT_RANGE)
