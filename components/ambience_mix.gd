class_name AmbienceMix
extends RefCounted
## The ambience and music levels as pure rules (scenes/ambience.gd and Audio play
## them; tests/test_ambience.gd checks them).

## Swarm levels at full intensity (the recordings sit at about -20 dBFS RMS;
## gunfire plays at 0 dB from files peaking near -1 dBFS).
const BED_DB := -7.0
const NEAR_DB := -5.0
const SILENT_DB := -60.0
const WIND_DB := -21.0
## Canyon echo of far shots, relative to the shot.
const ECHO_DB := -15.0
const ECHO_MIN_DIST := 20.0


## Swarm loudness for one wall half: `count` climbers whose summed height
## weight is `weight` (each bug 0.3 at the foot, 1.0 at the lip) and whose mean squared
## height fraction is `high`. Returns (bed dB, near-skitter dB, pitch).
static func swarm_levels(count: int, weight: float, high: float) -> Vector3:
	if count <= 0:
		return Vector3(SILENT_DB, SILENT_DB, 1.0)
	var amount := 1.0 - exp(-weight / 10.0) # 1 bug ~0.03-0.1, 10 ~0.5, 30+ ~0.95
	var bed := maxf(BED_DB + linear_to_db(maxf(amount, 0.001)), SILENT_DB)
	var near_amt := amount * smoothstep(0.15, 0.8, high)
	var near := maxf(NEAR_DB + linear_to_db(maxf(near_amt, 0.001)), SILENT_DB)
	return Vector3(bed, near, 1.0 + 0.08 * amount)


## The march on the canyon floor (`floor_bugs` walking, not yet climbing):
## x = how much the swarm's low rumble swells (0-1), y = how loud the busy
## chittering wash that comes in past 200 floor bugs is (0-1).
static func march_levels(floor_bugs: int) -> Vector2:
	var swell := clampf(log(1.0 + float(maxi(floor_bugs, 0))) / log(601.0), 0.0, 1.0)
	return Vector2(swell, smoothstep(200.0, 600.0, float(floor_bugs)))


## Wind bed level for weather `w`, closeness to the lip `edge` (0-1) and height
## above the plateau `height` (0-1, the airship deck is near 1).
static func wind_db(w: int, edge: float, height: float) -> float:
	var weather_db := 0.0
	match w:
		Weather.Kind.WINDY:
			weather_db = 6.0
		Weather.Kind.DUST_STORM:
			weather_db = 9.0
		Weather.Kind.THUNDERSTORM:
			weather_db = 4.0
		Weather.Kind.LIGHT_RAIN, Weather.Kind.SNOW:
			weather_db = 2.0
		Weather.Kind.FOG, Weather.Kind.HEAT_WAVE:
			weather_db = -3.0
	return WIND_DB + 4.0 * edge + 5.0 * height + weather_db


## Music for a wave: the big theme once waves get large (and for blood moons).
static func wave_track(wave: int, weather: int) -> StringName:
	return &"wave_theme_2" if wave >= 6 or weather == Weather.Kind.BLOOD_MOON else &"wave_theme_1"


## Wave music swells a little each wave (-9 dB on the first, -5 dB by the ninth).
static func wave_music_db(wave: int) -> float:
	return -9.0 + 0.5 * float(clampi(wave - 1, 0, 8))


## How loud the echo of a shot `dist` metres away is, relative to the shot: it
## fades in past ECHO_MIN_DIST and fades again for very distant shots.
static func echo_db(dist: float) -> float:
	var near := clampf((dist - ECHO_MIN_DIST) / 25.0, 0.0, 1.0)
	var far := clampf((dist - 90.0) / 120.0, 0.0, 1.0)
	return ECHO_DB + linear_to_db(maxf(near, 0.001)) - 8.0 * far
