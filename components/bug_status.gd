class_name BugStatus
extends RefCounted
## Host-side status effects on one bug: slow (barbed wire), root (bear trap,
## lasso), burn (chili patches). Bug.speed() multiplies these into movement.

var bug: Bug
var _slow_t := 0.0
var _slow_factor := 1.0
var _root_t := 0.0
var _burn_t := 0.0
var _burn_dps := 0.0
var _burn_source := ""
var _burn_cliff := -1
var frozen := false # debug showcase


func _init(b: Bug) -> void:
	bug = b


func slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_t > 0.0 else factor
	_slow_t = maxf(_slow_t, seconds)


func root(seconds: float) -> void:
	_root_t = maxf(_root_t, seconds)


func burn(dps: float, seconds: float, source: String, source_cliff: int) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_t = maxf(_burn_t, seconds)
	_burn_source = source
	_burn_cliff = source_cliff


func is_rooted() -> bool:
	return _root_t > 0.0 or frozen


func speed_multiplier() -> float:
	if is_rooted():
		return 0.0
	return _slow_factor if _slow_t > 0.0 else 1.0


func tick(delta: float) -> void:
	_slow_t = maxf(_slow_t - delta, 0.0)
	_root_t = maxf(_root_t - delta, 0.0)
	if _burn_t > 0.0:
		_burn_t -= delta
		bug.health.take_damage(_burn_dps * delta, _burn_source, _burn_cliff)
		if _burn_t <= 0.0:
			_burn_dps = 0.0
