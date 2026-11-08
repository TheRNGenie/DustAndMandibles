class_name ArmoryHeavyFx
extends RefCounted
## Every peer: the heavies' (and two primaries') visuals (ArmoryEffects.play_fx).
## The host sends these through PlayerNet.armory_fx. Kinds and their a, b, x:
##   hv_flame      Fire Lance puff:    a muzzle, b direction, x reach (m)
##   hv_acid       Acid Drencher puff: a muzzle, b direction, x reach (m)
##   hv_sizzle     acid stripped a bug's armour: a the bug
##   hv_mortar     shell lobbed then a blast: a start, b where it lands, x ArmoryHeavyRules.pack_blast(flight, radius)
##   hv_rocket     rocket with smoke trail then a blast: a start, b end, x ArmoryHeavyRules.pack_rocket(dir, homing)
##   hv_bolt       ballista bolt: a start, b where it struck, x seconds it stays stuck (0: gone on arrival)
##   hv_trap       bear trap laid open: a position, b surface normal, x trap id
##   hv_trap_snap  a trap snaps shut: a position, b normal, x trap id (-1: a new trap snapping on a bug at a)
##   hv_trap_gone  traps removed: x trap id (-1: all of them, the wave ended)
##   hv_ricochet   the bounce leg: a the bounce point, b its end, x 1 if it struck a bug
##   hv_pierce     a bullet going on through the line: a the first bug, b the end, x bugs pierced
## Returns false for any other kind. Nodes go under the current scene and free themselves.

## Colours.
const FLAME := Color("#FF8A2A")
const FLAME_CORE := Color("#FFE27A")
const SMOKE := Color("#8C8680")
const IRON := Color("#3A3634")
const BOLT_WOOD := Color("#7A5232")
const RICOCHET_STREAK := Color("#FFE6A0")
const PIERCE_STREAK := Color("#FFF1B0")
## Bolt flight speed (m/s, visual), and flame/acid particle lifetimes.
const BOLT_SPEED := 160.0
const PUFF_LIFE := 0.45
## Emitters kept per spray kind (one-shot, reused round-robin).
const SPRAY_POOL := 6

## Traps on show: id -> Node3D (each holds "jaw_a"/"jaw_b" pivots).
static var _traps: Dictionary = {}
## Spray emitter pools: kind -> Array of GPUParticles3D; and the next index.
static var _pools: Dictionary = {}
static var _pool_i: Dictionary = {}
static var _mats: Dictionary = {}


static func play(kind: StringName, a: Vector3, b: Vector3, x: float) -> bool:
	match kind:
		&"hv_flame":
			_spray(kind, a, b, x, FLAME, 2.6, 1.5)
			Audio.play_at(&"match_strike", a, -14.0, randf_range(0.7, 0.9))
		&"hv_acid":
			_spray(kind, a, b, x, Palette.ACID_GREEN, 1.6, -5.0)
			Audio.play_at(&"water_pour", a, -16.0, randf_range(1.2, 1.4))
		&"hv_sizzle":
			_sizzle(a)
		&"hv_mortar":
			_mortar(a, b, ArmoryHeavyRules.blast_flight(x), ArmoryHeavyRules.blast_radius(x))
		&"hv_rocket":
			_rocket(a, b, ArmoryHeavyRules.rocket_dir(x), ArmoryHeavyRules.rocket_homing(x))
		&"hv_bolt":
			_bolt(a, b, x)
		&"hv_trap":
			_trap(int(x), a, b)
		&"hv_trap_snap":
			_trap_snap(int(x), a, b)
		&"hv_trap_gone":
			_trap_gone(int(x))
		&"hv_ricochet":
			_ricochet(a, b, x > 0.5)
		&"hv_pierce":
			var v := VfxPool.instance
			if v != null and is_instance_valid(v):
				v.bullet_streak(a, b, PIERCE_STREAK, 0.045, 380.0)
		_:
			return false
	return true


static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null


static func _vfx() -> VfxPool:
	var v := VfxPool.instance
	return v if v != null and is_instance_valid(v) else null


## A flat unshaded (or lit) material, shared per colour.
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


# ------------------------------------------------------------------ sprays

## One puff of flame or acid: a pooled one-shot cone of glowing stars.
static func _spray(kind: StringName, muzzle: Vector3, dir: Vector3, reach: float, color: Color, brightness: float,
		gravity: float) -> void:
	var root := _root()
	if root == null or dir.length() < 0.01:
		return
	var pool: Array = _pools.get(kind, [])
	pool = pool.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	if pool.size() < SPRAY_POOL:
		var e := _make_spray(color, brightness, gravity, kind == &"hv_flame")
		root.add_child(e)
		pool.append(e)
	_pools[kind] = pool
	var i := int(_pool_i.get(kind, 0)) % pool.size()
	_pool_i[kind] = i + 1
	var em := pool[i] as GPUParticles3D
	var pm := em.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = reach / PUFF_LIFE * 0.7
	pm.initial_velocity_max = reach / PUFF_LIFE * 1.0
	var n := dir.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	em.global_transform = Transform3D(Basis.looking_at(n, up), muzzle)
	em.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	em.restart()
	em.emitting = true


static func _make_spray(color: Color, brightness: float, gravity: float, flame: bool) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.amount = 22
	e.lifetime = PUFF_LIFE
	e.explosiveness = 0.75
	e.local_coords = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-14, -14, -22), Vector3(28, 28, 26))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = ArmoryHeavyRules.FIRE_HALF_ANGLE * 0.8
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 4.0
	pm.damping_max = 8.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.max_value = 4.0
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 4.0 if flame else 2.5))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, (FLAME_CORE if flame else color.lightened(0.3)))
	grad.set_color(1, Color(SMOKE if flame else color.darkened(0.3), 0.0))
	grad.add_point(0.4, color)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = Materials.star(Color.WHITE, brightness)
	e.draw_pass_1 = quad
	return e


## Acid ate a bug's armour: a green fizz and a hiss.
static func _sizzle(pos: Vector3) -> void:
	var v := _vfx()
	if v != null:
		v.spark(pos, Vector3.UP, Palette.ACID_GREEN)
		v.dust_burst(pos, Vector3.UP, 0.5)
	Audio.play_at(&"fuse_sizzle", pos, -4.0, 1.3)


# ------------------------------------------------------------------ blasts

## A blast: fireball and rock chunks, a flash of light, a shock ring, the bang.
static func blast(center: Vector3, radius: float) -> void:
	var root := _root()
	Audio.play_at(&"dynamite", center)
	var v := _vfx()
	if v != null:
		v.pop(center, Palette.GLOW_YELLOW, radius * 0.8)
		v.pop(center, Palette.ROCK_C, radius * 0.5)
		v.dust_burst(center, Vector3.UP, radius * 0.4)
	if root == null:
		return
	var light := OmniLight3D.new()
	light.light_color = FLAME_CORE
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	root.add_child(light)
	light.global_position = center + Vector3.UP
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.35)
	lt.tween_callback(light.queue_free)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	ball.mesh = sphere
	var m := _mat(FLAME, true, true).duplicate() as StandardMaterial3D
	m.albedo_color = Color(FLAME, 0.7)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	ball.global_position = center
	ball.scale = Vector3.ONE * 0.3
	var bt := ball.create_tween().set_parallel(true)
	bt.tween_property(ball, "scale", Vector3.ONE * radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	bt.tween_property(m, "albedo_color:a", 0.0, 0.3)
	bt.chain().tween_callback(ball.queue_free)


## A trail of smoke that follows `node` (_land stops it).
static func _trail(node: Node3D, _seconds: float, color: Color, amount: int) -> void:
	var e := GPUParticles3D.new()
	e.amount = amount
	e.lifetime = 0.8
	e.local_coords = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.6, 0)
	var curve := Curve.new()
	curve.max_value = 3.0
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 3.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, FLAME_CORE)
	grad.set_color(1, Color(color, 0.0))
	grad.add_point(0.15, Color(color, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = Materials.star(Color.WHITE, 1.2)
	e.draw_pass_1 = quad
	e.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	node.add_child(e)
	e.emitting = true


## The flying body leaves its trail behind: the smoke lingers, then everything goes.
static func _land(node: Node3D) -> void:
	for c in node.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).emitting = false
		elif c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	node.get_tree().create_timer(0.9).timeout.connect(node.queue_free)


static func _mortar(from: Vector3, to: Vector3, flight: float, radius: float) -> void:
	var root := _root()
	if root == null:
		blast(to, radius)
		return
	var shell := Node3D.new()
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 10
	sphere.rings = 5
	mi.mesh = sphere
	mi.material_override = _mat(IRON)
	shell.add_child(mi)
	root.add_child(shell)
	shell.global_position = from
	_trail(shell, flight, SMOKE, 24)
	Audio.play_at(&"mortar", from, -2.0)
	var tw := shell.create_tween()
	tw.tween_method(func(t: float) -> void:
		shell.global_position = ArmoryHeavyRules.mortar_at(from, to, t), 0.0, 1.0, maxf(flight, 0.05))
	tw.tween_callback(func() -> void:
		blast(to, radius)
		_land(shell))


static func _rocket(from: Vector3, to: Vector3, dir: Vector3, homing: bool) -> void:
	var path := ArmoryHeavyRules.rocket_path(from, dir, to, homing)
	var flight := ArmoryHeavyRules.rocket_flight(path)
	var radius := ArmoryHeavyRules.ROCKET_RADIUS
	var root := _root()
	if root == null:
		blast(to, radius)
		return
	var rocket := Node3D.new()
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.09
	tube.height = 0.7
	tube.radial_segments = 8
	body.mesh = tube
	body.material_override = _mat(IRON)
	body.rotation.x = -PI * 0.5 # the tube lies along -Z (forward)
	rocket.add_child(body)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.2
	cone.radial_segments = 8
	nose.mesh = cone
	nose.material_override = _mat(Palette.TEAM_WEST)
	nose.rotation.x = -PI * 0.5
	nose.position = Vector3(0, 0, -0.45)
	rocket.add_child(nose)
	root.add_child(rocket)
	rocket.global_position = from
	_trail(rocket, flight, SMOKE, 40)
	Audio.play_at(&"fuse_sizzle", from, -2.0, 0.7)
	var tw := rocket.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := ArmoryHeavyRules.rocket_at(path, t)
		var ahead := ArmoryHeavyRules.rocket_at(path, minf(t + 0.02, 1.0))
		rocket.global_position = p
		var fwd := ahead - p
		if fwd.length() > 0.01:
			var up := Vector3.UP if absf(fwd.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			rocket.global_basis = Basis.looking_at(fwd.normalized(), up), 0.0, 1.0, flight)
	tw.tween_callback(func() -> void:
		blast(to, radius)
		_land(rocket))


# ------------------------------------------------------------------ bolt

static func _bolt(from: Vector3, to: Vector3, linger: float) -> void:
	var root := _root()
	if root == null or from.distance_to(to) < 0.3:
		return
	var bolt := Node3D.new()
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 1.6)
	shaft.mesh = box
	shaft.material_override = _mat(BOLT_WOOD)
	shaft.position = Vector3(0, 0, 0.8) # the tip sits at the node, the shaft trails behind
	bolt.add_child(shaft)
	var head := MeshInstance3D.new()
	var tip := BoxMesh.new()
	tip.size = Vector3(0.22, 0.04, 0.3)
	head.mesh = tip
	head.material_override = _mat(IRON)
	bolt.add_child(head)
	root.add_child(bolt)
	var n := (to - from).normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	bolt.global_transform = Transform3D(Basis.looking_at(n, up), from)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", to, from.distance_to(to) / BOLT_SPEED)
	tw.tween_callback(func() -> void:
		Audio.play_at(&"harpoon", to, 0.0, 0.8)
		var v := _vfx()
		if v != null:
			v.spark(to, -n, Palette.GLOW_YELLOW if linger <= 0.0 else Palette.ACID_GREEN))
	if linger > 0.0:
		tw.tween_interval(linger)
		tw.tween_property(bolt, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(bolt.queue_free)


# ------------------------------------------------------------------ traps

## An open iron trap: a base plate and two toothed jaws lying flat.
static func _make_trap(pos: Vector3, normal: Vector3) -> Node3D:
	var root := _root()
	if root == null:
		return null
	var t := Node3D.new()
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.26
	disc.height = 0.06
	disc.radial_segments = 10
	plate.mesh = disc
	plate.material_override = _mat(IRON)
	t.add_child(plate)
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "jaw_a" if side > 0.0 else "jaw_b"
		var jaw := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.75, 0.05, 0.06)
		jaw.mesh = bar
		jaw.material_override = _mat(IRON.lightened(0.15))
		jaw.position = Vector3(0, 0.02, 0.4 * side)
		pivot.add_child(jaw)
		for k in 5: # teeth, pointing up while open
			var tooth := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(0.04, 0.12, 0.04)
			tooth.mesh = tb
			tooth.material_override = _mat(Palette.BONE.darkened(0.3))
			tooth.position = Vector3(-0.3 + k * 0.15, 0.08, 0.4 * side)
			pivot.add_child(tooth)
		t.add_child(pivot)
	root.add_child(t)
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side_ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x_axis := side_ref.cross(up).normalized()
	t.global_transform = Transform3D(Basis(x_axis, up, x_axis.cross(up)), pos + up * 0.03)
	return t


static func _trap(id: int, pos: Vector3, normal: Vector3) -> void:
	_trap_gone(id) # (a reused id never leaves a stale trap)
	var t := _make_trap(pos, normal)
	if t == null:
		return
	_traps[id] = t
	t.scale = Vector3.ONE * 0.2
	t.create_tween().tween_property(t, "scale", Vector3.ONE, 0.15)
	Audio.play_at(&"hammer_hit", pos, -6.0, 1.2)
	var v := _vfx()
	if v != null:
		v.dust_burst(pos, normal if normal.length() > 0.01 else Vector3.UP, 0.4)


static func _trap_snap(id: int, pos: Vector3, normal: Vector3) -> void:
	var t: Node3D = null
	if id >= 0 and _traps.has(id) and is_instance_valid(_traps[id]):
		t = _traps[id]
		pos = t.global_position
	else:
		t = _make_trap(pos, normal)
	_traps.erase(id)
	if t == null:
		return
	var tw := t.create_tween().set_parallel(true)
	for jaw_name: String in ["jaw_a", "jaw_b"]:
		var pivot := t.get_node_or_null(jaw_name) as Node3D
		if pivot != null:
			var shut := -PI * 0.5 if jaw_name == "jaw_a" else PI * 0.5
			tw.tween_property(pivot, "rotation:x", shut, 0.07)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(t, "scale", Vector3.ONE * 0.01, 0.3)
	tw.chain().tween_callback(t.queue_free)
	Audio.play_at(&"hammer_hit", pos, 2.0, 0.8)
	var v := _vfx()
	if v != null:
		v.spark(pos, Vector3.UP)


static func _trap_gone(id: int) -> void:
	var ids: Array = _traps.keys() if id < 0 else [id]
	for k: Variant in ids:
		var t: Variant = _traps.get(k)
		_traps.erase(k)
		if t != null and is_instance_valid(t):
			var n := t as Node3D
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(n.queue_free)


# ------------------------------------------------------------------ bullets

static func _ricochet(at: Vector3, end: Vector3, struck: bool) -> void:
	var v := _vfx()
	Audio.play_at(&"armor_ping", at, -3.0, randf_range(1.1, 1.4))
	if v == null:
		return
	v.spark(at, (end - at).normalized())
	v.bullet_streak(at, end, RICOCHET_STREAK, 0.04, 300.0)
	if struck:
		v.spark(end, (at - end).normalized(), Palette.ACID_GREEN)
