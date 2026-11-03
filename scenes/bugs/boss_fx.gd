class_name BossFx
extends Node3D
## The bosses' shared machinery (one node in the world, same path on every peer):
##  - an event channel: a boss brain on the host calls send(bug, kind, args) and
##    every peer's copy of that boss gets on_event(kind, args) (reliable RPC), so
##    telegraphs, projectiles and one-off effects are seen the same everywhere;
##  - turret afflictions, decided by the host: webbed (Queen Spider) and stunned
##    (Thunder Cicada) turrets hold fire, acid (Acid Matriarch) eats a turret
##    over time until a Water Cannon washes it off. Every peer draws them: a silk
##    cocoon you can shoot apart, dizzy stars, dripping green acid;
##  - telegraph pieces any boss can use: glowing ground rings, spreading cracks,
##    screech shockwaves, glows on a boss's body;
##  - host hooks the rest of the game calls (splashes, fire patches, kills,
##    shots hitting the canyon floor) so bosses like the Tumble Titan and the
##    Bone Collector can react.

const WEB_COLOR := Color("#F4F1E8")
const STUN_COLOR := Color("#FFD23F")

static var instance: BossFx

## Host: turret instance id -> {"t": Turret, "web": s, "web_hp": hp, "stun": s, "acid": s, "dps": dps}
var _afflicted: Dictionary = {}
## Every peer: "kind:turret path" -> the overlay node drawn on that turret.
var _looks: Dictionary = {}

static var _ring_tex: ImageTexture
static var _crack_tex: ImageTexture
static var _cocoon_mesh: ArrayMesh
static var _acid_mesh: ArrayMesh


func _ready() -> void:
	instance = self
	if GameState.flag_value("--bossview") != "":
		var view: Node = (load("res://scenes/debug/boss_views.gd") as GDScript).new()
		view.name = "BossViews"
		add_child(view)


func _exit_tree() -> void:
	if instance == self:
		instance = null


# ------------------------------------------------------------------ event channel

## Host: tells every peer's copy of `bug` that `kind` happened (BossBrain.on_event).
func send(bug: Bug, kind: StringName, args: Array = []) -> void:
	if multiplayer.is_server() and bug != null and bug.net_id != 0:
		_event.rpc(bug.net_id, kind, args)


@rpc("authority", "call_local", "reliable")
func _event(net_id: int, kind: StringName, args: Array) -> void:
	var bm := BugManager.instance
	if bm == null:
		return
	var b := bm._by_id.get(net_id) as Bug
	if b != null and is_instance_valid(b) and b.boss != null:
		b.boss.on_event(kind, args)


# ------------------------------------------------------------------ host hooks

## Turrets that boss affliction stops from firing (webbed or stunned).
static func holds_fire(t: Turret) -> bool:
	if instance == null:
		return false
	var a: Dictionary = instance._afflicted.get(t.get_instance_id(), {})
	return float(a.get("web", 0.0)) > 0.0 or float(a.get("stun", 0.0)) > 0.0


## Host: a Water Cannon fired at `target`: its spray washes acid off every turret
## near it, and a hit on the Acid Matriarch rinses out her acid sac.
static func on_water(t: Turret, target: Bug) -> void:
	if instance == null:
		return
	instance.wash_near(t.global_position, AcidWash.RADIUS)
	if target != null and target.boss != null:
		target.boss.on_water_hit(t)


## Host: a splash went off (BugManager.splash): bosses with breakable parts and
## the corpse piles under it react.
static func on_splash(cliff: int, center: Vector3, radius: float, damage: float, source: String, source_cliff: int) -> void:
	for b: BossBrain in BossBrain.active:
		if b.bug != null and is_instance_valid(b.bug) and b.bug.is_alive():
			b.on_splash(cliff, center, radius, damage, source, source_cliff)
	_burn_corpses(cliff, center, radius)


## Host: a fire patch was laid (BugManager.add_fire): it burns husks too.
static func on_fire(cliff: int, center: Vector3, radius: float) -> void:
	_burn_corpses(cliff, center, radius)


## Host: a bug died (BugManager): bosses that feed on the dead hear about it.
static func on_bug_died(dead: Bug) -> void:
	for b: BossBrain in BossBrain.active:
		if b.bug != dead and b.bug != null and is_instance_valid(b.bug) and b.bug.is_alive():
			b.on_bug_died(dead)


## Host: a player's shot hit the world at `pos` (Gun): with a Bone Collector
## around, shooting the corpse pile at a cliff foot breaks husks apart.
static func on_world_hit(pos: Vector3) -> void:
	if pos.y > 8.0 or not BossBrain.any_alive(&"bone_collector"):
		return
	for cid in WorldLayout.cliff_count(): # Maps:
		_burn_corpses(cid, pos, 1.6, 2)


static func _burn_corpses(cliff: int, center: Vector3, radius: float, at_most: int = 12) -> void:
	if center.y > 8.0:
		return
	var pile := CorpsePile.instance
	if pile == null or not pile.multiplayer.is_server():
		return
	var n := pile.count_near(cliff, center, radius + 0.8)
	if n > 0:
		pile.clear_near.rpc(cliff, center, radius + 0.8, mini(n, at_most))


# ------------------------------------------------------------------ turret afflictions (host)

func _entry(t: Turret) -> Dictionary:
	var key := t.get_instance_id()
	if not _afflicted.has(key):
		_afflicted[key] = {"t": t, "web": 0.0, "web_hp": 0.0, "stun": 0.0, "acid": 0.0, "dps": 0.0}
	return _afflicted[key]


func is_webbed(t: Turret) -> bool:
	return float((_afflicted.get(t.get_instance_id(), {}) as Dictionary).get("web", 0.0)) > 0.0


func has_acid(t: Turret) -> bool:
	return float((_afflicted.get(t.get_instance_id(), {}) as Dictionary).get("acid", 0.0)) > 0.0


## Host: wraps a turret in silk for `seconds` (or until `hp` damage shoots it free).
func web(t: Turret, seconds: float, hp: float) -> void:
	if not multiplayer.is_server() or not is_instance_valid(t):
		return
	var e := _entry(t)
	e["web"] = seconds
	e["web_hp"] = hp
	_look.rpc(t.get_path(), &"web", true)


## Host: stuns a turret for `seconds` (it can't fire; its gun droops).
func stun(t: Turret, seconds: float) -> void:
	if not multiplayer.is_server() or not is_instance_valid(t):
		return
	var e := _entry(t)
	if float(e["stun"]) <= 0.0:
		_look.rpc(t.get_path(), &"stun", true)
	e["stun"] = maxf(float(e["stun"]), seconds)


## Host: coats a turret in acid that eats `dps` HP a second for `seconds`.
func acid(t: Turret, seconds: float, dps: float) -> void:
	if not multiplayer.is_server() or not is_instance_valid(t):
		return
	var e := _entry(t)
	if float(e["acid"]) <= 0.0:
		_look.rpc(t.get_path(), &"acid", true)
	e["acid"] = seconds
	e["dps"] = dps


## Host: washes acid off every turret within `radius` of `pos`.
func wash_near(pos: Vector3, radius: float) -> void:
	if not multiplayer.is_server():
		return
	for key: int in _afflicted:
		var e: Dictionary = _afflicted[key]
		if not is_instance_valid(e["t"]):
			continue
		var t := e["t"] as Turret
		if float(e["acid"]) > 0.0 and t != null and t.global_position.distance_to(pos) <= radius:
			e["acid"] = 0.0
			_look.rpc(t.get_path(), &"acid", false, true)


## Host: a player's bullet hit a web cocoon.
func hit_web(t: Turret, damage: float, source: String) -> void:
	if not multiplayer.is_server() or not is_instance_valid(t):
		return
	var e: Dictionary = _afflicted.get(t.get_instance_id(), {})
	if float(e.get("web", 0.0)) <= 0.0:
		return
	e["web_hp"] = float(e["web_hp"]) - damage
	_web_hit.rpc(t.get_path())
	if float(e["web_hp"]) <= 0.0:
		e["web"] = 0.0
		_look.rpc(t.get_path(), &"web", false, true)
		if source != "":
			Economy.notify_cliff(t.cliff_id, "%s shot a %s free of the web." % [source, t.def.display_name])


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _afflicted.is_empty():
		return
	var gone: Array[int] = []
	for key: int in _afflicted:
		var e: Dictionary = _afflicted[key]
		var tv: Variant = e["t"]
		if not is_instance_valid(tv):
			gone.append(key)
			continue
		var t := tv as Turret
		if t == null or not t.is_inside_tree():
			gone.append(key)
			continue
		var path := t.get_path()
		for kind: StringName in [&"web", &"stun", &"acid"]:
			var left := float(e[kind])
			if left <= 0.0:
				continue
			left -= delta
			e[kind] = left
			if left <= 0.0:
				e[kind] = 0.0
				_look.rpc(path, kind, false)
		if float(e["stun"]) > 0.0:
			# Dazed: the gun hangs down toward the canyon floor.
			var out := -t.global_basis.z
			t.aim_point = t.global_position + out * 4.0 + Vector3.DOWN * 3.5
		if float(e["acid"]) > 0.0:
			t.structure_damage(float(e["dps"]) * delta, "Matriarch acid")
		if float(e["web"]) <= 0.0 and float(e["stun"]) <= 0.0 and float(e["acid"]) <= 0.0:
			gone.append(key)
	for key in gone:
		_afflicted.erase(key)


# ------------------------------------------------------------------ turret looks (every peer)

## Every peer: shows or removes a boss affliction on a turret.
@rpc("authority", "call_local", "reliable")
func _look(path: NodePath, kind: StringName, on: bool, burst: bool = false) -> void:
	if GameState.flag_value("--bossview") != "":
		print("[bossfx] %s %s %s" % [kind, "on" if on else "off", path])
	var t := get_node_or_null(path) as Turret
	var key := "%s:%s" % [kind, path]
	var old := _looks.get(key) as Node3D
	if old != null and is_instance_valid(old):
		old.queue_free()
	_looks.erase(key)
	if t == null:
		return
	var center := t.global_position + Vector3.UP * 1.0
	if not on:
		if burst and kind == &"web":
			# Shot free: the silk bursts into fluff.
			pop(center, WEB_COLOR, 1.4)
			Audio.play_at(&"rustle", center, -2.0, 1.4)
		elif burst and kind == &"acid":
			# Washed off: a hiss of steam.
			dust(center, Vector3.UP, 1.1, Color(0.9, 0.95, 1.0))
			Audio.play_at(&"water_pour", center, -4.0, 1.2)
		return
	var n: Node3D
	match kind:
		&"web":
			n = _make_cocoon(t)
			Audio.play_at(&"rustle", center, 0.0, 0.8)
		&"stun":
			n = _make_dizzy()
		&"acid":
			n = _make_acid()
			Audio.play_at(&"acid_spit", center, 0.0, 0.8)
	if n == null:
		return
	n.name = "Boss_%s" % kind
	t.add_child(n)
	_looks[key] = n


@rpc("authority", "call_local", "unreliable")
func _web_hit(path: NodePath) -> void:
	var n := _looks.get("web:%s" % path) as Node3D
	if n != null and is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3.ONE * 0.9, 0.05)
		tw.tween_property(n, "scale", Vector3.ONE, 0.12)
		pop(n.global_position + Vector3.UP * 0.4, WEB_COLOR, 0.5)


## A shootable silk cocoon round a turret: player bullets hit it (WebBody) and the host tears it.
func _make_cocoon(t: Turret) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = cocoon_mesh()
	mi.material_override = WebBuilder.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3.UP * 1.0
	root.add_child(mi)
	var body := WebBody.new()
	body.fx = self
	body.turret = t
	body.collision_layer = WorldLayout.LAYER_BUG
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.15
	col.shape = sh
	col.position = Vector3.UP * 1.0
	body.add_child(col)
	root.add_child(body)
	# Wrapped up in a quick squash and stretch.
	root.scale = Vector3(1.3, 0.2, 1.3)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(0.9, 1.15, 0.9), 0.12)
	tw.tween_property(root, "scale", Vector3.ONE, 0.15)
	return root


class WebBody extends StaticBody3D:
	var fx: BossFx
	var turret: Turret

	func apply_hit(damage: float, _point: Vector3, _dir: Vector3, _pierce: bool = false,
			source: String = "", _source_cliff: int = -1) -> void:
		if fx != null and is_instance_valid(turret):
			fx.hit_web(turret, damage, source)


## Three comic stars circling over a stunned turret.
func _make_dizzy() -> Node3D:
	var root := Spinner.new()
	root.position = Vector3.UP * 2.1
	for i in 3:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.42, 0.42)
		q.mesh = quad
		q.material_override = Materials.star(STUN_COLOR, 2.4)
		var a := TAU * float(i) / 3.0
		q.position = Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(q)
	return root


class Spinner extends Node3D:
	var speed := 5.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		rotate_y(speed * delta)
		position.y = 2.1 + sin(_t * 6.0) * 0.08


## Gooey green acid stuck on a turret, dripping.
func _make_acid() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = acid_mesh()
	mi.material_override = Materials.toon(0.01)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var drips := GPUParticles3D.new()
	drips.amount = 14
	drips.lifetime = 0.9
	drips.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.direction = Vector3.DOWN
	pm.spread = 10.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.color = Palette.ACID_GREEN
	drips.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.14
	drop.radial_segments = 6
	drop.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Palette.ACID_GREEN
	dm.emission_enabled = true
	dm.emission = Palette.ACID_GREEN
	dm.emission_energy_multiplier = 0.8
	dm.vertex_color_use_as_albedo = true
	drop.material = dm
	drips.draw_pass_1 = drop
	drips.position = Vector3.UP * 1.1
	root.add_child(drips)
	return root


static func cocoon_mesh() -> ArrayMesh:
	if _cocoon_mesh != null:
		return _cocoon_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var st := MeshKit.begin()
	var r := Vector3(0.95, 1.15, 0.95)
	# A thin film over the whole turret...
	# (MeshKit stores alpha as 1 - glow: glow 0.75 leaves a quarter-opaque film.)
	MeshKit.add_ellipsoid(st, Transform3D(), r * 0.96, 8, 14, Color(0.95, 0.95, 0.92), 0.0, null, 0.75)
	# ...wound round and round with silk in every direction.
	for k in 34:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)).normalized()
		var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := axis.cross(side).normalized()
		var bulge := rng.randf_range(1.0, 1.08)
		var prev := Vector3.ZERO
		for i in 15:
			var a := TAU * float(i) / 14.0
			var d := side * cos(a) + up * sin(a)
			var p := Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * bulge
			if i > 0:
				WebBuilder.strand(st, prev, p, d, 0.045, Color(1, 1, 1, 0.9) if k % 3 != 0 else Color(0.82, 0.8, 0.74, 0.9))
			prev = p
	# Loose strands hanging down and a few tufts.
	for k in 8:
		var a := rng.randf() * TAU
		var top := Vector3(cos(a) * r.x * 0.8, -r.y * 0.5, sin(a) * r.z * 0.8)
		WebBuilder.strand(st, top, top + Vector3(rng.randf_range(-0.2, 0.2), -rng.randf_range(0.4, 0.9), rng.randf_range(-0.2, 0.2)), Vector3(cos(a), 0, sin(a)), 0.04, Color(1, 1, 1, 0.7))
	_cocoon_mesh = MeshKit.finish(st)
	return _cocoon_mesh


static func acid_mesh() -> ArrayMesh:
	if _acid_mesh != null:
		return _acid_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var st := MeshKit.begin()
	for k in 18:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.2, 1.7)
		var rr := 0.72 if y < 1.0 else 0.55
		var p := Vector3(cos(a) * rr, y, sin(a) * rr)
		var s := rng.randf_range(0.12, 0.26)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a), p), Vector3(s, s * 1.4, s), 4, 8, Palette.ACID_GREEN.lerp(Color("#5FAE3A"), rng.randf()), 0.0, null, 0.55)
		# A drip running down from each blob.
		MeshKit.add_limb(st, p, p + Vector3(0, -rng.randf_range(0.15, 0.4), 0), s * 0.35, Palette.ACID_GREEN, 5)
	_acid_mesh = MeshKit.finish(st)
	return _acid_mesh


# ------------------------------------------------------------------ telegraph pieces (local)

## A glowing ring on the ground at `center`, `radius` across, for `seconds`
## (pulsing faster as it runs out). Returns the decal (freed by itself).
func ground_ring(center: Vector3, radius: float, color: Color, seconds: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = ring_texture()
	d.texture_emission = ring_texture()
	d.emission_energy = 2.0
	d.modulate = color
	d.albedo_mix = 1.0
	d.size = Vector3(radius * 2.0, 12.0, radius * 2.0)
	d.upper_fade = 0.05
	d.lower_fade = 0.05
	d.cull_mask = 0xFFFFF & ~VfxPool.CORPSE_LAYER
	add_child(d)
	d.global_position = center
	var pulser := RingPulse.new()
	pulser.decal = d
	pulser.life = seconds
	pulser.color = color
	d.add_child(pulser)
	return d


class RingPulse extends Node:
	var decal: Decal
	var life := 1.0
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / maxf(life, 0.01), 0.0, 1.0)
		# Pulses quicker and brighter as the moment comes.
		var rate := lerpf(5.0, 22.0, k * k)
		var a := 0.55 + 0.45 * sin(_t * rate)
		decal.modulate = Color(color.r, color.g, color.b, lerpf(0.5, 1.0, k) * a)
		decal.emission_energy = lerpf(1.2, 3.5, k) * a
		if _t >= life:
			decal.queue_free()


## Cracks spreading over the ground at `center` for `seconds` (a burrower coming up).
func cracks(center: Vector3, radius: float, seconds: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = crack_texture()
	d.modulate = Color(1, 1, 1, 1)
	d.albedo_mix = 1.0
	d.size = Vector3(0.4, 8.0, 0.4)
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 0xFFFFF & ~VfxPool.CORPSE_LAYER
	add_child(d)
	d.global_position = center
	var tw := d.create_tween()
	tw.tween_property(d, "size", Vector3(radius * 2.2, 8.0, radius * 2.2), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(d, "modulate:a", 0.0, 1.5)
	tw.tween_callback(d.queue_free)
	return d


## A screech: rings of sound racing from `from` to `to`, then a ring bursting out at `to`.
func shockwave(from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var dir := (to - from)
	var flight := clampf(dir.length() / 90.0, 0.25, 0.7)
	for k in 4:
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh()
		ring.material_override = _glow_mat(color, 0.75)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var b := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
		# The ring mesh lies in XZ: turn it to face along the flight.
		b = b * Basis(Vector3.RIGHT, PI * 0.5)
		ring.global_transform = Transform3D(b.scaled(Vector3.ONE * 0.6), from)
		ring.visible = false
		var tw := ring.create_tween()
		tw.tween_interval(k * 0.09)
		tw.tween_callback(func() -> void: ring.visible = true)
		tw.tween_method(func(t: float) -> void:
			ring.global_transform = Transform3D(b.scaled(Vector3.ONE * lerpf(0.8, radius * 0.6, t)), from.lerp(to, t))
			(ring.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.85, 0.35, t), 0.0, 1.0, flight)
		tw.tween_callback(ring.queue_free)
	# The burst where it lands: a flat ring racing out over the ground.
	get_tree().create_timer(flight).timeout.connect(func() -> void:
		var burst := MeshInstance3D.new()
		burst.mesh = _ring_mesh()
		burst.material_override = _glow_mat(color, 0.9)
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		burst.global_position = to + Vector3.UP * 0.6
		burst.scale = Vector3.ONE * 0.3
		var tw := burst.create_tween().set_parallel(true)
		tw.tween_property(burst, "scale", Vector3(radius, 1.0, radius), 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(burst.material_override, "albedo_color:a", 0.0, 0.45)
		tw.chain().tween_callback(burst.queue_free))


static var _ring: ArrayMesh


## A flat glowing band (radius 1, in the XZ plane).
static func _ring_mesh() -> ArrayMesh:
	if _ring != null:
		return _ring
	var st := MeshKit.begin()
	var n := 40
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		MeshKit.quad(st, p0 * 0.82, p1 * 0.82, p1 * 1.0, p0 * 1.0, Vector3.UP, Color.WHITE)
		MeshKit.quad(st, p0 * 1.0, p1 * 1.0, p1 * 0.82, p0 * 0.82, Vector3.DOWN, Color.WHITE)
	_ring = MeshKit.finish(st)
	return _ring


static func _glow_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.no_depth_test = false
	return m


## A soft glowing blob (a telegraph light on a boss's body). Attach it to the bug.
static func glow_blob(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Sets a glow_blob's brightness (0..1).
static func set_glow(mi: MeshInstance3D, k: float) -> void:
	if mi == null:
		return
	var m := mi.material_override as StandardMaterial3D
	m.albedo_color.a = clampf(k, 0.0, 1.0)
	mi.visible = k > 0.01


# ------------------------------------------------------------------ small effects (local)

func pop(pos: Vector3, color: Color, size: float) -> void:
	if VfxPool.instance != null:
		VfxPool.instance.pop(pos, color, size)


func dust(pos: Vector3, dir: Vector3, size: float, _tint: Color = Color.WHITE) -> void:
	if VfxPool.instance != null:
		VfxPool.instance.dust_burst(pos, dir, size)


func shake(pos: Vector3, strength: float) -> void:
	if VfxPool.instance != null:
		VfxPool.instance.shake_requested.emit(pos, strength)


func lob(from: Vector3, to: Vector3, flight: float, color: Color) -> void:
	if VfxPool.instance != null:
		VfxPool.instance.lob(from, to, flight, color)


func rocks(pos: Vector3, size: float) -> void:
	if VfxPool.instance != null:
		VfxPool.instance.shell_crack(pos, Palette.ROCK_C, size)
		VfxPool.instance.dust_burst(pos, Vector3.UP, size)


# ------------------------------------------------------------------ textures

## A white ring with soft edges, tick marks and a faint fill (tinted by the decal).
static func ring_texture() -> ImageTexture:
	if _ring_tex != null:
		return _ring_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / float(n) * 2.0 - Vector2.ONE
			var r := p.length()
			var a := 0.0
			# The bold outer band.
			a = maxf(a, 1.0 - smoothstep(0.035, 0.07, absf(r - 0.9)))
			# A thinner inner band.
			a = maxf(a, 0.7 * (1.0 - smoothstep(0.012, 0.03, absf(r - 0.62))))
			# Twelve ticks round the edge.
			var ang := atan2(p.y, p.x)
			var tick := absf(fposmod(ang / TAU * 12.0, 1.0) - 0.5)
			if r > 0.72 and r < 0.86 and tick > 0.46:
				a = maxf(a, 0.8)
			# A faint fill.
			if r < 0.88:
				a = maxf(a, 0.12)
			if r > 0.99:
				a = 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## Dark branching cracks radiating from the middle, on a transparent ground.
static func crack_texture() -> ImageTexture:
	if _crack_tex != null:
		return _crack_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var ink := Color(0.16, 0.09, 0.06, 0.95)
	var rim := Color(0.45, 0.3, 0.2, 0.5)
	for k in 11:
		var a := TAU * float(k) / 11.0 + rng.randf_range(-0.2, 0.2)
		_crack(img, rng, Vector2(n, n) * 0.5, a, n * rng.randf_range(0.32, 0.48), 4.0, ink, rim, 2)
	# A dark hole in the middle.
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(Vector2(n, n) * 0.5)
			if d < 16.0:
				img.set_pixel(x, y, Color(0.1, 0.06, 0.04, clampf((16.0 - d) / 6.0, 0.0, 1.0) * 0.95))
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex


static func _crack(img: Image, rng: RandomNumberGenerator, from: Vector2, angle: float, length: float, width: float,
		ink: Color, rim: Color, depth: int) -> void:
	var p := from
	var a := angle
	var steps := int(length / 3.0)
	for i in steps:
		a += rng.randf_range(-0.35, 0.35)
		var q := p + Vector2(cos(a), sin(a)) * 3.0
		var w := width * (1.0 - float(i) / float(steps)) + 0.8
		for s in 4:
			var m := p.lerp(q, float(s) / 4.0)
			for dy in range(-int(w) - 1, int(w) + 2):
				for dx in range(-int(w) - 1, int(w) + 2):
					var x := int(m.x) + dx
					var y := int(m.y) + dy
					if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
						continue
					var d := Vector2(dx, dy).length()
					if d <= w:
						img.set_pixel(x, y, ink)
					elif d <= w + 1.5 and img.get_pixel(x, y).a < 0.3:
						img.set_pixel(x, y, rim)
		p = q
		if depth > 0 and rng.randf() < 0.06:
			_crack(img, rng, p, a + rng.randf_range(-1.0, 1.0), length * 0.4, w * 0.6, ink, rim, depth - 1)


## The Acid Matriarch's acid: how far a Water Cannon's spray reaches.
class AcidWash:
	const RADIUS := 10.0
