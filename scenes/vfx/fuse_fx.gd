class_name FuseFx
extends Node3D
## A burning dynamite fuse: a white-hot spitting tip, a spray of sparks, a thread
## of grey smoke, a flicker of orange light and the sizzle. Sits on the fuse's
## end (the hand's bundle and the thrown one); `lit` turns it on and off.
## `small` is the first-person size (the hand's bundle is right in your face).

var lit := false:
	set(v):
		lit = v
		if is_inside_tree():
			_apply()
var small := false
var _t := 0.0
var _star: MeshInstance3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _sizzle: AudioStreamPlayer3D
static var _star_mat: Material
static var _smoke_mat: StandardMaterial3D


func _ready() -> void:
	var k := 0.5 if small else 1.0
	if _star_mat == null:
		_star_mat = Materials.star(Color("#FFD27A"), 4.0)
	_star = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09) * k * (1.0 if small else 1.6)
	quad.material = _star_mat
	_star.mesh = quad
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 28
	_sparks.lifetime = 0.25 if small else 0.45
	_sparks.local_coords = false
	_sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	# In the hand the sparks stay round the fuse (they're a hand's width from your eye).
	var sv := 0.12 if small else 1.0
	pm.initial_velocity_min = 1.2 * sv
	pm.initial_velocity_max = 3.2 * sv
	pm.gravity = Vector3(0, -7.0 * sv, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color("#FFD9A0")
	_sparks.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.03, 0.03) * k
	dot.material = _star_mat
	_sparks.draw_pass_1 = dot
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_color = Color(0.62, 0.6, 0.58, 0.55)
	_smoke = GPUParticles3D.new()
	# In the air it leaves a thread of smoke along its arc, so the lob reads.
	_smoke.amount = 14 if small else 40
	_smoke.lifetime = 1.1 if small else 1.6
	_smoke.local_coords = false
	_smoke.emitting = false
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.UP
	sm.spread = 15.0
	sm.initial_velocity_min = 0.25 * k
	sm.initial_velocity_max = 0.6 * k
	sm.gravity = Vector3(0, 0.5 * k, 0)
	sm.damping_min = 0.4
	sm.damping_max = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	sm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.15, Color(1, 1, 1, 0.7))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	sm.color_ramp = gt
	_smoke.process_material = sm
	var puff := QuadMesh.new()
	puff.size = Vector2(0.12, 0.12) * k * (1.0 if small else 2.2)
	puff.material = _smoke_mat
	_smoke.draw_pass_1 = puff
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color("#FFA040")
	_light.omni_range = 2.2 if small else 5.0
	_light.shadow_enabled = false
	add_child(_light)
	_sizzle = AudioStreamPlayer3D.new()
	_sizzle.bus = &"Weapons" if AudioServer.get_bus_index("Weapons") >= 0 else &"Master"
	_sizzle.unit_size = 4.0
	_sizzle.max_distance = 40.0
	_sizzle.volume_db = -8.0 if small else -2.0
	var path := "res://audio/sfx/fuse_sizzle%s.wav" % ["", "__2", "__3"][randi() % 3]
	if ResourceLoader.exists(path):
		_sizzle.stream = load(path)
	_sizzle.finished.connect(func() -> void:
		if lit and is_inside_tree():
			_sizzle.play())
	add_child(_sizzle)
	_apply()


func _apply() -> void:
	_star.visible = lit
	_sparks.emitting = lit
	_smoke.emitting = lit
	if not lit:
		_light.light_energy = 0.0
	if lit and _sizzle.stream != null and not _sizzle.playing:
		_sizzle.play()
	elif not lit:
		_sizzle.stop()


func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	var f := 0.75 + 0.25 * sin(_t * 41.0) * sin(_t * 23.0)
	_light.light_energy = (0.9 if small else 2.2) * f
	_star.scale = Vector3.ONE * (0.8 + 0.4 * f)
