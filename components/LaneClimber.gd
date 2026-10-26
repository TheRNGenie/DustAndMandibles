class_name LaneClimber
extends RefCounted
## Host-side climbing brain: follows a lane up the cliff face with a little sideways
## drift, sometimes switches lanes at ledges, and handles the per-bug quirks:
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


func _init(b: Bug) -> void:
	bug = b
	target_z = b.lane_z
	_drift = randf() * TAU
	_leap_cd = randf_range(1.5, 3.0)
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
	_maybe_switch_lane(d)
	_drift += delta * (2.5 if d.behavior == BugDef.Behavior.LEAPER else 1.0)
	var wobble := sin(_drift) * (0.9 if d.behavior == BugDef.Behavior.LEAPER else 0.35)
	bug.lane_z = move_toward(bug.lane_z, target_z + wobble, 2.0 * delta)
	if bug.climb_y >= WorldLayout.CLIFF_HEIGHT:
		bug.begin_crest()


func _maybe_switch_lane(d: BugDef) -> void:
	for ledge in WorldLayout.LEDGE_Y:
		if _last_y < ledge and bug.climb_y >= ledge:
			var chance := 0.6 if d.behavior == BugDef.Behavior.LEAPER else 0.15
			if randf() < chance:
				var lanes := WorldLayout.LANE_Z.size()
				var next := clampi(bug.lane + (1 if randf() < 0.5 else -1), 0, lanes - 1)
				bug.lane = next
				target_z = WorldLayout.LANE_Z[next] + randf_range(-0.8, 0.8)


func _spit(delta: float) -> void:
	_spit_cd -= delta
	if _spit_cd > 0.0:
		return
	_spit_cd = SPIT_INTERVAL
	if spit_requested.is_valid():
		spit_requested.call(bug, SPIT_DAMAGE, SPIT_RANGE)
