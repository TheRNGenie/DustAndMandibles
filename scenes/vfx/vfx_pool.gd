class_name VfxPool
extends Node3D
## Pooled one-shot particle bursts (hit sparks, dust puffs). Uses GPUParticles3D
## with a shader-drawn star quad, so no texture files are needed.

const POOL_SIZE := 24

var _sparks: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _spark_i := 0
var _dust_i := 0
var _tracer_mat: StandardMaterial3D


func _ready() -> void:
	for i in POOL_SIZE:
		_sparks.append(_make_emitter(Palette.GLOW_YELLOW, 8, 0.3, Vector2(3.0, 7.0), 0.22, 2.5))
		_dust.append(_make_emitter(Palette.SAND.lightened(0.2), 6, 0.6, Vector2(0.8, 2.0), 0.5, 1.0))


## Spark burst at a hit point, spraying along the surface normal.
func spark(pos: Vector3, normal: Vector3) -> void:
	var e := _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	_fire(e, pos, normal)
	var d := _dust[_dust_i]
	_dust_i = (_dust_i + 1) % _dust.size()
	_fire(d, pos + normal * 0.05, normal)


## A brief bright streak from a muzzle to the hit point (for shots by the other player).
func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Palette.GLOW_YELLOW * 2.0
		_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, length)
	box.material = _tracer_mat
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(to - from, up), (from + to) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), 0.08)
	tw.tween_callback(mi.queue_free)


func _fire(e: GPUParticles3D, pos: Vector3, normal: Vector3) -> void:
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	# Emitters spray along local -Z, so point -Z along the surface normal.
	e.global_transform = Transform3D(Basis.looking_at(n, up), pos)
	e.restart()
	e.emitting = true


func _make_emitter(color: Color, amount: int, lifetime: float, speed: Vector2,
		size: float, brightness: float) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = amount
	e.lifetime = lifetime
	e.explosiveness = 1.0
	e.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 55.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 0.6, 0.3, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = Materials.star(color, brightness)
	e.draw_pass_1 = quad
	add_child(e)
	return e
