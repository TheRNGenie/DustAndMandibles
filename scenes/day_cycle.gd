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

var env: Environment
var sun: DirectionalLight3D
var sky: ShaderMaterial
## Hours since the run began at noon (12 = noon of day one).
var clock := START_HOUR

var _target := START_HOUR
var _rate := 0.0
var _storm := 0.0

## Hour, sun colour, sun energy, ambient, sky top, sky horizon.
const KEYS: Array = [
	[0.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#0E1630"), Color("#2C3560")],
	[4.5, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#141C3C"), Color("#3A3F6A")],
	[6.0, Color("#FFB08A"), 0.75, Color("#9A7AA8"), Color("#5E7FB8"), Color("#F6A27A")],
	[8.5, Color("#FFE2B8"), 1.15, Color("#B08AB8"), Color("#4FA8D2"), Color("#F7D2A0")],
	[12.0, Color("#FFF2D8"), 1.35, Color("#B898C0"), Color("#4FB8D8"), Color("#F7D9A0")],
	[15.5, Color("#FFE2B8"), 1.2, Color("#B08AB8"), Color("#4FA8D2"), Color("#F5C890")],
	[18.0, Color("#FF9A4A"), 1.0, Color("#7A5A8C"), Color("#3E5C93"), Color("#F08A4B")],
	[19.5, Color("#C27AA0"), 0.55, Color("#5A4A7A"), Color("#24305E"), Color("#9A5A7A")],
	[21.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#141C3C"), Color("#33396A")],
	[24.0, Color("#8FA6D9"), 0.35, Color("#4A4E7A"), Color("#0E1630"), Color("#2C3560")],
]
const STAGES: Array = [[5.0, "DEAD OF NIGHT"], [7.0, "DAYBREAK"], [11.0, "MORNING"], [13.0, "HIGH NOON"],
	[17.0, "AFTERNOON"], [19.0, "SUNDOWN"], [23.0, "NIGHTFALL"], [24.0, "MIDNIGHT"]]


func _ready() -> void:
	instance = self
	GameState.phase_changed.connect(_on_phase)
	clock = START_HOUR
	if GameState.flag_value("--hour") != "":
		clock = GameState.flag_value("--hour").to_float()
	_target = clock
	_apply_now()
	Audio.play_music(&"build_loop")


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


func _on_phase(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.WAVE:
			clock = maxf(clock, _wave_start(GameState.wave))
			_target = _wave_start(GameState.wave) + HOURS_PER_WAVE
			_rate = HOURS_PER_WAVE / WAVE_SECONDS
			Audio.play_music(&"wave_loop")
		GameState.Phase.WARNING:
			Audio.play_music(&"wave_loop")
		GameState.Phase.BUILD, GameState.Phase.LOBBY:
			if GameState.flag_value("--hour") != "":
				return
			# Finish the wave's quarter day quickly, then hold still until the next wave.
			_target = _wave_start(GameState.wave)
			_rate = maxf(absf(_target - clock) / CATCH_UP_SECONDS, 0.01)
			Audio.play_music(&"build_loop")
		GameState.Phase.GAME_OVER:
			_rate = 0.0
			Audio.play_music(&"")


func _process(delta: float) -> void:
	if clock < _target:
		clock = minf(clock + _rate * delta, _target)
	var want_storm := 1.0 if (GameState.storm and GameState.phase == GameState.Phase.BUILD) else 0.0
	_storm = move_toward(_storm, want_storm, delta / 5.0)
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
		sun_color = sun_color.lerp(Color("#C9C3BA"), _storm * 0.7)
		energy = lerpf(energy, energy * 0.6, _storm)
		top = top.lerp(Color("#6F7C8A"), _storm * 0.8)
		horizon = horizon.lerp(Color("#B9AE9E"), _storm * 0.8)
	# The sun arcs east to west between 6:00 and 18:00; at night a moon takes over.
	var day_t := (h - 6.0) / 12.0
	if day_t >= 0.0 and day_t <= 1.0:
		var elevation := sin(day_t * PI) * 68.0
		sun.rotation_degrees = Vector3(-maxf(elevation, 8.0), lerpf(-100.0, 100.0, day_t), 0.0)
	else:
		var night_t := fposmod(h - 18.0, 24.0) / 12.0
		var moon_el := sin(night_t * PI) * 50.0
		sun.rotation_degrees = Vector3(-maxf(moon_el, 12.0), lerpf(-100.0, 100.0, night_t), 0.0)
	sun.light_color = sun_color
	sun.light_energy = energy
	env.ambient_light_color = ambient
	env.fog_light_color = horizon
	sky.set_shader_parameter("top_color", top)
	sky.set_shader_parameter("horizon_color", horizon)
	# Clouds pick up the light: white by day, warm at dusk, dim blue-grey at night.
	sky.set_shader_parameter("cloud_color", Color("#FFF7EA").lerp(sun_color, 0.35) * clampf(energy / 1.2, 0.3, 1.0) + horizon * 0.15)
	sky.set_shader_parameter("sun_color", sun_color)
