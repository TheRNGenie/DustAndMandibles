class_name BugStatus
extends RefCounted
## Host-side status effects on one bug: slow (barbed wire), root (bear trap,
## lasso), burn (chili patches). Bug.speed() multiplies these into movement.

var bug # a Bug (untyped, so the rules load without the whole bug: tests)
var _slow_t := 0.0
var _slow_factor := 1.0
var _root_t := 0.0
var _burn_t := 0.0
var _burn_dps := 0.0
var _burn_source := ""
var _burn_cliff := -1
var frozen := false # debug showcase
## Signal Flare: marked bugs are every turret's first pick (GunRules.MARK_BONUS).
var _mark_t := 0.0
## Bee Smoker: drowsy (slowed hard; fliers sink).
var _drowsy_t := 0.0
## Queen's Bell (hive amber): turned on its neighbours instead of climbing.
var _frenzy_t := 0.0
## Rust Duster / Acid Drencher: armour eaten away (every hit pierces).
var _strip_t := 0.0
## Tar Sprayer: coated in pitch (slowed, and fire burns it twice as hard).
var _tar_t := 0.0
## Flashbang: dazzled: rooted, and it doesn't bite or spit either.
var _stun_t := 0.0
## Tar doubles burn damage.
const TAR_BURN_MULT := 2.0


func _init(b: Object) -> void:
	bug = b


func slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_t > 0.0 else factor
	_slow_t = maxf(_slow_t, seconds)


func root(seconds: float) -> void:
	_root_t = maxf(_root_t, seconds)


func burn(dps: float, seconds: float, source: String, source_cliff: int) -> void:
	dps *= bug.def.damage_mult(&"fire") # kill-method variants (Sootback / Ironback / Stoneshell)
	if is_tarred():
		dps *= TAR_BURN_MULT # Tar Sprayer: pitch burns hot
	_burn_dps = maxf(_burn_dps, dps)
	_burn_t = maxf(_burn_t, seconds)
	_burn_source = source
	_burn_cliff = source_cliff


## Signal Flare: every turret prioritises this bug for `seconds`.
func mark(seconds: float) -> void:
	_mark_t = maxf(_mark_t, seconds)


func is_marked() -> bool:
	return _mark_t > 0.0


## Bee Smoker: slowed to `factor` and drowsy for `seconds`.
func smoke(factor: float, seconds: float) -> void:
	slow(factor, seconds)
	_drowsy_t = maxf(_drowsy_t, seconds)


func is_drowsy() -> bool:
	return _drowsy_t > 0.0


## Queen's Bell: attacks the bugs near it instead of climbing for `seconds`.
func frenzy(seconds: float) -> void:
	_frenzy_t = maxf(_frenzy_t, seconds)


func is_frenzied() -> bool:
	return _frenzy_t > 0.0


## Rust Duster / Acid Drencher: its armour is gone for `seconds` (every hit pierces).
func strip(seconds: float) -> void:
	_strip_t = maxf(_strip_t, seconds)


func is_stripped() -> bool:
	return _strip_t > 0.0


## Tar Sprayer: slowed to `factor` and tarred (burns double) for `seconds`.
func tar(factor: float, seconds: float) -> void:
	slow(factor, seconds)
	_tar_t = maxf(_tar_t, seconds)


func is_tarred() -> bool:
	return _tar_t > 0.0


## Flashbang: frozen in place and not attacking for `seconds`.
func stun(seconds: float) -> void:
	root(seconds)
	_stun_t = maxf(_stun_t, seconds)


func is_stunned() -> bool:
	return _stun_t > 0.0


## Hive amber: sealed in an Amber Kiln statue (no burning through the resin).
func _encased() -> bool:
	var e: Variant = (bug as Object).get("entombed") if bug is Object else null
	return e != null and float(e) > 0.0


func is_rooted() -> bool:
	return _root_t > 0.0 or frozen


func speed_multiplier() -> float:
	if is_rooted():
		return 0.0
	return _slow_factor if _slow_t > 0.0 else 1.0


func tick(delta: float) -> void:
	_slow_t = maxf(_slow_t - delta, 0.0)
	_root_t = maxf(_root_t - delta, 0.0)
	_mark_t = maxf(_mark_t - delta, 0.0)
	_drowsy_t = maxf(_drowsy_t - delta, 0.0)
	_frenzy_t = maxf(_frenzy_t - delta, 0.0)
	_strip_t = maxf(_strip_t - delta, 0.0)
	_tar_t = maxf(_tar_t - delta, 0.0)
	_stun_t = maxf(_stun_t - delta, 0.0)
	if _burn_t > 0.0 and not _encased():
		_burn_t -= delta
		bug.health.take_damage(_burn_dps * delta, _burn_source, _burn_cliff)
		if _burn_t <= 0.0:
			_burn_dps = 0.0
