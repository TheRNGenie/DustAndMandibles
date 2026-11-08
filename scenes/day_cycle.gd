class_name DayCycle
extends Node
## Time of day. The run starts at High Noon and each wave moves the clock a
## quarter of a day (6 hours): wave 1 runs noon to sundown, wave 2 into
## midnight, wave 3 to daybreak, wave 4 back to noon, and so on. The clock only
## moves while bugs are coming; between waves it stands still. Sun, sky, fog,
## ambient light and a moon at night all follow the clock. Storm build phases
## grey the sky over. Music still switches between the build and wave loops.

static var instance: DayCycle

const START_HOUR := 12.0
const HOURS_PER_WAVE := 6.0
## About how long a wave lasts; the clock reaches the wave's end hour over this
## time and waits there if the wave runs long.
const WAVE_SECONDS := 150.0
const CATCH_UP_SECONDS := 4.0
## Sun bearing (yaw degrees) at sunrise and sunset: near the canyon's two ends.
const SUN_YAW := Vector2(-15.0, 192.0)
## Lowest the sun sits (degrees): high enough to clear the canyon's far rim so
## golden-hour light still reaches the floor.
const SUN_MIN_ELEVATION := 14.0

var env: Environment
var sun: DirectionalLight3D
var sky: ShaderMaterial
## Hours since the run began at noon (12 = noon of day one).
var clock := START_HOUR

var _target := START_HOUR
var _rate := 0.0
var _storm := 0.0
var _snap_weather := false
var _snow := 0.0
## Weather colour cast (alpha = strength) and fog thickness, eased.
var _tint := Color(1, 1, 1, 0)
var _fog_mult := 1.0
var _base_curve := 1.0
var _base_fog := -1.0
## Lightning: a brief flash added on top of everything.
var flash := 0.0
## Haze multiplier from smoking (Cigarette).
var clarity_fog := 1.0

## Hour, sun colour, sun energy, ambient, sky top, sky horizon.
const KEYS: Array = [
	[0.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#0A1028"), Color("#28305A")],
	[4.5, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#101838"), Color("#343A66")],
	[5.3, Color("#C08AB0"), 0.45, Color("#5A4A7A"), Color("#2A3468"), Color("#C87A8A")],
	[6.0, Color("#FFB08A"), 0.75, Color("#9A7AA8"), Color("#5E7FB8"), Color("#F6A27A")],
	[7.0, Color("#FFD0A0"), 1.0, Color("#A882B4"), Color("#5A9AC8"), Color("#F8C090")],
	[8.5, Color("#FFE2B8"), 1.15, Color("#B08AB8"), Color("#4FA8D2"), Color("#F7D2A0")],
	[12.0, Color("#FFF2D8"), 1.35, Color("#B898C0"), Color("#4FB8D8"), Color("#F7D9A0")],
	[15.5, Color("#FFE2B8"), 1.2, Color("#B08AB8"), Color("#4FA8D2"), Color("#F5C890")],
	[17.0, Color("#FFC870"), 1.25, Color("#A884A8"), Color("#4A8CC8"), Color("#F8B878")],
	[18.0, Color("#FFA848"), 1.15, Color("#7E5E92"), Color("#3A5A98"), Color("#FF9A52")],
	[18.8, Color("#FF6A5A"), 0.72, Color("#6A4A80"), Color("#2C3C78"), Color("#E0607A")],
	[19.6, Color("#A27AC0"), 0.45, Color("#4E4478"), Color("#1C2552"), Color("#6A4C80")],
	[21.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#101838"), Color("#30386A")],
	[24.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#0A1028"), Color("#28305A")],
]
const STAGES: Array = [[5.0, "DEAD OF NIGHT"], [7.0, "DAYBREAK"], [11.0, "MORNING"], [13.0, "HIGH NOON"],
	[17.0, "AFTERNOON"], [19.0, "SUNDOWN"], [23.0, "NIGHTFALL"], [24.0, "MIDNIGHT"]]

## The sky's cloud noise (made by tools/sky/make_sky_noise.py).
const SKY_NOISE: Texture2D = preload("res://assets/sky/sky_noise.png")
## The sky's cloud mix (Logan: "a much more detailed and varied skybox"). Each
## wave the run's seed picks one of these styles, a touch jittered, and the
## weather then pushes it about (see _sky_targets):
## [cumulus cover, cirrus, mackerel sky, horizon banks, cloud size].
const SKY_STYLES: Array = [
	[0.30, 0.30, 0.0, 0.45, 1.0], # fair weather
	[0.50, 0.12, 0.0, 0.60, 1.15], # big puffy cumulus
	[0.20, 0.15, 0.85, 0.35, 0.95], # a mackerel sky
	[0.12, 1.0, 0.0, 0.30, 1.0], # mares' tails
	[0.06, 0.30, 0.0, 0.90, 1.0], # a big clear sky with towers on the horizon
	[0.62, 0.0, 0.35, 0.50, 0.9], # broken cloud
]
const SKY_STYLE_NAMES: Array[String] = ["fair", "puffy", "mackerel", "mares_tails", "big_sky", "broken"]
## The moon's phase night by night (0.5 = full), starting from the run's seed.
const MOON_PHASES: Array[float] = [0.5, 0.62, 0.38, 0.72, 0.28, 0.84, 0.56, 0.18]
## How fast the clouds drift (noise units a second at wind strength 1).
const CLOUD_DRIFT := 0.0025
## Seconds a full change of the cloud mix takes (a new wave, new weather).
const SKY_EASE_SECONDS := 10.0
## Force a style from SKY_STYLES (-1 = the wave's own; the UI gallery sets it).
var sky_style := -1
## The cloud mix as it stands (eased toward _sky_targets), and how far the wind
## has carried the clouds.
var _sky_mix: Dictionary = {}
var _drift := Vector2.ZERO

## Free CC0 western tracks (audio/CREDITS.txt): a calm guitar piece between waves.
const BUILD_MUSIC := &"build_theme"
const BUILD_MUSIC_DB := -8.0


func _ready() -> void:
	instance = self
	GameState.phase_changed.connect(_on_phase)
	clock = START_HOUR
	if GameState.flag_value("--hour") != "":
		clock = GameState.flag_value("--hour").to_float()
	_target = clock
	_apply_now()
	Audio.play_music(BUILD_MUSIC, 2.5, BUILD_MUSIC_DB)


## Hour of the day, 0-24.
func hour() -> float:
	return fposmod(clock, 24.0)


func stage_name() -> String:
	var h := hour()
	if h < 1.0:
		return "MIDNIGHT"
	for s: Array in STAGES:
		if h < float(s[0]):
			return str(s[1])
	return "MIDNIGHT"


func is_night() -> bool:
	var h := hour()
	return h >= 20.0 or h < 5.5


func _wave_start(w: int) -> float:
	return START_HOUR + HOURS_PER_WAVE * float(maxi(w - 1, 0))


func _wave_music() -> StringName:
	return AmbienceMix.wave_track(GameState.wave, GameState.weather, AmbienceMix.bosses_in(WaveDirector.preview))


func _on_phase(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.WAVE:
			clock = maxf(clock, _wave_start(GameState.wave))
			_target = _wave_start(GameState.wave) + HOURS_PER_WAVE
			_rate = HOURS_PER_WAVE / WAVE_SECONDS
			Audio.play_music(_wave_music(), 2.5, AmbienceMix.wave_music_db(GameState.wave))
		GameState.Phase.WARNING:
			Audio.play_music(_wave_music(), 2.5, AmbienceMix.wave_music_db(GameState.wave))
		GameState.Phase.BUILD, GameState.Phase.LOBBY:
			if GameState.flag_value("--hour") != "":
				return
			# Finish the wave's quarter day quickly, then hold still until the next wave.
			_target = _wave_start(GameState.wave)
			_rate = maxf(absf(_target - clock) / CATCH_UP_SECONDS, 0.01)
			Audio.play_music(BUILD_MUSIC, 2.5, BUILD_MUSIC_DB)
		GameState.Phase.GAME_OVER:
			_rate = 0.0
			Audio.play_music(&"victory_theme" if GameState.won else &"", 2.0, BUILD_MUSIC_DB)


func _process(frame_delta: float) -> void:
	if clock < _target:
		clock = minf(clock + _rate * frame_delta, _target)
	# (snap_sky: the weather's light, haze and tint jump straight to their targets.)
	var delta := 1000.0 if _snap_weather else frame_delta
	_snap_weather = false
	var want_storm: float = [0.0, 0.25, 0.6, 0.95, 0.7, 0.85, 0.0, 0.5, 0.0][clampi(GameState.weather, 0, 8)]
	_tint = _tint.lerp(_weather_tint(GameState.weather), clampf(delta / 4.0, 0.0, 1.0))
	# Rain and storms grey the distance; a dust storm's murk surges with the gusts.
	var fog_mult: float = [1.0, 1.0, 1.8, 2.6, 2.2, 6.0, 1.4, 11.0, 1.6][clampi(GameState.weather, 0, 8)]
	if GameState.weather == Weather.Kind.DUST_STORM and WeatherFx.instance != null:
		fog_mult *= 0.7 + 0.6 * WeatherFx.instance.gust
	_fog_mult = lerpf(_fog_mult, fog_mult, clampf(delta / 4.0, 0.0, 1.0))
	# (A dust storm is murk, not storm cloud: it only half greys the light.)
	if GameState.weather == Weather.Kind.DUST_STORM:
		want_storm = 0.4
	_storm = move_toward(_storm, want_storm, delta / 5.0)
	var snow := 1.0 if GameState.weather == Weather.Kind.SNOW else 0.0
	_snow = move_toward(_snow, snow, delta / 5.0)
	_ease_sky(frame_delta)
	if env != null:
		if _base_fog < 0.0:
			_base_fog = env.fog_density
			_base_curve = env.fog_depth_curve
		var thick := (1.0 + _storm * 1.6) * _fog_mult * clarity_fog
		if env.fog_mode == Environment.FOG_MODE_DEPTH:
			# Depth fog (World: fully fogged by the far plane): weather thickens it
			# by bending the curve (a lower power fogs nearer).
			env.fog_depth_curve = float(env.get_meta(&"base_curve", _base_curve)) / pow(maxf(thick, 0.01), 0.6)
		else:
			env.fog_density = _base_fog * thick
	_apply_now()


func _apply_now() -> void:
	if sun == null or env == null or sky == null:
		return
	var h := hour()
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := clampf((h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	var sun_color: Color = (a[1] as Color).lerp(b[1], t)
	var energy := lerpf(float(a[2]), float(b[2]), t)
	var ambient: Color = (a[3] as Color).lerp(b[3], t)
	var top: Color = (a[4] as Color).lerp(b[4], t)
	var horizon: Color = (a[5] as Color).lerp(b[5], t)
	if _storm > 0.0:
		var grey := Color("#C9C3BA").lerp(Color("#E8EEF4"), _snow)
		sun_color = sun_color.lerp(grey, _storm * 0.7)
		energy = lerpf(energy, energy * 0.3, _storm)
		top = top.lerp(Color("#4C5866").lerp(Color("#B8C4D0"), _snow), _storm * 0.9)
		horizon = horizon.lerp(Color("#8E8E8C").lerp(Color("#E4E8EC"), _snow), _storm * 0.85)
		ambient = ambient.lerp(Color("#727A92").lerp(Color("#C8D0E0"), _snow), _storm * 0.7)
	if _tint.a > 0.01:
		var tc := Color(_tint.r, _tint.g, _tint.b)
		top = top.lerp(tc, _tint.a)
		horizon = horizon.lerp(tc.lightened(0.15), _tint.a)
		ambient = ambient.lerp(tc, _tint.a * 0.6)
		sun_color = sun_color.lerp(tc.lightened(0.3), _tint.a * 0.7)
	if flash > 0.0:
		flash = maxf(flash - get_process_delta_time() * 4.0, 0.0)
		ambient = ambient.lerp(Color("#E8F0FF"), flash)
		energy += flash * 2.0
	# The sun arcs over between 6:00 and 18:00, rising and setting near the two
	# ends of the canyon so the low golden-hour light rakes along it and every
	# pillar, turret and bug throws a long shadow down the floor. At night a
	# moon takes over.
	var day_t := (h - 6.0) / 12.0
	if day_t >= 0.0 and day_t <= 1.0:
		var elevation := sin(day_t * PI) * 68.0
		sun.rotation_degrees = Vector3(-maxf(elevation, SUN_MIN_ELEVATION), lerpf(SUN_YAW.x, SUN_YAW.y, day_t), 0.0)
	else:
		var night_t := fposmod(h - 18.0, 24.0) / 12.0
		var moon_el := sin(night_t * PI) * 50.0
		sun.rotation_degrees = Vector3(-maxf(moon_el, 12.0), lerpf(-100.0, 100.0, night_t), 0.0)
	sun.light_color = sun_color
	sun.light_energy = energy
	# Under storm cloud the shadows go soft and faint.
	sun.shadow_opacity = lerpf(1.0, 0.3, clampf(_storm * 1.1, 0.0, 1.0))
	# Grade: at golden hour the fill light leans to a dusty neutral (the red wash
	# flattened the painted rock, wood and chitin), and nights get a touch more
	# moonlit fill so the textures still read.
	ambient = ambient.lerp(Color("#B9AA9C"), golden_amount() * 0.3 * (1.0 - _storm))
	ambient = ambient.lerp(Color("#8E98C0"), night_amount() * 0.18)
	env.ambient_light_color = ambient
	# Golden hour: the haze stays a soft dusty peach, so the low sun reads as
	# warm light and long violet shadows rather than flooding everything orange.
	env.fog_light_color = horizon.lerp(Color("#C89A9A"), golden_amount() * 0.45 * (1.0 - _storm))
	_sky_set("fog_color", env.fog_light_color) # the far ground melts into the sky
	_sky_set("top_color", top)
	_sky_set("horizon_color", horizon)
	# Clouds pick up the light: white by day, warm at dusk, dim blue-grey at night.
	_sky_set("cloud_color", Color("#FFF7EA").lerp(sun_color, 0.35) * clampf(energy / 1.2, 0.3, 1.0) + horizon * 0.15)
	_sky_set("sun_color", sun_color)
	# Stars and moon at night, a flaring horizon at golden hour.
	var n := night_amount()
	var g := golden_amount() * (1.0 - _storm)
	_sky_set("night", n)
	_sky_set("golden", g)
	_sky_set("glow_color", Color("#FF7A3A") if h > 12.0 else Color("#FF9A7A"))
	_sky_set("overcast", clampf(_storm * 1.2, 0.0, 1.0))
	_sky_set("flash", flash)
	_send_sky_mix()
	_glow_at_night(n)


## Sky parameters as last sent: only changes go to the sky (between waves the
## clock stands still, and each change makes the sky redo its reflections).
var _sky_sent: Dictionary = {}


func _sky_set(param: StringName, value: Variant) -> void:
	var was: Variant = _sky_sent.get(param)
	if was != null and typeof(was) == typeof(value) and (was == value or (value is Color and (value as Color).is_equal_approx(was)) or (value is float and is_equal_approx(value, was))):
		return
	_sky_sent[param] = value
	sky.set_shader_parameter(param, value)


## The run's seed (the wave planner's), so each run gets its own skies.
func _run_seed() -> int:
	var planner: Variant = WaveDirector.get("_planner")
	return int(planner.get("_seed")) if planner != null else 0


## The cloud mix this wave and weather call for: the wave's style from the run's
## seed (the first build phase is always fair weather), then the weather on top.
func _sky_targets() -> Dictionary:
	var seed_v := _run_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, GameState.wave, "sky"])
	var roll := rng.randi_range(0, SKY_STYLES.size() - 1)
	var pick := sky_style if sky_style >= 0 else (roll if GameState.wave > 0 else 0)
	var st: Array = SKY_STYLES[clampi(pick, 0, SKY_STYLES.size() - 1)]
	var ang := rng.randf() * TAU
	var m := {"cover": float(st[0]) * rng.randf_range(0.85, 1.15), "cirrus": float(st[1]), "alto": float(st[2]),
		"bank": float(st[3]), "scale": float(st[4]) * rng.randf_range(0.9, 1.1),
		"wind": Vector2(cos(ang), sin(ang)) * rng.randf_range(0.7, 1.3),
		"storm": 0.0, "dust": 0.0, "heat": 0.0, "haze": 0.0, "blood": 0.0}
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = hash([seed_v, "sky seed"])
	m["seed"] = Vector2(seed_rng.randf(), seed_rng.randf()) * 8.0
	var along := Vector2(WeatherFx.wind_sign(), 0.0) # gusts blow along the canyon
	match GameState.weather:
		Weather.Kind.WINDY:
			m["wind"] = along * 3.0
			m["cirrus"] = maxf(float(m["cirrus"]), 0.8)
			m["cover"] = float(m["cover"]) * 0.8
		Weather.Kind.LIGHT_RAIN:
			m.merge({"cover": 0.84, "cirrus": 0.0, "alto": 0.0, "bank": 0.6, "storm": 0.45}, true)
		Weather.Kind.THUNDERSTORM:
			m.merge({"cover": 0.95, "cirrus": 0.0, "alto": 0.0, "bank": 1.0, "storm": 1.0}, true)
			m["wind"] = (m["wind"] as Vector2) * 2.0
		Weather.Kind.SNOW:
			m.merge({"cover": 0.9, "cirrus": 0.0, "alto": 0.3, "bank": 0.5}, true)
		Weather.Kind.DUST_STORM:
			m.merge({"dust": 1.0, "cover": 0.25, "cirrus": 0.0, "alto": 0.0, "wind": along * 2.5}, true)
		Weather.Kind.HEAT_WAVE:
			m.merge({"heat": 1.0, "cover": 0.04, "cirrus": 0.15, "alto": 0.0, "bank": 0.15}, true)
		Weather.Kind.FOG:
			m.merge({"haze": 1.0, "cover": 0.5}, true)
		Weather.Kind.BLOOD_MOON:
			m["blood"] = 1.0
			m["cover"] = minf(float(m["cover"]), 0.3)
	return m


## Eases the cloud mix toward this wave's and weather's, and lets the wind
## carry the clouds along.
func _ease_sky(delta: float) -> void:
	var want := _sky_targets()
	if _sky_mix.is_empty():
		_sky_mix = want
	var k := delta / SKY_EASE_SECONDS
	for key: String in want:
		var w: Variant = want[key]
		if key == "seed":
			_sky_mix[key] = w
		elif w is Vector2:
			_sky_mix[key] = (_sky_mix[key] as Vector2).move_toward(w, k * 3.0)
		else:
			_sky_mix[key] = move_toward(float(_sky_mix[key]), float(w), k)
	_drift += (_sky_mix["wind"] as Vector2) * CLOUD_DRIFT * delta


## Jumps the cloud mix straight to this wave's and weather's (the UI gallery).
func snap_sky() -> void:
	_sky_mix = _sky_targets()
	_snap_weather = true
	_apply_now()


## The moon's phase tonight (a blood moon is always full).
func moon_phase() -> float:
	if GameState.weather == Weather.Kind.BLOOD_MOON:
		return 0.5
	var night_i := int(floor((clock + 6.0) / 24.0))
	return MOON_PHASES[posmod(night_i + _run_seed(), MOON_PHASES.size())]


func _send_sky_mix() -> void:
	if _sky_mix.is_empty():
		_sky_mix = _sky_targets()
	_sky_set("cloud_amount", float(_sky_mix["cover"]))
	_sky_set("cirrus", float(_sky_mix["cirrus"]))
	_sky_set("alto", float(_sky_mix["alto"]))
	_sky_set("bank", float(_sky_mix["bank"]))
	_sky_set("cloud_scale", float(_sky_mix["scale"]))
	_sky_set("wind", _sky_mix["wind"])
	_sky_set("cloud_seed", _sky_mix["seed"])
	_sky_set("cloud_drift", _drift)
	for key: String in ["storm", "dust", "heat", "haze", "blood"]:
		_sky_set(key, float(_sky_mix[key]))
	_sky_set("moon_phase", moon_phase())
	_sky_set("detail", 1.0 if GraphicsQuality.level(Settings.effects) >= GraphicsQuality.MEDIUM else 0.0)


## 0 by day, 1 in full night (stars out, lamps glowing).
func night_amount() -> float:
	var h := hour()
	if h >= 12.0:
		return smoothstep(19.0, 20.6, h)
	return 1.0 - smoothstep(4.6, 6.0, h)


## 0..1 around sunrise and sunset.
func golden_amount() -> float:
	var h := hour()
	var dusk := 1.0 - clampf(absf(h - 18.2) / 1.8, 0.0, 1.0)
	var dawn := 1.0 - clampf(absf(h - 6.0) / 1.2, 0.0, 1.0)
	return smoothstep(0.0, 1.0, maxf(dusk, dawn))


var _glow_shown := -1.0


## Everything that glows (lantern glass, windows, bulbs, bug eyes) glows harder at night.
func _glow_at_night(n: float) -> void:
	if absf(n - _glow_shown) < 0.02:
		return
	_glow_shown = n
	var cache: Dictionary = Materials._cache
	for key: String in cache:
		if key.begins_with("toon_"):
			(cache[key] as ShaderMaterial).set_shader_parameter("emission_strength", 2.5 + n * 2.5)


## Colour cast for the weather (alpha = how strong).
static func _weather_tint(k: int) -> Color:
	match k:
		Weather.Kind.DUST_STORM:
			return Color(0.78, 0.55, 0.32, 0.75)
		Weather.Kind.HEAT_WAVE:
			return Color(1.0, 0.82, 0.55, 0.35)
		Weather.Kind.FOG:
			return Color(0.85, 0.86, 0.88, 0.55)
		Weather.Kind.BLOOD_MOON:
			return Color(0.75, 0.12, 0.1, 0.7)
	return Color(1, 1, 1, 0)
