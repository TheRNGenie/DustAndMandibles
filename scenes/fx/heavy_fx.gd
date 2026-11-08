class_name HeavyFx
extends RefCounted
## Every peer: the universal heavies' visuals (HeavyRules), all in the loaded
## crop's colour. The host sends them through PlayerNet.heavy_fx (kind, a, b, x,
## y, n); x usually packs the crop and a number (HeavyRules.pack):
##   lob        shell / grenade / keg in flight: a start, b where it lands, x crop + flight*100, y arc (1 mortar, 0 drum, 2 keg)
##   spike      railroad spike in flight: a start, b end, x crop + flight*100, y seconds it stays stuck (0 none), n surface normal
##   crossbow   bolt in flight: same as spike
##   bola       spinning bola in flight: a start, b end, x crop + flight*100
##   blast      a blast: a centre, b surface normal, x crop + radius*10
##   wave       Spike Driver shockwave across the rock: a centre, b normal, x crop + radius*10, y share (a fainter second pulse)
##   ricochet   corn's bounce: a from, b to, x crop
##   spray      one pump of the sprayer: a nozzle, b direction, x crop + cone deg, y reach
##   wrap       a bola wrapped round a bug: a its middle, x crop + hold*100, y body radius
##   clip       the bola's weights clipping a bug beside it: a from, b to, x crop
##   bola_drop  a bola that found nobody: a where it fell
##   stick      a bolt left stuck in a bug: a where, b direction, x crop, y seconds
##   keg        a keg stuck where it landed: a position, b normal, x crop + keg tag, y fuse lit (>= 0) or waiting (-1)
##   keg_gone   a keg goes: x crop + keg tag, y 1 if it went off (the blast comes separately)
##   load       a sack loaded into a rider's heavy: a the rider, x new crop, y old crop's index + 1 (0 none)
## Nodes go under the current scene and free themselves.

const IRON := Color("#3A3634")
const WOOD := Color("#7A5232")
const KEG_WOOD := Color("#8A5A30")
const SMOKE := Color("#8C8680")
## Kegs on show: tag -> Node3D.
static var _kegs: Dictionary = {}
static var _mats: Dictionary = {}
static var _spray_pool: Array = []
static var _spray_i := 0


static func play(kind: StringName, a: Vector3, b: Vector3, x: float, y: float, n: Vector3) -> void:
	var crop := HeavyRules.unpack_crop(x)
	var col := HeavyRules.color_of(crop)
	var num := HeavyRules.unpack_n(x)
	match kind:
		&"lob":
			_lob(a, b, num / 100.0, col, int(y))
		&"spike":
			_flyer(a, b, num / 100.0, col, y, n, "spike")
		&"crossbow":
			_flyer(a, b, num / 100.0, col, y, n, "bolt")
		&"bola":
			_flyer(a, b, num / 100.0, col, 0.0, n, "bola")
		&"blast":
			blast(a, num / 10.0, col, crop)
		&"wave":
			_wave(a, b, num / 10.0, col, y)
		&"ricochet":
			var v := _vfx()
			if v != null:
				v.bullet_streak(a, b, col.lightened(0.3), 0.05, 260.0)
				v.spark(b, Vector3.UP, col)
		&"spray":
			_spray(a, b, num, y, col)
		&"wrap":
			_wrap(a, num / 100.0, y, col)
		&"clip":
			var v := _vfx()
			if v != null:
				v.bullet_streak(a, b, col, 0.035, 90.0)
				v.spark(b, Vector3.UP, col)
			Audio.play_at(&"hammer_hit", b, -10.0, 1.3)
		&"bola_drop":
			var v := _vfx()
			if v != null:
				v.dust_burst(a, Vector3.UP, 0.4)
		&"stick":
			_stuck(a, b, col, y, "bolt")
		&"keg":
			_keg(int(num), a, b, col, y)
		&"keg_gone":
			var k: Variant = _kegs.get(int(num))
			_kegs.erase(int(num))
			if k is Node3D and is_instance_valid(k):
				(k as Node3D).queue_free()
		&"load":
			_load(a, col, int(y))


## The host helper under the current scene (made the first time it's needed).
static func host(net: Node) -> Node:
	if net == null or not net.is_inside_tree():
		return null
	var scene := net.get_tree().current_scene
	if scene == null:
		return null
	var h := scene.get_node_or_null(HeavyRules.HOST_NAME)
	if h != null and not h.is_queued_for_deletion():
		return h
	var script := load(HeavyRules.HOST_PATH) as GDScript
	if script == null:
		return null
	h = script.new() as Node
	h.name = HeavyRules.HOST_NAME
	scene.add_child(h)
	return h


## A hitscan heavy's tracers (Hand Cannon, Harvest Gatling, Crop Blunderbuss), in the crop's colour.
static func traces(id: StringName, start: Vector3, ends: Array, crop: StringName) -> void:
	var v := _vfx()
	if v == null:
		return
	var col := HeavyRules.color_of(crop)
	var width: float = {&"hand_cannon": 0.11, &"harvest_gatling": 0.04, &"crop_blunderbuss": 0.03}.get(id, 0.04)
	var speed: float = {&"hand_cannon": 420.0, &"harvest_gatling": 320.0, &"crop_blunderbuss": 180.0}.get(id, 300.0)
	for e: Vector3 in ends:
		v.bullet_streak(start, e, col, width, speed)
	if not ends.is_empty():
		v.spark(ends[0], Vector3.UP, col)


static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null


static func _vfx() -> VfxPool:
	var v := VfxPool.instance
	return v if v != null and is_instance_valid(v) else null


static func _mat(color: Color, unshaded: bool = false, alpha: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), unshaded, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## A glowing (emissive) material in the crop's colour.
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _ring(r: float, thick: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = maxf(r - thick, 0.01)
	t.outer_radius = r
	t.rings = 32
	t.ring_segments = 6
	return t


## A thin trail of the crop's colour behind a flying body.
static func _trail(node: Node3D, col: Color, amount: int) -> void:
	var e := GPUParticles3D.new()
	e.amount = amount
	e.lifetime = 0.6
	e.local_coords = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.4, 0)
	var curve := Curve.new()
	curve.max_value = 3.0
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 2.4))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, col.lightened(0.4))
	grad.set_color(1, Color(SMOKE, 0.0))
	grad.add_point(0.25, Color(col, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	quad.material = Materials.star(Color.WHITE, 1.4)
	e.draw_pass_1 = quad
	e.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	node.add_child(e)
	e.emitting = true


## The body lands: its trail lingers a moment, then it goes.
static func _end(node: Node3D) -> void:
	for c in node.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).emitting = false
		elif c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	node.get_tree().create_timer(0.7).timeout.connect(node.queue_free)


# ------------------------------------------------------------------ lobs

static func _lob(from: Vector3, to: Vector3, flight: float, col: Color, arc: int) -> void:
	var root := _root()
	if root == null:
		return
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = from
	var spin := Node3D.new()
	body.add_child(spin)
	match arc:
		1: # mortar shell: an iron ball banded in the crop's colour
			_mesh(spin, _sphere(0.2), _mat(IRON))
			_mesh(spin, _ring(0.205, 0.05), glow(col, 1.6))
		2: # powder keg: a little barrel tumbling end over end
			var keg := CylinderMesh.new()
			keg.top_radius = 0.16
			keg.bottom_radius = 0.16
			keg.height = 0.36
			keg.radial_segments = 10
			_mesh(spin, keg, _mat(KEG_WOOD))
			for yy: float in [-0.12, 0.12]:
				_mesh(spin, _ring(0.168, 0.03), _mat(IRON), Vector3(0, yy, 0))
			_mesh(spin, _sphere(0.05), glow(col, 3.0), Vector3(0, 0.2, 0))
		_: # drum grenade: a small glowing sphere
			_mesh(spin, _sphere(0.11), glow(col, 1.8))
	_trail(body, col, 18 if arc != 0 else 12)
	var high := arc == 1
	var tw := body.create_tween()
	tw.tween_method(func(t: float) -> void:
		body.global_position = HeavyRules.lob_at(from, to, t, high)
		spin.rotation = Vector3(t * 14.0, t * 5.0, 0.0), 0.0, 1.0, maxf(flight, 0.05))
	tw.tween_callback(func() -> void: _end(body))


# ------------------------------------------------------------------ spikes, bolts, bolas

static func _flyer(from: Vector3, to: Vector3, flight: float, col: Color, stuck: float, n: Vector3, what: String) -> void:
	var root := _root()
	if root == null or from.distance_to(to) < 0.2:
		return
	var body := Node3D.new()
	root.add_child(body)
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	body.global_transform = Transform3D(Basis.looking_at(dir, up), from)
	var spin := Node3D.new()
	body.add_child(spin)
	_build(spin, what, col)
	_trail(body, col, 22 if what == "spike" else 12)
	var tw := body.create_tween()
	tw.tween_property(body, "global_position", to, maxf(flight, 0.03))
	if what == "bola":
		var st := spin.create_tween().set_loops(int(ceilf(flight / 0.2)) + 1)
		st.tween_property(spin, "rotation:z", TAU, 0.2).from(0.0)
	tw.tween_callback(func() -> void:
		if what == "spike":
			Audio.play_at(&"hammer_hit", to, 2.0, 0.6)
		elif what == "bolt":
			Audio.play_at(&"harpoon", to, -4.0, 1.2)
		var v := _vfx()
		if v != null:
			v.spark(to, n if n.length() > 0.1 else -dir, col)
			if what == "spike":
				v.dust_burst(to, n if n.length() > 0.1 else -dir, 0.8)
		if stuck > 0.0:
			_stuck(to, dir, col, stuck, what)
		_end(body))


## The flying piece's meshes (its tip at the node, the rest trailing behind along +Z).
static func _build(parent: Node3D, what: String, col: Color) -> void:
	match what:
		"spike":
			_mesh(parent, _box(Vector3(0.09, 0.09, 0.9)), _mat(IRON), Vector3(0, 0, 0.45))
			_mesh(parent, _box(Vector3(0.2, 0.07, 0.1)), _mat(IRON.lightened(0.15)), Vector3(0, 0, 0.88))
			_mesh(parent, _box(Vector3(0.1, 0.1, 0.18)), glow(col, 2.5), Vector3(0, 0, 0.05))
		"bolt":
			_mesh(parent, _box(Vector3(0.035, 0.035, 0.75)), _mat(WOOD), Vector3(0, 0, 0.37))
			_mesh(parent, _box(Vector3(0.06, 0.06, 0.12)), glow(col, 2.5), Vector3(0, 0, 0.04))
			for s: float in [-1.0, 1.0]:
				_mesh(parent, _box(Vector3(0.1, 0.005, 0.12)), _mat(col.lightened(0.2)), Vector3(0, 0, 0.68)).rotation.z = s * 0.8
		"bola":
			for i in 3:
				var a := TAU * i / 3.0
				var p := Vector3(cos(a), sin(a), 0) * 0.32
				_mesh(parent, _sphere(0.07), _mat(IRON), p)
				var cord := _mesh(parent, _box(Vector3(0.018, 0.32, 0.018)), glow(col, 1.6), p * 0.5)
				cord.rotation.z = a + PI * 0.5


## A spike or bolt left stuck in the rock: glows, then crumbles away.
static func _stuck(at: Vector3, dir: Vector3, col: Color, seconds: float, what: String) -> void:
	var root := _root()
	if root == null:
		return
	var body := Node3D.new()
	root.add_child(body)
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	body.global_transform = Transform3D(Basis.looking_at(dir, up), at - dir * (0.25 if what == "spike" else 0.08))
	_build(body, "spike" if what == "spike" else "bolt", col)
	var tw := body.create_tween()
	tw.tween_interval(maxf(seconds - 0.3, 0.05))
	tw.tween_property(body, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(func() -> void:
		var v := _vfx()
		if v != null:
			v.pop(at, col.darkened(0.3), 0.25)
		body.queue_free())


# ------------------------------------------------------------------ blasts and waves

## A crop blast: a flash ring, a fireball in the crop's colour, debris, the bang.
## Cotton, herbs and sulfur leave a little cloud for half a second.
static func blast(center: Vector3, radius: float, col: Color, crop: StringName) -> void:
	Audio.play_at(&"dynamite", center, -4.0 if radius < 3.0 else 0.0, 1.25 if radius < 3.0 else 1.0)
	var v := _vfx()
	if v != null:
		v.pop(center, col, radius * 0.8)
		v.pop(center, Palette.ROCK_C, radius * 0.4)
		v.dust_burst(center, Vector3.UP, radius * 0.35)
	var root := _root()
	if root == null:
		return
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 5.0
	light.omni_range = radius * 3.0
	root.add_child(light)
	light.global_position = center + Vector3.UP
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.35)
	lt.tween_callback(light.queue_free)
	var ball := MeshInstance3D.new()
	ball.mesh = _sphere(1.0)
	var m := _mat(col, true, true).duplicate() as StandardMaterial3D
	m.albedo_color = Color(col, 0.65)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	ball.global_position = center
	ball.scale = Vector3.ONE * 0.3
	var bt := ball.create_tween().set_parallel(true)
	bt.tween_property(ball, "scale", Vector3.ONE * radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	bt.tween_property(m, "albedo_color:a", 0.0, 0.3)
	bt.chain().tween_callback(ball.queue_free)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring(1.0, 0.08)
	var rm := _mat(col.lightened(0.3), true, true).duplicate() as StandardMaterial3D
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.global_position = center + Vector3.UP * 0.1
	ring.scale = Vector3.ONE * 0.2
	var rt := ring.create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.3).set_ease(Tween.EASE_OUT)
	rt.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	rt.chain().tween_callback(ring.queue_free)
	if crop in [&"cotton", &"herbs", &"sulfur_root"]:
		_cloud(center, radius * 0.7, col)


## A soft cloud of the crop's colour that hangs half a second.
static func _cloud(at: Vector3, r: float, col: Color) -> void:
	var root := _root()
	if root == null:
		return
	var c := MeshInstance3D.new()
	c.mesh = _sphere(1.0)
	var m := _mat(col, true, true).duplicate() as StandardMaterial3D
	m.albedo_color = Color(col, 0.35)
	c.material_override = m
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(c)
	c.global_position = at
	c.scale = Vector3(r, r * 0.6, r)
	var t := c.create_tween()
	t.tween_interval(0.3)
	t.tween_property(m, "albedo_color:a", 0.0, 0.4)
	t.tween_callback(c.queue_free)


## The Spike Driver's shockwave: a ring rippling out across the rock face.
static func _wave(at: Vector3, normal: Vector3, radius: float, col: Color, share: float) -> void:
	var root := _root()
	if root == null:
		return
	Audio.play_at(&"ground_rumble", at, -2.0 if share >= 1.0 else -8.0, 1.4)
	var v := _vfx()
	if v != null:
		v.dust_burst(at, normal if normal.length() > 0.1 else Vector3.UP, radius * 0.3)
	var nrm := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.mesh = _ring(1.0, 0.12)
		var m := _mat(col, true, true).duplicate() as StandardMaterial3D
		m.albedo_color = Color(col.lightened(0.2 * i), 0.9 * clampf(share, 0.3, 1.0))
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		# The torus lies in its local XZ plane: turn its Y onto the rock's normal.
		var side := nrm.cross(Vector3.UP if absf(nrm.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
		ring.global_transform = Transform3D(Basis(side, nrm, side.cross(nrm)), at + nrm * 0.15)
		ring.scale = Vector3.ONE * 0.2
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.3 + 0.12 * i).set_delay(0.06 * i).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "albedo_color:a", 0.0, 0.45 + 0.12 * i).set_delay(0.06 * i)
		t.chain().tween_callback(ring.queue_free)


# ------------------------------------------------------------------ spray

## One pump: a fan of crop-coloured droplets and a mist that fades.
static func _spray(muzzle: Vector3, dir: Vector3, cone: float, reach: float, col: Color) -> void:
	var root := _root()
	if root == null or dir.length() < 0.01:
		return
	_spray_pool = _spray_pool.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	if _spray_pool.size() < 5:
		var e := GPUParticles3D.new()
		e.one_shot = true
		e.emitting = false
		e.amount = 40
		e.lifetime = 0.5
		e.explosiveness = 0.85
		e.local_coords = false
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.visibility_aabb = AABB(Vector3(-14, -14, -16), Vector3(28, 28, 20))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0, -1)
		pm.gravity = Vector3(0, -4.0, 0)
		pm.damping_min = 3.0
		pm.damping_max = 6.0
		var curve := Curve.new()
		curve.max_value = 3.0
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 2.6))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		e.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		quad.material = Materials.star(Color.WHITE, 1.3)
		e.draw_pass_1 = quad
		root.add_child(e)
		_spray_pool.append(e)
	var em := _spray_pool[_spray_i % _spray_pool.size()] as GPUParticles3D
	_spray_i += 1
	var pm2 := em.process_material as ParticleProcessMaterial
	pm2.spread = cone * 0.5
	pm2.initial_velocity_min = reach / 0.5 * 0.6
	pm2.initial_velocity_max = reach / 0.5 * 0.95
	var grad := Gradient.new()
	grad.set_color(0, col.lightened(0.35))
	grad.set_color(1, Color(col, 0.0))
	grad.add_point(0.5, Color(col, 0.75))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm2.color_ramp = gt
	var nd := dir.normalized()
	var up := Vector3.UP if absf(nd.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	em.global_transform = Transform3D(Basis.looking_at(nd, up), muzzle)
	em.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	em.restart()
	em.emitting = true
	_cloud(muzzle + nd * reach * 0.55, reach * 0.22, col)


# ------------------------------------------------------------------ bola wrap

static func _wrap(at: Vector3, hold: float, body_r: float, col: Color) -> void:
	var root := _root()
	if root == null:
		return
	Audio.play_at(&"whip_crack_1", at, -6.0, 1.4)
	var w := Node3D.new()
	root.add_child(w)
	w.global_position = at
	var r := maxf(body_r, 0.3) * 1.05
	for i in 3:
		var hoop := _mesh(w, _ring(r, 0.04), glow(col, 1.6))
		hoop.rotation = Vector3(0.5 * i, 1.1 * i, 0.3)
		var a := TAU * i / 3.0
		_mesh(w, _sphere(0.08), _mat(IRON), Vector3(cos(a) * r, 0.1 * i, sin(a) * r))
	var t := w.create_tween()
	t.tween_interval(maxf(hold - 0.3, 0.05))
	t.tween_property(w, "scale", Vector3.ONE * 0.01, 0.3)
	t.tween_callback(w.queue_free)


# ------------------------------------------------------------------ kegs

static func _keg(tag: int, pos: Vector3, normal: Vector3, col: Color, lit: float) -> void:
	var root := _root()
	if root == null:
		return
	var old: Variant = _kegs.get(tag)
	if old is Node3D and is_instance_valid(old):
		(old as Node3D).queue_free()
	var k := Node3D.new()
	root.add_child(k)
	var nrm := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var side := nrm.cross(Vector3.UP if absf(nrm.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	k.global_transform = Transform3D(Basis(side, nrm, side.cross(nrm)), pos)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.17
	barrel.bottom_radius = 0.17
	barrel.height = 0.4
	barrel.radial_segments = 10
	_mesh(k, barrel, _mat(KEG_WOOD), Vector3(0, 0.12, 0))
	for yy: float in [-0.02, 0.26]:
		_mesh(k, _ring(0.178, 0.03), _mat(IRON), Vector3(0, yy, 0))
	var fuse := _mesh(k, _sphere(0.055), glow(col, 1.0 if lit < 0.0 else 3.0), Vector3(0, 0.36, 0))
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.4 if lit < 0.0 else 1.5
	light.omni_range = 2.0
	light.position = Vector3(0, 0.45, 0)
	k.add_child(light)
	# The fuse glow breathes while it waits, and brightens fast once it's lit.
	var t := fuse.create_tween().set_loops()
	t.tween_property(fuse, "scale", Vector3.ONE * (1.8 if lit >= 0.0 else 1.3), 0.25 if lit >= 0.0 else 0.8)
	t.tween_property(fuse, "scale", Vector3.ONE, 0.25 if lit >= 0.0 else 0.8)
	_kegs[tag] = k
	Audio.play_at(&"fuse_sizzle", pos, -10.0 if lit < 0.0 else -3.0, 1.1)


# ------------------------------------------------------------------ loading

## A sack into a rider's heavy: a burst of the old crop thrown out (a swap) and a
## pulse of the new one.
static func _load(at: Vector3, col: Color, old_index: int) -> void:
	var v := _vfx()
	if v == null:
		return
	var p := at + Vector3.UP * 1.2
	if old_index > 0 and old_index <= HeavyRules.CROPS.size():
		v.pop(p, HeavyRules.color_of(HeavyRules.CROPS[old_index - 1]), 0.35)
	v.spark(p, Vector3.UP, col)
