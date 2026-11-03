extends RefCounted
## Pure rules for the Hive Queen (no autoloads, so the headless tests can load
## it): her three phases, how often she does what in each, and how big a brood
## she may call with so many of her bugs already alive.

## Phase 2 starts below this much health, phase 3 (plates shed, enraged) below the next.
const PHASE_2 := 0.6
const PHASE_3 := 0.3
## Bugs of her brood alive at once, at most.
const BROOD_CAP := 14
## Seconds between brood calls, resin spits and shrieks in phases 1-3 (0 = never).
const BROOD_EVERY := [16.0, 13.0, 9.0]
const SPIT_EVERY := [10.0, 8.0, 6.5]
const SHRIEK_EVERY := [0.0, 18.0, 13.0]
## Phase 3: she climbs this much faster and takes this much more damage.
const ENRAGED_SPEED := 1.6
const ENRAGED_DAMAGE := 1.3


## Her phase (1-3) at `hp_frac` of her health.
static func phase(hp_frac: float) -> int:
	if hp_frac > PHASE_2:
		return 1
	if hp_frac > PHASE_3:
		return 2
	return 3


static func brood_every(p: int) -> float:
	return BROOD_EVERY[clampi(p, 1, 3) - 1]


static func spit_every(p: int) -> float:
	return SPIT_EVERY[clampi(p, 1, 3) - 1]


static func shriek_every(p: int) -> float:
	return SHRIEK_EVERY[clampi(p, 1, 3) - 1]


## The brood she calls in phase `p`: [[bug id, count], ...] before the cap.
static func brood(p: int) -> Array:
	match clampi(p, 1, 3):
		1:
			return [[&"wolf_spider", 4]]
		2:
			return [[&"wolf_spider", 3], [&"spitter_scorpion", 2]]
	return [[&"hive_drone", 4], [&"wolf_spider", 3]]


## How many more she may call with `alive` of her brood still up, wanting `want`.
static func room(alive: int, want: int) -> int:
	return clampi(BROOD_CAP - alive, 0, want)


static func speed(p: int) -> float:
	return ENRAGED_SPEED if p >= 3 else 1.0


static func damage_taken(p: int) -> float:
	return ENRAGED_DAMAGE if p >= 3 else 1.0
