class_name BlastFx
extends Node3D
## Down the Hole: the tunnel going up (every peer, local only). A white flash,
## a fireball rolling out of the mouth, rock and timber thrown across the
## floor, boulders sliding off the wall above, then a wall of dust that rolls
## out and hangs there. Frees itself when it's done.

const LIFE := 14.0

var mouth := Vector3.ZERO
var out := Vector3.BACK
var _t := 0.0
var _flash: OmniLight3D
var _balls: Array = [] # [mesh, delay, grow, rise]
var _chunks: Array = [] # [mesh, velocity, spin, landed]
var _dust: Array = [] # [mesh, delay, velocity, grow]
var _fire_mat: StandardMaterial3D
var _smoke_mat: StandardMaterial3D
var _dust_mat: StandardMaterial3D


static func play(parent: Node3D, at: Vector3, way_out: Vector3) -> void:
	var fx := BlastFx.new()
	fx.mouth = at
	fx.out = way_out
	parent.add_child(fx)
	fx.global_position = at


func _ready() -> void:
	top_level = true
	_fire_mat = _mat(Color(1.0, 0.62, 0.2, 1.0), true)
	_smoke_mat = _mat(Color(0.2, 0.16, 0.14, 0.85), false)
	_dust_mat = _mat(Color(0.78, 0.6, 0.42, 0.6), false)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#FFE0A0")
	_flash.light_energy = 18.0
	_flash.omni_range = 70.0
	_flash.position = out * 3.0 + Vector3.UP * 3.0
	add_child(_flash)
	var side := out.cross(Vector3.UP).normalized()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Fireball: a few puffs out of the mouth, then smoke rising behind them.
	for i in 9:
		var mi := _sphere(_fire_mat)
		mi.position = out * rng.randf_range(0.5, 4.5) + side * rng.randf_range(-2.0, 2.0) + Vector3.UP * rng.randf_range(0.8, 3.5)
		_balls.append([mi, i * 0.04, rng.randf_range(3.0, 5.5), rng.randf_range(1.5, 4.0)])
	for i in 7:
		var mi := _sphere(_smoke_mat)
		mi.position = out * rng.randf_range(1.0, 5.0) + side * rng.randf_range(-2.5, 2.5) + Vector3.UP * rng.randf_range(2.0, 5.0)
		_balls.append([mi, 0.35 + i * 0.08, rng.randf_range(4.0, 7.0), rng.randf_range(3.0, 7.0)])
	# Rock and timber thrown out of the mouth.
	var rock := Materials.toon(0.02)
	for i in 34:
		var mi := MeshInstance3D.new()
		var st := MeshKit.begin()
		if i % 6 == 0:
			MeshKit.add_box(st, Transform3D(), Vector3(0.22, 0.22, rng.randf_range(1.0, 2.0)), Palette.WOOD_DARK)
		else:
			var s := rng.randf_range(0.2, 0.75)
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3(s, s * 0.8, s), 3, 6, [Palette.ROCK_B, Palette.ROCK_A, Color("#7E4434")][i % 3], 0.25, rng)
		mi.mesh = MeshKit.finish(st)
		mi.material_override = rock
		add_child(mi)
		mi.position = out * 1.5 + Vector3.UP * rng.randf_range(0.5, 3.0) + side * rng.randf_range(-1.5, 1.5)
		var v := out * rng.randf_range(8.0, 26.0) + side * rng.randf_range(-12.0, 12.0) + Vector3.UP * rng.randf_range(4.0, 16.0)
		_chunks.append([mi, v, Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6)), false])
	# Boulders shaken off the rock above the mouth (the canyon wall).
	for i in 6:
		var mi := MeshInstance3D.new()
		var st := MeshKit.begin()
		var s := rng.randf_range(0.6, 1.3)
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3(s, s * 0.85, s), 4, 7, Palette.ROCK_B, 0.2, rng)
		mi.mesh = MeshKit.finish(st)
		mi.material_override = rock
		add_child(mi)
		mi.position = Vector3.UP * rng.randf_range(12.0, 30.0) + side * rng.randf_range(-3.0, 3.0) + out * 0.8
		_chunks.append([mi, out * rng.randf_range(1.0, 3.0), Vector3(rng.randf(), rng.randf(), rng.randf()) * 2.0, false])
	# The dust wall rolling out.
	for i in 22:
		var mi := _sphere(_dust_mat)
		mi.position = out * rng.randf_range(0.5, 3.0) + side * rng.randf_range(-3.0, 3.0) + Vector3.UP * rng.randf_range(0.5, 2.0)
		var v := out * rng.randf_range(3.0, 9.0) + side * rng.randf_range(-4.0, 4.0) + Vector3.UP * rng.randf_range(0.2, 1.2)
		_dust.append([mi, 0.2 + rng.randf() * 0.6, v, rng.randf_range(3.0, 6.5)])
	# Sound: the crack, the roar, the rumble after.
	Audio.play_at(&"dynamite", mouth, 6.0)
	Audio.play_at(&"cannon", mouth, 4.0)
	get_tree().create_timer(0.18).timeout.connect(func() -> void: Audio.play_at(&"dynamite", mouth + out * 3.0, 4.0))
	get_tree().create_timer(0.45).timeout.connect(func() -> void: Audio.play_at(&"thunder", mouth, 2.0))
	get_tree().create_timer(0.8).timeout.connect(func() -> void: Audio.play_ui(&"ground_rumble", -2.0))
	var scene := get_tree().current_scene
	if scene != null:
		TunnelRumble.play(scene, mouth, out, 3.5, 7.0, false)
	var vfx := VfxPool.instance if is_instance_valid(VfxPool.instance) else null
	if vfx != null:
		vfx.pop(mouth + out * 2.0 + Vector3.UP * 2.0, Palette.GLOW_YELLOW, 4.0)
		for k in 4:
			vfx.dust_burst(mouth + out * (2.0 + k * 2.0) + Vector3.UP, out, 2.5)
			vfx.rock_chips(mouth + out * 1.5 + Vector3.UP * (1.0 + k), out, 2.0)


const TunnelRumble := preload("res://scenes/bugs/tunnel_rumble.gd")


func _mat(c: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _sphere(mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 12
	sph.rings = 6
	mi.mesh = sph
	mi.material_override = mat.duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.01
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	_flash.light_energy = 18.0 * maxf(1.0 - _t / 1.4, 0.0) + (3.0 * maxf(1.0 - _t / 4.0, 0.0) * (0.7 + randf() * 0.3))
	for b: Array in _balls:
		var mi: MeshInstance3D = b[0]
		var k := _t - float(b[1])
		if k < 0.0:
			continue
		var life := 1.2 if (mi.material_override as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD else 5.0
		var u := clampf(k / life, 0.0, 1.0)
		mi.scale = Vector3.ONE * float(b[2]) * (1.0 - pow(1.0 - u, 3.0)) * 2.0
		mi.position.y += float(b[3]) * delta * (1.0 - u)
		var m := mi.material_override as StandardMaterial3D
		var a0 := 1.0 if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD else 0.85
		m.albedo_color.a = a0 * (1.0 - u)
		if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
			m.albedo_color = Color(1.0, lerpf(0.75, 0.25, u), lerpf(0.35, 0.05, u), 1.0 - u)
	var cl := Bug.cliffs
	for c: Array in _chunks:
		if bool(c[3]):
			continue
		var mi: MeshInstance3D = c[0]
		var v: Vector3 = c[1]
		v.y -= 22.0 * delta
		c[1] = v
		mi.position += v * delta
		mi.rotation += (c[2] as Vector3) * delta
		var gp := mi.global_position
		var fy := cl.floor_height(gp.x, gp.z) if cl != null else mouth.y
		if gp.y <= fy + 0.15 and v.y < 0.0:
			mi.global_position.y = fy + 0.12
			c[3] = true
	for d: Array in _dust:
		var mi: MeshInstance3D = d[0]
		var k := _t - float(d[1])
		if k < 0.0:
			continue
		var u := clampf(k / 9.0, 0.0, 1.0)
		var v: Vector3 = d[2]
		mi.position += v * delta * (1.0 - u) * (1.0 - u)
		mi.scale = Vector3.ONE * float(d[3]) * (0.3 + 1.7 * (1.0 - pow(1.0 - u, 2.0)))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - smoothstep(0.55, 1.0, u)) * smoothstep(0.0, 0.05, u)
	# The thrown rock stays a while, then sinks away.
	if _t > LIFE - 3.0:
		for c: Array in _chunks:
			(c[0] as MeshInstance3D).position.y -= delta * 0.4
	if _t > LIFE:
		queue_free()
