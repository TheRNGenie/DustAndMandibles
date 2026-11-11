class_name Weather
extends RefCounted
## Weather for one wave, plus the temperature. Weather is rolled by the host
## when the warning bell rings, lasts until the wave is over, then the sky
## clears for the build phase.
##   Clear         standard rules
##   Windy         turret shots miss more, lobbed shots drift, players get pushed
##   Light Rain    crops grow 1.5x faster and need no watering; catchers fill ~7x faster
##   Thunderstorm  rain effects plus lightning (1 in 10 strikes wrecks a turret)
##   Snow (rare)   frost eats growing crops; the cold slows bugs
##   Dust storm    (rare) you can barely see: turret shots miss more with range
##   Heat wave     turrets overheat (fire slower); the heat dries crops and catchers,
##                 and players get thirsty up to twice as fast
##   Fog bank      turret shots miss more with range unless a lantern lights them up
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
	"Light rain: crops grow faster and need no water, and rain catchers fill fast.",
	"Thunderstorm: rain feeds the crops and fills the catchers, but lightning can wreck a turret.",
	"SNOW? Frost is killing the crops, but the cold slows the bugs.",
	"Dust storm! Turrets miss more the farther they shoot (lanterns help). Your own aim is fine.",
	"Heat wave: turrets run hot and fire slower, crops and catchers dry out, and you get thirsty fast.",
	"Fog bank rolling in: turrets miss more the farther they shoot, unless a lantern lights the way.",
	"BLOOD MOON. A huge swarm is coming, and every bug's shell pays double chitin.",
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
## A turret shot's chance to land, as a multiplier on its hit chance. Wind
## spoils every shot a little. Fog and dust (Nov 11 playtest fixes) cost
## accuracy, not range: near full up close, the misses come at range,
## 1 - p * dist_frac^1.2 (dist_frac = target distance over the turret's range),
## p halved within LANTERN_FOG_RADIUS of a lantern post.
const FOG_MISS := 0.45
const DUST_MISS := 0.55


static func turret_accuracy(k: int, dist_frac: float = 0.0, lit: bool = false) -> float:
	if k == Kind.WINDY:
		return 0.82
	var p := murk_miss(k)
	if p <= 0.0:
		return 1.0
	if lit:
		p *= 0.5
	return clampf(1.0 - p * pow(clampf(dist_frac, 0.0, 1.0), 1.2), 0.0, 1.0)


## The fog or dust's miss share at full range (0 in any other weather).
static func murk_miss(k: int) -> float:
	match k:
		Kind.FOG:
			return FOG_MISS
		Kind.DUST_STORM:
			return DUST_MISS
	return 0.0


## Turret range multiplier: the weather no longer shortens it (Nov 11: fog and
## dust cost accuracy instead, turret_accuracy).
static func turret_range(_k: int, _lit: bool = false) -> float:
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


## How fast players get thirsty: normal up to 85 F, about twice as fast at 115 F.
static func thirst_rate(t: float) -> float:
	return clampf(1.0 + (t - 85.0) / 30.0, 0.8, 2.0)


## Rain-catcher fill speed multiplier (heat evaporates it).
static func water_temp_rate(t: float) -> float:
	return clampf(lerpf(1.0, 0.5, (t - 90.0) / 30.0), 0.5, 1.0)
