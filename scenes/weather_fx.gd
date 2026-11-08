class_name WeatherFx
extends Node3D
## What the weather looks and feels like (Logan: "make the weather systems feel
## more intense and impressive"), all local and cosmetic apart from the gusts
## and the host's lightning strikes:
##   - rain: dense velocity-stretched streaks round the camera, heavier sheets
##     further out, grey curtains of rain sweeping the distance, splash rings
##     where drops hit the ground and the roofs (GPU collision), the world
##     darkening as it gets wet and drying out after;
##   - thunderstorms: branching bolts with flickering return strokes, a blinding
##     flash, sparks, smoke and a scorch where one lands, and distant strikes
##     all round the horizon with their thunder arriving late;
##   - dust storms: rolling clouds of dust and sheets of sand streaming along
##     the canyon, grit flying past, tumbleweeds bowling through, visibility
##     surging with the gusts and a gritty, sand-brown screen;
##   - wind: dust wisps, tumbleweeds; snow: soft swirling flakes in two layers,
##     settling white on what faces up; fog: low banks rolling over the ground;
##   - heat wave: the air shimmering over the ground; blood moon: drifting embers
##     and ash.
## Particle counts follow the particle quality setting (GraphicsQuality.PARTICLE_RATIO);
## each layer fades with amount_ratio, so nothing reallocates mid-wave.

static var instance: WeatherFx

const SPLASH_TEX_SIZE := 64
## How fast the world gets wet / dry (per second), and how fast snow and dust settle.
const WET_RATE := 1.0 / 10.0
const DRY_RATE := 1.0 / 70.0
const SETTLE_RATE := 1.0 / 40.0
const STREAK_SHADER := preload("res://shaders/weather_streak.gdshader")
const SHEET_SHADER := preload("res://shaders/weather_sheet.gdshader")
const BOLT_SHADER := preload("res://shaders/weather_bolt.gdshader")
## Soft noisy puffs for the dust clouds and fog banks (made once).
static var _puff: Texture2D

var _rain_near: GPUParticles3D
var _rain_far: GPUParticles3D
var _splash: GPUParticles3D
var _curtains: GPUParticles3D
var _snow_near: GPUParticles3D
var _snow_far: GPUParticles3D
var _dust_clouds: GPUParticles3D
var _dust_sheets: GPUParticles3D
var _grit: GPUParticles3D
var _fog_wisps: GPUParticles3D
var _embers: GPUParticles3D
var _heightfield: GPUParticlesCollisionHeightField3D
var _curtain_mat: ShaderMaterial
var _dust_walls: GPUParticles3D
var _wall_mat: ShaderMaterial
## The streak and sheet materials, which take the day's light every frame.
var _lit_mats: Array[ShaderMaterial] = []
var _lit := -1.0
## Set by snap(): the next frame jumps straight to the weather's look.
var _snap := false
var _sheet_t := 3.0
var _wall_scroll := Vector2.ZERO
var _screen: WeatherScreen
var _weeds: Array[Tumble] = []
var _bolt_t := 0.0
var _far_bolt_t := 4.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
## Surface weather as it stands (0..1), sent to the world's shaders as globals.
var _wet := 0.0
var _snow_cover := 0.0
var _dust_coat := 0.0
var _sent := Vector3(-1, -1, -1)
## Gust strength now (0..1): dust storms surge and ease with it.
var gust := 0.0


## Which way the wind blows along the canyon (+1 or -1), fixed per wave.
static func wind_sign() -> float:
	return 1.0 if GameState.wave % 2 == 0 else -1.0


func _ready() -> void:
	instance = self
	_rng.randomize()
	var q := GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	var gpu_collide := not Settings.is_compatibility()
	var streak := _soft_tex(8, 64, true)
	var dot := _soft_tex(32, 32, false)
	# Rain: near streaks (they splash), far sheets, distant curtains.
	_rain_near = _layer("RainNear", int(9000 * q), 0.75, Vector3(24, 2, 24), streak, Color(0.72, 0.78, 0.9, 0.7), Vector2(0.028, 0.85), true)
	_rain_far = _layer("RainFar", int(5000 * q), 1.4, Vector3(85, 4, 85), streak, Color(0.7, 0.76, 0.88, 0.32), Vector2(0.07, 2.8), true)
	# (The far sheets keep clear of the camera: a ring, not a box, so no streak
	# ever passes close enough to fill the view.)
	var fpm := _rain_far.process_material as ParticleProcessMaterial
	fpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fpm.emission_ring_axis = Vector3.UP
	fpm.emission_ring_radius = 85.0
	fpm.emission_ring_inner_radius = 16.0
	fpm.emission_ring_height = 4.0
	_streak_param(_rain_near, "near_fade", 1.6)
	_streak_param(_rain_far, "near_fade", 14.0)
	if gpu_collide:
		_heightfield = GPUParticlesCollisionHeightField3D.new()
		_heightfield.size = Vector3(56, 60, 56)
		_heightfield.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
		_heightfield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
		_heightfield.follow_camera_enabled = true
		add_child(_heightfield)
		_splash = _splash_layer(int(2400 * q))
		var pm := _rain_near.process_material as ParticleProcessMaterial
		pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
		pm.sub_emitter_amount_at_collision = 1
		_rain_near.collision_base_size = 0.05
		_rain_near.sub_emitter = _rain_near.get_path_to(_splash)
	_curtains = _curtain_layer()
	# Snow: small sharp flakes close by, big soft ones further out, both swirling.
	_snow_near = _layer("SnowNear", int(3600 * q), 6.0, Vector3(24, 3, 24), dot, Color(1, 1, 1, 1.0), Vector2(0.13, 0.13), false)
	_snow_far = _layer("SnowFar", int(2000 * q), 9.0, Vector3(70, 6, 70), dot, Color(1, 1, 1, 0.7), Vector2(0.42, 0.42), false)
	for s: GPUParticles3D in [_snow_near, _snow_far]:
		var pm := s.process_material as ParticleProcessMaterial
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.2
		pm.turbulence_noise_scale = 6.0
		pm.turbulence_influence_min = 0.08
		pm.turbulence_influence_max = 0.2
		pm.scale_min = 0.6
		pm.scale_max = 1.5
	# Dust: rolling clouds, sand streaming low, grit flying past.
	_dust_clouds = _layer("DustClouds", int(340 * q), 6.0, Vector3(90, 7, 90), _puff_tex(), Color(1, 1, 1, 0.62), Vector2(22, 22), false)
	var dpm := _dust_clouds.process_material as ParticleProcessMaterial
	# Each cloud its own shade, from dark umber to pale sand: the murk has billows.
	var tones := Gradient.new()
	tones.colors = PackedColorArray([Color(0.46, 0.31, 0.2), Color(0.68, 0.48, 0.31), Color(0.86, 0.68, 0.47)])
	tones.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tt := GradientTexture1D.new()
	tt.gradient = tones
	dpm.color_initial_ramp = tt
	dpm.scale_min = 0.5
	dpm.scale_max = 1.3
	dpm.angle_min = -180.0
	dpm.angle_max = 180.0
	dpm.angular_velocity_min = -12.0
	dpm.angular_velocity_max = 12.0
	dpm.color_ramp = _fade_ramp(0.2, 0.7)
	_dust_sheets = _layer("DustSheets", int(1400 * q), 1.2, Vector3(30, 0.6, 30), streak, Color(0.86, 0.68, 0.46, 0.6), Vector2(0.11, 2.8), true)
	_grit = _layer("Grit", int(1300 * q), 0.8, Vector3(12, 4, 12), streak, Color(0.55, 0.4, 0.26, 0.7), Vector2(0.02, 0.35), true)
	_streak_param(_dust_sheets, "near_fade", 2.5)
	_streak_param(_grit, "near_fade", 0.6)
	# Walls of dust rolling along the canyon in the middle distance.
	_dust_walls = _sheet_layer("DustWalls", 30, _dust_wall_img(), Vector2(70, 46), 14.0, Color(0.74, 0.55, 0.37, 0.75), 45.0, 230.0)
	_wall_mat = (_dust_walls.draw_pass_1 as QuadMesh).material as ShaderMaterial
	_wall_mat.set_shader_parameter("tiling", Vector2(1.6, 1.0))
	var wpm := _dust_walls.process_material as ParticleProcessMaterial
	wpm.color_initial_ramp = tt
	# Fog banks drifting low over the ground; embers and ash under a blood moon.
	_fog_wisps = _layer("FogWisps", int(140 * maxf(q, 0.6)), 14.0, Vector3(100, 2.5, 100), _puff_tex(), Color(0.93, 0.94, 0.96, 0.5), Vector2(30, 11), false)
	# Banks of cloud: soft where they meet the ground, thinning out close to the eye.
	for p: GPUParticles3D in [_fog_wisps, _dust_clouds]:
		var bm := (p.draw_pass_1 as QuadMesh).material as StandardMaterial3D
		bm.proximity_fade_enabled = true
		bm.proximity_fade_distance = 4.0
		bm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		bm.distance_fade_min_distance = 2.0
		bm.distance_fade_max_distance = 12.0
	(_fog_wisps.process_material as ParticleProcessMaterial).color_ramp = _fade_ramp(0.25, 0.7)
	_embers = _layer("Embers", int(500 * q), 7.0, Vector3(40, 10, 40), dot, Color(1.0, 0.45, 0.2, 1.0), Vector2(0.06, 0.06), false)
	var em := _embers.draw_pass_1.surface_get_material(0) as StandardMaterial3D
	em.emission_enabled = true
	em.emission = Color(1.0, 0.35, 0.12)
	em.emission_energy_multiplier = 3.0
	var epm := _embers.process_material as ParticleProcessMaterial
	epm.turbulence_enabled = true
	epm.turbulence_noise_strength = 1.5
	epm.color_ramp = _fade_ramp(0.1, 0.6)
	# Tumbleweeds bowling through in wind and dust.
	for i in 5:
		var tw := Tumble.new()
		tw.seed_value = 900 + i
		add_child(tw)
		_weeds.append(tw)
	_screen = WeatherScreen.new()
	add_child(_screen)
	GameState.weather_changed.connect(func(_k: int) -> void: _bolt_t = _next_bolt())
	_bolt_t = 999.0


# ------------------------------------------------------------------ building the layers

## A soft white texture: a narrow streak (soft sides, softer ends) or a round dot.
static func _soft_tex(w: int, h: int, streak: bool) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var a := 0.0
			if streak:
				a = (1.0 - u * u) * pow(1.0 - absf(v), 0.7) * (0.6 + 0.4 * (1.0 - v) * 0.5)
			else:
				a = pow(clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0), 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _tex(path: String, fallback: Texture2D) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else fallback


## Alpha in over `a` of the life, out over the last `1 - b`.
static func _fade_ramp(a: float, b: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, a, b, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A particle layer following the camera: `size` the quad (streaks are
## stretched along their velocity), `box` the emission box's half extents.
func _layer(n: String, amount: int, life: float, box: Vector3, tex: Texture2D, color: Color, size: Vector2, streak: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = maxi(amount, 8)
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(-box * 2.0 - Vector3(0, 40, 0), box * 4.0 + Vector3(0, 80, 0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.DOWN
	pm.spread = 3.0
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = streak
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = size
	if streak:
		# Stretched along the velocity and turned to the camera (weather_streak).
		var sm := ShaderMaterial.new()
		sm.shader = STREAK_SHADER
		sm.set_shader_parameter("tint", color)
		sm.set_shader_parameter("tex", tex)
		q.material = sm
		_lit_mats.append(sm)
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = color
		mat.albedo_texture = tex
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	return p


static func _streak_param(p: GPUParticles3D, key: String, value: Variant) -> void:
	((p.draw_pass_1 as QuadMesh).material as ShaderMaterial).set_shader_parameter(key, value)


## A soft, lumpy puff (noise inside a round falloff), lighter on top.
static func _puff_tex() -> Texture2D:
	if _puff != null:
		return _puff
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.045
	n.fractal_octaves = 4
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length() / (s * 0.5)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d * d) * (0.25 + v * 1.1) - 0.08, 0.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, d))
			var shade := 0.8 + 0.12 * v + 0.1 * (1.0 - float(y) / s)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	_puff = ImageTexture.create_from_image(img)
	return _puff


## Blowing dust for the dust walls: lumpy billows (tiling side to side and up
## and down), thicker low down.
static func _dust_wall_img() -> Image:
	var n := FastNoiseLite.new()
	n.seed = 31
	n.frequency = 0.014
	n.fractal_octaves = 5
	var w := 256
	var h := 128
	var src := n.get_seamless_image(w, h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := src.get_pixel(x, y).r
			var a := clampf((v - 0.25) * 1.6, 0.0, 1.0)
			var shade := 0.78 + 0.3 * v
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return img


## Rain for the curtains: streaks of every strength running top to bottom
## (tiling), over a thin grey haze.
static func _rain_sheet_img() -> Image:
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cols := PackedFloat32Array()
	var phase := PackedFloat32Array()
	cols.resize(w)
	phase.resize(w)
	for k in 90:
		var x := rng.randi_range(0, w - 1)
		cols[x] = maxf(cols[x], rng.randf_range(0.25, 1.0))
		phase[x] = rng.randf() * TAU
	for y in h:
		for x in w:
			var s: float = cols[x] * clampf(0.35 + 0.65 * sin(float(y) / h * TAU * 3.0 + phase[x]), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(0.22 + s * 0.78, 0.0, 1.0)))
	return img


## Splash rings where the near rain hits (a flat ring that spreads and fades,
## a couple of droplets thrown up).
func _splash_layer(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Splashes"
	p.amount = maxi(amount, 8)
	p.lifetime = 0.35
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color_ramp = _fade_ramp(0.05, 0.3)
	p.process_material = pm
	var img := Image.create(SPLASH_TEX_SIZE, SPLASH_TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in SPLASH_TEX_SIZE:
		for x in SPLASH_TEX_SIZE:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(Vector2.ONE * SPLASH_TEX_SIZE * 0.5) / (SPLASH_TEX_SIZE * 0.5)
			var a := clampf(1.0 - absf(r - 0.78) / 0.14, 0.0, 1.0) * (1.0 if r < 1.0 else 0.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.45, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.7)
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = mat
	p.draw_pass_1 = plane
	add_child(p)
	return p


## Grey curtains of rain sweeping the middle distance: tall cards in a ring
## round the camera, their streaks scrolling down.
func _curtain_layer() -> GPUParticles3D:
	var p := _sheet_layer("RainCurtains", 46, _rain_sheet_img(), Vector2(34, 90), 30.0, Color(0.56, 0.6, 0.68, 0.4), 90.0, 260.0)
	_curtain_mat = (p.draw_pass_1 as QuadMesh).material as ShaderMaterial
	_curtain_mat.set_shader_parameter("tiling", Vector2(1.0, 1.6))
	return p


## Tall cards of weather in a ring round the camera, `inner` to `outer` metres
## out, each `size` (raised `lift`), drawn with weather_sheet.
func _sheet_layer(n: String, amount: int, img: Image, size: Vector2, lift: float, color: Color, inner: float, outer: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(Vector3(-320, -100, -320), Vector3(640, 260, 640))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = outer
	pm.emission_ring_inner_radius = inner
	pm.emission_ring_height = 1.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.color_ramp = _fade_ramp(0.2, 0.75)
	p.process_material = pm
	img.generate_mipmaps()
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, lift, 0)
	var m := ShaderMaterial.new()
	m.shader = SHEET_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("near_fade", inner * 0.6)
	q.material = m
	_lit_mats.append(m)
	p.draw_pass_1 = q
	add_child(p)
	return p


# ------------------------------------------------------------------ every frame

## Jumps straight to the weather's look next frame (the UI gallery).
func snap() -> void:
	_snap = true


func _process(frame_delta: float) -> void:
	var delta := 1000.0 if _snap else frame_delta
	_snap = false
	_t += frame_delta
	var w := GameState.weather
	var cam := get_viewport().get_camera_3d()
	var storm := w == Weather.Kind.THUNDERSTORM
	var rain := Weather.is_rain(w)
	var dusty := w == Weather.Kind.DUST_STORM
	var windy := w == Weather.Kind.WINDY
	var ws := wind_sign()
	# Gusts: a slow swell with quick surges on top.
	var g := 0.55 + 0.3 * sin(_t * 0.37) + 0.25 * sin(_t * 1.13 + 1.0) * sin(_t * 0.21)
	gust = clampf(g, 0.0, 1.0)
	_fade(_rain_near, 1.0 if storm else (0.5 if rain else 0.0), delta)
	_fade(_rain_far, 1.0 if storm else (0.55 if rain else 0.0), delta)
	_fade(_curtains, 1.0 if storm else (0.5 if rain else 0.0), delta, 0.25)
	_fade(_dust_walls, (0.7 + 0.3 * gust) if dusty else 0.0, delta, 0.25)
	_fade(_snow_near, 1.0 if w == Weather.Kind.SNOW else 0.0, delta)
	_fade(_snow_far, 1.0 if w == Weather.Kind.SNOW else 0.0, delta)
	_fade(_dust_clouds, (0.7 + 0.3 * gust) if dusty else (0.12 if windy else 0.0), delta)
	_fade(_dust_sheets, (0.6 + 0.4 * gust) if dusty else (0.35 if windy else 0.0), delta)
	_fade(_grit, (0.5 + 0.5 * gust) if dusty else (0.15 if windy else 0.0), delta)
	_fade(_fog_wisps, 1.0 if w == Weather.Kind.FOG else 0.0, delta, 0.2)
	_fade(_embers, 1.0 if w == Weather.Kind.BLOOD_MOON else 0.0, delta)
	if _splash != null:
		_splash.emitting = _rain_near.emitting
	if cam != null:
		var at := cam.global_position
		var slant := Vector3(0, 0, ws) * (9.0 if storm else 4.0)
		# Emit upwind and above so the slanted rain lands round the camera.
		_rain_near.global_position = at + Vector3(0, 14.0, 0) - slant * 0.4
		_rain_far.global_position = at + Vector3(0, 30.0, 0) - slant * 0.8
		_set_vel(_rain_near, Vector3(0, -34.0, 0) + slant, 3.0)
		_set_vel(_rain_far, Vector3(0, -30.0, 0) + slant * 1.2, 4.0)
		_curtains.global_position = Vector3(at.x, at.y - 25.0, at.z)
		_set_vel(_curtains, Vector3(0, 0, ws * 5.0), 2.0)
		_curtain_mat.set_shader_parameter("scroll", Vector2(0.0, fposmod(-_t * 1.1, 1.0)))
		# The dust walls roll along the canyon: across the view when looking
		# across it, churning when looking along it.
		_dust_walls.global_position = Vector3(at.x, at.y - 16.0, at.z)
		_set_vel(_dust_walls, Vector3(0, 0, ws * (14.0 + 10.0 * gust)), 3.0)
		_wall_scroll += Vector2(cam.global_basis.x.z * ws * (0.05 + 0.04 * gust), 0.012) * frame_delta
		_wall_scroll = Vector2(fposmod(_wall_scroll.x, 1.0), fposmod(_wall_scroll.y, 1.0))
		_wall_mat.set_shader_parameter("scroll", _wall_scroll)
		var sway := Vector3(sin(_t * 0.5) * 0.6, -1.6, ws * (0.8 if not windy else 4.0))
		_snow_near.global_position = at + Vector3(0, 9.0, 0)
		_snow_far.global_position = at + Vector3(0, 16.0, 0)
		_set_vel(_snow_near, sway, 0.6)
		_set_vel(_snow_far, sway * 1.2, 0.8)
		var blow := Vector3(0, 0, ws) * (20.0 + 14.0 * gust) if dusty else Vector3(0, 0, ws) * 12.0
		_dust_clouds.global_position = at + Vector3(0, 2.0, -ws * 30.0)
		_dust_sheets.global_position = at + Vector3(0, -1.2, -ws * 8.0)
		_grit.global_position = at + Vector3(0, 0.2, -ws * 4.0)
		_set_vel(_dust_clouds, blow * 0.8 + Vector3(0, 0.6, 0), 4.0)
		_set_vel(_dust_sheets, blow * 1.3 + Vector3(0, 0.2, 0), 3.0)
		_set_vel(_grit, blow * 1.6, 5.0)
		_fog_wisps.global_position = Vector3(at.x, at.y - 0.6, at.z)
		_set_vel(_fog_wisps, Vector3(0, 0, ws * 1.5), 0.5)
		_embers.global_position = at + Vector3(0, -2.0, 0)
		_set_vel(_embers, Vector3(0, 1.0, ws * 1.2), 0.8)
	# Surface weather: wet in the rain (and drying after), snow settling, dust powdering.
	_wet = move_toward(_wet, 1.0 if storm else (0.7 if rain else 0.0), delta * (WET_RATE if rain else DRY_RATE))
	_snow_cover = move_toward(_snow_cover, 0.85 if w == Weather.Kind.SNOW else 0.0, delta * SETTLE_RATE)
	_dust_coat = move_toward(_dust_coat, 0.6 if dusty else 0.0, delta * SETTLE_RATE)
	var now := Vector3(_wet, _snow_cover, _dust_coat)
	if now.distance_to(_sent) > 0.004:
		_sent = now
		RenderingServer.global_shader_parameter_set(&"weather_wet", _wet)
		RenderingServer.global_shader_parameter_set(&"weather_snow", _snow_cover)
		RenderingServer.global_shader_parameter_set(&"weather_dust", _dust_coat)
	var across := ws
	if cam != null:
		var side := cam.global_basis.x.z * ws
		across = signf(side if absf(side) > 0.01 else ws) * maxf(absf(side), 0.3)
	_screen.set_state(w, gust, across, delta > 100.0)
	# Rain and sand take the day's light: dim at night, lit up by lightning.
	var lit := 1.0
	var dc := DayCycle.instance
	if dc != null:
		lit = lerpf(1.0, 0.3, dc.night_amount()) + dc.flash * 1.4
	if absf(lit - _lit) > 0.01:
		_lit = lit
		for m: ShaderMaterial in _lit_mats:
			m.set_shader_parameter("light", lit)
	for tw: Tumble in _weeds:
		tw.active = windy or dusty
		tw.speed = (10.0 + 8.0 * gust) if dusty else 7.0
	if windy or dusty:
		_push_local_player(frame_delta)
	# Distant strikes on every peer (just a show), lightning flickering inside the
	# cloud between them; the host calls the real ones down.
	if storm:
		_far_bolt_t -= frame_delta
		if _far_bolt_t <= 0.0:
			_far_bolt_t = _rng.randf_range(2.5, 7.0)
			_far_strike(cam)
		_sheet_t -= frame_delta
		if _sheet_t <= 0.0:
			_sheet_t = _rng.randf_range(1.5, 5.0)
			_sheet_flash()
	if multiplayer.is_server() and storm and GameState.phase == GameState.Phase.WAVE:
		_bolt_t -= frame_delta
		if _bolt_t <= 0.0:
			_bolt_t = _next_bolt()
			_strike()


## Eases a layer's share of its particles toward `want`; off when empty.
func _fade(p: GPUParticles3D, want: float, delta: float, rate: float = 0.5) -> void:
	if p == null:
		return
	p.amount_ratio = move_toward(p.amount_ratio, want, delta * rate)
	var on := p.amount_ratio > 0.001
	if p.emitting != on:
		p.emitting = on


static func _set_vel(p: GPUParticles3D, v: Vector3, jitter: float) -> void:
	var pm := p.process_material as ParticleProcessMaterial
	var speed := v.length()
	if speed < 0.001:
		return
	pm.direction = v / speed
	pm.initial_velocity_min = maxf(speed - jitter, 0.0)
	pm.initial_velocity_max = speed + jitter


func _next_bolt() -> float:
	var r := Weather.lightning_interval(GameState.weather)
	return _rng.randf_range(r.x, r.y) if r.y > 0.0 else 999.0


## Gusts: a steady sideways shove that comes and goes.
func _push_local_player(delta: float) -> void:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if not p.is_multiplayer_authority():
			continue
		var gust_k := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.0013)
		p.velocity.z += wind_sign() * Weather.WIND_PUSH * gust_k * delta * (3.0 if not p.is_on_floor() else 1.0)


# ------------------------------------------------------------------ lightning

## Host: pick a spot (often a turret) and call the bolt down.
func _strike() -> void:
	var turrets := get_tree().get_nodes_in_group("turrets")
	var target := Vector3.ZERO
	var victim := ""
	if not turrets.is_empty() and _rng.randf() < Weather.LIGHTNING_TURRET_CHANCE:
		var t := turrets[_rng.randi() % turrets.size()] as Turret
		target = t.global_position
		victim = t.get_path()
	else:
		var cid := _rng.randi() % 2
		var cl := Bug.cliffs
		if cl == null:
			return
		if _rng.randf() < 0.5:
			target = cl.plateau_point(cid, _rng.randf_range(2.0, 28.0), _rng.randf_range(-20.0, 20.0))
		else:
			target = cl.face_point(cid, _rng.randf_range(10.0, 55.0), _rng.randf_range(-20.0, 20.0))
	# Bugs caught in the blast are fried.
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b.is_alive() and b.global_position.distance_to(target) < 3.5:
			b.receive_hit(400.0, target, Vector3.DOWN, true, 1.0, "Lightning", -1)
	if victim != "":
		var t := get_node_or_null(victim) as Turret
		if t != null and t.health != null:
			t.health.take_damage(t.health.hp + 1.0, "Lightning", -1)
	if GameState.has_flag("--debug"):
		print("[weather] lightning at %s%s" % [str(target.snapped(Vector3.ONE)), " (turret wrecked)" if victim != "" else ""])
	_bolt.rpc(target, victim != "")


@rpc("authority", "call_local", "reliable")
func _bolt(target: Vector3, hit_turret: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	var from := target + Vector3(_rng.randf_range(-30, 30), 170.0, _rng.randf_range(-30, 30))
	var dist := cam.global_position.distance_to(target) if cam != null else 50.0
	_draw_bolt(from, target, cam, 1.0, true)
	_impact(target)
	if DayCycle.instance != null:
		DayCycle.instance.flash = 1.0
	_screen.flash(clampf(1.0 - dist / 220.0, 0.25, 0.9))
	# The crack right away, the rumble rolling in after.
	Audio.play_at(&"thunder", target, 9.0, 1.15)
	get_tree().create_timer(clampf(dist / 343.0, 0.05, 1.5) + 0.35).timeout.connect(func() -> void:
		Audio.play_ui(&"thunder", -6.0, 0.72))
	if hit_turret:
		Economy.notice.emit("Lightning struck a turret and wrecked it!")
	for n: Node in get_tree().get_nodes_in_group("players"):
		var pl := n as Player
		if pl.is_multiplayer_authority():
			pl.add_shake(clampf(1.0 - pl.global_position.distance_to(target) / 60.0, 0.15, 0.8))


## A strike somewhere far off (250-1300 m), seen and then heard late.
func _far_strike(cam: Camera3D) -> void:
	if cam == null:
		return
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(250.0, 1300.0)
	var ground := cam.global_position + Vector3(cos(a), 0, sin(a)) * d
	ground.y = _ground_y(ground, cam.global_position.y - 30.0)
	var top := ground + Vector3(_rng.randf_range(-60, 60), _rng.randf_range(220.0, 320.0), _rng.randf_range(-60, 60))
	_draw_bolt(top, ground, cam, clampf(d / 140.0, 1.6, 7.0), false, clampf(1.15 - d / 1500.0, 0.3, 1.0))
	if DayCycle.instance != null:
		DayCycle.instance.flash = maxf(DayCycle.instance.flash, clampf(0.55 - d / 3000.0, 0.15, 0.45))
	get_tree().create_timer(d / 343.0).timeout.connect(func() -> void:
		Audio.play_ui(&"thunder", lerpf(-8.0, -22.0, d / 1300.0), _rng.randf_range(0.6, 0.82)))


## Lightning hidden in the cloud: the sky flickers a few times, no bolt, and
## now and then a low rumble follows.
func _sheet_flash() -> void:
	var dc := DayCycle.instance
	if dc == null:
		return
	var tw := create_tween()
	for k in _rng.randi_range(2, 4):
		var v := _rng.randf_range(0.15, 0.4)
		tw.tween_callback(func() -> void: dc.flash = maxf(dc.flash, v))
		tw.tween_interval(_rng.randf_range(0.05, 0.14))
	if _rng.randf() < 0.5:
		get_tree().create_timer(_rng.randf_range(2.0, 4.5)).timeout.connect(func() -> void:
			Audio.play_ui(&"thunder", -20.0, _rng.randf_range(0.55, 0.7)))


## The ground height under `p` (a ray from high above), or `fallback`.
func _ground_y(p: Vector3, fallback: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 400.0, p - Vector3.UP * 400.0)
	q.collision_mask = WorldLayout.LAYER_WORLD
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else fallback


## A branching bolt from `top` to `ground`: a jagged main channel with forks
## (and forks off the forks), drawn as camera-facing ribbons with a white-hot
## core in a blue glow (weather_bolt), `width` times life size. A dim stepped
## leader races down first, then 3-4 return strokes flicker along the whole
## path. `bright` dims a far one.
func _draw_bolt(top: Vector3, ground: Vector3, cam: Camera3D, width: float, near: bool, bright: float = 1.0) -> void:
	var eye := cam.global_position if cam != null else ground + Vector3(0, 0, 50)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main := _channel(top, ground, 26, 9.0)
	_ribbon(st, main, 2.8 * width, eye, 1.0, 0.0, 1.0)
	var span := top.y - ground.y
	for k in _rng.randi_range(5, 9):
		var i := _rng.randi_range(2, main.size() - 6)
		var start: Vector3 = main[i]
		var dir: Vector3 = ((main[i + 1] as Vector3) - start).normalized()
		var side := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		var flen := span * _rng.randf_range(0.12, 0.32)
		var end: Vector3 = start + (dir * 0.6 + side * 0.8).normalized() * flen
		var fork := _channel(start, end, 10, 5.0)
		var t0 := float(i) / (main.size() - 1)
		var t1 := t0 + flen / span
		_ribbon(st, fork, 1.4 * width, eye, 0.6, t0, t1)
		if _rng.randf() < 0.55:
			var j := _rng.randi_range(2, fork.size() - 3)
			var s2: Vector3 = fork[j]
			var side2 := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
			var e2: Vector3 = s2 + (Vector3.DOWN * 0.5 + side2).normalized() * flen * 0.45
			var tj := lerpf(t0, t1, float(j) / (fork.size() - 1))
			_ribbon(st, _channel(s2, e2, 6, 3.0), 0.8 * width, eye, 0.4, tj, tj + flen * 0.45 / span)
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = BOLT_SHADER
	m.set_shader_parameter("energy", 0.0)
	m.set_shader_parameter("reveal", 0.0)
	mi.material_override = m
	root.add_child(mi)
	var light: OmniLight3D = null
	if near:
		light = OmniLight3D.new()
		light.light_color = Color(0.8, 0.88, 1.0)
		light.light_energy = 0.0
		light.omni_range = 90.0
		light.position = ground + Vector3.UP * 12.0
		root.add_child(light)
	var tw := root.create_tween()
	# The leader: a dim, forking line stepping down the sky.
	tw.tween_callback(func() -> void: m.set_shader_parameter("energy", 0.3 * bright))
	tw.tween_method(func(r: float) -> void: m.set_shader_parameter("reveal", r), 0.0, 1.0, 0.1 if near else 0.13)
	tw.tween_callback(func() -> void: m.set_shader_parameter("reveal", 2.0))
	# Return strokes: on, nearly off, on brighter, a dim flicker, on, fading.
	var steps: Array = [[0.07, 1.0], [0.05, 0.06], [0.08, 1.3], [0.05, 0.3], [0.09, 0.95], [0.2, 0.2], [0.14, 0.07]]
	for s: Array in steps:
		var k := float(s[1])
		tw.tween_callback(func() -> void:
			m.set_shader_parameter("energy", k * bright)
			if light != null:
				light.light_energy = 26.0 * k
			if DayCycle.instance != null and k > 0.5:
				DayCycle.instance.flash = maxf(DayCycle.instance.flash, 0.7 * k if near else 0.3 * bright))
		tw.tween_interval(float(s[0]))
	tw.tween_callback(root.queue_free)


## A jagged line of `n` points from a to b, wandering up to `jag` metres.
func _channel(a: Vector3, b: Vector3, n: int, jag: float) -> Array:
	var pts: Array = [a]
	var drift := Vector3.ZERO
	for i in range(1, n):
		var t := float(i) / (n - 1)
		drift += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * jag * 0.45
		drift *= 0.75
		pts.append(a.lerp(b, t) + drift * sin(t * PI))
	pts[n - 1] = b
	return pts


## A strip along `pts`, `w` wide (tapering toward the end), turned to face
## `eye`: UV.x across it, UV.y running `v0` to `v1` down the channel, vertex
## alpha the branch's `strength`.
static func _ribbon(st: SurfaceTool, pts: Array, w: float, eye: Vector3, strength: float, v0: float, v1: float) -> void:
	var n := pts.size()
	var sides: Array[Vector3] = []
	for i in n:
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var next: Vector3 = pts[mini(i + 1, n - 1)]
		var along := (next - prev).normalized()
		var side := along.cross((eye - p).normalized()).normalized()
		sides.append(side * w * 0.5 * (1.0 - float(i) / n * 0.45))
	var col := Color(1, 1, 1, strength)
	for i in n - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var va := lerpf(v0, v1, float(i) / (n - 1))
		var vb := lerpf(v0, v1, float(i + 1) / (n - 1))
		var sa: Vector3 = sides[i]
		var sb: Vector3 = sides[i + 1]
		for vtx: Array in [[a - sa, 0.0, va], [a + sa, 1.0, va], [b + sb, 1.0, vb], [a - sa, 0.0, va], [b + sb, 1.0, vb], [b - sb, 0.0, vb]]:
			st.set_color(col)
			st.set_uv(Vector2(float(vtx[1]), float(vtx[2])))
			st.add_vertex(vtx[0])


## Where a bolt lands: a burst of sparks, a puff of smoke and dust, a ring of
## dust thrown out, and a scorch that fades over half a minute.
func _impact(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	get_tree().current_scene.add_child(root)
	var sparks := GPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 70
	sparks.lifetime = 0.9
	sparks.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -14.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = _fade_ramp(0.0, 0.5)
	sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.55)
	var sm := ShaderMaterial.new()
	sm.shader = STREAK_SHADER
	sm.set_shader_parameter("tint", Color(1.0, 0.97, 0.9, 1.0))
	sm.set_shader_parameter("tex", _soft_tex(8, 32, true))
	sm.set_shader_parameter("near_fade", 0.3)
	sm.set_shader_parameter("light", 2.0)
	pm.particle_flag_align_y = true
	q.material = sm
	sparks.draw_pass_1 = q
	sparks.emitting = true
	root.add_child(sparks)
	var ring := GPUParticles3D.new()
	ring.one_shot = true
	ring.amount = 26
	ring.lifetime = 2.2
	ring.explosiveness = 1.0
	var rpm := ParticleProcessMaterial.new()
	rpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rpm.emission_ring_axis = Vector3.UP
	rpm.emission_ring_radius = 1.0
	rpm.emission_ring_inner_radius = 0.6
	rpm.emission_ring_height = 0.2
	rpm.direction = Vector3.UP
	rpm.spread = 10.0
	rpm.initial_velocity_min = 0.5
	rpm.initial_velocity_max = 1.5
	rpm.radial_velocity_min = 9.0
	rpm.radial_velocity_max = 14.0
	rpm.damping_min = 5.0
	rpm.damping_max = 7.0
	rpm.gravity = Vector3.ZERO
	rpm.scale_min = 0.7
	rpm.scale_max = 1.3
	rpm.color_ramp = _fade_ramp(0.04, 0.4)
	ring.process_material = rpm
	var rq := QuadMesh.new()
	rq.size = Vector2(3.2, 3.2)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.vertex_color_use_as_albedo = true
	rmat.albedo_color = Color(0.62, 0.5, 0.38, 0.6)
	rmat.albedo_texture = _puff_tex()
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	rq.material = rmat
	ring.draw_pass_1 = rq
	ring.emitting = true
	root.add_child(ring)
	var smoke := GPUParticles3D.new()
	smoke.one_shot = true
	smoke.amount = 18
	smoke.lifetime = 3.5
	smoke.explosiveness = 0.9
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spm.emission_sphere_radius = 1.5
	spm.direction = Vector3.UP
	spm.spread = 60.0
	spm.initial_velocity_min = 2.0
	spm.initial_velocity_max = 6.0
	spm.gravity = Vector3(0, 0.6, 0)
	spm.damping_min = 1.5
	spm.damping_max = 2.5
	spm.scale_min = 0.8
	spm.scale_max = 1.6
	spm.color_ramp = _fade_ramp(0.05, 0.5)
	smoke.process_material = spm
	var sq := QuadMesh.new()
	sq.size = Vector2(4.0, 4.0)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.albedo_color = Color(0.32, 0.3, 0.3, 0.55)
	smat.albedo_texture = _puff_tex()
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = smat
	smoke.draw_pass_1 = sq
	smoke.emitting = true
	root.add_child(smoke)
	# The scorch: a dark burn on whatever it hit.
	var burn := Decal.new()
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(32, 32)) / 32.0
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.06, 0.04, 0.03, pow(a, 0.6) * 0.85))
	burn.texture_albedo = ImageTexture.create_from_image(img)
	burn.size = Vector3(5.0, 4.0, 5.0)
	root.add_child(burn)
	var tw := root.create_tween()
	tw.tween_interval(20.0)
	tw.tween_property(burn, "modulate:a", 0.0, 10.0)
	tw.tween_callback(root.queue_free)


# ------------------------------------------------------------------ tumbleweeds

## A tumbleweed blown past the camera: rolls in from upwind, bounding and
## spinning, and comes round again further along. Local and cosmetic.
class Tumble extends MeshInstance3D:
	var seed_value := 0
	var active := false
	var speed := 8.0
	var _rng := RandomNumberGenerator.new()
	var _bounce := 0.0
	var _offset := Vector3.ZERO
	var _ground := 0.0

	func _ready() -> void:
		_rng.seed = seed_value
		var st := MeshKit.begin()
		var c := Color("#B8955A")
		for i in 26:
			var a := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * 0.6
			var b := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * 0.6
			MeshKit.add_limb(st, a, b, 0.025, c.darkened(_rng.randf() * 0.3), 3)
		mesh = MeshKit.finish(st)
		material_override = Materials.toon(0.006)
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visible = false
		scale = Vector3.ONE * _rng.randf_range(0.8, 1.4)

	func _process(delta: float) -> void:
		var cam := get_viewport().get_camera_3d()
		if not active or cam == null:
			visible = false
			_offset = Vector3.ZERO
			return
		var ws := WeatherFx.wind_sign()
		if not visible or (position - cam.global_position).dot(Vector3(0, 0, ws)) > 45.0:
			# Back in upwind of the camera, somewhere to one side.
			_offset = Vector3(_rng.randf_range(-16.0, 16.0), 0, -ws * _rng.randf_range(35.0, 55.0))
			position = cam.global_position + _offset
			_ground = cam.global_position.y - 1.7
			visible = true
		position += Vector3(sin(_bounce * 0.3) * 0.5, 0, ws * speed) * delta
		_bounce += delta * (2.5 + speed * 0.3)
		# Keep to the ground: a ray down now and then.
		if Engine.get_process_frames() % 6 == seed_value % 6:
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 6.0, position - Vector3.UP * 30.0)
			q.collision_mask = WorldLayout.LAYER_WORLD
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				_ground = (hit["position"] as Vector3).y
		position.y = _ground + 0.55 * scale.x + absf(sin(_bounce)) * 0.9
		rotate(Vector3(1, 0, 0), ws * speed * delta * 1.6)


# ------------------------------------------------------------------ the screen

## Full-screen weather over the view: sand-brown grit streaming across in a
## dust storm, heat shimmer bending the lower view in a heat wave, a cold grey
## edge in a storm, and the white-out of a close lightning flash. Hidden (no
## cost) in clear weather.
class WeatherScreen extends CanvasLayer:
	var _rect: ColorRect
	var _mat: ShaderMaterial
	var _flash := 0.0
	var _dust := 0.0
	var _heat := 0.0
	var _storm := 0.0

	func _ready() -> void:
		layer = -1 # (over the 3D view, under the HUD)
		_rect = ColorRect.new()
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/weather_screen.gdshader") as Shader
		_rect.material = _mat
		add_child(_rect)
		_rect.visible = false

	func flash(amount: float) -> void:
		_flash = maxf(_flash, amount)

	## `across`: how the wind crosses the view (-1..1, the grit's way on screen);
	## `snap` jumps straight to the weather's look.
	func set_state(w: int, gust: float, across: float, snap: bool) -> void:
		var dt := 1000.0 if snap else get_process_delta_time()
		_dust = move_toward(_dust, (0.65 + 0.35 * gust) if w == Weather.Kind.DUST_STORM else (0.15 if w == Weather.Kind.WINDY else 0.0), dt * 0.5)
		_heat = move_toward(_heat, 1.0 if w == Weather.Kind.HEAT_WAVE else 0.0, dt * 0.3)
		_storm = move_toward(_storm, 1.0 if w == Weather.Kind.THUNDERSTORM else (0.5 if Weather.is_rain(w) else 0.0), dt * 0.3)
		_flash = maxf(_flash - dt * 4.0, 0.0)
		var on := _dust > 0.001 or _heat > 0.001 or _storm > 0.001 or _flash > 0.001
		_rect.visible = on
		if on:
			_mat.set_shader_parameter("dust", _dust)
			_mat.set_shader_parameter("heat", _heat)
			_mat.set_shader_parameter("storm", _storm)
			_mat.set_shader_parameter("flash", _flash)
			_mat.set_shader_parameter("wind", across)
