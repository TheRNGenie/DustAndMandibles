class_name SpecialShotFx
extends RefCounted
## Every peer: what the special shots of the newer turrets look like
## (TurretDef.special). Drawn from the replicated aim point when the shot counter
## ticks, like tracers (Turret._draw_shot); the host decides what they do
## (TurretEffects). Steam: a rolling cone of steam puffs. Flood: a gush of water
## arcing to the far lip, then a sheet running down a lane of the wall. Twin: two
## lobbed shells, one iron, one chili red. Bola: spinning weighted ropes.

const STEAM_TINT := Color("#F7F4EE")
const STEAM_SHADE := Color("#A9B6C2")
const WATER := Color("#5FB4D6")
const WATER_DEEP := Color("#3D8DB5")
const FOAM := Color("#EAF6FA")
const ROPE := Color("#C8A060")
const ROPE_DARK := Color("#9A7A44")
const LEATHER := Color("#6B4229")
const BLAST_SHELL := Color("#3A3634")
const FIRE_SHELL := Color("#E3361F")

static var _steam_mat: ShaderMaterial
static var _flame_mat: ShaderMaterial
static var _smoke_mat: ShaderMaterial
static var _sheet_shader: Shader
static var _blob_mesh: ArrayMesh
static var _bola_mesh: ArrayMesh
static var _tangles: Dictionary = {}
## Process materials and puff quads by their settings: every steam or chili shot
## with the same look shares them instead of building new ones (and new
## gradient textures) per shot.
static var _shared: Dictionary = {}


## A new world: drop the last game's materials, so these pick up this world's
## night dimming (VfxPool's puff materials) like every other puff.
static func reset() -> void:
	_steam_mat = null
	_flame_mat = null
	_smoke_mat = null
	_shared.clear()


static func _process_for(key: String, make: Callable) -> ParticleProcessMaterial:
	if not _shared.has(key):
		_shared[key] = make.call()
	return _shared[key]


static func _quad_for(size: Vector2, mat: Material) -> QuadMesh:
	var key := "quad:%s:%d" % [str(size), mat.get_instance_id()]
	if not _shared.has(key):
		var q := QuadMesh.new()
		q.size = size
		q.material = mat
		_shared[key] = q
	return _shared[key]


static func draw(t: Turret, vfx: VfxPool) -> void:
	var from := t.muzzle_position()
	var aim := t.aim_point
	match t.def.special:
		&"steam":
			steam_cone(vfx, from, aim, t.def.range * t.range_multiplier())
		&"flood":
			flood(vfx, from, t.covers, aim, t.def.effect_size * 0.5)
		&"twin":
			# Two tubes side by side: the iron blast tube left, the red fire tube right.
			var side := t._muzzle.global_basis.x.normalized() * 0.26
			vfx.lob(from - side, aim, t.def.flight_time, BLAST_SHELL)
			vfx.lob(from + side, SpecialShotRules.twin_fire_point(aim), t.def.flight_time, FIRE_SHELL)
			vfx.muzzle_flash(from - side, -t._muzzle.global_basis.z)
			vfx.muzzle_flash(from + side, -t._muzzle.global_basis.z)
			var fire_at := SpecialShotRules.twin_fire_point(aim)
			vfx.get_tree().create_timer(t.def.flight_time).timeout.connect(func() -> void:
				if is_instance_valid(vfx):
					chili_flames(vfx, fire_at, t.def.effect_size, SpecialShotRules.TWIN_FIRE_TIME))
		&"bola":
			var right := t._muzzle.global_basis.x.normalized()
			bola_throw(vfx, from, aim, t.def.flight_time)
			bola_throw(vfx, from, aim + right * randf_range(-2.5, 2.5) + Vector3.UP * randf_range(-1.5, 1.5), t.def.flight_time * 1.1)


# ------------------------------------------------------------------ steam

## A cone of scalding steam from the nozzle to the wall, rolling off where it hits.
static func steam_cone(vfx: VfxPool, from: Vector3, to: Vector3, reach: float) -> void:
	var dir := to - from
	var dist := clampf(dir.length(), 4.0, reach + 4.0)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	if _steam_mat == null or not is_instance_valid(_steam_mat):
		_steam_mat = vfx.puff_material(STEAM_TINT, STEAM_SHADE)
	var life := 0.85
	# The jet: puffs spread from the nozzle to the wall, swelling as they go.
	var jet := _puffs(vfx, 44, life, 0.5, Vector2(dist * 0.3 / life, dist * 1.02 / life), SpecialShotRules.STEAM_HALF_ANGLE_DEG * 0.85, 1.2, 3.4, 1.1)
	_place(jet, from, dir)
	# A thick white plume right at the nozzle.
	var plume := _puffs(vfx, 10, 0.5, 0.9, Vector2(3.0, 9.0), 18.0, 2.0, 2.4, 0.8)
	_place(plume, from, dir)
	# Steam billowing back off the rock where the cone lands.
	var hit_at := from + dir * dist
	vfx.get_tree().create_timer(life * 0.55).timeout.connect(func() -> void:
		if is_instance_valid(vfx):
			var roll := _puffs(vfx, 16, 1.4, 0.8, Vector2(1.0, 4.0), 75.0, 2.5, 2.6, 2.2)
			_place(roll, hit_at, -dir))


## A one-shot puff emitter (freed when done) with the shared steam material.
static func _puffs(vfx: VfxPool, amount: int, life: float, burst: float, speed: Vector2, spread: float,
		rise: float, grow: float, size: float) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.amount = amount
	e.lifetime = life
	e.explosiveness = burst
	e.local_coords = false
	e.process_material = _process_for("puffs:%s:%.2f:%.2f:%.2f" % [str(speed), spread, rise, grow], func() -> ParticleProcessMaterial:
		var pm := VfxPool.puff_process(speed, spread, rise, grow)
		pm.damping_min = 0.0
		pm.damping_max = 0.4
		return pm)
	e.draw_pass_1 = _quad_for(Vector2(size, size), _steam_mat)
	e.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	vfx.add_child(e)
	vfx.get_tree().create_timer(life + 0.4).timeout.connect(e.queue_free)
	return e


## Points an emitter's spray (local -Z) along `dir` at `pos` and fires it.
static func _place(e: GPUParticles3D, pos: Vector3, dir: Vector3) -> void:
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	e.global_transform = Transform3D(Basis.looking_at(dir, up), pos)
	e.restart()
	e.emitting = true


## The Twin Mortar's fire shell: a patch of chili flames licking up the wall for
## `seconds`, under a rising smudge of smoke.
static func chili_flames(vfx: VfxPool, at: Vector3, radius: float, seconds: float) -> void:
	if _flame_mat == null or not is_instance_valid(_flame_mat):
		_flame_mat = vfx.puff_material(Color("#FFC23A"), Color("#E0482C"))
		_smoke_mat = vfx.puff_material(Color("#6A5A54"), Color("#3E3432"))
	var ratio: float = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	for k in 2:
		var e := GPUParticles3D.new()
		e.amount = 34 if k == 0 else 10
		e.lifetime = 0.7 if k == 0 else 1.8
		e.local_coords = false
		var layer := k
		e.process_material = _process_for("flames:%d:%.2f" % [k, radius], func() -> ParticleProcessMaterial:
			var pm := VfxPool.puff_process(Vector2(1.0, 2.5) if layer == 0 else Vector2(1.0, 2.0), 25.0, 5.0 if layer == 0 else 2.0, 1.6 if layer == 0 else 3.0)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = radius * (0.8 if layer == 0 else 0.6)
			return pm)
		e.draw_pass_1 = _quad_for(Vector2.ONE * (1.5 if k == 0 else 1.8), _flame_mat if k == 0 else _smoke_mat)
		e.amount_ratio = ratio
		vfx.add_child(e)
		e.global_transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.FORWARD), at + Vector3.UP * (0.0 if k == 0 else 1.2))
		e.emitting = true
		vfx.get_tree().create_timer(seconds).timeout.connect(func() -> void:
			if is_instance_valid(e):
				e.emitting = false
				vfx.get_tree().create_timer(2.0).timeout.connect(e.queue_free))


# ------------------------------------------------------------------ flood

## The flood: a gush arcing from the chute to the far lip, then a sheet of water
## running down a band `half` metres either side of the aim point's lane.
static func flood(vfx: VfxPool, from: Vector3, cliff: int, aim: Vector3, half: float) -> void:
	var cl := Bug.cliffs
	if cl == null or cliff < 0:
		return
	var z := lane_z_at(cl, cliff, aim)
	var top := WorldLayout.CLIFF_HEIGHT - 0.8
	var lip := cl.face_point(cliff, top, z) + cl.face_normal(cliff, top, z) * 0.6
	var arrive := SpecialShotRules.FLOOD_ARRIVE
	if _blob_mesh == null:
		var st := MeshKit.begin()
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 4, 9, WATER.lightened(0.15), 0.0, null, 0.25)
		_blob_mesh = MeshKit.finish(st)
	# The gush: a rope of water blobs, fat in the middle, fanning across the band.
	var mat := Materials.toon(0.0)
	for i in 22:
		var k := float(i) / 21.0
		var land := lip + cl.face_point(cliff, top, z + (k - 0.5) * half * 1.4) - cl.face_point(cliff, top, z)
		var mi := MeshInstance3D.new()
		mi.mesh = _blob_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * lerpf(0.35, 0.8, sin(k * PI))
		vfx.add_child(mi)
		mi.global_position = from
		var peak := (from + land) * 0.5 + Vector3.UP * (2.5 + from.distance_to(land) * 0.05)
		var tw := mi.create_tween()
		tw.tween_interval(absf(k - 0.5) * 0.12)
		tw.tween_method(func(u: float) -> void:
			mi.global_position = from.lerp(peak, u).lerp(peak.lerp(land, u), u)
			mi.scale = Vector3.ONE * lerpf(0.35, 1.1, u) * lerpf(0.5, 1.0, sin(k * PI)), 0.0, 1.0, arrive)
		tw.tween_callback(mi.queue_free)
	vfx.get_tree().create_timer(arrive).timeout.connect(func() -> void:
		if not is_instance_valid(vfx):
			return
		_sheet(vfx, cl, cliff, z, half, top)
		var n := cl.face_normal(cliff, top, z)
		var splash := _puffs(vfx, 18, 1.1, 0.9, Vector2(2.0, 6.0), 60.0, -2.0, 2.2, 1.6)
		_place(splash, lip, n + Vector3.UP * 0.6)
		Audio.play_at(&"water_blast", lip))


## The water sheet down the wall: the front runs down at FLOOD_SPEED, then it thins out.
static func _sheet(vfx: VfxPool, cl: CliffBuilder, cliff: int, z: float, half: float, top: float) -> void:
	var rows := 30
	var cols := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for r in rows + 1:
		var y := lerpf(top, 0.3, float(r) / rows)
		var row: Array = []
		for c in cols + 1:
			var zz := z - half + 2.0 * half * float(c) / cols
			row.append(cl.face_point(cliff, y, zz) + cl.face_normal(cliff, y, zz) * 0.45)
		pts.append(row)
	for r in rows:
		for c in cols:
			var quad := [Vector2i(c, r), Vector2i(c + 1, r), Vector2i(c + 1, r + 1), Vector2i(c, r), Vector2i(c + 1, r + 1), Vector2i(c, r + 1)]
			for q: Vector2i in quad:
				st.set_uv(Vector2(float(q.x) / cols, float(q.y) / rows))
				st.add_vertex(pts[q.y][q.x])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _sheet_shader_get()
	m.set_shader_parameter("water", WATER)
	m.set_shader_parameter("deep", WATER_DEEP)
	m.set_shader_parameter("foam", FOAM)
	mi.material_override = m
	vfx.add_child(mi)
	var run := top / SpecialShotRules.FLOOD_SPEED
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("front", v), 0.0, 1.08, run)
	tw.tween_callback(func() -> void:
		if is_instance_valid(vfx):
			var foot := cl.face_point(cliff, 0.8, z) + cl.face_normal(cliff, 0.8, z) * 1.0
			var foam := _puffs(vfx, 22, 1.6, 0.8, Vector2(1.5, 5.0), 80.0, 0.5, 2.6, 2.0)
			_place(foam, foot, Vector3.UP + cl.face_normal(cliff, 0.8, z)))
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.9)
	tw.tween_callback(mi.queue_free)


static func _sheet_shader_get() -> Shader:
	if _sheet_shader == null:
		_sheet_shader = Shader.new()
		_sheet_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float front = 0.0;
uniform float fade = 1.0;
uniform vec4 water : source_color = vec4(0.37, 0.7, 0.84, 1.0);
uniform vec4 deep : source_color = vec4(0.24, 0.55, 0.71, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 0.97, 0.98, 1.0);
void fragment() {
	float v = UV.y;
	float head = front - v + 0.012 * sin(UV.x * 31.0 + TIME * 7.0);
	if (head < 0.0) discard;
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float streak = sin(UV.x * 41.0 + sin(UV.x * 13.0) * 2.5) * 0.5 + 0.5;
	float flow = fract(v * 7.0 - TIME * 2.6 + streak * 0.7);
	float bands = step(0.8, flow) * 0.55 + step(0.78, streak) * 0.3;
	float lead = 1.0 - smoothstep(0.0, 0.04, head);
	vec3 col = mix(deep.rgb, water.rgb, streak);
	col = mix(col, foam.rgb, clamp(bands + lead, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = edge * fade * clamp(0.6 + 0.35 * lead + 0.2 * bands, 0.0, 0.95);
}
"""
	return _sheet_shader


## Lane position (along the wall) of a point on or near cliff `cliff`'s face.
static func lane_z_at(cl: CliffBuilder, cliff: int, p: Vector3) -> float:
	var y := clampf(p.y, 0.0, WorldLayout.CLIFF_HEIGHT)
	var best := 0.0
	var best_d := INF
	for i in 47:
		var z := -23.0 + i
		var d := cl.face_point(cliff, y, z).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = z
	var fine := best
	for i in 21:
		var z := best - 1.0 + i * 0.1
		var d := cl.face_point(cliff, y, z).distance_squared_to(p)
		if d < best_d:
			best_d = d
			fine = z
	return fine


# ------------------------------------------------------------------ bolas

## A bola spinning flat through the air from the launcher to `to`.
static func bola_throw(vfx: VfxPool, from: Vector3, to: Vector3, flight: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = bola_mesh()
	mi.material_override = Materials.toon(0.01)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vfx.add_child(mi)
	mi.global_position = from
	var peak := (from + to) * 0.5 + Vector3.UP * (1.5 + from.distance_to(to) * 0.04)
	var axis := (to - from).normalized()
	var flat := Basis.looking_at(axis, Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	var tw := mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		mi.global_position = from.lerp(peak, u).lerp(peak.lerp(to, u), u)
		mi.global_basis = flat * Basis(Vector3.UP, u * 26.0) * Basis().scaled(Vector3.ONE * lerpf(0.6, 1.0, minf(u * 4.0, 1.0))), 0.0, 1.0, maxf(flight, 0.1))
	tw.tween_callback(func() -> void:
		if is_instance_valid(vfx):
			vfx.spark(to, -axis, Palette.BONE)
		mi.queue_free())


## Three leather weights on ropes knotted at the middle (flying bola).
static func bola_mesh() -> ArrayMesh:
	if _bola_mesh != null:
		return _bola_mesh
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.09, 3, 8, ROPE_DARK)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var end := Vector3(cos(a), 0, sin(a)) * 0.85
		var mid := end * 0.5 + Vector3(sin(a) * 0.08, 0.04, -cos(a) * 0.08)
		MeshKit.tube(st, [Vector3.ZERO, mid, end], [0.025, 0.025, 0.025], 5, ROPE)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), end), Vector3(0.2, 0.18, 0.2), 4, 9, LEATHER.lightened(0.05 * i))
		MeshKit.add_cylinder(st, Transform3D(Basis(), end), 0.205, 0.205, 0.05, 9, ROPE_DARK)
	_bola_mesh = MeshKit.finish(st)
	return _bola_mesh


## Bola ropes wound round a bug of body radius `r`, three weights dangling.
static func bola_tangle_mesh(r: float) -> ArrayMesh:
	var key := snappedf(r, 0.05)
	if _tangles.has(key):
		return _tangles[key]
	var st := MeshKit.begin()
	var rr := key * 1.12
	var thick := clampf(key * 0.06, 0.03, 0.12)
	for k in 3:
		var tilt := Basis(Vector3.RIGHT, 0.5 + k * 0.6) * Basis(Vector3.FORWARD, k * 1.1)
		var pts: Array = []
		var radii: Array = []
		for j in 17:
			var a := TAU * float(j) / 16.0
			pts.append(tilt * Vector3(cos(a) * rr, 0, sin(a) * rr * 0.9))
			radii.append(thick)
		MeshKit.tube(st, pts, radii, 5, ROPE if k != 1 else ROPE_DARK)
		var knot := tilt * Vector3(rr, 0, 0)
		var weight := knot + Vector3(0, -rr * 0.55, 0) + tilt * Vector3(0.15, 0, 0) * key
		MeshKit.tube(st, [knot, (knot + weight) * 0.5 + Vector3(0.05, 0, 0) * key, weight], [thick * 0.8, thick * 0.8, thick * 0.8], 5, ROPE)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), weight), Vector3.ONE * clampf(key * 0.22, 0.1, 0.45), 4, 9, LEATHER)
	_tangles[key] = MeshKit.finish(st)
	return _tangles[key]
