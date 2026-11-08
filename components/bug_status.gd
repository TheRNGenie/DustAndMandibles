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
## Universal crop-fed turrets (CropEffects): Cotton's stacking slow, Herbs'
## poison stacks, Sulfur Root's volatile, Sarsaparilla's mark.
var _cslow_t := 0.0
var _cslow := 0.0
var _poison: Array = [] # [dps, seconds left] per stack
var _poison_source := ""
var _poison_cliff := -1
var _vol_t := 0.0
var _vol_k := 1.0
var _vol_source := ""
var _vol_cliff := -1
var _cmark_t := 0.0
var _cmark_bonus := 0.0
## Special weapons (Crop Syringe, Venom Needle): shell weakened, takes more damage.
var _weak_t := 0.0
var _weak_bonus := 0.0


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


## Cotton: each hit takes `step` more off its speed (up to `most`) for `seconds`.
func crop_slow(step: float, most: float, seconds: float) -> void:
	_cslow = minf((_cslow if _cslow_t > 0.0 else 0.0) + step, most)
	_cslow_t = seconds


func crop_slowed() -> float:
	return _cslow if _cslow_t > 0.0 else 0.0


## Herbs: a poison stack of `dps` for `seconds`; at most `most` stacks (a new
## one past that replaces the one closest to running out).
func poison(dps: float, seconds: float, most: int, source: String, source_cliff: int) -> void:
	if _encased():
		return
	_poison_source = source
	_poison_cliff = source_cliff
	if _poison.size() < most:
		_poison.append([dps, seconds])
		return
	var low := 0
	for i in _poison.size():
		if float(_poison[i][1]) < float(_poison[low][1]):
			low = i
	_poison[low] = [dps, seconds]


func poison_stacks() -> int:
	return _poison.size()


## Sulfur Root: for `seconds`, dying sets off a blast (CropEffects.volatile_burst).
func volatile(seconds: float, k: float, source: String, source_cliff: int) -> void:
	_vol_t = maxf(_vol_t, seconds)
	_vol_k = maxf(_vol_k if _vol_t > 0.0 else 0.0, k)
	_vol_source = source
	_vol_cliff = source_cliff


func is_volatile() -> bool:
	return _vol_t > 0.0


func volatile_k() -> float:
	return _vol_k


func volatile_source() -> String:
	return _vol_source


func volatile_cliff() -> int:
	return _vol_cliff


## Sarsaparilla: +`bonus` damage from everything for `seconds` (refreshed, not stacked).
func crop_mark(seconds: float, bonus: float) -> void:
	_cmark_t = seconds
	_cmark_bonus = maxf(_cmark_bonus if _cmark_t > 0.0 else 0.0, bonus)


func is_crop_marked() -> bool:
	return _cmark_t > 0.0


## Special weapons: +`bonus` damage from everything for `seconds` (the strongest
## one running counts). Multiplies with Sarsaparilla's mark.
func weaken(seconds: float, bonus: float) -> void:
	_weak_bonus = maxf(_weak_bonus if _weak_t > 0.0 else 0.0, bonus)
	_weak_t = maxf(_weak_t, seconds)


func is_weakened() -> bool:
	return _weak_t > 0.0


## Every hit's damage multiplier from statuses (Sarsaparilla's mark, a weakened shell).
func damage_taken_mult() -> float:
	return (1.0 + (_cmark_bonus if _cmark_t > 0.0 else 0.0)) * (1.0 + (_weak_bonus if _weak_t > 0.0 else 0.0))


func speed_multiplier() -> float:
	if is_rooted():
		return 0.0
	return (_slow_factor if _slow_t > 0.0 else 1.0) * (1.0 - crop_slowed())


func tick(delta: float) -> void:
	_slow_t = maxf(_slow_t - delta, 0.0)
	_root_t = maxf(_root_t - delta, 0.0)
	_mark_t = maxf(_mark_t - delta, 0.0)
	_drowsy_t = maxf(_drowsy_t - delta, 0.0)
	_frenzy_t = maxf(_frenzy_t - delta, 0.0)
	_strip_t = maxf(_strip_t - delta, 0.0)
	_tar_t = maxf(_tar_t - delta, 0.0)
	_stun_t = maxf(_stun_t - delta, 0.0)
	_cslow_t = maxf(_cslow_t - delta, 0.0)
	_vol_t = maxf(_vol_t - delta, 0.0)
	_cmark_t = maxf(_cmark_t - delta, 0.0)
	_weak_t = maxf(_weak_t - delta, 0.0)
	if not _poison.is_empty():
		var hurt := 0.0
		for i in range(_poison.size() - 1, -1, -1):
			var s: Array = _poison[i]
			var dt := minf(delta, float(s[1]))
			hurt += float(s[0]) * dt
			s[1] = float(s[1]) - delta
			if float(s[1]) <= 0.0:
				_poison.remove_at(i)
		if hurt > 0.0 and not _encased():
			bug.health.take_damage(hurt, _poison_source, _poison_cliff)
	if _burn_t > 0.0 and not _encased():
		_burn_t -= delta
		bug.health.take_damage(_burn_dps * delta, _burn_source, _burn_cliff)
		if _burn_t <= 0.0:
			_burn_dps = 0.0
