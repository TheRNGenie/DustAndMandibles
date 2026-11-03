class_name AmberFx
extends RefCounted
## What hive amber looks like in play (every peer, local only): the Amber Kiln's
## statues and their shattering, the molten splat, the Queen's Bell's toll ring
## and the frenzy mark, and the Mandible Lance's beam material.

static var _shell_mat: StandardMaterial3D
static var _ring_mat: StandardMaterial3D
static var _beam_mat: StandardMaterial3D
static var _beam_core_mat: StandardMaterial3D


## A lumpy, glassy blob of resin a bit bigger than the bug (local origin at its middle).
static func shell_mesh(body_radius: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var r := maxf(body_radius, 0.25)
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3(r * 1.35, r * 1.05, r * 1.55), 7, 14, AmberRules.COLOR, 0.12, rng)
	# Drips and knuckles of resin on the outside.
	for i in 6:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r * 1.1, rng.randf_range(-0.5, 0.6) * r, sin(a) * r * 1.3)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * r * rng.randf_range(0.25, 0.45), 4, 8, AmberRules.COLOR.lerp(AmberRules.DEEP, 0.3), 0.15, rng)
	for i in 3:
		var a := rng.randf() * TAU
		var top := Vector3(cos(a) * r * 0.9, -r * 0.6, sin(a) * r * 1.1)
		MeshKit.add_cylinder(st, Transform3D(Basis(), top + Vector3(0, -r * 0.3, 0)), r * 0.05, r * 0.14, r * 0.6, 6, AmberRules.COLOR)
	return MeshKit.finish(st)


static func shell_material() -> StandardMaterial3D:
	if _shell_mat == null:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(AmberRules.COLOR, 0.62)
		m.vertex_color_use_as_albedo = false
		m.roughness = 0.12
		m.metallic_specular = 0.9
		m.emission_enabled = true
		m.emission = AmberRules.GLOW
		m.emission_energy_multiplier = 0.55
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.6
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_shell_mat = m
	return _shell_mat


## A statue shimmers a little (the light catching it): a slow scale breath.
static func set_pulse(mi: MeshInstance3D) -> void:
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.03, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)


## The statue goes: shattered (shards and a flash, a coin-ish ring for the
## loot) or crumbling to dull dust.
static func shatter(at_node: Node, at: Vector3, radius: float, shattered: bool) -> void:
	var vfx := Turret.vfx
	if vfx != null and is_instance_valid(vfx):
		if shattered:
			vfx.shell_crack(at, AmberRules.COLOR, maxf(radius * 1.6, 0.6))
			vfx.pop(at, AmberRules.GLOW, maxf(radius, 0.5))
			for i in 4:
				vfx.spark(at, Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized(), AmberRules.GLOW)
		else:
			vfx.shell_crack(at, AmberRules.DEEP, maxf(radius * 1.2, 0.5))
	if at_node != null and at_node.is_inside_tree():
		Audio.play_at(&"loot_crack" if shattered else &"salvage", at)
		if shattered:
			Audio.play_at(&"coin", at, -6.0)


## Molten amber landing on the wall: a hot gold splash and a smear.
static func splat(vfx: VfxPool, at: Vector3, normal: Vector3, radius: float) -> void:
	if vfx == null:
		return
	vfx.pop(at, AmberRules.COLOR, radius * 0.6)
	vfx.pop(at, AmberRules.GLOW.lightened(0.2), radius * 0.35)
	for i in 5:
		vfx.spark(at, (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.3, 0.9), randf_range(-0.8, 0.8))).normalized(), AmberRules.GLOW)


# ------------------------------------------------------------------ Queen's Bell

## An expanding ring of amber light out from `center` (a toll), fading as it goes.
static func toll_ring(parent: Node, center: Vector3, radius: float, up: Vector3 = Vector3.UP, seconds: float = 1.1) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	mi.mesh = torus
	mi.material_override = _ring().duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3.ONE * 0.5), center)
	var mat := mi.material_override as StandardMaterial3D
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_method(func(s: float) -> void:
		if is_instance_valid(mi):
			mi.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3(s, maxf(s * 0.15, 0.5), s)), center), 0.5, radius, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func _ring() -> StandardMaterial3D:
	if _ring_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(AmberRules.GLOW, 0.85)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_mat = m
	return _ring_mat


## The mark over a frenzied bug: an angry amber "!!" that throbs, gone when the frenzy ends.
static func frenzy_mark() -> Label3D:
	return FrenzyMark.new()


static func pulse_mark(_l: Label3D) -> void:
	pass


class FrenzyMark:
	extends Label3D

	var _t := 0.0

	func _init() -> void:
		text = "!!"
		font_size = 96
		pixel_size = 0.013
		outline_size = 18
		modulate = Color("#FF7A1E")
		outline_modulate = Color("#2B1B17")
		billboard = BaseMaterial3D.BILLBOARD_ENABLED
		no_depth_test = true
		fixed_size = false

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		scale = Vector3.ONE * (1.0 + 0.18 * sin(_t * 14.0))
		modulate = Color("#FF7A1E").lerp(AmberRules.GLOW, 0.5 + 0.5 * sin(_t * 9.0))
		if Time.get_ticks_msec() > int(get_meta(&"until", 0)):
			visible = false


# ------------------------------------------------------------------ Mandible Lance

## The beam's glowing outer sheath and white-hot core.
static func beam_material(core: bool) -> StandardMaterial3D:
	if core and _beam_core_mat != null:
		return _beam_core_mat
	if not core and _beam_mat != null:
		return _beam_mat
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color("#FFF4C8", 0.95) if core else Color(AmberRules.COLOR.lightened(0.1), 0.55)
	if core:
		_beam_core_mat = m
	else:
		_beam_mat = m
	return m
