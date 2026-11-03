class_name Targeting
extends RefCounted
## THE cross-defense rule, in one place: a turret may only shoot bugs that are
## climbing the cliff its spot on the grid covers (on the canyon, the OTHER
## cliff; on bigger maps MapDef.covered_cliff splits a lip between neighbours),
## never its own. Breachers (bugs that crested onto a plateau) are
## never turret targets; only players and traps can hurt them.

## Can a turret owned by `turret_cliff` target a bug climbing `bug_cliff`?
## `covered` is the cliff the turret's spot covers (-1: any cliff but its own).
static func cliff_allows(turret_cliff: int, bug_cliff: int, bug_is_climbing: bool, covered: int = -1) -> bool:
	if covered >= 0:
		return bug_is_climbing and bug_cliff == covered and bug_cliff != turret_cliff
	return bug_is_climbing and bug_cliff != turret_cliff


## Canyon Expeditions: a cliff turret may also shoot a bug out on the canyon
## floor (a hunter after a player who's down, or a site's waking sleeper) when
## it's in the build phase, covering a partner. The pitch limit (the 30 degree
## Downward Discharge law, plus scaffolds) still applies, so in practice only
## the far floor out past the opposite cliff's foot is in reach.
static func floor_allows(is_floor_bug: bool, on_ground: bool) -> bool:
	return is_floor_bug and on_ground


## Score for a floor bug: above every climber (a partner's life is on it), nearest first.
static func floor_priority(distance: float) -> float:
	return 100000.0 - distance


## Last-line (plateau guard) turrets: only bugs on the turret owner's OWN plateau,
## never a climber on either cliff face.
static func guard_allows(turret_cliff: int, bug_cliff: int, bug_on_plateau: bool) -> bool:
	return bug_on_plateau and bug_cliff == turret_cliff


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


## Score for a bug that a Signal Flare marked: on top of everything else (GunRules).
static func marked_priority(score: float, marked: bool) -> float:
	return score + GunRules.mark_bonus(marked)
