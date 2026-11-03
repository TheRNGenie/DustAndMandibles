extends RefCounted
## Pure rules for the Hive Mother (Story, chapter 10: The Reckoning; no
## autoloads, so the headless tests can load it). The Queen's mother, sealed in
## the lower hive since before the railroad came: three phases by her health,
## what she does how often in each, how big a brood she may call, how many
## turrets her amber hail picks and what her deep hum does to her brood.

const PHASE_2 := 0.6
const PHASE_3 := 0.3
## Bugs of her brood alive near her at once, at most.
const BROOD_CAP := 16
## Seconds between brood calls, amber hails, deep hums and shrieks in phases 1-3 (0 = never).
const BROOD_EVERY := [15.0, 12.0, 9.0]
const HAIL_EVERY := [11.0, 9.0, 7.0]
const HUM_EVERY := [0.0, 20.0, 14.0]
const SHRIEK_EVERY := [0.0, 0.0, 15.0]
## Amber hail: this many turrets picked (each hit gums every turret within HAIL_RADIUS).
const HAIL_TARGETS := [2, 3, 4]
const HAIL_RADIUS := 3.5
## Deep hum: her brood within HUM_RADIUS climbs this much faster for HUM_SECONDS.
const HUM_RADIUS := 30.0
const HUM_SPEED := 1.5
const HUM_SECONDS := 6.0
## Phase 3: the amber crust she sheds hatches this many hive drones.
const CRUST_HATCH := 5
## Phase 3: she climbs this much faster and takes this much more damage.
const ENRAGED_SPEED := 1.45
const ENRAGED_DAMAGE := 1.25


static func phase(hp_frac: float) -> int:
	if hp_frac > PHASE_2:
		return 1
	if hp_frac > PHASE_3:
		return 2
	return 3


static func _of(table: Array, p: int) -> float:
	return float(table[clampi(p, 1, 3) - 1])


static func brood_every(p: int) -> float:
	return _of(BROOD_EVERY, p)


static func hail_every(p: int) -> float:
	return _of(HAIL_EVERY, p)


static func hum_every(p: int) -> float:
	return _of(HUM_EVERY, p)


static func shriek_every(p: int) -> float:
	return _of(SHRIEK_EVERY, p)


static func hail_targets(p: int) -> int:
	return int(HAIL_TARGETS[clampi(p, 1, 3) - 1])


## The brood she calls in phase `p`: [[bug id, count], ...] before the cap.
static func brood(p: int) -> Array:
	match clampi(p, 1, 3):
		1:
			return [[&"wolf_spider", 4], [&"brood_mother", 1]]
		2:
			return [[&"wolf_spider", 3], [&"spitter_scorpion", 3]]
	return [[&"hive_drone", 4], [&"rattler_beetle", 2]]


static func room(alive: int, want: int) -> int:
	return clampi(BROOD_CAP - alive, 0, want)


static func speed(p: int) -> float:
	return ENRAGED_SPEED if p >= 3 else 1.0


static func damage_taken(p: int) -> float:
	return ENRAGED_DAMAGE if p >= 3 else 1.0
