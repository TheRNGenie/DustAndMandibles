class_name CropTagFx
extends Node3D
## A universal turret's crop effect drawn on a bug (every peer, Bug.crop_tag):
##   mark     Sarsaparilla: an amber diamond over the bug, always on top and the
##            same size at any distance; pulses slowly, fast in its last 0.5 s
##   vines    Tumbleweed Vine: dry vine loops round its legs at the ground
##   poison   Herbs: green vapour rising off it
##   thread   Cotton: white threads wound round its body
##   stagger  Barrel Cactus: a crunch of olive thorn shards
## One of each kind per bug: a fresh tag just extends the old one.

var kind := 0
var life := 1.0
var _t := 0.0
var _diamond: Label3D
var _mesh: MeshInstance3D

const MARK_COLOR := Color("#FFBF00")


static func show_on(b: Node3D, k: int, seconds: float, body_r: float, clearance: float) -> void:
	for c in b.get_children():
		if c is CropTagFx and (c as CropTagFx).kind == k:
			var old := c as CropTagFx
			old.life = old._t + seconds
			return
	var fx := CropTagFx.new()
	fx.kind = k
	fx.life = seconds
	b.add_child(fx)
	fx._build(body_r, clearance)


func _build(r: float, clearance: float) -> void:
	match kind:
		CropEffects.TAG_MARK:
			_diamond = Label3D.new()
			_diamond.text = "◆"
			_diamond.font_size = 96
			_diamond.pixel_size = 0.0012
			_diamond.fixed_size = true
			_diamond.no_depth_test = true
			_diamond.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_diamond.modulate = MARK_COLOR
			_diamond.outline_size = 18
			_diamond.outline_modulate = Color(0.25, 0.12, 0.0, 0.9)
			_diamond.render_priority = 10
			_diamond.position = Vector3(0, clearance + r * 2.2 + 0.4, 0)
			add_child(_diamond)
		CropEffects.TAG_VINES:
			var st := MeshKit.begin()
			var col := Color("#B08A5A")
			for i in 5:
				var a0 := TAU * i / 5.0
				var rr := r * (1.0 + 0.15 * (i % 2))
				var prev := Vector3(cos(a0) * rr, 0.05, sin(a0) * rr)
				for k in 10:
					var a := a0 + float(k + 1) * 0.55
					var p := Vector3(cos(a) * rr * (1.0 - k * 0.04), 0.05 + k * 0.035 * (1.0 + clearance), sin(a) * rr * (1.0 - k * 0.04))
					MeshKit.add_limb(st, prev, p, 0.022, col.darkened(0.1 * (k % 3)), 3)
					prev = p
			_mesh = MeshInstance3D.new()
			_mesh.mesh = MeshKit.finish(st)
			_mesh.material_override = Materials.toon(0.0)
			_mesh.position.y = -clearance * 0.2
			add_child(_mesh)
			scale = Vector3(1, 0.01, 1)
		CropEffects.TAG_THREAD:
			var st := MeshKit.begin()
			for i in 3:
				var y := clearance * 0.3 + (float(i) - 1.0) * r * 0.45
				var rr := r * (1.05 - absf(float(i) - 1.0) * 0.2)
				var tilt := Basis(Vector3.RIGHT, 0.25 * (float(i) - 1.0))
				var prev := tilt * Vector3(rr, y, 0)
				for k in 14:
					var a := TAU * float(k + 1) / 14.0
					var p := tilt * Vector3(cos(a) * rr, y, sin(a) * rr)
					MeshKit.add_limb(st, prev, p, 0.014, Color("#FFFDF0"), 3)
					prev = p
			_mesh = MeshInstance3D.new()
			_mesh.mesh = MeshKit.finish(st)
			_mesh.material_override = Materials.toon(0.0)
			add_child(_mesh)
		CropEffects.TAG_POISON:
			add_child(_motes(Color("#3FBF3F"), r, clearance, Vector3.UP * 0.6, 14, 1.0))
		CropEffects.TAG_STAGGER:
			add_child(_motes(Color("#6E8240"), r, clearance, Vector3.UP * 2.0, 10, 0.5, true))


func _motes(col: Color, r: float, clearance: float, vel: Vector3, n: int, lifetime: float, burst: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = lifetime
	p.one_shot = burst
	p.explosiveness = 0.9 if burst else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.8
	p.direction = vel.normalized()
	p.spread = 35.0 if not burst else 70.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3(0, 0.3 if not burst else -6.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.85))
	g.set_color(1, Color(col, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12) * (1.0 + r)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/fx/smoke.png") and not burst:
		m.albedo_texture = load("res://assets/fx/smoke.png")
	q.material = m
	p.mesh = q
	p.position.y = clearance * 0.3
	p.emitting = true
	return p


func _process(delta: float) -> void:
	_t += delta
	var left := life - _t
	if left <= 0.0:
		queue_free()
		return
	match kind:
		CropEffects.TAG_MARK:
			# A slow pulse, quick in the last half second.
			var hz := 1.2 if left > 0.5 else 6.0
			var k := 0.5 + 0.5 * sin(_t * TAU * hz)
			_diamond.modulate = MARK_COLOR.lerp(Color("#FFF2C0"), k * 0.6)
			_diamond.scale = Vector3.ONE * (1.0 + 0.18 * k)
		CropEffects.TAG_VINES:
			# Vines whip up out of the ground, then wilt back down at the end.
			var up := minf(_t / 0.15, 1.0) * minf(left / 0.2, 1.0)
			scale = Vector3(1, maxf(up, 0.01), 1)
		CropEffects.TAG_THREAD:
			_mesh.rotation.y += delta * 1.5
			_mesh.transparency = clampf(1.0 - left / 0.3, 0.0, 1.0)
