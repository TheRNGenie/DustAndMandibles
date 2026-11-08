class_name ArmorySecondaryFx
extends RefCounted
## Every peer: the secondaries' visuals (ArmoryEffects.play_fx). Returns false
## for a kind that isn't one of these. What a, b and x mean for each kind is
## listed at the top of ArmorySecondaryRules. Everything here is cheap and
## frees itself: pooled puffs for the sprays, one-shot particles, a few simple
## meshes and lights driven by tweens.

## Puff emitters kept per spray (the sprays fire ten times a second).
const PUFF_POOL := 6
## Most chain links drawn on one stretch of chain.
const MAX_LINKS := 70
## Metres per chain link.
const LINK := 0.32
## Caltrops scattered per square metre of patch (and the most on one patch).
const CALTROP_DENSITY := 0.55
const CALTROP_MOST := 40

const TAR := Color("#2B2118")
const TAR_SHADE := Color("#0C0906")
const RUST := Color("#D0682C")
const RUST_SHADE := Color("#7A3618")
const PEPPER := Color("#E0482C")
const PEPPER_SHADE := Color("#8A1C10")
const DUST := Color("#E2BE8C")
const DUST_SHADE := Color("#A97E5E")
const SMOKE := Color("#D9D6D0")
const SMOKE_SHADE := Color("#7E7A74")
const GLOW_WORM := Color("#C8FF5A")
const PHOSPHOR := Color("#FFF6D8")
const IRON := Color("#3C3A38")

## Built once per world (VfxPool's puff materials dim at night with it).
static var _pool_ref: Object
static var _mats: Dictionary = {}
static var _puffs: Dictionary = {}
static var _next_puff: Dictionary = {}
## Caltrop patches on show (sec_caltrops_clear lifts the nearest).
static var _patches: Array[Node3D] = []


static func play(kind: StringName, a: Vector3, b: Vector3, x: float) -> bool:
	match kind:
		&"sec_tar":
			_spray(kind, a, b, x, TAR, TAR_SHADE, -3.5)
		&"sec_rust":
			_spray(kind, a, b, x, RUST, RUST_SHADE, 0.2)
		&"sec_scream":
			_scream(a, x)
		&"sec_flash":
			_flash(a, b, x)
		&"sec_pepper":
			_pepper(a, x)
		&"sec_concuss":
			_concuss(a, b, x)
		&"sec_chain":
			_chain(a, b, x)
		&"sec_lure":
			_lure(a, b, x)
		&"sec_caltrops":
			_caltrops(a, b, x)
		&"sec_caltrops_clear":
			_clear_caltrops(a)
		&"sec_phosphor":
			_phosphor(a, b, x)
		_:
			return false
	return true


# ------------------------------------------------------------------ helpers

static func _pool() -> VfxPool:
	var p := VfxPool.instance if is_instance_valid(VfxPool.instance) else null
	if p != _pool_ref:
		_pool_ref = p
		_mats.clear()
		_puffs.clear()
		_next_puff.clear()
	return p


## Where visuals go: the effects pool, or the current scene.
static func _parent() -> Node:
	var p := _pool()
	if p != null and p.is_inside_tree():
		return p
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null


static func _add(n: Node3D, at: Vector3) -> bool:
	var parent := _parent()
	if parent == null:
		n.free()
		return false
	parent.add_child(n)
	n.global_position = at
	return true


## Frees `n` after `seconds` (it must be in the tree).
static func _free_after(n: Node, seconds: float) -> void:
	n.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


## A soft cartoon puff material (shared per colour; dims at night with the pool's).
static func _puff_mat(tint: Color, shade: Color) -> Material:
	var key := "puff%s" % tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var p := _pool()
	var m: Material
	if p != null:
		m = p.puff_material(tint, shade)
	else:
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.albedo_color = tint
		m = sm
	_mats[key] = m
	return m


## An unshaded, optionally additive, see-through material.
static func _flat_mat(color: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	return m


## Lit iron (chains, caltrops), shared.
static func _iron() -> StandardMaterial3D:
	if not _mats.has("iron"):
		var m := StandardMaterial3D.new()
		m.albedo_color = IRON
		m.metallic = 0.7
		m.roughness = 0.45
		_mats["iron"] = m
	return _mats["iron"]


## A basis whose Y is `up` (unit).
static func _up_basis(up: Vector3) -> Basis:
	var n := up.normalized() if up.length() > 0.01 else Vector3.UP
	var side := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var xa := n.cross(side).normalized()
	return Basis(xa, n, xa.cross(n).normalized())


## A one-shot cloud of puffs at `at` that frees itself.
static func _cloud(at: Vector3, dir: Vector3, mat: Material, amount: int, life: float, speed: Vector2,
		spread: float, gravity: float, grow: float, size: float, radius: float) -> void:
	var e := GPUParticles3D.new()
	e.one_shot = true
	e.amount = amount
	e.lifetime = life
	e.explosiveness = 0.85
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	var pm := VfxPool.puff_process(speed, spread, gravity, grow)
	if radius > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	e.draw_pass_1 = quad
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(e, at):
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	e.global_basis = Basis.looking_at(d, up) # emitters spray along -Z
	e.amount_ratio = GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	e.emitting = true
	_free_after(e, life + 0.5)


## An expanding see-through sphere (shock rings, the flash's glare).
static func _bubble(at: Vector3, color: Color, from: float, to: float, seconds: float, additive: bool,
		flatten: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	mi.mesh = s
	var m := _flat_mat(color, additive)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, at):
		return
	mi.scale = flatten * from
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", flatten * to, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## A light that flashes up and dies away over `seconds`.
static func _flash_light(at: Vector3, color: Color, energy: float, reach: float, seconds: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	if not _add(l, at):
		return
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ sprays

## One puff of a spray from the muzzle `at` along `dir` reaching `reach` metres.
static func _spray(kind: StringName, at: Vector3, dir: Vector3, reach: float, tint: Color, shade: Color,
		gravity: float) -> void:
	var p := _pool()
	if p == null or not p.is_inside_tree():
		return
	var pool: Array = _puffs.get(kind, [])
	if pool.is_empty():
		var mat := _puff_mat(tint, shade)
		for i in PUFF_POOL:
			var e := GPUParticles3D.new()
			e.one_shot = true
			e.emitting = false
			e.amount = 7
			e.lifetime = 1.3
			e.explosiveness = 0.7
			e.local_coords = false
			e.visibility_aabb = AABB(Vector3.ONE * -16.0, Vector3.ONE * 32.0)
			e.process_material = VfxPool.puff_process(Vector2(reach * 0.55, reach * 0.95), 16.0, gravity, 3.0)
			var quad := QuadMesh.new()
			quad.size = Vector2(0.6, 0.6)
			quad.material = mat
			e.draw_pass_1 = quad
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(e)
			pool.append(e)
		_puffs[kind] = pool
	var i := int(_next_puff.get(kind, 0))
	_next_puff[kind] = (i + 1) % pool.size()
	var d := dir.normalized()
	# From just in front of and below the eye (where the nozzle is).
	p._fire(pool[i] as GPUParticles3D, at + d * 0.7 + Vector3.DOWN * 0.25, d)


# ------------------------------------------------------------------ bursts

## Screamer: a shriek ring rolling out to the scatter radius.
static func _scream(at: Vector3, radius: float) -> void:
	Audio.play_at(&"queen_shriek", at, -2.0, 1.7)
	_bubble(at, Color(0.75, 0.95, 1.0, 0.45), 0.4, radius, 0.45, true)
	_bubble(at, Color(0.9, 1.0, 1.0, 0.3), 0.2, radius * 0.6, 0.3, true)
	var p := _pool()
	if p != null:
		p.spark(at, Vector3.UP, Palette.GLOW_YELLOW)


## Flashbang: a blinding white glare and a light that lights up the stun radius.
static func _flash(at: Vector3, normal: Vector3, radius: float) -> void:
	Audio.play_at(&"dynamite", at, 0.0, 1.8)
	_bubble(at, Color(1, 1, 1, 0.95), 0.3, radius * 0.45, 0.28, true)
	_bubble(at, Color(1, 1, 0.9, 0.35), 0.5, radius, 0.5, true)
	_flash_light(at, Color(1, 1, 0.95), 18.0, radius * 2.2, 0.55)
	var p := _pool()
	if p != null:
		p.spark(at, normal if normal.length() > 0.01 else Vector3.UP, Palette.GLOW_YELLOW)


## Pepper-Bomb: a red pepper cloud the size of the berserk radius.
static func _pepper(at: Vector3, radius: float) -> void:
	Audio.play_at(&"fuse_sizzle", at, 0.0, 1.4)
	Audio.play_at(&"dynamite", at, -8.0, 1.5)
	var mat := _puff_mat(PEPPER, PEPPER_SHADE)
	_cloud(at, Vector3.UP, mat, 26, 2.8, Vector2(0.8, 2.6), 180.0, 0.15, 3.2, 1.6, radius * 0.45)
	_cloud(at, Vector3.UP, _puff_mat(Color("#F2A040"), Color("#A04A18")), 10, 1.6, Vector2(1.5, 4.0), 180.0, 0.1,
			2.4, 1.0, radius * 0.25)


## Concussion: a dust shockwave rolling down the cone from the muzzle.
static func _concuss(at: Vector3, dir: Vector3, reach: float) -> void:
	var mat := _puff_mat(DUST, DUST_SHADE)
	_cloud(at, dir, mat, 22, 0.9, Vector2(reach * 0.8, reach * 1.4), 14.0, 0.2, 3.4, 0.9, 0.0)
	var mid := at + dir.normalized() * minf(reach * 0.35, 6.0)
	_bubble(mid, Color(1.0, 0.95, 0.85, 0.35), 0.3, 2.4, 0.3, true)
	var p := _pool()
	if p != null:
		p.dust_burst(at + dir.normalized() * 1.5, dir, 1.0)


# ------------------------------------------------------------------ lasting

## Chain Binder: one stretch of chain from `a` to `b` that stays while they're bound.
static func _chain(a: Vector3, b: Vector3, seconds: float) -> void:
	Audio.play_at(&"hook_bite", a, -2.0, 0.85)
	var root := Node3D.new()
	if not _add(root, a):
		return
	var span := b - a
	var count := clampi(int(span.length() / LINK) + 1, 2, MAX_LINKS)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.06
	mesh.outer_radius = 0.13
	mesh.rings = 8
	mesh.ring_segments = 6
	var along := span.normalized() if span.length() > 0.01 else Vector3.UP
	# A link: long along the chain, its hole across it (the torus's axis is its Y).
	var across := _up_basis(along)
	var base := Basis(along * 1.7, across.z, across.x)
	for i in count:
		var link := MeshInstance3D.new()
		link.mesh = mesh
		link.material_override = _iron()
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Each link turned a quarter from the last, sagging a little in the middle.
		var t := float(i) / float(count - 1)
		var sag := Vector3.DOWN * sin(t * PI) * minf(span.length() * 0.06, 0.8)
		var rot := Basis(along, PI * 0.5 * float(i % 2))
		link.transform = Transform3D(rot * base, span * t + sag)
		root.add_child(link)
	var tw := root.create_tween()
	tw.tween_interval(maxf(seconds - 0.3, 0.1))
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(root.queue_free)


## Glow-Worm: a fat glowing grub stuck where it landed, pulsing light for `seconds`.
static func _lure(at: Vector3, normal: Vector3, seconds: float) -> void:
	Audio.play_at(&"pluck", at, 0.0, 0.7)
	var root := Node3D.new()
	if not _add(root, at):
		return
	root.global_basis = _up_basis(normal)
	var grub := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.16
	cap.height = 0.62
	cap.radial_segments = 10
	cap.rings = 4
	grub.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = GLOW_WORM
	m.emission_enabled = true
	m.emission = GLOW_WORM
	m.emission_energy_multiplier = 2.5
	grub.material_override = m
	grub.rotation = Vector3(0.0, 0.0, PI * 0.5) # lying along the surface
	grub.position = Vector3(0, 0.12, 0)
	grub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grub)
	var halo := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	halo.mesh = s
	var hm := _flat_mat(Color(GLOW_WORM.r, GLOW_WORM.g, GLOW_WORM.b, 0.25), true)
	halo.material_override = hm
	halo.position = Vector3(0, 0.12, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = GLOW_WORM
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.shadow_enabled = false
	l.position = Vector3(0, 0.5, 0)
	root.add_child(l)
	var pulses := maxi(int(seconds / 0.5), 1)
	var tw := root.create_tween()
	for i in pulses:
		tw.tween_property(l, "light_energy", 4.5, 0.18)
		tw.parallel().tween_property(halo, "scale", Vector3.ONE * 1.5, 0.18)
		tw.tween_property(l, "light_energy", 1.5, 0.32)
		tw.parallel().tween_property(halo, "scale", Vector3.ONE, 0.32)
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(root.queue_free)


## Caltrops: iron spikes scattered over the patch (b = normal * radius) for `seconds`.
static func _caltrops(at: Vector3, b: Vector3, seconds: float) -> void:
	Audio.play_at(&"hammer_hit", at, -3.0, 1.5)
	var radius := maxf(b.length(), 0.5)
	var root := Node3D.new()
	if not _add(root, at):
		return
	root.global_basis = _up_basis(b)
	var spike := PrismMesh.new()
	spike.size = Vector3(0.12, 0.26, 0.12)
	var count := clampi(int(PI * radius * radius * CALTROP_DENSITY), 8, CALTROP_MOST)
	for i in count:
		# Even-ish over the disc (square root keeps the middle from bunching up).
		var r := sqrt(randf()) * radius
		var ang := randf() * TAU
		var c := Node3D.new()
		c.position = Vector3(cos(ang) * r, 0.08, sin(ang) * r)
		c.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		for axis in [Vector3.ZERO, Vector3(PI, 0, 0), Vector3(PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.5)]:
			var mi := MeshInstance3D.new()
			mi.mesh = spike
			mi.material_override = _iron()
			mi.rotation = axis
			mi.position = Basis.from_euler(axis) * Vector3(0, 0.1, 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.add_child(mi)
		root.add_child(c)
	var p := _pool()
	if p != null:
		p.dust_burst(at, b, 0.7)
	_patches.append(root)
	var tw := root.create_tween()
	tw.tween_interval(maxf(seconds - 0.4, 0.1))
	tw.tween_property(root, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(func() -> void:
		_patches.erase(root)
		root.queue_free())


## A caltrop patch lifted early (its shooter laid another): the one at `at` goes.
static func _clear_caltrops(at: Vector3) -> void:
	_patches = _patches.filter(func(n: Node3D) -> bool: return is_instance_valid(n))
	var best: Node3D = null
	var best_d := 1.0
	for n in _patches:
		var d := n.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		_patches.erase(best)
		best.queue_free()


## Phosphor: a white-hot burning patch with smoke (b = normal * radius) for `seconds`.
static func _phosphor(at: Vector3, b: Vector3, seconds: float) -> void:
	Audio.play_at(&"dynamite", at, -4.0, 1.3)
	Audio.play_at(&"match_strike", at, 0.0, 0.7)
	var radius := maxf(b.length(), 0.5)
	var root := Node3D.new()
	if not _add(root, at):
		return
	root.global_basis = _up_basis(b)
	var ratio := GraphicsQuality.PARTICLE_RATIO[GraphicsQuality.level(Settings.particles)]
	# White-hot flames: star quads rising off a disc.
	var flames := GPUParticles3D.new()
	flames.amount = int(18 + radius * 8.0)
	flames.lifetime = 0.7
	flames.local_coords = false
	flames.visibility_aabb = AABB(Vector3.ONE * -12.0, Vector3.ONE * 24.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.2
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 2.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	flames.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	quad.material = Materials.star(PHOSPHOR, 4.0)
	flames.draw_pass_1 = quad
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.amount_ratio = ratio
	root.add_child(flames)
	# Thick white smoke rolling up off it.
	var smoke := GPUParticles3D.new()
	smoke.amount = int(8 + radius * 2.0)
	smoke.lifetime = 2.6
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 22, 28))
	var sp := VfxPool.puff_process(Vector2(0.6, 1.6), 25.0, 1.2, 3.6)
	sp.direction = Vector3.UP
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = radius * 0.7
	smoke.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(1.6, 1.6)
	sq.material = _puff_mat(SMOKE, SMOKE_SHADE)
	smoke.draw_pass_1 = sq
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.amount_ratio = ratio
	smoke.position = Vector3(0, 0.6, 0)
	root.add_child(smoke)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.92, 0.75)
	l.light_energy = 6.0
	l.omni_range = radius * 2.6
	l.shadow_enabled = false
	l.position = Vector3(0, 1.0, 0)
	root.add_child(l)
	_flash_light(at, Color(1, 1, 0.95), 14.0, radius * 3.0, 0.4)
	flames.emitting = true
	smoke.emitting = true
	var tw := root.create_tween()
	var flickers := maxi(int(seconds / 0.2), 1)
	for i in flickers:
		tw.tween_property(l, "light_energy", randf_range(4.5, 7.5), 0.2)
	tw.tween_callback(func() -> void:
		flames.emitting = false
		smoke.emitting = false)
	tw.tween_property(l, "light_energy", 0.0, 1.0)
	tw.tween_interval(1.8)
	tw.tween_callback(root.queue_free)
