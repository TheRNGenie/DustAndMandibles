class_name VfxPool
extends Node3D
## Pooled one-shot effects: hit sparks, dust puffs, bug death "pops" (chunks plus a
## comic star burst), muzzle flashes, tracers and acid blobs. GPUParticles3D with a
## shader-drawn star quad and generated meshes, so no texture files are needed.

const POOL_SIZE := 24
const POP_POOL := 16

var _sparks: Array[GPUParticles3D] = []
var _bug_sparks: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _pops: Array[GPUParticles3D] = []
var _pop_stars: Array[GPUParticles3D] = []
var _flashes: Array[GPUParticles3D] = []
var _i: Dictionary = {}
var _tracer_mat: StandardMaterial3D
var _acid_mat: ShaderMaterial


func _ready() -> void:
	for i in POOL_SIZE:
		_sparks.append(_make_emitter(Palette.GLOW_YELLOW, 8, 0.3, Vector2(3.0, 7.0), 0.22, 2.5))
		_bug_sparks.append(_make_emitter(Palette.ACID_GREEN, 10, 0.35, Vector2(3.0, 6.0), 0.26, 2.0))
		_dust.append(_make_emitter(Palette.SAND.lightened(0.2), 6, 0.6, Vector2(0.8, 2.0), 0.5, 1.0))
		_flashes.append(_make_emitter(Palette.GLOW_YELLOW, 2, 0.06, Vector2(0.0, 0.2), 0.7, 3.0))
	for i in POP_POOL:
		_pops.append(_make_chunks())
		_pop_stars.append(_make_emitter(Color.WHITE, 3, 0.25, Vector2(0.0, 0.5), 1.6, 2.5))


func _next(pool: Array[GPUParticles3D], key: String) -> GPUParticles3D:
	var idx := int(_i.get(key, 0))
	_i[key] = (idx + 1) % pool.size()
	return pool[idx]


## Spark burst at a hit point, spraying along the surface normal. Green when you hit a bug.
func spark(pos: Vector3, normal: Vector3, tint: Color = Palette.GLOW_YELLOW) -> void:
	if tint == Palette.GLOW_YELLOW:
		_fire(_next(_sparks, "spark"), pos, normal)
		_fire(_next(_dust, "dust"), pos + normal * 0.05, normal)
	else:
		_fire(_next(_bug_sparks, "bug_spark"), pos, normal)


func muzzle_flash(pos: Vector3, dir: Vector3) -> void:
	_fire(_next(_flashes, "flash"), pos, dir)


## A bug dies: it "pops" into chunks of its shell colour with a big star burst.
func pop(pos: Vector3, color: Color, size: float) -> void:
	var chunks := _next(_pops, "pop")
	var pm := chunks.process_material as ParticleProcessMaterial
	pm.color = color
	pm.scale_min = 0.6 * size
	pm.scale_max = 1.3 * size
	pm.initial_velocity_max = 6.0 + size * 2.0
	_fire(chunks, pos, Vector3.UP)
	var star := _next(_pop_stars, "pop_star")
	(star.process_material as ParticleProcessMaterial).color = color.lightened(0.4)
	(star.process_material as ParticleProcessMaterial).scale_min = size
	(star.process_material as ParticleProcessMaterial).scale_max = size * 1.3
	_fire(star, pos, Vector3.UP)


## A brief bright streak from a muzzle to the hit point.
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
	box.size = Vector3(0.05, 0.05, length)
	box.material = _tracer_mat
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(to - from, up), (from + to) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), 0.08)
	tw.tween_callback(mi.queue_free)


## A glob of acid arcing from a spitter to its target.
func acid_blob(from: Vector3, to: Vector3, flight: float) -> void:
	if _acid_mat == null:
		_acid_mat = Materials.toon_unique(0.02)
	var mi := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.35, 5, 8, Palette.ACID_GREEN, 0.0, null, 0.6)
	mi.mesh = MeshKit.finish(st)
	mi.material_override = _acid_mat
	add_child(mi)
	mi.global_position = from
	var peak := (from + to) * 0.5 + Vector3.UP * (6.0 + from.distance_to(to) * 0.1)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var a := from.lerp(peak, t)
		var b := peak.lerp(to, t)
		mi.global_position = a.lerp(b, t), 0.0, 1.0, flight)
	tw.tween_callback(func() -> void:
		spark(to, Vector3.UP, Palette.ACID_GREEN)
		mi.queue_free())


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
	e.process_material = _process_material(speed, 55.0, -6.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = Materials.star(color, brightness)
	e.draw_pass_1 = quad
	add_child(e)
	return e


func _make_chunks() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 14
	e.lifetime = 0.9
	e.explosiveness = 1.0
	e.local_coords = false
	var pm := _process_material(Vector2(3.0, 8.0), 80.0, -14.0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	e.process_material = pm
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.12, 0.18)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	e.draw_pass_1 = box
	add_child(e)
	return e


func _process_material(speed: Vector2, spread: float, gravity: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3(0, gravity, 0)
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
	grad.set_color(1, Color(1, 0.7, 0.4, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	return pm
