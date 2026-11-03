class_name SiteProps
extends RefCounted
## Lays out each raid site's props, colliders, traps and lights under its root
## (Canyon Expeditions). The root sits at the site's centre turned to its frame
## (local +Z out from the canyon wall); every prop is dropped onto the real
## floor. Loot spots (SitePlan.SPOTS) are kept clear. Also the railroad wreck's
## collapse: the trestles come down and timbers fall from above.

## Seconds a falling timber takes to land.
const TIMBER_FALL := 0.9

static var _cache: Dictionary = {}


static func _mesh(key: String, make: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## A mesh at local (x, z), dropped onto the ground, turned `yaw`, plus an extra
## tilt and lift.
static func _put(root: Node3D, mgr: SiteManager, mesh: ArrayMesh, local: Vector2, yaw: float = 0.0,
		tilt: Basis = Basis(), lift: float = 0.0, scale: float = 1.0, outline: float = 0.02) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Materials.toon(outline)
	root.add_child(mi)
	var w := root.global_transform * Vector3(local.x, 0.0, local.y)
	mi.position = Vector3(local.x, mgr.ground_at(w) - root.global_position.y + lift, local.y)
	mi.basis = (Basis(Vector3.UP, yaw) * tilt).scaled(Vector3.ONE * scale)
	return mi


## A solid box (players and shots stop on it) in the root's frame.
static func _solid(root: Node3D, mgr: SiteManager, local: Vector2, size: Vector3, yaw: float = 0.0, lift: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WorldLayout.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	var w := root.global_transform * Vector3(local.x, 0.0, local.y)
	body.position = Vector3(local.x, mgr.ground_at(w) - root.global_position.y + size.y * 0.5 + lift, local.y)
	body.rotation.y = yaw
	return body


static func _light(root: Node3D, local: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.position = local
	root.add_child(l)
	return l


static func build(root: Node3D, site: SitePlan.Site, mgr: SiteManager) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = site.seed
	# Every site gets a soft fill so it reads in the canyon's shadow.
	_light(root, Vector3(0, 7.0, 1.0), Color("#FFE2B8"), 0.7, 16.0)
	match site.kind:
		SitePlan.Kind.MOUTH:
			_mouth(root, site, mgr, rng)
		SitePlan.Kind.BONEYARD:
			_boneyard(root, site, mgr, rng)
		SitePlan.Kind.CAMP:
			_camp(root, site, mgr, rng)
		SitePlan.Kind.NEST:
			_nest(root, site, mgr, rng)
		SitePlan.Kind.WRECK:
			_wreck(root, site, mgr, rng)


static func _rocks(root: Node3D, mgr: SiteManager, rng: RandomNumberGenerator, spots: Array) -> void:
	for p: Vector2 in spots:
		var r := rng.randi() % 4
		_put(root, mgr, _mesh("rock%d" % r, PropBuilder.rock.bind(r + 40, 1.0)), p, rng.randf() * TAU, Basis(), -0.2, rng.randf_range(0.7, 1.3))


static func _mouth(root: Node3D, site: SitePlan.Site, mgr: SiteManager, rng: RandomNumberGenerator) -> void:
	_put(root, mgr, _mesh("shoring", SiteBuilder.shoring.bind(7, 5.6, 4.4)), Vector2(0, -3.9))
	for s: float in [-1.0, 1.0]:
		_solid(root, mgr, Vector2(s * 2.65, -3.9), Vector3(0.35, 4.4, 0.35))
	# A tipped ore cart (a rail car, cut down), spilling its load.
	_put(root, mgr, _mesh("cart", SiteBuilder.rail_car.bind(55)), Vector2(-3.6, 0.6), 0.5, Basis(Vector3.BACK, 1.25), 0.45, 0.42)
	_solid(root, mgr, Vector2(-3.6, 0.6), Vector3(1.2, 1.0, 2.3), 0.5)
	_put(root, mgr, _mesh("husk1", SiteBuilder.husk.bind(1)), Vector2(2.9, -1.2), rng.randf() * TAU, Basis(), 0.0, 1.3)
	_put(root, mgr, _mesh("husk2", SiteBuilder.husk.bind(2)), Vector2(1.1, 3.4), rng.randf() * TAU, Basis(Vector3.BACK, 0.4), 0.0, 1.0)
	_rocks(root, mgr, rng, [Vector2(-4.6, -2.6), Vector2(4.7, 2.2), Vector2(-4.0, 4.4)])
	# The lantern on the shoring, and the dark hole's cold breath.
	_light(root, Vector3(-2.75, 2.5, -3.4), Color("#FFB45A"), 2.2, 10.0)


static func _boneyard(root: Node3D, site: SitePlan.Site, mgr: SiteManager, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.35, 0.35)
	_put(root, mgr, _mesh("carcass%d" % (site.seed % 3), SiteBuilder.carcass.bind(site.seed % 3 + 700, 11.0)), Vector2(0, -0.5), yaw, Basis(), -0.35)
	# The skull and the spine are solid; you can walk in under the ribs.
	_solid(root, mgr, Vector2(0, -0.5), Vector3(1.0, 1.6, 11.0), yaw)
	var skull := Vector2(0, -0.5) + Vector2(sin(yaw), cos(yaw)) * 7.0
	_solid(root, mgr, skull, Vector3(3.6, 2.6, 3.6), yaw)
	# A second, older carcass half under the sand.
	_put(root, mgr, _mesh("carcass_small", SiteBuilder.carcass.bind(731, 6.5)), Vector2(5.6, -2.8), 1.9, Basis(Vector3.BACK, 0.35), -1.0)
	_rocks(root, mgr, rng, [Vector2(-5.6, 5.4), Vector2(5.8, 5.6)])
	_light(root, Vector3(0, 5.0, 2.0), Color("#D8E4FF"), 1.3, 14.0)


static func _camp(root: Node3D, site: SitePlan.Site, mgr: SiteManager, rng: RandomNumberGenerator) -> void:
	for t: Array in [[Vector2(-3.8, -3.2), 0.25, 1], [Vector2(3.1, -4.0), -0.35, 2]]:
		_put(root, mgr, _mesh("tent%d" % int(t[2]), SiteBuilder.tent.bind(int(t[2]) * 13)), t[0], float(t[1]))
		_solid(root, mgr, t[0], Vector3(2.4, 2.0, 3.0), float(t[1]))
	_put(root, mgr, _mesh("table", SiteBuilder.map_table), Vector2(-0.6, 1.0), 0.15)
	_solid(root, mgr, Vector2(-0.6, 1.0), Vector3(1.4, 0.85, 0.8), 0.15)
	_put(root, mgr, _mesh("theodolite", SiteBuilder.theodolite), Vector2(2.3, 1.8), -2.4)
	_put(root, mgr, _mesh("crate_a", SiteBuilder.crate.bind(3, Vector3(1.0, 0.75, 0.75), false)), Vector2(5.0, 0.2), 0.3)
	_put(root, mgr, _mesh("crate_b", SiteBuilder.crate.bind(4, Vector3(0.8, 0.6, 0.6), false)), Vector2(5.0, 0.3), 0.8, Basis(), 0.75)
	_put(root, mgr, _mesh("crate_c", SiteBuilder.crate.bind(5, Vector3(1.0, 0.75, 0.75), true)), Vector2(-5.1, 1.2), -0.4)
	_solid(root, mgr, Vector2(5.0, 0.2), Vector3(1.0, 1.35, 0.8), 0.3)
	_solid(root, mgr, Vector2(-5.1, 1.2), Vector3(1.0, 0.75, 0.75), -0.4)
	_put(root, mgr, _mesh("barrel", PropBuilder.barrel.bind(9)), Vector2(4.2, -1.0))
	_put(root, mgr, _mesh("fire", SiteBuilder.cold_fire.bind(8)), Vector2(-1.4, 3.6))
	for i in 4:
		_put(root, mgr, _mesh("stake", SiteBuilder.survey_stake), Vector2(-4.5 + 3.0 * i, 6.0 + 0.2 * i), rng.randf_range(-0.4, 0.4))
	# The booby traps: two bear traps in the grass and a tripwire guarding the
	# gap between the tents (where the good stuff is).
	var k := 0
	for t: Array in [[Vector2(2.2, 4.0), &"bear"], [Vector2(-3.4, 2.2), &"bear"], [Vector2(-1.8, -4.6), &"wire"]]:
		var trap := SiteTrap.new()
		trap.setup(site.index, k, t[1])
		root.add_child(trap)
		var p: Vector2 = t[0]
		var w := root.global_transform * Vector3(p.x, 0.0, p.y)
		trap.position = Vector3(p.x, mgr.ground_at(w) - root.global_position.y, p.y)
		trap.rotation.y = rng.randf_range(-0.6, 0.6) if t[1] == &"bear" else 0.0
		mgr.register_trap(site.index, k, trap)
		k += 1
	_light(root, Vector3(-0.1, 1.6, 1.0), Color("#FFC870"), 2.0, 9.0)


static func _nest(root: Node3D, site: SitePlan.Site, mgr: SiteManager, rng: RandomNumberGenerator) -> void:
	_put(root, mgr, _mesh("nest%d" % (site.seed % 2), SiteBuilder.nest.bind(site.seed % 2 + 300, 4.6)), Vector2.ZERO, rng.randf() * TAU)
	# A few spare clutches stuck to the rim (just dressing; the loot ones are inside).
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		_put(root, mgr, _mesh("eggs_rim%d" % i, SiteBuilder.egg_cluster.bind(900 + i, 4)), Vector2(cos(a), sin(a)) * 5.2, a, Basis(), 0.3, 0.8)
	_light(root, Vector3(0, 1.4, 0), Color("#A8F060"), 2.0, 9.5)


static func _wreck(root: Node3D, site: SitePlan.Site, mgr: SiteManager, rng: RandomNumberGenerator) -> void:
	_put(root, mgr, _mesh("track", SiteBuilder.track.bind(21, 15.0)), Vector2(0.0, -1.2), PI * 0.5 + 0.08)
	# Number Seven on her side, nose toward the wall, propped on two trestle bents.
	var loco := _put(root, mgr, _mesh("loco", SiteBuilder.locomotive), Vector2(-0.6, -2.6), PI * 0.5 + 0.15, Basis(Vector3.BACK, 1.22), 0.95)
	loco.name = "Loco"
	_solid(root, mgr, Vector2(-0.6, -2.6), Vector3(9.0, 2.0, 2.4), 0.15)
	_put(root, mgr, _mesh("tender", SiteBuilder.tender.bind(22)), Vector2(-5.6, -4.4), 0.6, Basis(Vector3.BACK, 0.5), 0.2)
	_solid(root, mgr, Vector2(-5.6, -4.4), Vector3(2.4, 2.0, 3.8), 0.6)
	_put(root, mgr, _mesh("car_a", SiteBuilder.rail_car.bind(23)), Vector2(3.0, 3.2), 0.35, Basis(Vector3.BACK, 0.12), 0.0)
	_solid(root, mgr, Vector2(3.0, 3.2), Vector3(2.3, 2.0, 5.4), 0.35)
	_put(root, mgr, _mesh("car_b", SiteBuilder.rail_car.bind(24)), Vector2(-3.6, 2.6), -0.5, Basis(Vector3.BACK, 1.45), 1.1)
	_solid(root, mgr, Vector2(-3.6, 2.6), Vector3(2.0, 2.2, 5.4), -0.5)
	# The trestle bents holding her up (they come down in a collapse).
	var standing := Node3D.new()
	standing.name = "Standing"
	root.add_child(standing)
	for b: Array in [[Vector2(-2.6, -0.4), 0.2, 0.2], [Vector2(2.4, -0.6), -0.15, -0.25]]:
		var mi := _put(root, mgr, _mesh("bent%d" % int(b[1] * 10.0), SiteBuilder.trestle_bent.bind(30, 3.6)), b[0], float(b[1]), Basis(Vector3.RIGHT, float(b[2])))
		mi.reparent(standing)
	# Fallen timbers already lying about, and the heap a collapse leaves.
	for i in 4:
		var p := Vector2(rng.randf_range(-5.5, 5.5), rng.randf_range(-1.0, 6.0))
		_put(root, mgr, _mesh("timber%d" % (i % 2), SiteBuilder.timber.bind(40 + i % 2)), p, rng.randf() * TAU, Basis(), 0.16)
	var rubble := Node3D.new()
	rubble.name = "Rubble"
	rubble.visible = false
	root.add_child(rubble)
	for i in 8:
		var p := Vector2(rng.randf_range(-4.5, 4.5), rng.randf_range(-2.0, 5.0))
		var mi := _put(root, mgr, _mesh("timber%d" % (i % 2), SiteBuilder.timber.bind(40 + i % 2)), p, rng.randf() * TAU, Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), 0.2)
		mi.reparent(rubble)
	_light(root, Vector3(2.0, 1.6, -1.0), Color("#FFD890"), 1.8, 10.0)
	_light(root, Vector3(-2.0, 2.4, 3.0), Color("#FFB070"), 1.2, 9.0)


## Shows a wreck as it stands after a collapse (state sync, no animation).
static func set_collapsed(root: Node3D, on: bool) -> void:
	var standing := root.get_node_or_null("Standing") as Node3D
	var rubble := root.get_node_or_null("Rubble") as Node3D
	if standing == null or rubble == null:
		return
	standing.visible = not on
	rubble.visible = on


## Every peer: the wreck comes down. Timbers drop out of the sky onto `drops`
## (world points) and land in dust; then the rubble stays till the refill.
static func collapse(root: Node3D, drops: Array, vfx: VfxPool) -> void:
	var standing := root.get_node_or_null("Standing") as Node3D
	if standing != null:
		var tw := root.create_tween()
		tw.tween_property(standing, "rotation:z", 0.6, TIMBER_FALL * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: set_collapsed(root, true))
	Audio.play_at(&"ground_rumble", root.global_position, 6.0, 0.8)
	var mesh := SiteBuilder.timber(41)
	var mat := Materials.toon(0.02)
	for at: Vector3 in drops:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		root.get_parent().add_child(mi)
		var rng_yaw := fmod(at.x * 13.7 + at.z * 7.1, TAU)
		mi.global_position = at + Vector3(0, 9.0, 0)
		mi.rotation = Vector3(0.6, rng_yaw, 0.3)
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", at + Vector3(0, 0.2, 0), TIMBER_FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(mi, "rotation", Vector3(0.0, rng_yaw, PI * 0.5), TIMBER_FALL)
		tw.tween_callback(func() -> void:
			Audio.play_at(&"hammer_hit", at, 6.0, 0.5)
			if vfx != null:
				vfx.dust_burst(at, Vector3.UP, 1.4)
				vfx.splinters(at, 1.2))
		tw.tween_interval(6.0)
		tw.tween_callback(mi.queue_free)
	if vfx != null:
		vfx.shake_requested.emit(root.global_position, 0.6)
