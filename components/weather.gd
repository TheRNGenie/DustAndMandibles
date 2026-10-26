class_name Weather
extends RefCounted
## Weather for one wave. Rolled by the host when the warning bell rings, lasts
## until the wave is over, then the sky clears for the build phase.
##   Clear         standard rules
##   Windy         gusts along the canyon: turret shots miss more, lobbed shots
##                 drift, players and thrown rocks get pushed
##   Light Rain    crops grow 1.5x faster and need no watering; catchers fill fast
##   Thunderstorm  rain effects plus lightning: every so often a bolt hits a
##                 turret and wrecks it (and fries any bugs it lands on)
##   Snow (rare)   frost: growing crops lose progress; cold bugs climb slower
## Pure rules (no nodes) so they can be unit-tested.

enum Kind { CLEAR, WINDY, LIGHT_RAIN, THUNDERSTORM, SNOW }

const NAMES: Array[String] = ["Clear skies", "Windy", "Light rain", "Thunderstorm", "Snow"]
const BLURBS: Array[String] = [
	"Clear skies. Standard rules.",
	"Wind's picking up: turrets miss more, mortars drift, and you'll get pushed around.",
	"Light rain: crops grow faster and need no water.",
	"Thunderstorm: rain feeds the crops, but lightning can wreck a turret.",
	"SNOW? Frost is killing the crops, but the cold slows the bugs.",
]
## Roll weights: plain weather is common, the dramatic kinds are rarer.
const WEIGHTS: Array[float] = [40.0, 24.0, 20.0, 11.0, 5.0]


static func roll(rng: RandomNumberGenerator) -> Kind:
	var total := 0.0
	for w in WEIGHTS:
		total += w
	var r := rng.randf() * total
	for i in WEIGHTS.size():
		r -= WEIGHTS[i]
		if r <= 0.0:
			return i as Kind
	return Kind.CLEAR


static func is_rain(k: int) -> bool:
	return k == Kind.LIGHT_RAIN or k == Kind.THUNDERSTORM


## Crop growth speed multiplier.
static func crop_rate(k: int) -> float:
	return 1.5 if is_rain(k) else 1.0


## Growing crops lose this much progress per second (frost).
static func frost_rate(k: int) -> float:
	return 0.35 if k == Kind.SNOW else 0.0


## Bug movement multiplier.
static func bug_speed(k: int) -> float:
	return 0.8 if k == Kind.SNOW else 1.0


## Turret hit chance multiplier.
static func turret_accuracy(k: int) -> float:
	return 0.82 if k == Kind.WINDY else 1.0


## Seconds between lightning strikes (0 = none).
static func lightning_interval(k: int) -> Vector2:
	return Vector2(12.0, 25.0) if k == Kind.THUNDERSTORM else Vector2.ZERO


## Chance a strike picks a turret instead of open ground.
const LIGHTNING_TURRET_CHANCE := 0.2
## Wind push on players and rocks (m/s), along +Z or -Z.
const WIND_PUSH := 1.6
