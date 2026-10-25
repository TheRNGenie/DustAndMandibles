class_name Targeting
extends RefCounted
## THE cross-defense rule, in one place: a turret may only shoot bugs that are
## climbing the OTHER cliff. Breachers (bugs that crested onto a plateau) are
## never turret targets; only players and traps can hurt them.

## Can a turret owned by `turret_cliff` target a bug climbing `bug_cliff`?
static func cliff_allows(turret_cliff: int, bug_cliff: int, bug_is_climbing: bool) -> bool:
	return bug_is_climbing and bug_cliff != turret_cliff


## Is `target` inside the turret's pitch limit (degrees below horizontal) and range?
static func in_arc(muzzle: Vector3, target: Vector3, pitch_limit_deg: float, max_range: float) -> bool:
	var to := target - muzzle
	var dist := to.length()
	if dist > max_range or dist < 0.01:
		return false
	var horizontal := Vector2(to.x, to.z).length()
	var pitch := rad_to_deg(atan2(to.y, horizontal))
	return pitch >= -pitch_limit_deg


## Score for choosing between valid targets: prefer bugs closest to the top of the cliff.
static func priority(climb_y: float, distance: float) -> float:
	return climb_y * 10.0 - distance
