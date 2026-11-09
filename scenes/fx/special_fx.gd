class_name SpecialFx
extends RefCounted
## Every peer: the special weapons' visuals (PlayerNet.special_fx; the host sends
## them from SpecialRules / SpecialZones). `c` is the shot's colour, already
## tinted toward the gun's crop. Cheap and self-freeing: tracers and pops from
## the VfxPool, a few simple meshes driven by tweens.
##   sp_shot      a = muzzle, b = end, x = weapon (SpecialRules.IDS index)
##   sp_impact    a = point, b = normal, x = 1 on a bug
##   sp_ricochet  a, b = the corn bounce from one bug to the next
##   sp_crack     a = bug, x = seconds weakened
##   sp_arc       a, b = one jump of the Spark Pistol's chain
##   sp_dust      a = muzzle, b = direction, x = reach
##   sp_cloud     a = centre, x = radius (a puff of the Smoke Bellows' cloud)
##   sp_bramble   a, b = one leg of the bramble ball's flight, x = when it starts (s)
##   sp_lob       a = muzzle, b = where the pod sticks, x = flight time
##   sp_burst     a = pod, b = normal, x = radius
##   sp_anchor    a = muzzle, b = where the anchor bit
##   sp_wire      a, b = the anchors, x = seconds it lasts
##   sp_wire_hit  a, b = the wire, x = triggers left
##   sp_wire_end  a, b = the wire
##   sp_carrier   a = bug, x = seconds it carries the crop
##   sp_spread    a = carrier, b = the bug it touched

## Seconds a cloud puff's visual hangs (the rules' CLOUD_TIME).
const CLOUD_LIFE := 4.0
## At most one dust puff drawn every this many ms.
const DUST_MS := 90

static var _wires: Array = [] # [a, b, MeshInstance3D]
static var _pods: Array[Node3D] = []
static var _anchors: Array[Node3D] = []
static var _dust_ms := 0
static var _mats: Dictionary = {}


static func _pool() -> VfxPool:
	return VfxPool.instance if is_instance_valid(VfxPool.instance) else null


static func _scene() -> Node:
	var p := _pool()
	return p if p != null else null


static func _glow_mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s:%s" % [c.to_html(), alpha]
	if _mats.has(key) and is_instance_valid(_mats[key]):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[key] = m
	return m


static func play(kind: StringName, a: Vector3, b: Vector3, x: float, c: Color) -> void:
	var p := _pool()
	if p == null:
		return
	match kind:
		&"sp_shot":
			_shot(p, a, b, int(x), c)
		&"sp_impact":
			p.spark(a, b if b.length() > 0.1 else Vector3.UP, c)
		&"sp_ricochet":
			p.tracer(a, b, c, 0.025)
			p.spark(b, Vector3.UP, c)
		&"sp_crack":
			p.shell_crack(a + Vector3.UP * 0.3, c.lerp(Color.WHITE, 0.5), 0.35)
		&"sp_arc":
			_arc(p, a, b, c, 0.03)
		&"sp_dust":
			var now := Time.get_ticks_msec()
			if now - _dust_ms < DUST_MS:
				return
			_dust_ms = now
			for i in 3:
				var t := 0.25 + i * 0.3
				p.pop(a + b * x * t, c, 0.25 + t * 0.9)
		&"sp_cloud":
			_cloud(p, a, x, c)
		&"sp_bramble":
			_bramble(p, a, b, x, c)
		&"sp_lob":
			_lob(p, a, b, x, c)
		&"sp_burst":
			p.pop(a, c, x * 0.5)
			p.pop(a, c.darkened(0.3), x * 0.3)
			Audio.play_at(&"dynamite", a, -12.0, 1.6)
			_drop_nearest(_pods, a, 2.5)
		&"sp_anchor":
			p.tracer(a, b, Color("#B8BCC4"), 0.012)
			_anchor(p, b)
			Audio.play_at(&"build", b, -8.0, 1.6)
		&"sp_wire":
			_wire(p, a, b, x, c)
		&"sp_wire_hit":
			_wire_flash(p, a, b, x, c)
		&"sp_wire_end":
			_wire_end(p, a, b)
		&"sp_carrier":
			_carrier(a, x, c)
		&"sp_spread":
			p.tracer(a + Vector3.UP * 0.4, b + Vector3.UP * 0.4, c, 0.02)
			p.spark(b + Vector3.UP * 0.4, Vector3.UP, c)


## A shot's flight, drawn the gun's way.
static func _shot(p: VfxPool, a: Vector3, b: Vector3, weapon: int, c: Color) -> void:
	var id: StringName = SpecialRules.IDS[weapon] if weapon >= 0 and weapon < SpecialRules.IDS.size() else &""
	match id:
		&"barb_sling":
			p.bullet_streak(a, b, c, 0.02, 90.0)
		&"signal_flare":
			p.bullet_streak(a, b, c.lightened(0.2), 0.09, 60.0)
		&"crop_syringe":
			p.bullet_streak(a, b, c, 0.03, 110.0)
		&"venom_needle":
			p.bullet_streak(a, b, c, 0.012, 160.0)
		&"spark_pistol":
			_arc(p, a, b, c, 0.045)
		_:
			p.tracer(a, b, c, 0.02)


## A jagged lightning line: a few short tracers with the middle points knocked aside.
static func _arc(p: VfxPool, a: Vector3, b: Vector3, c: Color, w: float) -> void:
	var n := clampi(int(a.distance_to(b) / 1.2), 3, 9)
	var side := (b - a).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(b - a).normalized()
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := a.lerp(b, t)
		if i < n:
			q += side * randf_range(-0.3, 0.3) + up * randf_range(-0.3, 0.3)
		p.tracer(prev, q, c, w)
		prev = q
	p.spark(b, Vector3.UP, c)


## A soft ball of smoke that swells and fades.
static func _cloud(p: VfxPool, at: Vector3, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 16
	m.rings = 8
	mi.mesh = m
	mi.material_override = _glow_mat(c.lerp(Color("#D9D6D0"), 0.35), 0.22)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * r * 0.4
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r, r * 0.7, r), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_interval(CLOUD_LIFE - 1.6)
	tw.tween_property(mi, "scale", Vector3(r, r * 0.6, r) * 1.1, 1.0)
	tw.parallel().tween_property(mi, "transparency", 1.0, 1.0)
	tw.tween_callback(mi.queue_free)
	p.pop(at, c, r * 0.25)


## A thorny ball flying one leg, starting `delay` s after the shot; a pop where it lands.
static func _bramble(p: VfxPool, a: Vector3, b: Vector3, delay: float, c: Color) -> void:
	var mi := Node3D.new()
	# The fal bramble ball, the same one that sits loaded in the pistol's muzzle,
	# a little bigger in flight so its thorns read at range.
	var ball: Mesh = ArmoryGuns.parts(&"bramble_pistol").get("shell")
	if ball != null:
		var bm := MeshInstance3D.new()
		bm.mesh = ball
		bm.position = -ArmoryGuns.pivot(&"bramble_pistol", "shell")
		mi.add_child(bm)
		mi.scale = Vector3.ONE * 1.5
	else:
		var cm := MeshInstance3D.new()
		var st := MeshKit.begin()
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE * 0.1, 4, 7, c.lerp(Color("#5A3E22"), 0.4))
		for i in 8:
			var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(d), d * 0.11), Vector3(0.02, 0.09, 0.02), c.darkened(0.2))
		cm.mesh = MeshKit.finish(st)
		cm.material_override = Materials.toon(0.02)
		mi.add_child(cm)
	mi.visible = false
	p.add_child(mi)
	mi.global_position = a
	var flight := a.distance_to(b) / SpecialRules.BRAMBLE_SPEED
	var tw := mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_property(mi, "global_position", b, maxf(flight, 0.02))
	tw.parallel().tween_property(mi, "rotation", Vector3(TAU * 2.0, TAU, 0.0), maxf(flight, 0.02))
	tw.tween_callback(func() -> void:
		p.pop(b, c, SpecialRules.BRAMBLE_RADIUS * 0.4)
		Audio.play_at(&"hammer_hit", b, -12.0, 1.5)
		mi.queue_free())


## The pod's floaty arc, then it sits there pulsing until it bursts.
static func _lob(p: VfxPool, a: Vector3, b: Vector3, flight: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.2
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	p.add_child(mi)
	mi.global_position = a
	var peak := (a + b) * 0.5 + Vector3.UP * (1.0 + a.distance_to(b) * 0.12)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		mi.global_position = a.lerp(peak, t).lerp(peak.lerp(b, t), t), 0.0, 1.0, maxf(flight, 0.05))
	tw.tween_callback(func() -> void:
		p.spark(b, Vector3.UP, c)
		_pods.append(mi)
		var pulse := mi.create_tween().set_loops(12)
		pulse.tween_property(mat, "emission_energy_multiplier", 1.6, 0.35)
		pulse.tween_property(mat, "emission_energy_multiplier", 0.3, 0.35)
		pulse.finished.connect(func() -> void:
			_pods.erase(mi)
			mi.queue_free()))


static func _anchor(p: VfxPool, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.035
	m.bottom_radius = 0.01
	m.height = 0.16
	mi.mesh = m
	mi.material_override = _glow_mat(Color("#7B7F86"))
	p.add_child(mi)
	mi.global_position = at
	_anchors.append(mi)
	var tw := mi.create_tween()
	tw.tween_interval(SpecialRules.WIRE_TIME + 25.0) # an unused first anchor rusts away
	tw.tween_callback(func() -> void:
		_anchors.erase(mi)
		mi.queue_free())


static func _wire(p: VfxPool, a: Vector3, b: Vector3, life: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.012
	m.bottom_radius = 0.012
	m.height = 1.0
	m.radial_segments = 6
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c * 1.6
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	var d := b - a
	mi.global_transform = Transform3D(MeshKit.basis_from_y(d.normalized()) * Basis.from_scale(Vector3(1, d.length(), 1)), (a + b) * 0.5)
	if not _near_anchor(b):
		_anchor(p, b)
	_wires.append([a, b, mi])
	var tw := mi.create_tween()
	tw.tween_interval(life + 0.5) # (the host ends it sooner when it snaps)
	tw.tween_callback(func() -> void: _wire_end(p, a, b))


static func _near_anchor(at: Vector3) -> bool:
	for n in _anchors:
		if is_instance_valid(n) and n.global_position.distance_to(at) < 0.3:
			return true
	return false


static func _find_wire(a: Vector3, b: Vector3) -> int:
	for i in _wires.size():
		var w: Array = _wires[i]
		if (w[0] as Vector3).distance_to(a) < 0.2 and (w[1] as Vector3).distance_to(b) < 0.2:
			return i
	return -1


static func _wire_flash(p: VfxPool, a: Vector3, b: Vector3, left: float, c: Color) -> void:
	var i := _find_wire(a, b)
	p.tracer(a, b, c.lightened(0.5), 0.05)
	Audio.play_at(&"whip_crack_1", (a + b) * 0.5, -10.0, 1.5)
	if i >= 0 and is_instance_valid(_wires[i][2]):
		var mi: MeshInstance3D = _wires[i][2]
		var mat := mi.material_override as StandardMaterial3D
		mat.albedo_color = c * (0.7 + 0.9 * clampf(left / SpecialRules.WIRE_TRIGGERS, 0.0, 1.0))


static func _wire_end(p: VfxPool, a: Vector3, b: Vector3) -> void:
	var i := _find_wire(a, b)
	if i < 0:
		return
	var mi: MeshInstance3D = _wires[i][2]
	_wires.remove_at(i)
	if is_instance_valid(mi):
		mi.queue_free()
	for at: Vector3 in [a, b]:
		p.spark(at, Vector3.UP, Color("#B8BCC4"))
		_drop_nearest(_anchors, at, 0.3)


static func _drop_nearest(list: Array, at: Vector3, within: float) -> void:
	var best: Node3D = null
	var best_d := within
	for n in list:
		if is_instance_valid(n) and (n as Node3D).global_position.distance_to(at) < best_d:
			best_d = (n as Node3D).global_position.distance_to(at)
			best = n
	if best != null:
		list.erase(best)
		best.queue_free()


## Crop-coloured motes orbiting the carrier bug for `seconds`.
static func _carrier(at: Vector3, seconds: float, c: Color) -> void:
	var p := _pool()
	var bug := _bug_near(p, at)
	if bug == null:
		return
	var old := bug.get_node_or_null("SpCarrier")
	if old != null:
		old.queue_free()
	var root := Node3D.new()
	root.name = "SpCarrier"
	bug.add_child(root)
	root.position = Vector3.UP * 0.5
	for i in 5:
		var mi := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.05
		m.height = 0.1
		mi.mesh = m
		mi.material_override = _glow_mat(c * 1.4)
		var ang := TAU * i / 5.0
		mi.position = Vector3(cos(ang), 0.15 * sin(ang * 2.0), sin(ang)) * 0.75
		root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * seconds * 0.6, maxf(seconds - 1.0, 0.1))
	tw.tween_property(root, "scale", Vector3.ONE * 0.2, 1.0)
	tw.tween_callback(root.queue_free)


static func _bug_near(p: Node, at: Vector3) -> Node3D:
	if p == null or p.get_tree() == null:
		return null
	var best: Node3D = null
	var best_d := 2.0
	for n: Node in p.get_tree().get_nodes_in_group("bugs"):
		var b := n as Node3D
		if b != null and b.global_position.distance_to(at) < best_d:
			best_d = b.global_position.distance_to(at)
			best = b
	return best
