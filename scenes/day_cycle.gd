class_name DayCycle
extends Node
## Lighting and music follow the phases: warm morning light and the calm guitar
## loop in the build phase, orange dusk with long shadows and the stomping loop
## during the wave. Storm build phases are grey and dim.

const BLEND_TIME := 6.0

var env: Environment
var sun: DirectionalLight3D
var sky: ShaderMaterial


class Look:
	var sun_pitch: float
	var sun_color: Color
	var sun_energy: float
	var ambient: Color
	var sky_top: Color
	var sky_horizon: Color

	func _init(p: float, sc: Color, se: float, amb: Color, top: Color, hor: Color) -> void:
		sun_pitch = p
		sun_color = sc
		sun_energy = se
		ambient = amb
		sky_top = top
		sky_horizon = hor


var _day := Look.new(-42.0, Color("#FFE8C2"), 1.25, Color("#B08AB8"), Palette.SKY_TOP, Palette.SKY_HORIZON)
var _dusk := Look.new(-14.0, Color("#FF9A4A"), 1.05, Color("#7A5A8C"), Color("#3E5C93"), Color("#F08A4B"))
var _storm := Look.new(-50.0, Color("#C9C3BA"), 0.7, Color("#8A8494"), Color("#6F7C8A"), Color("#B9AE9E"))


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)
	_apply(_day, 0.0)
	Audio.play_music(&"build_loop")


func _on_phase(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.BUILD, GameState.Phase.LOBBY:
			_apply(_storm if GameState.storm else _day, BLEND_TIME)
			Audio.play_music(&"build_loop")
		GameState.Phase.WARNING, GameState.Phase.WAVE:
			_apply(_dusk, BLEND_TIME)
			Audio.play_music(&"wave_loop")
		GameState.Phase.GAME_OVER:
			Audio.play_music(&"")


func _apply(look: Look, seconds: float) -> void:
	if seconds <= 0.0:
		sun.rotation_degrees.x = look.sun_pitch
		sun.light_color = look.sun_color
		sun.light_energy = look.sun_energy
		env.ambient_light_color = look.ambient
		sky.set_shader_parameter("top_color", look.sky_top)
		sky.set_shader_parameter("horizon_color", look.sky_horizon)
		env.fog_light_color = look.sky_horizon
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sun, "rotation_degrees:x", look.sun_pitch, seconds)
	tw.tween_property(sun, "light_color", look.sun_color, seconds)
	tw.tween_property(sun, "light_energy", look.sun_energy, seconds)
	tw.tween_property(env, "ambient_light_color", look.ambient, seconds)
	tw.tween_property(env, "fog_light_color", look.sky_horizon, seconds)
	tw.tween_property(sky, "shader_parameter/top_color", look.sky_top, seconds)
	tw.tween_property(sky, "shader_parameter/horizon_color", look.sky_horizon, seconds)
