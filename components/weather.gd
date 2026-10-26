class_name Weather
extends RefCounted
## Weather for one wave, plus the temperature. Weather is rolled by the host
## when the warning bell rings, lasts until the wave is over, then the sky
## clears for the build phase.
##   Clear         standard rules
##   Windy         turret shots miss more, lobbed shots drift, players get pushed
##   Light Rain    crops grow 1.5x faster and need no watering; catchers fill fast
##   Thunderstorm  rain effects plus lightning (1 in 10 strikes wrecks a turret)
##   Snow (rare)   frost eats growing crops; the cold slows bugs
##   Dust storm    (rare) you can barely see: turrets reach only ~55% as far
##   Heat wave     turrets overheat (fire slower); the heat dries crops and catchers
##   Fog bank      turrets reach only ~65% as far unless a lantern lights them up
##   Blood moon    (very rare, night only) a much bigger wave; bugs drop 2x chitin
## Temperature (degrees F) comes from the time of day plus the weather. It
## scales crop growth (happiest 60-90 F), rain-catcher filling, and bug speed
## (cold bugs are sluggish, hot bugs are quick). Pure rules, unit-tested.

enum Kind { CLEAR, WINDY, LIGHT_RAIN, THUNDERSTORM, SNOW, DUST_STORM, HEAT_WAVE, FOG, BLOOD_MOON }

const NAMES: Array[String] = ["Clear skies", "Windy", "Light rain", "Thunderstorm", "Snow", "Dust storm",
	"Heat wave", "Fog bank", "Blood moon"]
const BLURBS: Array[String] = [
	"Clear skies. Standard rules.",
	"Wind's picking up: turrets miss more, mortars drift, and you'll get pushed around.",
	"Light rain: crops grow faster and need no water.",
	"Thunderstorm: rain feeds the crops, but lightning can wreck a turret.",
	"SNOW? Frost is killing the crops, but the cold slows the bugs.",
	"Dust storm! Turrets can barely see. Get on the guns yourself.",
	"Heat wave: turrets run hot and fire slower, crops and catchers dry out.",
	"Fog bank rolling in: turrets can't see far unless a lantern lights the way.",
	"BLOOD MOON. A huge swarm is coming, and every bug drops double chitin.",
]
## Roll weights: plain weather is common, the dramatic kinds are rarer.
const WEIGHTS: Array[float] = [34.0, 18.0, 16.0, 9.0, 4.0, 5.0, 7.0, 7.0, 3.0]


## `night`: whether the wave happens at night (blood moons only rise at night).
static func roll(rng: RandomNumberGenerator, night: bool = true) -> Kind:
	var total := 0.0
	for i in WEIGHTS.size():
		total += _weight(i, night)
	var r := rng.randf() * total
	for i in WEIGHTS.size():
		r -= _weight(i, night)
		if r <= 0.0:
			return i as Kind
	return Kind.CLEAR


static func _weight(i: int, night: bool) -> float:
	if i == Kind.BLOOD_MOON and not night:
		return 0.0
	return WEIGHTS[i]


## Is the wave starting at this hour a night wave?
static func is_night(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= 18.0 or h < 6.0


static func is_rain(k: int) -> bool:
	return k == Kind.LIGHT_RAIN or k == Kind.THUNDERSTORM


## Crop growth speed multiplier from the weather itself.
static func crop_rate(k: int) -> float:
	return 1.5 if is_rain(k) else 1.0


## Growing crops lose this much progress per second (frost).
static func frost_rate(k: int) -> float:
	return 0.35 if k == Kind.SNOW else 0.0


## Bug movement multiplier from the weather (snow's cold comes through the temperature).
static func bug_speed(_k: int) -> float:
	return 1.0


## Turret hit chance multiplier.
static func turret_accuracy(k: int) -> float:
	return 0.82 if k == Kind.WINDY else 1.0


## Turret range multiplier (how far they can see).
static func turret_range(k: int, lit: bool = false) -> float:
	match k:
		Kind.DUST_STORM:
			return 0.55
		Kind.FOG:
			return 1.0 if lit else 0.65
	return 1.0


## Turret time-between-shots multiplier.
static func turret_fire_interval(k: int) -> float:
	return 1.25 if k == Kind.HEAT_WAVE else 1.0


## Chitin drop multiplier.
static func chitin_mult(k: int) -> int:
	return 2 if k == Kind.BLOOD_MOON else 1


## Extra share of bugs on top of the planned wave.
static func extra_bugs(k: int) -> float:
	return 0.6 if k == Kind.BLOOD_MOON else 0.0


## Seconds between lightning strikes (0 = none).
static func lightning_interval(k: int) -> Vector2:
	return Vector2(12.0, 25.0) if k == Kind.THUNDERSTORM else Vector2.ZERO


## Chance a strike picks a turret instead of open ground.
const LIGHTNING_TURRET_CHANCE := 0.1
## Wind push on players and rocks (m/s), along +Z or -Z.
const WIND_PUSH := 1.6
## Lanterns light the fog for turrets within this distance.
const LANTERN_FOG_RADIUS := 14.0


# ------------------------------------------------------------------ temperature

## Degrees F from the hour of day and the weather: about 58 F before dawn,
## about 102 F mid-afternoon on a clear day.
static func temperature(hour: float, k: int) -> float:
	var base := 80.0 + 22.0 * sin((fposmod(hour, 24.0) - 9.0) / 24.0 * TAU)
	var offset: float = [0.0, -5.0, -10.0, -14.0, -48.0, 4.0, 18.0, -9.0, -4.0][clampi(k, 0, 8)]
	return base + offset


## Crop growth multiplier from temperature: happiest between 60 and 90 F.
static func crop_temp_rate(t: float) -> float:
	if t < 60.0:
		return clampf(lerpf(0.4, 1.0, (t - 35.0) / 25.0), 0.4, 1.0)
	if t > 90.0:
		return clampf(lerpf(1.0, 0.55, (t - 90.0) / 30.0), 0.55, 1.0)
	return 1.0


## Bug speed from temperature: sluggish in the cold, quick in the heat.
static func bug_temp_speed(t: float) -> float:
	return clampf(lerpf(0.75, 1.15, (t - 30.0) / 85.0), 0.75, 1.15)


## Rain-catcher fill speed multiplier (heat evaporates it).
static func water_temp_rate(t: float) -> float:
	return clampf(lerpf(1.0, 0.5, (t - 90.0) / 30.0), 0.5, 1.0)
