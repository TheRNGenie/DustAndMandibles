class_name VfxPool
extends Node3D
## Pooled one-shot effects: hit sparks, dust puffs, bug death "pops" (chunks plus a
## comic star burst), muzzle flashes, tracers and acid blobs. GPUParticles3D with a
## shader-drawn star quad and generated meshes, so no texture files are needed.

const POOL_SIZE := 24
const POP_POOL := 16
const PUFF_SHADER: Shader = preload("res://shaders/vfx_puff.gdshader")
# Helpers live in their own scripts (preloaded, so no global class names needed).
const SwarmAudio := preload("res://scenes/vfx/swarm_audio.gd")
const TurretFx := preload("res://scenes/vfx/turret_fx.gd")
const CanyonLife := preload("res://scenes/vfx/canyon_life.gd")

static var instance: VfxPool

var _sparks: Array[GPUParticles3D] = []
var _bug_sparks: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _pops: Array[GPUParticles3D] = []
var _pop_stars: Array[GPUParticles3D] = []
var _flashes: Array[GPUParticles3D] = []
var _i: Dictionary = {}
var _tracer_mats: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		_sparks.append(_make_emitter(Palette.GLOW_YELLOW, 8, 0.3, Vector2(3.0, 7.0), 0.22, 2.5))
		_bug_sparks.append(_make_emitter(Palette.ACID_GREEN, 10, 0.35, Vector2(3.0, 6.0), 0.26, 2.0))
		_dust.append(_make_emitter(Palette.SAND.lightened(0.2), 6, 0.6, Vector2(0.8, 2.0), 0.5, 1.0))
		_flashes.append(_make_emitter(Palette.GLOW_YELLOW, 2, 0.06, Vector2(0.0, 0.2), 0.7, 3.0))
	for i in POP_POOL:
		_pops.append(_make_chunks())
		_pop_stars.append(_make_emitter(Color.WHITE, 3, 0.25, Vector2(0.0, 0.5), 1.6, 2.5))
	instance = self
	_ready_extras()


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
	_muzzle_extras(pos, dir)


## Emitted for big blasts so the local camera can shake (strength fades with distance).
signal shake_requested(pos: Vector3, strength: float)


## A bug dies: it "pops" into chunks of its shell colour with a big star burst.
func pop(pos: Vector3, color: Color, size: float) -> void:
	if size >= 1.5:
		shake_requested.emit(pos, size * 0.2)
	var chunks := _next(_pops, "pop")
	var pm := chunks.process_material as ParticleProcessMaterial
	pm.color = color
	pm.scale_min = 0.6 * size
	pm.scale_max = 1.3 * size
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.0 + size * 2.0
	_fire(chunks, pos, Vector3.UP)
	var star := _next(_pop_stars, "pop_star")
	(star.process_material as ParticleProcessMaterial).color = color.lightened(0.4)
	(star.process_material as ParticleProcessMaterial).scale_min = size
	(star.process_material as ParticleProcessMaterial).scale_max = size * 1.3
	_fire(star, pos, Vector3.UP)


## A dead bug's shell cracks apart: a few big shards tumble off (no star burst).
func shell_crack(pos: Vector3, color: Color, size: float) -> void:
	var chunks := _next(_pops, "pop")
	var pm := chunks.process_material as ParticleProcessMaterial
	pm.color = color
	pm.scale_min = 0.9 * size
	pm.scale_max = 1.6 * size
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0 + size
	_fire(chunks, pos, Vector3.UP)
	dust_burst(pos, Vector3.UP, 0.6 * size)


## A brief bright streak from a muzzle to the hit point.
func tracer(from: Vector3, to: Vector3, color: Color = Palette.GLOW_YELLOW, width: float = 0.05) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var key := color.to_html()
	if not _tracer_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color * 2.0
		_tracer_mats[key] = m
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	box.material = _tracer_mats[key]
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(to - from, up), (from + to) * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), 0.1)
	tw.tween_callback(mi.queue_free)


## A stylized bullet for player shots: a white-hot core inside a coloured glow
## that zips from the muzzle to the hit, leaving a fading streak behind it.
var _streak_mats: Dictionary = {}


func _streak_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), alpha]
	if not _streak_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(color.r, color.g, color.b, alpha)
		_streak_mats[key] = m
	return _streak_mats[key]


func bullet_streak(from: Vector3, to: Vector3, color: Color, width: float, speed: float) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	# The fading trail along the whole path.
	var trail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(width * 0.6, width * 0.6, length)
	tb.material = _streak_mat(color, 0.55)
	trail.mesh = tb
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	trail.global_transform = Transform3D(basis, (from + to) * 0.5)
	var tt := trail.create_tween()
	tt.tween_property(trail, "scale", Vector3(0.05, 0.05, 1.0), 0.28).set_ease(Tween.EASE_IN)
	tt.tween_callback(trail.queue_free)
	# The bolt itself: a glow sheath around a hot core, flying down the path.
	var bolt_len := clampf(length * 0.3, 0.6, 3.0)
	var bolt := Node3D.new()
	add_child(bolt)
	for layer: Array in [[width * 2.6, color, 0.7], [width, Color(1.0, 0.97, 0.85), 1.0]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(float(layer[0]), float(layer[0]), bolt_len)
		b.material = _streak_mat(layer[1], float(layer[2]))
		mi.mesh = b
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(mi)
	var start := from + dir * bolt_len * 0.5
	var end := to - dir * bolt_len * 0.5
	bolt.global_transform = Transform3D(basis, start)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", end, maxf(length / speed, 0.03))
	tw.tween_property(bolt, "scale", Vector3(0.2, 0.2, 0.2), 0.04)
	tw.tween_callback(bolt.queue_free)


## A glob of acid arcing from a spitter to its target.
func acid_blob(from: Vector3, to: Vector3, flight: float) -> void:
	lob(from, to, flight, Palette.ACID_GREEN)


## A lobbed shot (acid, chili, dynamite) arcing to its target.
func lob(from: Vector3, to: Vector3, flight: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.35, 5, 8, color, 0.0, null, 0.6)
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.02)
	add_child(mi)
	mi.global_position = from
	var peak := (from + to) * 0.5 + Vector3.UP * (6.0 + from.distance_to(to) * 0.1)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var a := from.lerp(peak, t)
		var b := peak.lerp(to, t)
		mi.global_position = a.lerp(b, t), 0.0, 1.0, flight)
	tw.tween_callback(func() -> void:
		spark(to, Vector3.UP, color)
		mi.queue_free())


## Floating comic damage number where your shot landed (bigger and yellow on weak spots).
func damage_number(pos: Vector3, amount: float, weak: bool) -> void:
	var l := Label3D.new()
	l.text = str(int(amount)) + ("!" if weak else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012 if weak else 0.0009
	l.font_size = 48
	l.outline_size = 14
	l.modulate = Palette.GLOW_YELLOW if weak else Palette.BONE
	l.outline_modulate = Palette.OUTLINE
	add_child(l)
	l.global_position = pos + Vector3.UP * 0.4
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 1.2, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


## A burning chili patch on the cliff face: looping flame stars for a few seconds.
func fire_patch(center: Vector3, radius: float, seconds: float) -> void:
	var e := GPUParticles3D.new()
	e.amount = int(12 + radius * 6.0)
	e.lifetime = 0.6
	e.local_coords = false
	var pm := _process_material(Vector2(0.5, 2.0), 30.0, 3.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = Materials.star(Palette.TEAM_WEST.lightened(0.2), 2.5)
	e.draw_pass_1 = quad
	add_child(e)
	e.global_position = center
	e.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		e.emitting = false
		get_tree().create_timer(1.0).timeout.connect(e.queue_free))


func _fire(e: GPUParticles3D, pos: Vector3, normal: Vector3) -> void:
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	# Emitters spray along local -Z, so point -Z along the surface normal.
	e.global_transform = Transform3D(Basis.looking_at(n, up), pos)
	e.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
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


## Shell chunks: lit, flat, jagged shards that tumble away and shrink out.
func _make_chunks() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 12
	e.lifetime = 1.3
	e.explosiveness = 1.0
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-8, -14, -8), Vector3(16, 22, 16))
	var pm := _process_material(Vector2(3.0, 8.0), 80.0, -16.0)
	pm.angular_velocity_min = -540.0
	pm.angular_velocity_max = 540.0
	pm.particle_flag_rotate_y = true
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	# Hold full size most of the way, then shrink out (rather than fading from the start).
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.9))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color_ramp = null
	e.process_material = pm
	e.draw_pass_1 = _shard_mesh()
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	return e


static var _shard: ArrayMesh


## A curved shard of shell, shaded with the particle colour.
static func _shard_mesh() -> ArrayMesh:
	if _shard != null:
		return _shard
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.17, 0.05, 0.13), 2, 5, Color.WHITE, 0.3, rng)
	var mesh := MeshKit.finish(st)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mat.metallic_specular = 0.6
	mesh.surface_set_material(0, mat)
	_shard = mesh
	return mesh


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


# ================================================================== polish pass
# Tunnel dust, ichor splats, shell cracks, muzzle light, casings, splinters, smoke.
# Everything here is pooled and capped; nothing is created per bug or per shot.

const TUNNEL_COOLDOWN := 0.3
const SPLAT_POOL := 64
## Visual layer for dead bugs (splat decals skip it).
const CORPSE_LAYER := 1 << 19
const SPLAT_LIFE := 14.0
const SPLAT_FADE := 3.0
const LIGHT_POOL := 4
const CASING_POOL := 24
const SPLINTER_POOL := 6
const BURST_POOL := 10

var _tunnel_fx: Array[GPUParticles3D] = []
var _tunnel_busy: PackedFloat32Array = PackedFloat32Array()
var _tunnel_last: PackedFloat32Array = PackedFloat32Array()
var _bursts: Array[GPUParticles3D] = []
var _splats: Array[Decal] = []
var _splat_age: PackedFloat32Array = PackedFloat32Array()
var _splat_alpha: PackedFloat32Array = PackedFloat32Array()
var _splats_live := 0
var _lights: Array[OmniLight3D] = []
var _light_e: PackedFloat32Array = PackedFloat32Array()
var _casings: Array[GPUParticles3D] = []
var _splinters: Array[GPUParticles3D] = []
var _puff_mats: Array[ShaderMaterial] = []
var _puff_base: Array = []
var _light_t := 0.0
## 0.3 at night .. 1 in full day: unshaded puffs are dimmed by it.
var daylight := 1.0
var swarm: Node
var turret_fx: Node
var canyon_life: Node


## --nopolish turns the polish pass off (for before/after perf checks).
var polish := true


func _ready_extras() -> void:
	polish = not GameState.has_flag("--nopolish")
	for i in BURST_POOL:
		_bursts.append(_make_puff_burst())
	for i in SPLAT_POOL:
		var d := Decal.new()
		d.texture_albedo = _splat_texture()
		# A faint glow so the ichor reads as wet acid even in shadow.
		d.texture_emission = _splat_texture()
		d.emission_energy = 0.35
		d.visible = false
		d.distance_fade_enabled = true
		d.distance_fade_begin = 70.0
		d.distance_fade_length = 20.0
		d.albedo_mix = 1.0
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		# Corpses sit on CORPSE_LAYER only, so the ichor never paints them.
		d.cull_mask = 0xFFFFF & ~CORPSE_LAYER
		add_child(d)
		_splats.append(d)
	_splat_age.resize(SPLAT_POOL)
	_splat_alpha.resize(SPLAT_POOL)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = Color("#FFC56A")
		l.omni_range = 7.5
		l.omni_attenuation = 1.4
		l.light_specular = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
	_light_e.resize(LIGHT_POOL)
	for i in CASING_POOL:
		_casings.append(_make_casing_emitter())
	for i in SPLINTER_POOL:
		_splinters.append(_make_splinter_emitter())
	if GameState.flag_value("--vfxview") != "":
		var views: Node = load("res://scenes/debug/vfx_views.gd").new()
		views.name = "VfxViews"
		add_child(views)
	if not polish:
		return
	swarm = SwarmAudio.new()
	swarm.name = "SwarmAudio"
	add_child(swarm)
	turret_fx = TurretFx.new()
	turret_fx.name = "TurretFx"
	turret_fx.set("vfx", self)
	add_child(turret_fx)
	canyon_life = CanyonLife.new()
	canyon_life.name = "CanyonLife"
	canyon_life.set("vfx", self)
	add_child(canyon_life)


func _process(delta: float) -> void:
	# Tunnel dust clouds keep rolling while bugs keep coming out.
	for i in _tunnel_busy.size():
		if _tunnel_busy[i] > 0.0:
			_tunnel_busy[i] -= delta
			if _tunnel_busy[i] <= 0.0:
				_tunnel_fx[i].emitting = false
	# Muzzle lights: a quick bright pop, then off.
	for i in LIGHT_POOL:
		if _light_e[i] > 0.0:
			_light_e[i] = maxf(_light_e[i] - delta * 12.0, 0.0)
			_lights[i].light_energy = _light_e[i] * 3.5 * (1.6 - daylight * 0.6)
			if _light_e[i] <= 0.0:
				_lights[i].visible = false
	# Ichor splats dry out and fade.
	if _splats_live > 0:
		for i in SPLAT_POOL:
			var d := _splats[i]
			if not d.visible:
				continue
			_splat_age[i] += delta
			var left := SPLAT_LIFE - _splat_age[i]
			if left <= 0.0:
				d.visible = false
				_splats_live -= 1
			elif left < SPLAT_FADE:
				d.modulate.a = _splat_alpha[i] * left / SPLAT_FADE
	# Unshaded puffs follow the light of day.
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.5
		var want := 1.0
		if DayCycle.instance != null and DayCycle.instance.sun != null:
			want = clampf(DayCycle.instance.sun.light_energy / 1.3, 0.3, 1.0)
		if absf(want - daylight) > 0.01:
			daylight = want
			var night := Color("#7C86B8")
			for k in _puff_mats.size():
				var base: Array = _puff_base[k]
				var t0: Color = base[0]
				var s0: Color = base[1]
				_puff_mats[k].set_shader_parameter("tint", t0.lerp(t0 * night, 1.0 - daylight))
				_puff_mats[k].set_shader_parameter("shade", s0.lerp(s0 * night, 1.0 - daylight))


## A shared cartoon puff material (dust, smoke); dimmed at night by `daylight`.
func puff_material(tint: Color, shade: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PUFF_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("shade", shade)
	_puff_mats.append(m)
	_puff_base.append([tint, shade])
	return m


## Process material for puffs: they swell, drift and fade.
static func puff_process(speed: Vector2, spread: float, gravity: float, grow: float = 2.2) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var curve := Curve.new()
	curve.max_value = grow
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.35, grow * 0.75))
	curve.add_point(Vector2(1, grow))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.12, Color(1, 1, 1, 0.85))
	grad.add_point(0.6, Color(1, 1, 1, 0.6))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	return pm


# ------------------------------------------------------------------ swarm dust

## A bug comes out of a tunnel (every peer): the mouth puffs dust and keeps
## rolling a cloud while more follow.
func tunnel_dust(pos: Vector3) -> void:
	if not polish:
		return
	if not _ensure_tunnels():
		return
	var best := -1
	var best_d := 400.0
	for i in _tunnel_fx.size():
		var d := _tunnel_fx[i].global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	_tunnel_busy[best] = 2.0
	_tunnel_fx[best].emitting = true
	var now := Time.get_ticks_msec() * 0.001
	if now - _tunnel_last[best] > TUNNEL_COOLDOWN:
		_tunnel_last[best] = now
		var out := -_tunnel_fx[best].global_basis.z
		dust_burst(_tunnel_fx[best].global_position, out + Vector3.UP * 0.6, 1.0)


## One big rolling puff of dust (tunnel bursts, wrecks).
func dust_burst(pos: Vector3, dir: Vector3, size: float = 1.0) -> void:
	var e := _next(_bursts, "burst")
	(e.process_material as ParticleProcessMaterial).scale_min = 0.7 * size
	(e.process_material as ParticleProcessMaterial).scale_max = 1.3 * size
	_fire(e, pos, dir)


func _ensure_tunnels() -> bool:
	if not _tunnel_fx.is_empty():
		return true
	if Bug.cliffs == null:
		return false
	var mat := puff_material(Color("#E9C08A"), Color("#B07E62"))
	for ti in Bug.cliffs.tunnel_count(): # Maps: any map's tunnels
		var tn := Bug.cliffs.tunnel(ti)
		var out: Vector3 = tn[1]
		var e := GPUParticles3D.new()
		e.amount = 48
		e.lifetime = 3.0
		e.local_coords = false
		e.emitting = false
		e.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 12, 20))
		var pm := puff_process(Vector2(1.5, 4.0), 40.0, 0.35, 3.2)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(2.0, 0.3, 0.6)
		e.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		quad.material = mat
		e.draw_pass_1 = quad
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
		var at: Vector3 = (tn[0] as Vector3) + out * 2.2 + Vector3.UP * 0.4
		# Emitters spray along -Z: point it out of the tunnel and a little up.
		e.global_transform = Transform3D(Basis.looking_at((out + Vector3.UP * 0.35).normalized(), Vector3.UP), at)
		_tunnel_fx.append(e)
		_tunnel_busy.append(0.0)
		_tunnel_last.append(-10.0)
	return true


func _make_puff_burst() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 10
	e.lifetime = 1.6
	e.explosiveness = 0.9
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 12, 16))
	e.process_material = puff_process(Vector2(1.0, 4.5), 70.0, 0.4, 2.6)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	quad.material = puff_material(Color("#EBC796"), Color("#B5826A"))
	e.draw_pass_1 = quad
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	return e


# ------------------------------------------------------------------ bug deaths

## Ichor splashed on the rock where a bug died: a decal along the surface normal.
## The pool of 64 is reused oldest-first, and each dries out after SPLAT_LIFE.
func ichor_splat(pos: Vector3, normal: Vector3, color: Color, size: float) -> void:
	if not polish:
		return
	var i := int(_i.get("splat", 0))
	_i["splat"] = (i + 1) % SPLAT_POOL
	var d := _splats[i]
	if not d.visible:
		_splats_live += 1
	var n := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var r := clampf(size, 0.4, 3.5) * randf_range(1.1, 1.5)
	d.size = Vector3(r * 2.0, 1.0 + r * 0.3, r * 2.0)
	var x := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(x, n, x.cross(n)).rotated(n, randf() * TAU)
	d.global_transform = Transform3D(b, pos)
	_splat_alpha[i] = 0.92
	d.modulate = Color(color.r, color.g, color.b, 0.92)
	d.visible = true
	_splat_age[i] = 0.0


static var _splat_tex: ImageTexture


## A white splat with satellite droplets (tinted per bug by the decal's modulate).
static func _splat_texture() -> ImageTexture:
	if _splat_tex != null:
		return _splat_tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var blobs: Array[Vector3] = [Vector3(0.5, 0.5, 0.2)]
	for k in 7:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(0.08, 0.2)
		blobs.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.07, 0.12)))
	for k in 10:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(0.27, 0.44)
		blobs.append(Vector3(0.5 + cos(a) * dist, 0.5 + sin(a) * dist, rng.randf_range(0.015, 0.04)))
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var field := 0.0
			for bl in blobs:
				var dd := Vector2(u - bl.x, v - bl.y).length_squared()
				field += bl.z * bl.z / maxf(dd, 0.00001)
			var a := clampf((field - 1.0) * 3.0, 0.0, 1.0)
			# Darker wet rim, a glossy fleck in the middle.
			var shade := 0.72 if field < 1.8 else 1.0
			if Vector2(u - 0.46, v - 0.44).length() < 0.045:
				shade = 1.0
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	_splat_tex = ImageTexture.create_from_image(img)
	return _splat_tex


# ------------------------------------------------------------------ guns and casings

## Called with every turret muzzle flash: lights the rock around it for a blink
## (lights are shared by turrets close together) and kicks out a casing.
func _muzzle_extras(pos: Vector3, dir: Vector3) -> void:
	if not polish:
		return
	var pick := 0
	var lowest := 9.0
	for i in LIGHT_POOL:
		if _light_e[i] > 0.0 and _lights[i].global_position.distance_squared_to(pos) < 64.0:
			pick = i
			lowest = -1.0
			break
		if _light_e[i] < lowest:
			lowest = _light_e[i]
			pick = i
	_light_e[pick] = 1.0
	var fwd := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	_lights[pick].global_position = pos + fwd * 0.4
	_lights[pick].visible = true
	# Casing: out the right side of the breech, up and back.
	var right := fwd.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.1 else Vector3.RIGHT
	_fire(_next(_casings, "casing"), pos - fwd * 0.5, (right + Vector3.UP * 0.8 - fwd * 0.3).normalized())


var _casing_mesh: CylinderMesh


func _make_casing_emitter() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 1
	e.lifetime = 1.0
	e.explosiveness = 1.0
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-4, -6, -4), Vector3(8, 9, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -14, 0)
	pm.angular_velocity_min = -900.0
	pm.angular_velocity_max = 900.0
	pm.particle_flag_rotate_y = true
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	e.process_material = pm
	if _casing_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 0.13
		cyl.radial_segments = 6
		cyl.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#D9A441")
		m.metallic = 0.7
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = Color("#5A3A10")
		cyl.material = m
		_casing_mesh = cyl
	e.draw_pass_1 = _casing_mesh
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	return e


# ------------------------------------------------------------------ wrecks

## Wood splinters and dust: a scaffold level comes down or a structure is wrecked.
func splinters(pos: Vector3, size: float = 1.0) -> void:
	var e := _next(_splinters, "splinter")
	var pm := e.process_material as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(0.8, 1.2, 0.8) * size
	_fire(e, pos, Vector3.UP)
	dust_burst(pos, Vector3.UP, 1.4 * size)
	Audio.play_at(&"hammer_hit", pos, -2.0)


func _make_splinter_emitter() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 16
	e.lifetime = 1.6
	e.explosiveness = 0.95
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-8, -12, -8), Vector3(16, 20, 16))
	var pm := _process_material(Vector2(3.0, 7.5), 70.0, -15.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 1.2, 0.8)
	pm.angular_velocity_min = -600.0
	pm.angular_velocity_max = 600.0
	pm.particle_flag_rotate_y = true
	pm.damping_min = 0.3
	pm.damping_max = 1.0
	pm.color_ramp = null
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.75, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	e.process_material = pm
	var st := MeshKit.begin()
	# A jagged plank splinter: a long thin box, tapered to a point at one end.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.09, 0.05, 0.45), Palette.WOOD, 0.0)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.22)), 0.05, 0.0, 0.25, 4, Palette.WOOD.lightened(0.15))
	var mesh := MeshKit.finish(st)
	mesh.surface_set_material(0, Materials.toon(0.0))
	e.draw_pass_1 = mesh
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	return e
