class_name UniLook
extends RefCounted
## A universal crop-fed gun's crop looks that aren't its parts (every peer): the
## base ring (grey empty, the crop's colour loaded), the crop's idle wisps and
## the pour when it's loaded. UniversalCrewedTurret uses it (UniversalTurret has
## the same built in).

var owner: Node3D
var spec: Dictionary
var muzzle: Node3D
var gun: Node3D
var head: Node3D
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var _ring_col := CropEffects.EMPTY_COLOR
var _idle: CPUParticles3D
var _idle_crop: StringName = &"-"


func _init(o: Node3D, s: Dictionary, h: Node3D, g: Node3D, m: Node3D) -> void:
	owner = o
	spec = s
	head = h
	gun = g
	muzzle = m
	var r := float(spec.get("ring_r", 1.6))
	var st := MeshKit.begin()
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), r, r - 0.12, 0.03, 48, Color.WHITE)
	ring = MeshInstance3D.new()
	ring.mesh = MeshKit.finish(st)
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = CropEffects.EMPTY_COLOR
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(ring)


func update(delta: float, ctx: UniCtx, loaded: bool, crop: StringName) -> void:
	var want := ctx.color * 1.25 if loaded and ctx.load_k > 0.6 else CropEffects.EMPTY_COLOR
	_ring_col = _ring_col.lerp(want, clampf(delta / 0.3 * 2.5, 0.0, 1.0))
	ring_mat.albedo_color = _ring_col
	var c: StringName = crop if loaded and ctx.load_k >= 1.0 else &""
	if c != _idle_crop:
		_idle_crop = c
		if _idle != null:
			_idle.queue_free()
			_idle = null
		if c != &"" and UniversalTurret.IDLE.has(c):
			_idle = _make_idle(UniversalTurret.IDLE[c])
	if _idle != null:
		_idle.emitting = ctx.shot_age > 0.6


func _make_idle(s: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(s[5])
	p.lifetime = float(s[4])
	p.direction = (s[2] as Vector3).normalized() if (s[2] as Vector3).length() > 0.0 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = (s[2] as Vector3).length() * 0.5
	p.initial_velocity_max = (s[2] as Vector3).length()
	p.gravity = s[3]
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4 if bool(s[1]) else 0.08
	var g := Gradient.new()
	g.set_color(0, Color(s[0] as Color, 0.0))
	g.add_point(0.2, Color(s[0] as Color, 0.55))
	g.set_color(g.get_point_count() - 1, Color(s[0] as Color, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE * float(s[6]) * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/fx/smoke.png") and float(s[6]) >= 0.08:
		m.albedo_texture = load("res://assets/fx/smoke.png")
	q.material = m
	p.mesh = q
	p.local_coords = false
	if bool(s[1]):
		p.position = Vector3(0, 0.4, 0)
		owner.add_child(p)
	else:
		muzzle.add_child(p)
	return p


## The crop pouring in where the model takes it (spec "pour", head space).
func pour(c: StringName) -> void:
	var at: Vector3 = spec.get("pour", Vector3(0, 1.4, 0))
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -6.0, 0)
	p.color = CropEffects.color_of(c)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.05
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	box.material = m
	p.mesh = box
	p.position = at + Vector3.UP * 0.3
	head.add_child(p)
	p.emitting = true
	owner.get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	Audio.play_at(&"crank_gatling_close", owner.global_position, -4.0)
