extends Node3D
## A living canyon, all cosmetic and local to each peer: tumbleweeds bouncing
## along the floor and the back of the plateaus with the wind, vultures
## circling high overhead, the odd dust devil wandering about, and a flock of
## birds that bursts off the cliff tops when a wave starts. Everything is a
## handful of nodes (the birds are one MultiMesh), so it costs next to nothing.

const TUMBLEWEEDS_FLOOR := 5
const TUMBLEWEEDS_PLATEAU := 2 # per cliff
const VULTURES := 4
const BIRDS := 22
const DEVIL_EVERY := Vector2(22.0, 45.0)
const DEVIL_LIFE := 14.0

var vfx: Node3D
var cliffs: CliffBuilder
var _rng := RandomNumberGenerator.new()
## {node, mi, where (-1 floor / cliff id), x_or_d, z, speed, spin, hop}
var _weeds: Array[Dictionary] = []
## {node, wings [l, r], radius, height, angle, speed, center, flap_t}
var _vultures: Array[Dictionary] = []
var _devil: GPUParticles3D
var _devil_t := 0.0
var _devil_next := 12.0
var _devil_pos := Vector3.ZERO
var _devil_vel := Vector3.ZERO
var _devil_cliff := -1
var _birds: MultiMeshInstance3D
var _bird_pos: PackedVector3Array = PackedVector3Array()
var _bird_vel: PackedVector3Array = PackedVector3Array()
var _bird_phase: PackedFloat32Array = PackedFloat32Array()
var _birds_t := -1.0


func _ready() -> void:
	_rng.seed = 2024
	# The canyon is built before us but Bug.cliffs is set just after; wait a frame.
	await get_tree().process_frame
	cliffs = Bug.cliffs
	if cliffs == null:
		return
	if GameState.has_flag("--nolife"):
		return
	_make_weeds()
	_make_vultures()
	_make_devil()
	_make_birds()
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		if p == GameState.Phase.WAVE:
			scatter_birds())


func _process(delta: float) -> void:
	if cliffs == null:
		return
	_update_weeds(delta)
	_update_vultures(delta)
	_update_devil(delta)
	_update_birds(delta)


static func _wind() -> float:
	var w := GameState.weather
	var strong := w == Weather.Kind.WINDY or w == Weather.Kind.DUST_STORM or w == Weather.Kind.THUNDERSTORM
	return WeatherFx.wind_sign() * (2.4 if strong else 1.0)


# ------------------------------------------------------------------ tumbleweeds

func _make_weeds() -> void:
	var mesh := _tumbleweed_mesh()
	var mat := Materials.toon(0.01)
	var total := TUMBLEWEEDS_FLOOR + TUMBLEWEEDS_PLATEAU * 2
	for i in total:
		var where := -1 if i < TUMBLEWEEDS_FLOOR else (i - TUMBLEWEEDS_FLOOR) % 2
		var root := Node3D.new()
		add_child(root)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		root.add_child(mi)
		var size := _rng.randf_range(0.7, 1.25)
		root.scale = Vector3.ONE * size
		var w := {"node": root, "mi": mi, "where": where, "size": size,
			"a": _rng.randf_range(-13.0, 13.0) if where < 0 else _rng.randf_range(34.0, 42.0),
			"z": _rng.randf_range(-85.0, 85.0) if where < 0 else _rng.randf_range(-30.0, 30.0),
			"speed": _rng.randf_range(2.0, 4.0), "hop": _rng.randf() * TAU, "drift": _rng.randf_range(-0.3, 0.3)}
		_weeds.append(w)


func _tumbleweed_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var st := MeshKit.begin()
	var cols := [Color("#B88C52"), Color("#9C7444"), Color("#C9A266")]
	# A tangle of twiggy arcs round a ball about 0.55 m across.
	for k in 34:
		var a := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.5
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.5
		var mid := (a + b) * 0.5
		mid = mid.normalized() * 0.55 if mid.length() > 0.05 else a.cross(Vector3.UP).normalized() * 0.55
		MeshKit.add_limb(st, a, mid, 0.022, cols[k % 3], 4)
		MeshKit.add_limb(st, mid, b, 0.022, cols[(k + 1) % 3], 4)
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.22, 3, 6, Color("#8A6238"), 0.3, rng)
	return MeshKit.finish(st)


func _update_weeds(delta: float) -> void:
	var wind := _wind()
	for w in _weeds:
		var speed := float(w["speed"]) * absf(wind)
		var z := float(w["z"]) + speed * signf(wind) * delta
		var a := float(w["a"]) + float(w["drift"]) * delta
		var where := int(w["where"])
		var lim := 88.0 if where < 0 else 32.0
		var fade := 1.0
		if absf(z) > lim:
			# Off the end: come back in at the other end.
			z = -signf(z) * lim
			w["speed"] = _rng.randf_range(2.0, 4.0)
		fade = clampf((lim - absf(z)) / 4.0, 0.0, 1.0)
		if where < 0:
			a = clampf(a, -14.0, 14.0)
		else:
			a = clampf(a, 33.0, 43.0)
		w["z"] = z
		w["a"] = a
		var ground: Vector3
		if where < 0:
			ground = cliffs.warp(Vector3(a, 0, z))
			ground.y = cliffs.floor_height(ground.x, z)
		else:
			ground = cliffs.plateau_point(where, a, z)
		var size := float(w["size"])
		w["hop"] = float(w["hop"]) + delta * (2.0 + speed * 0.9)
		var hop := absf(sin(float(w["hop"]))) * (0.25 + speed * 0.12)
		var root := w["node"] as Node3D
		root.position = ground + Vector3.UP * (0.5 * size + hop)
		root.scale = Vector3.ONE * size * maxf(fade, 0.01)
		# Roll about the axis across the wind.
		var mi := w["mi"] as MeshInstance3D
		mi.rotate(Vector3.RIGHT, -signf(wind) * speed * delta / (0.5 * size))


# ------------------------------------------------------------------ vultures

func _make_vultures() -> void:
	var body_mesh := _vulture_body()
	var wing_mesh := _vulture_wing()
	var mat := Materials.toon(0.02)
	for i in VULTURES:
		var root := Node3D.new()
		add_child(root)
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)
		var wings: Array[Node3D] = []
		for s: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(s * 0.25, 0.1, 0)
			root.add_child(pivot)
			var wmi := MeshInstance3D.new()
			wmi.mesh = wing_mesh
			wmi.material_override = mat
			wmi.scale = Vector3(s, 1, 1)
			wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(wmi)
			wings.append(pivot)
		root.scale = Vector3.ONE * 1.6
		_vultures.append({"node": root, "wings": wings, "radius": _rng.randf_range(22.0, 48.0),
			"height": _rng.randf_range(95.0, 125.0), "angle": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.12, 0.2) * (1.0 if i % 2 == 0 else -1.0),
			"center": Vector3(_rng.randf_range(-15.0, 15.0), 0, _rng.randf_range(-30.0, 30.0)),
			"flap": _rng.randf_range(2.0, 8.0), "flap_t": 0.0})


func _vulture_body() -> ArrayMesh:
	var st := MeshKit.begin()
	var dark := Color("#2E2224")
	# Body along -Z (forward), a ruff, a bald pink head and a hooked beak.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.28, 0.24, 0.62), 4, 8, dark)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.06, -0.5)), Vector3(0.2, 0.18, 0.16), 3, 7, Color("#E8DCCB"))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.72)), Vector3(0.11, 0.11, 0.14), 3, 7, Color("#D47A70"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1, -0.88)), 0.05, 0.0, 0.14, 5, Color("#E8D6A0"))
	# Fanned tail.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0.7)), Vector3(0.42, 0.04, 0.36), dark.darkened(0.2))
	return MeshKit.finish(st)


func _vulture_wing() -> ArrayMesh:
	var st := MeshKit.begin()
	var dark := Color("#33262A")
	# Broad wing out along +X with fingered primaries at the tip.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.75, 0, 0.05)), Vector3(1.5, 0.05, 0.62), dark)
	for k in 5:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -0.25 + k * 0.12), Vector3(1.65, 0, -0.18 + k * 0.1)), Vector3(0.55, 0.035, 0.1), dark.darkened(0.25))
	return MeshKit.finish(st)


func _update_vultures(delta: float) -> void:
	for v in _vultures:
		var ang := float(v["angle"]) + float(v["speed"]) * delta
		v["angle"] = ang
		var r := float(v["radius"])
		var c: Vector3 = v["center"]
		var h := float(v["height"]) + sin(ang * 2.0) * 3.0
		var pos := c + Vector3(cos(ang) * r, h, sin(ang) * r)
		var sgn := signf(float(v["speed"]))
		var fwd := Vector3(-sin(ang), 0, cos(ang)) * sgn
		var root := v["node"] as Node3D
		# Banked into the turn.
		var b := Basis.looking_at(fwd, Vector3.UP)
		b = b * Basis(Vector3.BACK, 0.35 * sgn)
		root.global_transform = Transform3D(b.scaled(Vector3.ONE * 1.6), pos)
		# Mostly gliding, now and then a few slow, heavy flaps.
		v["flap_t"] = float(v["flap_t"]) + delta
		var flap := 0.0
		var ft := float(v["flap_t"])
		if ft > float(v["flap"]):
			flap = sin((ft - float(v["flap"])) * 5.0) * 0.55
			if ft - float(v["flap"]) > TAU / 5.0 * 3.0:
				v["flap_t"] = 0.0
				v["flap"] = _rng.randf_range(4.0, 10.0)
		var wings: Array = v["wings"]
		(wings[0] as Node3D).rotation.z = -(0.12 + flap)
		(wings[1] as Node3D).rotation.z = 0.12 + flap


# ------------------------------------------------------------------ dust devil

func _make_devil() -> void:
	_devil = GPUParticles3D.new()
	_devil.amount = 70
	_devil.lifetime = 2.4
	_devil.local_coords = true
	_devil.emitting = false
	_devil.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 16, 12))
	var pm: ParticleProcessMaterial = vfx.call("puff_process", Vector2(3.2, 5.0), 6.0, 0.0, 2.6)
	pm.direction = Vector3(0, 1, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.9
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.3
	pm.radial_accel_min = 0.6
	pm.radial_accel_max = 1.2
	pm.damping_min = 0.0
	pm.damping_max = 0.3
	_devil.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = vfx.call("puff_material", Color("#E2B983"), Color("#AE7D60"))
	_devil.draw_pass_1 = quad
	_devil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_devil)


func _update_devil(delta: float) -> void:
	if _devil_t > 0.0:
		_devil_t -= delta
		# Spinning the emitter (local coords) twists the column into a funnel.
		_devil.rotate_y(delta * 7.0)
		_devil_pos += _devil_vel * delta
		_devil_vel = _devil_vel.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.0011) * delta * 0.8)
		var g := _devil_pos
		if _devil_cliff < 0:
			g.y = cliffs.floor_height(g.x, g.z)
		else:
			g.y = cliffs.ground_height_at(_devil_cliff, g)
		_devil.global_position = g
		_devil.amount_ratio = clampf(minf(DEVIL_LIFE - _devil_t, _devil_t) / 2.0, 0.05, 1.0)
		if _devil_t <= 0.0:
			_devil.emitting = false
		return
	_devil_next -= delta
	if _devil_next > 0.0 or GameState.weather == Weather.Kind.LIGHT_RAIN or GameState.weather == Weather.Kind.SNOW \
			or GameState.weather == Weather.Kind.THUNDERSTORM:
		return
	_devil_next = _rng.randf_range(DEVIL_EVERY.x, DEVIL_EVERY.y)
	_devil_t = DEVIL_LIFE
	# Out on the canyon floor most of the time, sometimes across a plateau's back.
	_devil_cliff = -1 if _rng.randf() < 0.6 else _rng.randi() % 2
	var z := _rng.randf_range(-50.0, 50.0)
	if _devil_cliff < 0:
		_devil_pos = cliffs.warp(Vector3(_rng.randf_range(-8.0, 8.0), 0, z))
	else:
		_devil_pos = cliffs.plateau_point(_devil_cliff, _rng.randf_range(20.0, 34.0), clampf(z, -22.0, 22.0))
	_devil_vel = Vector3(0, 0, _wind() * _rng.randf_range(1.5, 2.6))
	_devil.emitting = true


# ------------------------------------------------------------------ birds

func _make_birds() -> void:
	var st := MeshKit.begin()
	var col := Color("#2A2026")
	# A little gull-wing "V": body plus two swept wings. Flapping squashes it in Y.
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.06, 0.06, 0.16), 2, 5, col)
	for s: float in [-1.0, 1.0]:
		MeshKit.tri(st, Vector3(0, 0, -0.05), Vector3(s * 0.38, 0.12, 0.02), Vector3(0, 0, 0.08),
				Vector3.UP, Vector3.UP, Vector3.UP, MeshKit.vcol(col), Vector3.UP)
		MeshKit.tri(st, Vector3(0, 0, -0.05), Vector3(s * 0.38, 0.12, 0.02), Vector3(0, 0, 0.08),
				Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, MeshKit.vcol(col), Vector3.DOWN)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshKit.finish(st)
	mm.instance_count = BIRDS
	mm.visible_instance_count = 0
	_birds = MultiMeshInstance3D.new()
	_birds.multimesh = mm
	_birds.material_override = Materials.toon(0.0)
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_birds)
	_bird_pos.resize(BIRDS)
	_bird_vel.resize(BIRDS)
	_bird_phase.resize(BIRDS)


## A wave starts: birds roosting along both cliff lips burst up and fly off.
func scatter_birds() -> void:
	if _birds == null:
		return
	for i in BIRDS:
		var cid := i % 2
		var z := _rng.randf_range(-35.0, 35.0)
		var p := cliffs.plateau_point(cid, _rng.randf_range(0.5, 3.0), z) + Vector3.UP * 0.2
		_bird_pos[i] = p
		var away := Vector3(WorldLayout.side_sign(cid) * _rng.randf_range(0.3, 1.0), _rng.randf_range(1.2, 2.0), _rng.randf_range(-1.0, 1.0))
		_bird_vel[i] = away.normalized() * _rng.randf_range(5.0, 8.0)
		_bird_phase[i] = _rng.randf() * TAU
	_birds_t = 9.0
	_birds.multimesh.visible_instance_count = BIRDS
	_birds.global_transform = Transform3D()
	Audio.play_at(&"rustle", cliffs.plateau_point(0, 1.0, 0.0), 2.0)
	Audio.play_at(&"rustle", cliffs.plateau_point(1, 1.0, 0.0), 2.0)


func _update_birds(delta: float) -> void:
	if _birds_t <= 0.0:
		return
	_birds_t -= delta
	var mm := _birds.multimesh
	if _birds_t <= 0.0:
		mm.visible_instance_count = 0
		return
	for i in BIRDS:
		var v := _bird_vel[i]
		# Climb steeply at first, then level off and speed away.
		v += Vector3(v.x, 0, v.z).normalized() * 3.0 * delta + Vector3.UP * (2.0 - v.y * 0.4) * delta
		_bird_vel[i] = v
		_bird_pos[i] += v * delta
		_bird_phase[i] += delta * 18.0
		var flap := 0.25 + absf(sin(_bird_phase[i])) * 1.1
		var b := Basis.looking_at(v.normalized(), Vector3.UP).scaled(Vector3(1.6, flap * 1.6, 1.6))
		mm.set_instance_transform(i, Transform3D(b, _bird_pos[i]))
