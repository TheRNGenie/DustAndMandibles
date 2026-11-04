class_name DynamiteBlast
extends Node3D
## A thrown bundle of dynamite going up (every peer, local only): a white flash,
## a ball of fire, rock and dirt thrown up and out, a ring of dust rolling away
## and a column of smoke that hangs, sized to the blast radius. Sound is the
## big one: the dynamite crack doubled, a cannon's thump under it, thunder
## rolling round the canyon after and the ground rumbling for anyone near.
## The same pieces as the story's tunnel blast (BlastFx), on a thrown bundle's
## scale. Frees itself when it's done.

const LIFE := 8.0

var radius := DynamiteRules.RADIUS
var _t := 0.0
var _flash: OmniLight3D
var _balls: Array = [] # [mesh, delay, grow, rise, fire?]
var _chunks: Array = [] # [mesh, velocity, spin, landed]
var _dust: Array = [] # [mesh, delay, velocity, grow]
var _scorch: MeshInstance3D


static func play(parent: Node, at: Vector3, blast_radius: float, normal: Vector3 = Vector3.UP) -> DynamiteBlast:
	var fx := DynamiteBlast.new()
	fx.radius = blast_radius
	fx.set_meta(&"normal", normal)
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _ready() -> void:
	top_level = true
	var normal: Vector3 = get_meta(&"normal", Vector3.UP)
	if normal.length() < 0.1:
		normal = Vector3.UP
	normal = normal.normalized()
	var k := radius / DynamiteRules.RADIUS
	var fire := _mat(Color(1.0, 0.62, 0.2, 1.0), true) # (the tunnel blast's colours)
	var smoke := _mat(Color(0.36, 0.31, 0.27, 0.6), false)
	var dust := _mat(Color(0.78, 0.6, 0.42, 0.6), false)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#FFE0A0")
	_flash.light_energy = 7.0
	_flash.omni_range = minf(radius * 3.5, 30.0)
	_flash.shadow_enabled = false
	_flash.position = normal * 1.5
	add_child(_flash)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := normal.cross(Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var side2 := normal.cross(side).normalized()
	# The fireball: puffs bursting out from the centre, smoke rising behind.
	for i in 11:
		var mi := _sphere(fire)
		mi.position = normal * rng.randf_range(0.3, 2.0) * k + (side * rng.randf_range(-1, 1) + side2 * rng.randf_range(-1, 1)) * 2.2 * k
		_balls.append([mi, i * 0.025, rng.randf_range(2.6, 4.2) * k, rng.randf_range(1.0, 3.0), true])
	for i in 9:
		var mi := _sphere(smoke)
		mi.position = normal * rng.randf_range(1.0, 3.0) * k + (side * rng.randf_range(-1, 1) + side2 * rng.randf_range(-1, 1)) * 1.6 * k
		_balls.append([mi, 0.2 + i * 0.07, rng.randf_range(2.6, 4.4) * k, rng.randf_range(2.5, 5.5), false])
	# Rock, dirt clods and splinters thrown up and out.
	var rock := Materials.toon(0.02)
	for i in 26:
		var m := MeshInstance3D.new()
		var st := MeshKit.begin()
		var s := rng.randf_range(0.08, 0.3) * sqrt(k)
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3(s, s * 0.8, s), 3, 6, [Palette.ROCK_B, Palette.ROCK_A, Color("#7E4434"), Color("#5A3A26")][i % 4], 0.25, rng)
		m.mesh = MeshKit.finish(st)
		m.material_override = rock
		add_child(m)
		m.position = normal * 0.4
		var out := (side * rng.randf_range(-1, 1) + side2 * rng.randf_range(-1, 1)).normalized()
		var v := out * rng.randf_range(4.0, 13.0) * k + normal * rng.randf_range(5.0, 15.0) * k
		_chunks.append([m, v, Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8)), false])
	# The dust ring rolling away along the ground (or the rock face).
	for i in 16:
		var mi := _sphere(dust)
		var a := TAU * float(i) / 16.0 + rng.randf() * 0.3
		var out := side * cos(a) + side2 * sin(a)
		mi.position = out * 0.8 * k + normal * 0.4
		_dust.append([mi, 0.05 + rng.randf() * 0.2, out * rng.randf_range(6.0, 10.0) * k + normal * rng.randf_range(0.2, 1.0), rng.randf_range(2.0, 3.6) * k])
	# A blackened scorch where it went off.
	_scorch = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.45
	disc.bottom_radius = radius * 0.45
	disc.height = 0.02
	disc.radial_segments = 20
	_scorch.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.08, 0.06, 0.05, 0.55)
	_scorch.material_override = sm
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.basis = MeshKit.basis_from_y(normal)
	_scorch.position = normal * 0.04
	add_child(_scorch)
	# The big boom.
	var at := global_position
	Audio.play_at(&"dynamite", at, 9.0)
	Audio.play_at(&"cannon", at, 6.0, 0.7)
	get_tree().create_timer(0.09).timeout.connect(func() -> void: Audio.play_at(&"dynamite", at + normal * 2.0, 6.0, 0.8))
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Audio.play_at(&"thunder", at, 4.0))
	var vfx := VfxPool.instance if is_instance_valid(VfxPool.instance) else null
	if vfx != null:
		vfx.pop(at + normal * 0.8, Palette.GLOW_YELLOW, radius * 0.9)
		vfx.pop(at + normal * 0.5, Palette.ROCK_C, radius * 0.6)
		for j in 3:
			vfx.dust_burst(at + normal * 0.5, (normal + side * (j - 1) * 0.8).normalized(), 2.0 * k)
			vfx.rock_chips(at + normal * 0.3, (normal + side2 * (j - 1) * 0.8).normalized(), 1.6 * k)


static func _mat(c: Color, glow: bool) -> StandardMaterial3D:
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
	_flash.light_energy = 7.0 * maxf(1.0 - _t / 0.35, 0.0) + 2.0 * maxf(1.0 - _t / 2.0, 0.0) * (0.7 + randf() * 0.3)
	for b: Array in _balls:
		var mi: MeshInstance3D = b[0]
		var k := _t - float(b[1])
		if k < 0.0:
			continue
		var is_fire := bool(b[4])
		var life := 0.9 if is_fire else 4.5
		var u := clampf(k / life, 0.0, 1.0)
		mi.scale = Vector3.ONE * float(b[2]) * (1.0 - pow(1.0 - u, 3.0)) * (2.0 if is_fire else 1.6)
		mi.position.y += float(b[3]) * delta * (1.0 - u)
		var m := mi.material_override as StandardMaterial3D
		if is_fire:
			m.albedo_color = Color(1.0, lerpf(0.8, 0.25, u), lerpf(0.4, 0.05, u), 1.0 - u)
		else:
			m.albedo_color.a = 0.6 * (1.0 - u) * smoothstep(0.0, 0.1, u)
		mi.visible = u < 1.0
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
		var fy := cl.floor_height(gp.x, gp.z) if cl != null else global_position.y - 60.0
		if (gp.y <= fy + 0.1 and v.y < 0.0) or _t > 4.0:
			c[3] = true
			mi.visible = gp.y > fy - 0.5
	for d: Array in _dust:
		var mi: MeshInstance3D = d[0]
		var k := _t - float(d[1])
		if k < 0.0:
			continue
		var u := clampf(k / 5.0, 0.0, 1.0)
		mi.position += (d[2] as Vector3) * delta * (1.0 - u) * (1.0 - u)
		mi.scale = Vector3.ONE * float(d[3]) * (0.3 + 1.7 * (1.0 - pow(1.0 - u, 2.0)))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - smoothstep(0.5, 1.0, u)) * smoothstep(0.0, 0.05, u)
	(_scorch.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - smoothstep(LIFE - 2.0, LIFE, _t))
	if _t > LIFE:
		queue_free()
