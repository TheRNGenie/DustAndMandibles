class_name Cigarette
extends Node3D
## Press T to light up (unlimited). For BUFF_TIME seconds you move a little faster
## and the world looks crisper: less haze, a touch more contrast and colour.
## A cigarette with a glowing tip sits in the corner of your view while you take
## your drags, with smoke puffs drifting up.

signal changed(seconds_left: float)

const BUFF_TIME := 45.0
const HOLD_TIME := 6.0
const SPEED_BONUS := 0.1
const CLARITY_FOG := 0.35 # fog density multiplier at full clarity

var player: Player
var left := 0.0
var _hold := 0.0
var _clarity := 0.0
var _cig: MeshInstance3D
var _ember: OmniLight3D
var _puff_t := 0.0
var _base_fog := -1.0


func _ready() -> void:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0)), 0.012, 0.012, 0.11, 8, Palette.BONE)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.065)), 0.0125, 0.0125, 0.03, 8, Color("#C98A3A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.058)), 0.012, 0.012, 0.008, 8, Color("#FF6A1A"), true, 0.9)
	_cig = MeshInstance3D.new()
	_cig.mesh = MeshKit.finish(st)
	_cig.material_override = Materials.toon(0.002)
	_cig.position = Vector3(-0.2, -0.17, -0.42)
	_cig.scale = Vector3.ONE * 0.75
	_cig.rotation = Vector3(0.25, 0.6, 0.15)
	_cig.visible = false
	add_child(_cig)
	_ember = OmniLight3D.new()
	_ember.light_color = Color("#FF7A2A")
	_ember.light_energy = 0.0
	_ember.omni_range = 0.6
	_ember.position = _cig.position + Vector3(0.03, 0.0, -0.05)
	add_child(_ember)


func light() -> void:
	left = BUFF_TIME
	_hold = HOLD_TIME
	_cig.visible = true
	Audio.play_at(&"pluck", global_position, -10.0)
	changed.emit(left)


func speed_multiplier() -> float:
	return 1.0 + SPEED_BONUS if left > 0.0 else 1.0


func _process(delta: float) -> void:
	if left > 0.0:
		left = maxf(left - delta, 0.0)
		changed.emit(left)
	_hold = maxf(_hold - delta, 0.0)
	_cig.visible = _hold > 0.0
	_ember.light_energy = (0.6 + sin(Time.get_ticks_msec() * 0.006) * 0.25) if _hold > 0.0 else 0.0
	if _hold > 0.0:
		_puff_t -= delta
		if _puff_t <= 0.0:
			_puff_t = 1.4
			_puff()
	_clarity = move_toward(_clarity, 1.0 if left > 0.0 else 0.0, delta / 1.5)
	_apply_clarity()


## The "visual clarity" part: thinner haze and a crisper, slightly richer picture.
func _apply_clarity() -> void:
	if DayCycle.instance == null or DayCycle.instance.env == null:
		return
	var env := DayCycle.instance.env
	if _base_fog < 0.0:
		_base_fog = env.fog_density
	env.fog_density = _base_fog * lerpf(1.0, CLARITY_FOG, _clarity)
	env.adjustment_enabled = true
	env.adjustment_contrast = lerpf(1.0, 1.05, _clarity)
	env.adjustment_saturation = lerpf(1.0, 1.1, _clarity)
	env.adjustment_brightness = Settings.brightness


func _puff() -> void:
	var p := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.92, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	get_tree().current_scene.add_child(p)
	var cam_fwd: Vector3 = -(get_parent() as Node3D).global_transform.basis.z
	p.global_position = _cig.global_position + cam_fwd * 0.35 + Vector3.UP * 0.05
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "global_position", p.global_position + cam_fwd * 0.6 + Vector3(randf_range(-0.15, 0.15), 0.7, randf_range(-0.15, 0.15)), 2.2)
	tw.tween_property(p, "scale", Vector3.ONE * 3.0, 2.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.2)
	tw.chain().tween_callback(p.queue_free)
