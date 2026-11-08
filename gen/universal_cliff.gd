class_name UniversalCliff
extends RefCounted
## Universal crop-fed turrets: the 10 cliff turrets (Crop Hopper, Harvest
## Mortar, Crop Flak Post, Thresher Post, Homestead Rifle, Rail Driver, Crop
## Cannon, Storm Blower, Snare Launcher, Frontier Sentinel). Models built in
## code in the parts the handoff lists (see UniKit for the conventions and
## UniversalBuilder for the spec), and their animation.


## The id's spec, or {} for one not built yet (UniversalBuilder uses a stand-in).
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"cf_crop_hopper": return _crop_hopper(team)
		&"cf_harvest_mortar": return _harvest_mortar(team)
		&"cf_crop_flak_post": return _crop_flak_post(team)
		&"cf_thresher_post": return _thresher_post(team)
		&"cf_homestead_rifle": return _homestead_rifle(team)
		&"cf_rail_driver": return _rail_driver(team)
		&"cf_crop_cannon": return _crop_cannon(team)
		&"cf_storm_blower": return _storm_blower(team)
		&"cf_snare_launcher": return _snare_launcher(team)
		&"cf_frontier_sentinel": return _frontier_sentinel(team)
	return {}


## Every frame, every peer: pose the id's moving parts (see UniCtx).
static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match id:
		&"cf_crop_hopper": _anim_crop_hopper(rig, ctx, delta)
		&"cf_harvest_mortar": _anim_harvest_mortar(rig, ctx, delta)
		&"cf_crop_flak_post": _anim_crop_flak_post(rig, ctx, delta)
		&"cf_thresher_post": _anim_thresher_post(rig, ctx, delta)
		&"cf_homestead_rifle": _anim_homestead_rifle(rig, ctx, delta)
		&"cf_rail_driver": _anim_rail_driver(rig, ctx, delta)
		&"cf_crop_cannon": _anim_crop_cannon(rig, ctx, delta)
		&"cf_storm_blower": _anim_storm_blower(rig, ctx, delta)
		&"cf_snare_launcher": _anim_snare_launcher(rig, ctx, delta)
		&"cf_frontier_sentinel": _anim_frontier_sentinel(rig, ctx, delta)


# ------------------------------------------------------------------ helpers

## 0..1 that eases out over `dur` seconds after a shot (1 at the shot): recoil.
static func kick_k(age: float, dur: float) -> float:
	if age >= dur:
		return 0.0
	var k := 1.0 - age / dur
	return k * k


## The loading animation's lid / door opening, 0..1: opens over the first 30%,
## stays open, closes over the last 30%.
static func open_k(load_k: float) -> float:
	if load_k >= 1.0:
		return 0.0
	return smoothstep(0.0, 0.3, load_k) * (1.0 - smoothstep(0.7, 1.0, load_k))


# ------------------------------------------------------------------ 1. Crop Hopper

## Brass triple-barrel gun on the shared platform: an open hopper on top at the
## back feeds a belt down into the three barrels.
## Parts: base_platform, turret_body, barrel_assembly (barrel_1..3 on it,
## each with a glowing tip), crop_hopper (+ hopper_lid, hopper_fill), feed_belt.
static func _crop_hopper(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	# Brass housing: an upright drum with iron cheeks holding the barrel trunnion.
	parts.append(UniKit.part("turret_body", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.2, 0.05)), 0.3, 0.27, 0.4, 16, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.41, 0.05)), 0.27, 0.27, 0.03, 16, UniKit.BRASS)
		UniKit.rivet_ring(st, Vector3(0, 0.36, 0.05), 0.285, 12)
		UniKit.rivet_ring(st, Vector3(0, 0.05, 0.05), 0.3, 12)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.2, 0.47, -0.02)), Vector3(0.06, 0.26, 0.24), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.24, 0.45, -0.02)), 0.05, 0.05, 0.04, 10, UniKit.BRASS)
		# A team pennant on the back.
		MeshKit.add_limb(st, Vector3(0.22, 0.3, 0.3), Vector3(0.22, 0.95, 0.32), 0.012, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.22, 0.86, 0.43)), Vector3(0.01, 0.12, 0.2), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.2, 0.05), "r": 0.3, "h": 0.4}}))
	# The barrels: a spinning cluster of three round the gun's axis.
	parts.append(UniKit.part("barrel_assembly", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.0)), 0.13, 0.13, 0.22, 14, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.5)), 0.12, 0.12, 0.04, 14, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.13)), 0.06, 0.08, 0.06, 10, UniKit.BRASS_DK)), Vector3.ZERO))
	for i in 3:
		var a := PI * 0.5 + TAU * i / 3.0
		var off := Vector3(cos(a), sin(a), 0) * 0.075
		parts.append(UniKit.part("barrel_%d" % (i + 1), "barrel_assembly", UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, 0.06, -0.9, 0.035, UniKit.IRON_DK)
			UniKit.band(st, 0, 0, -0.3, 0.045, 0.04)
			UniKit.band(st, 0, 0, -0.78, 0.045, 0.04)), off))
		parts.append(UniKit.part("barrel_%d_glow" % (i + 1), "barrel_%d" % (i + 1), UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, -0.87, 0.04, 0.05)), Vector3.ZERO, Basis(), {"glow": true}))
	# The open hopper on the back, with its lid hinged at the back edge and the crop inside.
	var hop := Vector3(0, 0.58, 0.2)
	parts.append(UniKit.part("crop_hopper", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.lathe(st, Transform3D(), [Vector2(0.06, -0.14), Vector2(0.1, -0.06), Vector2(0.2, 0.1), Vector2(0.21, 0.13)], 14, UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.13, 0)), 0.225, 0.19, 0.03, 14, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.2, 0)), Vector3(0.06, 0.12, 0.06), UniKit.IRON)), hop))
	parts.append(UniKit.part("hopper_fill", "crop_hopper", UniKit.mesh(func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.17, 0.18, 0.04, 14, Color(0.85, 0.85, 0.85))
		for k in 22:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.16
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * r, 0.1, sin(a) * r)), Vector3(0.022, 0.016, 0.022), 2, 5,
					Color(1, 1, 1) if k % 2 == 0 else Color(0.8, 0.8, 0.78))), Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("hopper_lid", "crop_hopper", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.0, -0.21)), 0.215, 0.215, 0.025, 14, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.025, -0.36)), Vector3(0.06, 0.03, 0.05), UniKit.BRASS)), Vector3(0, 0.15, 0.21)))
	# The feed belt: links running from the hopper's spout down to the barrels' breech.
	parts.append(UniKit.part("feed_belt", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		for k in 7:
			var p := Vector3(0, 0.0, 0).lerp(Vector3(0, -0.2, -0.16), k / 6.0)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.9), p), Vector3(0.08, 0.025, 0.04), UniKit.BRASS_DK if k % 2 == 0 else UniKit.IRON_LT)),
		Vector3(0, 0.39, 0.13)))
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.45, "parts": parts,
		"muzzles": [["barrel_1", Vector3(0, 0, -0.92)], ["barrel_2", Vector3(0, 0, -0.92)], ["barrel_3", Vector3(0, 0, -0.92)]],
		"pour": hop + Vector3(0, 0.35, 0), "ring_r": 0.85}


## Barrels fire in turn (1, 2, 3), each kicking back 2 cm and springing back in
## 0.08 s; the cluster turns a third per shot, 15% quicker after 3 s of fire.
## The belt steps with each shot; the hopper lid opens while loading.
static func _anim_crop_hopper(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var spin := float(rig.state.get("spin", 0.0))
	var speed := float(rig.state.get("speed", 0.0))
	var want := 0.0
	if ctx.firing > 0.0 and ctx.shot_age < 0.4:
		want = 9.0 * (1.15 if ctx.firing > 3.0 else 1.0)
	speed = move_toward(speed, want, delta * (30.0 if want > speed else 8.0))
	spin += speed * delta
	rig.state["spin"] = spin
	rig.state["speed"] = speed
	rig.turn("barrel_assembly", Vector3.BACK, spin)
	var fired := ctx.shots % 3
	for i in 3:
		rig.kick("barrel_%d" % (i + 1), 0.02 * kick_k(ctx.shot_age, 0.08) if i == fired else 0.0)
	rig.pose("feed_belt", Vector3(0, 0, -0.025 * kick_k(ctx.shot_age, 0.1)))
	rig.turn("hopper_lid", Vector3.RIGHT, PI * 0.5 * open_k(ctx.load_k))


# ------------------------------------------------------------------ shared bits (turrets 2-10)

## Adds a part whose mesh `fill` writes into a fresh SurfaceTool. `opts` may hold
## "basis" and any UniKit.part extras ("glow", "crop", "trim").
static func _add(parts: Array, name: String, parent: String, pos: Vector3, opts: Dictionary, fill: Callable) -> void:
	var extra := opts.duplicate()
	var b: Basis = extra.get("basis", Basis())
	extra.erase("basis")
	parts.append(UniKit.part(name, parent, UniKit.mesh(fill), pos, b, extra))


## The gun pivot's pitch right now (radians, + = up): elevation gears and screws
## follow it. (UniRig.holders[2] is the gun pivot's visual holder.)
static func _gun_pitch(rig: UniRig) -> float:
	if rig.holders.size() < 3:
		return 0.0
	var g := rig.holders[2].get_parent() as Node3D
	return g.rotation.x if g != null else 0.0


## Part `n` at its rest pose scaled by `s` in its own axes and moved by `offset`
## (parent space). Crop parts are tucked away with a near-zero scale rather than
## hidden, since UniRig.set_crop sets their visibility.
static func _lscale(rig: UniRig, n: String, s: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var p: Node3D = rig.part(n)
	if p == null:
		return
	var r: Transform3D = rig.rest[n]
	p.transform = Transform3D(r.basis * Basis.from_scale(s), r.origin + offset)


## A ring part puffing out along -Z after a shot (smoke ring, shockwave): it
## travels `dist` m and grows to `grow` times over `dur` s, then shrinks away.
static func _puff(rig: UniRig, n: String, age: float, dur: float, dist: float, grow: float) -> void:
	if age >= dur:
		_lscale(rig, n, Vector3.ONE * 0.001)
		return
	var k := age / dur
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var fade := 1.0 - smoothstep(0.7, 1.0, k)
	_lscale(rig, n, Vector3.ONE * maxf(lerpf(0.8, grow, e) * fade, 0.001), Vector3(0, 0, -dist * e))


## A flared bell mouth along -Z from z0 (radius r0) to z1 (radius r1) on (x, y),
## with an inside wall so it reads hollow from the front.
static func _bell(st: SurfaceTool, x: float, y: float, z0: float, z1: float, r0: float, r1: float, wall: float, color: Color, segments: int = 14) -> void:
	var l := z0 - z1
	var ra := lerpf(r0, r1, 0.25)
	var rb := lerpf(r0, r1, 0.7)
	var prof: Array = [Vector2(r0, 0.0), Vector2(ra, l * 0.55), Vector2(rb, l * 0.88), Vector2(r1, l),
		Vector2(r1 - wall, l), Vector2(rb - wall, l * 0.88), Vector2(ra - wall, l * 0.55), Vector2(r0 - wall, l * 0.02)]
	MeshKit.lathe(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(x, y, z0)), prof, segments, color)


## A toothed gear round xf's local Y, with a brass hub.
static func _gear(st: SurfaceTool, xf: Transform3D, r: float, width: float, teeth: int, color: Color) -> void:
	MeshKit.add_cylinder(st, xf, r, r, width, 16, color)
	for i in teeth:
		var a := TAU * i / float(teeth)
		MeshKit.add_box(st, xf * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (r + 0.01)), Vector3(0.026, width, 0.022), color)
	MeshKit.add_cylinder(st, xf, r * 0.35, r * 0.35, width + 0.02, 10, UniKit.BRASS)


## A hand / valve wheel round xf's local Y: a rim, two crossed spokes and a hub.
static func _wheel(st: SurfaceTool, xf: Transform3D, r: float, color: Color) -> void:
	MeshKit.add_rim(st, xf, r, r - 0.02, 0.022, 16, color)
	for i in 2:
		MeshKit.add_box(st, xf * Transform3D(Basis(Vector3.UP, PI * 0.5 * i), Vector3.ZERO), Vector3(r * 2.0 - 0.02, 0.014, 0.016), color)
	MeshKit.add_cylinder(st, xf, 0.022, 0.022, 0.04, 8, UniKit.IRON_DK)


## The iron post the post-mounted guns stand on (on "base": it doesn't turn),
## from the platform up to `top`, with a bolted foot flange and gussets.
static func _post(st: SurfaceTool, top: float, r: float) -> void:
	var y0 := UniKit.PLATFORM_TOP
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, y0 + 0.02, 0)), r + 0.12, r + 0.12, 0.04, 12, UniKit.IRON_DK)
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		UniKit.bolt(st, Vector3(cos(a) * (r + 0.08), y0 + 0.04, sin(a) * (r + 0.08)), Vector3.UP, 0.022, 0.02)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, (y0 + top) * 0.5, 0)), r, r * 0.85, top - y0, 12, UniKit.IRON)
	for i in 4:
		var a := TAU * i / 4.0
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * (r + 0.03), y0 + 0.08, sin(a) * (r + 0.03))), Vector3(0.07, 0.1, 0.02), UniKit.IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, top - 0.04, 0)), r * 0.85 + 0.015, r * 0.85 + 0.015, 0.03, 12, UniKit.BRASS_DK)


## A team pennant on a rod from `foot` (rod height `h`), flying towards +Z.
static func _pennant(st: SurfaceTool, foot: Vector3, h: float, team: Color) -> void:
	MeshKit.add_limb(st, foot, foot + Vector3(0, h, 0.02), 0.011, UniKit.IRON_DK)
	MeshKit.add_box(st, Transform3D(Basis(), foot + Vector3(0, h - 0.08, 0.12)), Vector3(0.01, 0.1, 0.2), team)


## The turntable disc the yoke-mounted guns turn on (head space).
static func _turntable(st: SurfaceTool, r: float) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), r, r, 0.06, 16, UniKit.IRON_DK)
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.055, 0)), r + 0.01, r - 0.03, 0.025, 16, UniKit.BRASS_DK)
	UniKit.rivet_ring(st, Vector3(0, 0.065, 0), r - 0.06, 10)


# ------------------------------------------------------------------ 2. Harvest Mortar

## Squat iron mortar: a wide flared tube set 60 degrees up in a riveted drum
## body, a side chamber (left) behind a hinged door for the crop shell, and an
## elevation gear on the right trunnion meshed with a cranked pinion.
## Parts: base_platform, mortar_body, trunnion, mortar_tube (+ tube_glow,
## smoke_ring), crop_chamber (+ chamber_door with chamber_window,
## chamber_shell), elevation_gear, elevation_pinion.
static func _harvest_mortar(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	# Body: a squat drum with bands, a team stripe and two cheeks for the trunnion.
	_add(parts, "mortar_body", "head", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.14, 0), "r": 0.37, "h": 0.28}}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.14, 0)), 0.38, 0.33, 0.28, 16, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.025, 0)), 0.39, 0.39, 0.05, 16, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.255, 0)), 0.345, 0.34, 0.04, 16, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.15, 0)), 0.362, 0.36, 0.035, 16, team)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.285, 0)), 0.31, 0.3, 0.02, 16, UniKit.IRON_DK)
		UniKit.rivet_ring(st, Vector3(0, 0.205, 0), 0.345, 14)
		UniKit.rivet_ring(st, Vector3(0, 0.085, 0), 0.37, 14)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.25, 0.42, 0)), Vector3(0.07, 0.28, 0.24), UniKit.IRON)
			UniKit.rivet_row(st, Vector3(sx * 0.288, 0.32, -0.09), Vector3(sx * 0.288, 0.32, 0.09), 3)
		# The pinion's bracket behind the right cheek.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.265, 0.54, 0.14)), Vector3(0.04, 0.05, 0.08), UniKit.IRON_DK)
	)
	_add(parts, "trunnion", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.05, 0.05, 0.56, 12, UniKit.BRASS_DK)
	)
	# The tube, 60 degrees up in gun space (the gun pivot stays level when loaded).
	_add(parts, "mortar_tube", "gun", Vector3.ZERO, {"basis": Basis(Vector3.RIGHT, deg_to_rad(60.0))}, func(st: SurfaceTool) -> void:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.06)), Vector3(0.155, 0.155, 0.14), 4, 14, UniKit.IRON_DK)
		UniKit.barrel(st, 0, 0, 0.06, -0.42, 0.15, UniKit.IRON, 16, 0.135)
		_bell(st, 0, 0, -0.42, -0.62, 0.135, 0.2, 0.03, UniKit.IRON_DK, 16)
		UniKit.band(st, 0, 0, -0.02, 0.165, 0.06, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, -0.28, 0.152, 0.04, UniKit.BRASS)
		UniKit.band(st, 0, 0, -0.41, 0.15, 0.03, UniKit.IRON_LT)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.425)), 0.115, 0.115, 0.01, 12, Color(0.08, 0.08, 0.08))
	)
	_add(parts, "tube_glow", "mortar_tube", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.57)), 0.142, 0.11, 0.025, 14, UniKit.GLOW_WHITE)
	)
	_add(parts, "smoke_ring", "mortar_tube", Vector3(0, 0, -0.64), {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.19, 0.13, 0.06, 14, Color(0.95, 0.95, 0.93))
	)
	# The side chamber (left): an open box against the body, the door on its outer face.
	var ch := Vector3(-0.4, 0.16, 0)
	_add(parts, "crop_chamber", "head", ch, {}, func(st: SurfaceTool) -> void:
		for sy: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, sy * 0.095, 0)), Vector3(0.17, 0.02, 0.26), UniKit.IRON_LT)
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, sz * 0.12)), Vector3(0.17, 0.19, 0.02), UniKit.IRON_LT)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.07, 0, 0)), Vector3(0.02, 0.19, 0.24), UniKit.IRON_DK)
		UniKit.rivet_row(st, Vector3(-0.06, 0.107, -0.11), Vector3(-0.06, 0.107, 0.11), 4)
	)
	_add(parts, "chamber_shell", "crop_chamber", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, -0.01)), Vector3(0.06, 0.06, 0.1), 4, 10, Color(1, 1, 1))
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.08)), 0.05, 0.05, 0.03, 10, Color(0.75, 0.75, 0.72))
	)
	# Door hinged on the chamber's front edge; it swings out to the left.
	_add(parts, "chamber_door", "crop_chamber", Vector3(-0.095, 0, -0.12), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.12)), Vector3(0.02, 0.18, 0.24), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.014, -0.05, 0.19)), Vector3(0.015, 0.03, 0.05), UniKit.IRON_DK)
		for sy: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, sy * 0.06, 0)), 0.014, 0.014, 0.05, 6, UniKit.IRON_DK)
	)
	_add(parts, "chamber_window", "chamber_door", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.012, 0.025, 0.12)), Vector3(0.01, 0.07, 0.12), UniKit.GLOW_WHITE)
	)
	# Elevation gear on the right trunnion (turns with the tube), and the cranked
	# pinion behind it on the body that drives it.
	_add(parts, "elevation_gear", "gun", Vector3(0.31, 0, 0), {}, func(st: SurfaceTool) -> void:
		_gear(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.11, 0.03, 14, UniKit.IRON_LT)
	)
	_add(parts, "elevation_pinion", "head", Vector3(0.31, 0.54, 0.16), {}, func(st: SurfaceTool) -> void:
		_gear(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.045, 0.03, 8, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(-0.01, 0, 0)), 0.015, 0.015, 0.1, 6, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.03, 0.04, 0)), Vector3(0.014, 0.09, 0.02), UniKit.IRON)
		MeshKit.add_limb(st, Vector3(0.03, 0.08, 0), Vector3(0.08, 0.08, 0), 0.013, UniKit.WOOD)
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.48, "parts": parts,
		"muzzles": [["mortar_tube", Vector3(0, 0, -0.66)]], "rest_pitch": 0.4,
		"pour": ch + Vector3(-0.15, 0.3, 0), "ring_r": 0.85}


## The tube kicks back 3 cm along its own axis (0.15 s return) and puffs a smoke
## ring; 0.5 s after each shot the elevation gear ticks to re-lay the aim (the
## pinion turns with the gun's pitch and the tick). Loading: the door swings
## open, the shell slides in from the left, the door shuts.
static func _anim_harvest_mortar(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	rig.kick("mortar_tube", 0.03 * kick_k(ctx.shot_age, 0.15))
	_puff(rig, "smoke_ring", ctx.shot_age, 0.5, 0.5, 2.4)
	var tick := 0.0
	if ctx.shots > 0:
		tick = (float(ctx.shots - 1) + smoothstep(0.5, 0.62, ctx.shot_age)) * 0.07
	rig.turn("elevation_gear", Vector3.RIGHT, tick)
	rig.turn("elevation_pinion", Vector3.RIGHT, -(_gun_pitch(rig) + tick) * 2.4)
	rig.turn("chamber_door", Vector3.UP, -1.75 * open_k(ctx.load_k))
	var slide := 1.0 if ctx.load_k >= 1.0 else smoothstep(0.3, 0.6, ctx.load_k)
	rig.pose("chamber_shell", Vector3(-0.3 * (1.0 - slide), 0, 0))


# ------------------------------------------------------------------ 3. Crop Flak Post

## Blunderbuss on a post: a brass bell-mouth barrel with iron bands swivelling
## in a fork on a pivot collar, a drum magazine slung under it with viewing
## slots that show the crop.
## Parts: base_platform, post_body (on the base: it doesn't turn),
## pivot_mechanism (collar, fork and pin), scatter_barrel (+ bell_ring_1/2,
## bell_glow), crop_drum (+ drum_slots), drum_hanger.
static func _crop_flak_post(team: Color) -> Dictionary:
	var parts: Array = []
	var top := 0.44
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "post_body", "base", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.31, 0), "r": 0.1, "h": 0.24}}, func(st: SurfaceTool) -> void:
		_post(st, top, 0.1)
	)
	# The collar turns on the post; the fork holds the barrel's pin.
	_add(parts, "pivot_mechanism", "head", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.035, 0)), 0.14, 0.14, 0.07, 14, UniKit.BRASS)
		UniKit.rivet_ring(st, Vector3(0, 0.07, 0), 0.12, 8)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.085, 0)), Vector3(0.38, 0.035, 0.14), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.17, 0.16, 0)), Vector3(0.045, 0.2, 0.12), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.2, 0.2, 0)), 0.035, 0.035, 0.03, 10, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0, 0.2, 0)), 0.025, 0.025, 0.4, 8, UniKit.BRASS_DK)
		_pennant(st, Vector3(0.0, 0.07, 0.13), 0.55, team)
	)
	# Brass barrel with a flared bell, breech knob and iron bands.
	_add(parts, "scatter_barrel", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.22, 0.08, 0.095, UniKit.IRON_DK, 14)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.25)), Vector3(0.05, 0.05, 0.05), 3, 8, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.045, 0.045, 0.3, 10, UniKit.IRON)
		UniKit.barrel(st, 0, 0, 0.1, -0.5, 0.08, UniKit.BRASS, 14, 0.07)
		_bell(st, 0, 0, -0.5, -0.82, 0.07, 0.21, 0.025, UniKit.BRASS, 16)
		UniKit.band(st, 0, 0, 0.08, 0.1, 0.03, UniKit.IRON)
		UniKit.band(st, 0, 0, -0.5, 0.085, 0.04, UniKit.IRON)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.82)), 0.225, 0.183, 0.03, 16, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.505)), 0.06, 0.06, 0.01, 10, Color(0.08, 0.08, 0.08))
	)
	for i in 2:
		_add(parts, "bell_ring_%d" % (i + 1), "scatter_barrel", Vector3(0, 0, -0.18 - 0.17 * i), {}, func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, 0, 0.088 - i * 0.005, 0.035, UniKit.IRON_DK)
		)
	_add(parts, "bell_glow", "scatter_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.77)), 0.15, 0.115, 0.02, 14, UniKit.GLOW_WHITE)
	)
	# The drum magazine under the barrel: nine viewing slots, grey when empty.
	_add(parts, "drum_hanger", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.07, -0.3)), Vector3(0.05, 0.07, 0.07), UniKit.IRON)
	)
	_add(parts, "crop_drum", "gun", Vector3(0, -0.15, -0.3), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.1, 0.1, 0.2, 18, UniKit.IRON)
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, sz * 0.1)), 0.105, 0.105, 0.025, 18, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.025, 0.025, 0.25, 8, UniKit.BRASS_DK)
		for k in 9:
			var a := TAU * k / 9.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.099), Vector3(0.008, 0.032, 0.13), Color("#7E7C78"))
	)
	_add(parts, "drum_slots", "crop_drum", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		for k in 9:
			var a := TAU * k / 9.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.102), Vector3(0.008, 0.028, 0.12), Color(1, 1, 1) if k % 2 == 0 else Color(0.85, 0.85, 0.82))
	)
	return {"head_y": top, "gun_y": 0.2, "parts": parts,
		"muzzles": [["scatter_barrel", Vector3(0, 0, -0.84)]],
		"pour": Vector3(0, 0.6, -0.3), "ring_r": 0.85}


## A heavy 4 cm kick (0.2 s return) and the iron rings shiver; the drum clicks
## round 40 degrees per shot. Loading: the drum drops 5 cm, fills, rises again.
static func _anim_crop_flak_post(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	rig.kick("scatter_barrel", 0.04 * kick_k(ctx.shot_age, 0.2))
	var shiver := kick_k(ctx.shot_age, 0.35) * sin(ctx.shot_age * 95.0) * 0.12
	for i in 2:
		var s := 1.0 + shiver * (1.0 - i * 0.4)
		_lscale(rig, "bell_ring_%d" % (i + 1), Vector3(s, s, 1.0))
	var clicks := 0.0
	if ctx.shots > 0:
		clicks = float(ctx.shots - 1) + smoothstep(0.0, 0.08, ctx.shot_age)
	rig.pose("crop_drum", Vector3(0, -0.05 * open_k(ctx.load_k), 0), Basis(Vector3.BACK, deg_to_rad(40.0) * clicks))


# ------------------------------------------------------------------ 4. Thresher Post

## Burst gun on a thin post: a nine-chamber revolver drum in an iron frame feeds
## one barrel with brass sights; a glass feed tube runs down from a caged crop
## reservoir behind to a port on the frame.
## Parts: base_platform, post_body (on the base), post_collar (collar and fork),
## gun_frame, drum_mechanism (+ drum_glow), single_barrel (+ barrel_glow),
## crop_reservoir (+ reservoir_fill, reservoir_lid), crop_feed_tube (+ feed_flow).
static func _thresher_post(team: Color) -> Dictionary:
	var parts: Array = []
	var top := 0.42
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "post_body", "base", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.3, 0), "r": 0.075, "h": 0.22}}, func(st: SurfaceTool) -> void:
		_post(st, top, 0.075)
	)
	_add(parts, "post_collar", "head", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.11, 0.11, 0.06, 12, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.075, 0.02)), Vector3(0.34, 0.03, 0.14), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.155, 0.16, 0)), Vector3(0.035, 0.17, 0.1), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.175, 0.23, 0)), 0.03, 0.03, 0.025, 10, UniKit.BRASS)
		# Reservoir bracket up the back, with the team plate on it.
		MeshKit.add_limb(st, Vector3(0, 0.08, 0.09), Vector3(0, 0.4, 0.3), 0.018, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.24, 0.2)), Vector3(0.09, 0.07, 0.012), team)
	)
	# The frame round the drum: recoil shield, top strap, side straps (holding the
	# pivot stubs) and the front plate the barrel screws into.
	_add(parts, "gun_frame", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.135)), Vector3(0.24, 0.26, 0.03), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.135, 0)), Vector3(0.07, 0.025, 0.3), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.07, -0.135)), Vector3(0.12, 0.13, 0.03), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.125, 0, 0)), Vector3(0.02, 0.06, 0.27), UniKit.IRON_DK)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.14, 0, 0)), 0.022, 0.022, 0.04, 8, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.022, 0.022, 0.27, 8, UniKit.BRASS)
		# Feed port on the shield, where the glass tube meets it.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, 0.16)), Vector3(0.05, 0.04, 0.03), UniKit.BRASS)
		UniKit.rivet_row(st, Vector3(-0.1, -0.1, 0.152), Vector3(0.1, -0.1, 0.152), 4)
	)
	_add(parts, "drum_mechanism", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.11, 0.11, 0.2, 18, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.09)), 0.113, 0.113, 0.02, 18, UniKit.BRASS_DK)
		for k in 9:
			var a := TAU * k / 9.0
			var d := Vector3(cos(a), sin(a), 0)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, d * 0.07 + Vector3(0, 0, -0.1)), 0.022, 0.022, 0.006, 8, Color(0.07, 0.07, 0.07))
			var b := TAU * (k + 0.5) / 9.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, b), Vector3(cos(b), sin(b), 0) * 0.108), Vector3(0.008, 0.026, 0.15), UniKit.IRON_LT)
	)
	_add(parts, "drum_glow", "drum_mechanism", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		for k in 9:
			var b := TAU * (k + 0.5) / 9.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, b), Vector3(cos(b), sin(b), 0) * 0.07 + Vector3(0, 0, -0.101)), Vector3(0.03, 0.01, 0.006), UniKit.GLOW_WHITE)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, b), Vector3(cos(b), sin(b), 0) * 0.111), Vector3(0.006, 0.01, 0.13), UniKit.GLOW_WHITE)
	)
	# The barrel, on the top chamber's line.
	_add(parts, "single_barrel", "gun", Vector3(0, 0.07, -0.15), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.0, -0.72, 0.04, UniKit.IRON, 12, 0.036)
		UniKit.band(st, 0, 0, -0.03, 0.05, 0.04, UniKit.BRASS)
		UniKit.band(st, 0, 0, -0.36, 0.045, 0.03, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.722)), 0.02, 0.02, 0.004, 8, Color(0.06, 0.06, 0.06))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, -0.67)), Vector3(0.01, 0.035, 0.03), UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.016, 0.05, -0.08)), Vector3(0.012, 0.03, 0.015), UniKit.BRASS)
	)
	_add(parts, "barrel_glow", "single_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.7, 0.043, 0.04, UniKit.GLOW_WHITE)
	)
	# The reservoir: brass caps and posts round a cage, so the crop shows through.
	var res := Vector3(0, 0.56, 0.36)
	_add(parts, "crop_reservoir", "head", res, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.09, 0)), 0.1, 0.09, 0.03, 12, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.12, 0)), 0.03, 0.04, 0.04, 8, UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.09, 0)), 0.1, 0.08, 0.025, 12, UniKit.BRASS_DK)
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.09, 0, sin(a) * 0.09)), Vector3(0.018, 0.18, 0.018), UniKit.IRON)
	)
	_add(parts, "reservoir_fill", "crop_reservoir", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.015, 0)), 0.08, 0.08, 0.13, 12, Color(0.9, 0.9, 0.88))
		var rng := RandomNumberGenerator.new()
		rng.seed = 44
		for k in 10:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.065
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * r, 0.055, sin(a) * r)), Vector3(0.02, 0.014, 0.02), 2, 5, Color(1, 1, 1))
	)
	_add(parts, "reservoir_lid", "crop_reservoir", Vector3(0, 0.1, 0.1), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.006, -0.1)), 0.1, 0.1, 0.018, 12, UniKit.IRON)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.025, -0.1)), Vector3(0.02, 0.015, 0.02), 2, 6, UniKit.BRASS)
	)
	# The glass feed tube: straight from the reservoir's spout down to the frame's port.
	var a0 := res + Vector3(0, -0.14, -0.02)
	var a1 := Vector3(0, 0.23 + 0.1, 0.16)
	var tl := a0.distance_to(a1)
	var tb := Basis.looking_at((a1 - a0).normalized(), Vector3.UP)
	_add(parts, "crop_feed_tube", "head", a0, {"basis": tb}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.0, -tl, 0.02, UniKit.GLASS, 10)
		UniKit.band(st, 0, 0, -0.015, 0.027, 0.03, UniKit.BRASS)
		UniKit.band(st, 0, 0, -tl + 0.015, 0.027, 0.03, UniKit.BRASS)
	)
	_add(parts, "feed_flow", "crop_feed_tube", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		var z := -0.035
		while z > -tl + 0.07:
			UniKit.barrel(st, 0, 0, z, z - 0.02, 0.023, Color(1, 1, 1), 8)
			z -= 0.04
	)
	return {"head_y": top, "gun_y": 0.23, "parts": parts,
		"muzzles": [["single_barrel", Vector3(0, 0, -0.74)]],
		"pour": res + Vector3(0, 0.3, 0), "ring_r": 0.85}


## Three-shot bursts: the drum steps one chamber (40 degrees) per shot, so 120
## degrees a burst, then clicks back in the pause; the barrel kicks 1.5 cm a
## shot. Crop dashes creep down the feed tube while loaded and the tube swells
## with each burst. Loading: the reservoir lid flips open.
static func _anim_thresher_post(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var step := 0.0
	if ctx.shots > 0:
		var e := smoothstep(0.0, 0.045, ctx.shot_age)
		match ctx.shots % 3:
			1: step = e
			2: step = 1.0 + e
			_: step = (2.0 + e) * (1.0 - smoothstep(0.25, 0.38, ctx.shot_age))
	rig.turn("drum_mechanism", Vector3.BACK, deg_to_rad(40.0) * step)
	rig.kick("single_barrel", 0.015 * kick_k(ctx.shot_age, 0.06))
	var pulse := kick_k(ctx.shot_age, 0.3) if ctx.shots > 0 else 0.0
	_lscale(rig, "crop_feed_tube", Vector3(1.0 + 0.3 * pulse, 1.0 + 0.3 * pulse, 1.0))
	rig.pose("feed_flow", Vector3(0, 0, -fmod(ctx.t * 0.05, 0.04)))
	rig.turn("reservoir_lid", Vector3.RIGHT, 1.6 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 5. Homestead Rifle

## A buffalo rifle on a pivot bracket: heavy wooden stock and forend, a long
## iron barrel with brass bands and sights, the bolt on the left side and an
## open-topped crop breech on top of the receiver with a gate at its back.
## Parts: base_platform, pivot_bracket (turntable and yoke), rifle_stock (the
## recoiling root: receiver, stock, forend), rifle_barrel (+ barrel_tip_glow),
## bolt_mechanism, crop_breech (+ breech_glow, breech_round, breech_gate).
static func _homestead_rifle(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "pivot_bracket", "head", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.28, 0), "size": Vector3(0.27, 0.44, 0.16)}}, func(st: SurfaceTool) -> void:
		_turntable(st, 0.3)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.3, 0.07, 0.16), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.115, 0.3, 0)), Vector3(0.045, 0.46, 0.13), UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.115, 0.2, 0)), Vector3(0.05, 0.05, 0.135), team)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.145, 0.5, 0)), 0.045, 0.045, 0.025, 10, UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.14, 0.12, -0.05), Vector3(sx * 0.14, 0.42, -0.05), 4)
		_pennant(st, Vector3(0.17, 0.07, 0.1), 0.88, team)
	)
	# The rifle itself: receiver on the trunnion pin, wooden stock behind, forend under.
	_add(parts, "rifle_stock", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.05)), Vector3(0.1, 0.1, 0.3), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.03, 0.03, 0.2, 8, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.025, 0.28)), Vector3(0.07, 0.085, 0.18), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.055, 0.38)), Vector3(0.08, 0.13, 0.08), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.06, 0.425)), Vector3(0.085, 0.135, 0.014), UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.055, -0.26)), Vector3(0.075, 0.05, 0.34), UniKit.WOOD_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.055, -0.435)), Vector3(0.08, 0.055, 0.02), UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3(0, -0.075, 0.12)), 0.035, 0.026, 0.012, 8, UniKit.BRASS_DK)
		UniKit.rivet_row(st, Vector3(-0.052, -0.02, -0.07), Vector3(-0.052, -0.02, 0.17), 4)
	)
	_add(parts, "rifle_barrel", "rifle_stock", Vector3(0, 0.01, -0.1), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.0, -0.82, 0.034, UniKit.IRON, 12, 0.027)
		for z: float in [-0.12, -0.42, -0.72]:
			UniKit.band(st, 0, 0, z, 0.042 + z * 0.01, 0.03, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.04, -0.78)), Vector3(0.008, 0.035, 0.025), UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.013, 0.045, -0.06)), Vector3(0.01, 0.035, 0.012), UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.821)), 0.014, 0.014, 0.004, 8, Color(0.06, 0.06, 0.06))
	)
	_add(parts, "barrel_tip_glow", "rifle_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.79, 0.032, 0.035, UniKit.GLOW_WHITE)
	)
	# The bolt on the receiver's left side: it turns up about its own axis and slides back.
	_add(parts, "bolt_mechanism", "rifle_stock", Vector3(-0.055, 0.025, 0.08), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.07, -0.06, 0.02, UniKit.IRON_LT, 10)
		MeshKit.add_limb(st, Vector3(0, 0, 0.04), Vector3(-0.1, -0.01, 0.06), 0.011, UniKit.IRON_LT)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.1, -0.01, 0.06)), Vector3.ONE * 0.025, 3, 8, UniKit.BRASS)
	)
	# The crop breech: an open-topped brass chamber on the receiver's back, the round inside.
	_add(parts, "crop_breech", "rifle_stock", Vector3(0, 0.075, 0.1), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.022, 0)), Vector3(0.09, 0.012, 0.16), UniKit.BRASS_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.04, 0.005, 0)), Vector3(0.012, 0.05, 0.16), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.005, -0.075)), Vector3(0.09, 0.05, 0.012), UniKit.BRASS_DK)
	)
	_add(parts, "breech_glow", "crop_breech", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.047, 0.005, 0)), Vector3(0.006, 0.025, 0.1), UniKit.GLOW_WHITE)
	)
	_add(parts, "breech_round", "crop_breech", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0.0, 0.06, -0.05, 0.022, Color(1, 1, 1), 10)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.022, 0.022, 0.03), 3, 10, Color(0.9, 0.9, 0.88))
		UniKit.band(st, 0, 0, 0.055, 0.025, 0.012, Color(0.7, 0.7, 0.68))
	)
	# The gate closing the chamber's back, hinged at its foot: it tips back to load.
	_add(parts, "breech_gate", "crop_breech", Vector3(0, -0.02, 0.08), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.025, 0.006)), Vector3(0.09, 0.05, 0.012), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.045, 0.016)), Vector3(0.03, 0.012, 0.012), UniKit.BRASS)
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.5, "parts": parts,
		"muzzles": [["rifle_barrel", Vector3(0, 0, -0.84)]],
		"pour": Vector3(0, 0.85, 0.12), "ring_r": 0.85}


## Each shot kicks the rifle back 2 cm (0.12 s) and cycles the bolt over 0.4 s:
## turn up, pull back 3 cm, push home, turn down. Unloaded the bolt stands open.
## Loading: bolt opens, the gate tips back, the round slides in, the gate shuts,
## the bolt locks.
static func _anim_homestead_rifle(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	rig.kick("rifle_stock", 0.02 * kick_k(ctx.shot_age, 0.12))
	var up := 0.0
	var back := 0.0
	if not ctx.loaded:
		up = 1.0
		back = 1.0
	elif ctx.load_k < 1.0:
		var o := smoothstep(0.0, 0.12, ctx.load_k) * (1.0 - smoothstep(0.85, 1.0, ctx.load_k))
		up = o
		back = o * (1.0 - smoothstep(0.75, 0.85, ctx.load_k))
	elif ctx.shots > 0 and ctx.shot_age < 0.4:
		var p := ctx.shot_age / 0.4
		up = smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.75, 1.0, p))
		back = smoothstep(0.25, 0.5, p) * (1.0 - smoothstep(0.5, 0.75, p))
	rig.pose("bolt_mechanism", Vector3(0, 0, 0.03 * back), Basis(Vector3.BACK, -1.3 * up))
	var gate := 0.0
	var slide := 1.0
	if ctx.load_k < 1.0:
		gate = smoothstep(0.12, 0.3, ctx.load_k) * (1.0 - smoothstep(0.6, 0.75, ctx.load_k))
		slide = smoothstep(0.32, 0.55, ctx.load_k)
	rig.turn("breech_gate", Vector3.RIGHT, 1.4 * gate)
	rig.pose("breech_round", Vector3(0, 0, 0.12 * (1.0 - slide)))


# ------------------------------------------------------------------ 6. Rail Driver

## A railgun: a long iron housing with two copper rails and an open channel
## between them, four copper coil rings along it, a spike magazine on top at the
## back and a caged glowing capacitor behind it.
## Parts: base_platform, rail_mount (turntable, pedestal, fork), rail_housing
## (the recoiling root, + barrel_channel glow, channel_flash, rail_spike),
## magnetic_coils (+ coil_1..coil_4, 1 at the front), crop_magazine
## (+ magazine_spikes, magazine_panel), charge_capacitor (+ capacitor_core).
static func _rail_driver(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "rail_mount", "head", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.18, 0), "size": Vector3(0.2, 0.24, 0.22)}}, func(st: SurfaceTool) -> void:
		_turntable(st, 0.3)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.18, 0)), Vector3(0.2, 0.24, 0.22), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.29, 0)), Vector3(0.34, 0.03, 0.18), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.2, -0.112)), Vector3(0.16, 0.045, 0.008), team)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.15, 0.39, 0)), Vector3(0.035, 0.2, 0.14), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.172, 0.47, 0)), 0.035, 0.035, 0.02, 10, UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.102, 0.1, -0.08), Vector3(sx * 0.102, 0.1, 0.08), 3)
		_pennant(st, Vector3(0.21, 0.06, 0.13), 0.88, team)
	)
	# The housing: iron beam, copper rails, brass rail caps, pin through the middle.
	_add(parts, "rail_housing", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.275)), Vector3(0.22, 0.1, 1.35), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.08, 0.09, -0.36)), Vector3(0.045, 0.08, 1.24), UniKit.COPPER)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.08, 0.09, -0.955)), Vector3(0.055, 0.09, 0.04), UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.112, 0.0, 0.3), Vector3(sx * 0.112, 0.0, -0.9), 9)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.03, 0.03, 0.32, 8, UniKit.BRASS_DK)
	)
	_add(parts, "barrel_channel", "rail_housing", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.053, -0.35)), Vector3(0.1, 0.006, 1.18), UniKit.GLOW_WHITE)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.0565, 0.1, -0.35)), Vector3(0.004, 0.018, 1.18), UniKit.GLOW_WHITE)
	)
	_add(parts, "channel_flash", "rail_housing", Vector3(0, 0.09, -0.35), {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.1, 0.06, 1.2), Color(1, 1, 1))
	)
	_add(parts, "rail_spike", "rail_housing", Vector3(0, 0.085, 0.1), {"crop": true}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.1, -0.12, 0.016, Color(0.9, 0.9, 0.88), 8)
		UniKit.barrel(st, 0, 0, -0.12, -0.2, 0.016, Color(1, 1, 1), 8, 0.001)
		for k in 3:
			var a := TAU * k / 3.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.02 + Vector3(0, 0, 0.08)), Vector3(0.02, 0.004, 0.04), Color(0.75, 0.75, 0.72))
	)
	# The four coils, each held off the housing by small brackets.
	_add(parts, "magnetic_coils", "rail_housing", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		for k in 4:
			var z := -0.86 + 0.22 * k
			for sx: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.13, 0.03, z)), Vector3(0.04, 0.03, 0.03), UniKit.IRON)
	)
	for k in 4:
		_add(parts, "coil_%d" % (k + 1), "magnetic_coils", Vector3(0, 0.035, -0.86 + 0.22 * k), {}, func(st: SurfaceTool) -> void:
			MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.19, 0.15, 0.07, 16, UniKit.COPPER)
			for sz: float in [-1.0, 1.0]:
				MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, sz * 0.038)), 0.2, 0.15, 0.012, 16, UniKit.BRASS_DK)
		)
	# The spike magazine over the channel's back: open on the left so the spikes show.
	_add(parts, "crop_magazine", "rail_housing", Vector3(0, 0.2, 0.17), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.065, 0)), Vector3(0.18, 0.02, 0.2), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.08, 0, 0)), Vector3(0.02, 0.13, 0.2), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.095)), Vector3(0.18, 0.13, 0.012), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.07, 0)), Vector3(0.18, 0.02, 0.2), UniKit.IRON_DK)
		for k in 3:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.085, -0.04 + 0.04 * k, 0)), Vector3(0.012, 0.012, 0.2), UniKit.BRASS)
	)
	_add(parts, "magazine_spikes", "crop_magazine", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		for k in 3:
			UniKit.barrel(st, 0.0, -0.035 + 0.035 * k, 0.08, -0.06, 0.014, Color(1, 1, 1) if k % 2 == 0 else Color(0.85, 0.85, 0.82), 8)
			UniKit.barrel(st, 0.0, -0.035 + 0.035 * k, -0.06, -0.085, 0.014, Color(1, 1, 1), 8, 0.001)
	)
	_add(parts, "magazine_panel", "crop_magazine", Vector3(0, 0, 0.1), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(0.18, 0.13, 0.012), UniKit.IRON_LT)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, 0.016)), Vector3(0.06, 0.015, 0.012), UniKit.BRASS)
	)
	# The capacitor behind: a brass-capped cage round a glowing core.
	_add(parts, "charge_capacitor", "rail_housing", Vector3(0, 0.05, 0.36), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.015, 0)), 0.085, 0.085, 0.03, 12, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.205, 0)), 0.075, 0.06, 0.03, 12, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.235, 0)), 0.015, 0.015, 0.04, 6, UniKit.COPPER)
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.072, 0.11, sin(a) * 0.072)), Vector3(0.014, 0.17, 0.014), UniKit.COPPER)
	)
	_add(parts, "capacitor_core", "charge_capacitor", Vector3(0, 0.03, 0), {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.05, 0.05, 0.16, 10, UniKit.GLOW_WHITE)
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.47, "parts": parts,
		"muzzles": [["rail_housing", Vector3(0, 0.09, -0.98)]],
		"pour": Vector3(0, 0.95, 0.17), "ring_r": 0.85}


## The capacitor core swells as it charges (from 0.5 s after a shot); in the
## last 0.3 s before a shot the coils pulse front to back. A shot flashes the
## whole channel, the coils dim, the housing kicks 1 cm and the next spike
## drops from the magazine. Loading: the magazine's back panel slides up.
static func _anim_rail_driver(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var armed := ctx.loaded and ctx.load_k >= 1.0
	var c := ctx.charge
	var pre := smoothstep(0.885, 1.0, c) if armed and ctx.tracking and ctx.shots > 0 else 0.0
	if armed and ctx.tracking and ctx.shot_age < 0.05:
		pre = 1.0
	var dim := kick_k(ctx.shot_age, 0.5) if ctx.shots > 0 else 0.0
	for k in 4:
		var wave := 0.5 + 0.5 * sin(ctx.t * 14.0 + k * 1.6)
		var s := 1.0 + pre * 0.14 * wave - dim * 0.07
		if armed:
			s += 0.015 * sin(ctx.t * 3.0 + k)
		_lscale(rig, "coil_%d" % (k + 1), Vector3(s, s, 1.0))
	var fill := 0.25
	if armed:
		fill = 0.35 + 0.65 * smoothstep(0.19, 0.885, c) if ctx.shots > 0 else 1.0
	var w := 0.75 + 0.25 * fill + 0.2 * pre
	_lscale(rig, "capacitor_core", Vector3(w, fill, w))
	var flash := 1.0 - smoothstep(0.03, 0.14, ctx.shot_age) if ctx.shots > 0 else 0.0
	_lscale(rig, "channel_flash", Vector3(maxf(flash, 0.001), maxf(flash, 0.001), 1.0))
	rig.kick("rail_housing", 0.01 * kick_k(ctx.shot_age, 0.15))
	# The next spike: gone at the shot, drops in from under the magazine.
	var spike := 1.0
	var slide := 0.0
	if ctx.load_k < 1.0:
		slide = 1.0 - smoothstep(0.35, 0.65, ctx.load_k)
	elif ctx.shots > 0 and ctx.shot_age < 0.9:
		spike = 0.001 if ctx.shot_age < 0.5 else 1.0
		slide = 1.0 - smoothstep(0.5, 0.9, ctx.shot_age)
	_lscale(rig, "rail_spike", Vector3.ONE * spike, Vector3(0, 0.08 * slide, 0.06 * slide))
	rig.pose("magazine_panel", Vector3(0, 0.12 * open_k(ctx.load_k), 0))


# ------------------------------------------------------------------ 7. Crop Cannon

## A Parrott-style siege gun: the thickest barrel on the cliff (reinforcing band
## at the breech) on a heavy iron carriage with trunnions, a top-hinged breech
## door, a tray behind holding the next crop-packed round, and an elevation
## screw with a hand wheel under the chase.
## Parts: base_platform, cannon_carriage, trunnions, cannon_barrel (+ muzzle_glow,
## blast_ring, breech_door), crop_round_holder (+ crop_round), elevation_screw,
## screw_wheel.
static func _crop_cannon(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "cannon_carriage", "head", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.29, 0), "size": Vector3(0.58, 0.46, 0.5)}}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.035, 0.2)), Vector3(0.62, 0.07, 1.1), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.25, 0.29, 0)), Vector3(0.08, 0.46, 0.5), UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(sx * 0.25, 0.2, -0.3)), Vector3(0.07, 0.3, 0.1), UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.25, 0.565, 0)), Vector3(0.1, 0.03, 0.15), UniKit.BRASS_DK)
			UniKit.bolt(st, Vector3(sx * 0.25, 0.58, -0.05), Vector3.UP, 0.016, 0.015)
			UniKit.bolt(st, Vector3(sx * 0.25, 0.58, 0.05), Vector3.UP, 0.016, 0.015)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.292, 0.36, 0)), Vector3(0.006, 0.05, 0.42), team)
			UniKit.rivet_row(st, Vector3(sx * 0.292, 0.14, -0.2), Vector3(sx * 0.292, 0.14, 0.2), 5)
		# Transom between the cheeks, and the nut block the elevation screw runs in.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, 0.05)), Vector3(0.44, 0.08, 0.1), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, -0.2)), Vector3(0.44, 0.06, 0.12), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.15, -0.2)), 0.05, 0.05, 0.04, 8, UniKit.BRASS_DK)
		_pennant(st, Vector3(0.24, 0.07, 0.6), 0.86, team)
	)
	_add(parts, "trunnions", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.06, 0.06, 0.58, 12, UniKit.IRON_LT)
	)
	# The barrel: a lathed Parrott profile from the breech (z 0.4) to the muzzle (z -0.92).
	_add(parts, "cannon_barrel", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		var prof: Array = [Vector2(0.13, 0.0), Vector2(0.185, 0.015), Vector2(0.19, 0.04), Vector2(0.19, 0.3), Vector2(0.17, 0.33),
			Vector2(0.16, 0.6), Vector2(0.135, 1.1), Vector2(0.13, 1.2), Vector2(0.15, 1.24), Vector2(0.15, 1.3), Vector2(0.13, 1.32)]
		MeshKit.lathe(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.4)), prof, 16, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.39)), 0.13, 0.13, 0.02, 14, Color(0.07, 0.07, 0.07))
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.86)), 0.13, 0.13, 0.02, 14, Color(0.07, 0.07, 0.07))
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.92)), 0.14, 0.085, 0.015, 16, UniKit.IRON)
		for z: float in [0.36, 0.14]:
			UniKit.band(st, 0, 0, z, 0.198, 0.03, UniKit.BRASS_DK)
		for k in 8:
			var a := TAU * (k + 0.5) / 8.0
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.192, sin(a) * 0.192, 0.25)), Vector3.ONE * 0.016, 2, 6, UniKit.BOLT)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.2, 0.3)), Vector3(0.02, 0.03, 0.05), UniKit.BRASS)
	)
	_add(parts, "muzzle_glow", "cannon_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.925)), 0.12, 0.09, 0.008, 16, UniKit.GLOW_WHITE)
	)
	_add(parts, "blast_ring", "cannon_barrel", Vector3(0, 0, -0.95), {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.22, 0.15, 0.06, 16, Color(0.95, 0.95, 0.93))
	)
	# The breech door, hinged along its top edge: it swings up and back to open.
	_add(parts, "breech_door", "cannon_barrel", Vector3(0, 0.15, 0.405), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, -0.15, 0.02)), 0.15, 0.15, 0.04, 16, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.022, 0.022, 0.14, 8, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.15, 0.05)), Vector3(0.2, 0.03, 0.025), UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.1, -0.15, 0.07)), Vector3(0.025, 0.025, 0.05), UniKit.IRON_DK)
		UniKit.rivet_row(st, Vector3(-0.09, -0.24, 0.042), Vector3(0.09, -0.24, 0.042), 3)
	)
	# The round tray behind the breech, on legs off the bed plate.
	_add(parts, "crop_round_holder", "head", Vector3(0, 0.5, 0.68), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(0.22, 0.02, 0.26), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.105, -0.06, 0)), Vector3(0.02, 0.08, 0.26), UniKit.IRON)
			MeshKit.add_limb(st, Vector3(sx * 0.08, -0.11, 0.06), Vector3(sx * 0.1, -0.46, 0.08), 0.02, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.06, 0.125)), Vector3(0.22, 0.08, 0.02), UniKit.WOOD)
	)
	_add(parts, "crop_round", "crop_round_holder", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.1, -0.06, 0.085, Color(0.95, 0.95, 0.93), 12)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, -0.06)), Vector3(0.085, 0.085, 0.07), 4, 12, Color(1, 1, 1))
		for z: float in [0.07, -0.0]:
			UniKit.band(st, 0, 0, z, 0.088, 0.015, Color(0.7, 0.68, 0.64))
	)
	# Elevation screw under the chase (rises and turns with the pitch) and its wheel.
	_add(parts, "elevation_screw", "head", Vector3(0, 0.1, -0.2), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.026, 0.026, 0.48, 8, UniKit.IRON_LT)
		for k in 8:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03 + 0.025 * k, 0)), 0.034, 0.034, 0.008, 8, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.235, 0)), Vector3(0.1, 0.02, 0.08), UniKit.IRON_DK)
	)
	_add(parts, "screw_wheel", "head", Vector3(0, 0.24, -0.2), {}, func(st: SurfaceTool) -> void:
		_wheel(st, Transform3D(), 0.1, UniKit.BRASS_DK)
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.5, "parts": parts,
		"muzzles": [["cannon_barrel", Vector3(0, 0, -0.96)]],
		"pour": Vector3(0, 0.8, 0.68), "ring_r": 0.9}


## HEAVY: the barrel slams back 6 cm in the carriage and eases home over 0.4 s,
## a concussive ring blows off the muzzle and the breech door bangs open 0.1 s
## later. The round in the tray then slides into the breech (0.5 s), the door
## swings shut and the next round is set in the tray. The elevation screw
## turns and rises with the barrel's pitch (it stays put when firing). Unloaded,
## the door hangs open. Loading: round in, door shut, next round set.
static func _anim_crop_cannon(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	var back := 0.0
	if ctx.shots > 0:
		back = 0.06 * minf(a / 0.05, 1.0) * (1.0 - smoothstep(0.2, 0.6, a))
	rig.pose("cannon_barrel", Vector3(0, 0, back))
	_puff(rig, "blast_ring", a, 0.6, 0.8, 3.0)
	var door := 0.0
	var slide := 0.0
	var round_k := 1.0
	if not ctx.loaded:
		door = 0.6
	elif ctx.load_k < 1.0:
		var l := ctx.load_k
		door = lerpf(0.6, 1.0, smoothstep(0.0, 0.12, l)) * (1.0 - smoothstep(0.62, 0.85, l))
		slide = smoothstep(0.15, 0.6, l)
		round_k = 0.001 if l >= 0.6 and l < 0.88 else (smoothstep(0.88, 1.0, l) if l >= 0.88 else 1.0)
	elif ctx.shots > 0 and a < 3.4:
		door = smoothstep(0.1, 0.16, a) * (1.0 - smoothstep(2.4, 2.75, a))
		slide = smoothstep(1.8, 2.3, a)
		if a >= 2.3:
			round_k = 0.001 if a < 2.9 else maxf(smoothstep(2.9, 3.3, a), 0.001)
			slide = 0.0 if a >= 2.9 else 1.0
	rig.turn("breech_door", Vector3.RIGHT, -1.9 * door)
	_lscale(rig, "crop_round", Vector3.ONE * round_k, Vector3(0, 0, -0.3 * slide))
	# The screw follows the chase: rise = how far the barrel's underside has moved
	# up at the screw (z = -0.2 in front of the trunnions).
	var p := _gun_pitch(rig)
	var rise := -0.16 * cos(p) + 0.2 * sin(p) + 0.16
	rig.turn("elevation_screw", Vector3.UP, rise * 45.0, Vector3(0, rise, 0))
	rig.turn("screw_wheel", Vector3.UP, rise * 45.0)


# ------------------------------------------------------------------ 8. Storm Blower

## A steam-foghorn blast cannon: a short fat riveted housing on a yoke, a wide
## brass horn in front, a pressure tank on the back with sight glasses, a gauge
## (left side) and a screw cap, and a valve wheel on top.
## Parts: base_platform, blower_yoke, blower_housing (rocks back; + blast_cone,
## pressure_tank with tank_glow, tank_cap and gauge_needle, valve_mechanism with
## valve_wheel), shock_ring.
static func _storm_blower(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "blower_yoke", "head", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		_turntable(st, 0.32)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.09, 0)), Vector3(0.56, 0.05, 0.16), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.255, 0.28, 0)), Vector3(0.05, 0.38, 0.14), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.285, 0.48, 0)), 0.045, 0.045, 0.025, 10, UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.282, 0.12, -0.05), Vector3(sx * 0.282, 0.4, -0.05), 4)
		_pennant(st, Vector3(0.24, 0.12, 0.08), 0.75, team)
	)
	# The housing: a fat riveted drum lying along the line of fire.
	_add(parts, "blower_housing", "gun", Vector3.ZERO, {"trim": {"c": Vector3(0, 0, -0.05), "size": Vector3(0.4, 0.4, 0.34)}}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.12, -0.22, 0.2, UniKit.IRON, 16)
		for z: float in [0.11, -0.21]:
			UniKit.band(st, 0, 0, z, 0.212, 0.035, UniKit.BRASS)
		for k in 8:
			var a := TAU * (k + 0.5) / 8.0
			UniKit.rivet_row(st, Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.07), Vector3(cos(a) * 0.2, sin(a) * 0.2, -0.17), 2)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.04, 0.04, 0.5, 10, UniKit.BRASS_DK)
	)
	_add(parts, "blast_cone", "blower_housing", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		_bell(st, 0, 0, -0.22, -0.62, 0.19, 0.36, 0.03, UniKit.BRASS, 18)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.62)), 0.375, 0.325, 0.04, 18, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.225)), 0.17, 0.17, 0.01, 14, Color(0.08, 0.08, 0.08))
		for k in 3:
			var a := PI * k / 3.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(0, 0, -0.235)), Vector3(0.34, 0.018, 0.015), UniKit.IRON)
	)
	# The pressure tank on the back: sight glasses on both sides, gauge on the left.
	_add(parts, "pressure_tank", "blower_housing", Vector3(0, 0, 0.21), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.1, -0.09, 0.13, UniKit.BRASS_DK, 14)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.13, 0.13, 0.06), 4, 14, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, 0.0, 0.138, 0.025, UniKit.IRON_DK)
		UniKit.gauge(st, Vector3(-0.14, 0.04, 0.03), Vector3.LEFT, 0.055)
		var face := Vector3(-0.158, 0.04, 0.03)
		for z: Array in [[-2.3, Color("#8A8A88")], [0.1, Color("#D8B23A")], [0.6, Color("#D8B23A")], [1.05, Color("#4E9A4A")], [1.4, Color("#4E9A4A")], [1.9, Color("#B8352A")]]:
			var ang: float = z[0]
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, ang), face + Vector3(0, cos(ang), sin(ang)) * 0.042), Vector3(0.004, 0.012, 0.02), z[1])
	)
	_add(parts, "tank_glow", "pressure_tank", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.12, -0.06, 0.0)), Vector3(0.014, 0.035, 0.15), UniKit.GLOW_WHITE)
	)
	_add(parts, "gauge_needle", "pressure_tank", Vector3(-0.162, 0.04, 0.03), {}, func(st: SurfaceTool) -> void:
		UniKit.needle(st, 0.045)
	)
	_add(parts, "tank_cap", "pressure_tank", Vector3(0, 0.13, 0.02), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.045, 0.045, 0.04, 10, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.12, 0.018, 0.02), UniKit.IRON_DK)
	)
	_add(parts, "valve_mechanism", "blower_housing", Vector3(0, 0.19, -0.05), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.08, 0.05, 0.09), UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.09, 0)), 0.014, 0.014, 0.1, 6, UniKit.IRON_LT)
	)
	_add(parts, "valve_wheel", "valve_mechanism", Vector3(0, 0.13, 0), {}, func(st: SurfaceTool) -> void:
		_wheel(st, Transform3D(), 0.085, Color("#9A2E24"))
	)
	_add(parts, "shock_ring", "gun", Vector3(0, 0, -0.64), {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.33, 0.27, 0.04, 18, Color(1, 1, 1))
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.48, "parts": parts,
		"muzzles": [["blast_cone", Vector3(0, 0, -0.64)]],
		"pour": Vector3(0, 0.95, 0.21), "ring_r": 0.85}


## On a shot the valve wheel snaps a quarter turn open (0.1 s) and back, a
## shockwave ring blows out of the horn, the housing rocks back 3 cm and the
## tank shudders; the gauge drops to yellow and climbs back to green as the
## next blast charges. Loaded, the housing hums (a faint shake). Unloaded the
## gauge reads zero. Loading: the tank cap unscrews, the crop pours in, the
## cap screws home and the gauge climbs.
static func _anim_storm_blower(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	var hum := Vector3.ZERO
	if ctx.loaded:
		hum = Vector3(sin(ctx.t * 47.0), sin(ctx.t * 61.0), 0) * 0.0015
	rig.pose("blower_housing", hum + Vector3(0, 0, 0.03 * kick_k(a, 0.3)))
	var valve := smoothstep(0.0, 0.1, a) * (1.0 - smoothstep(0.25, 0.4, a)) if ctx.shots > 0 else 0.0
	rig.turn("valve_wheel", Vector3.UP, -PI * 0.5 * valve)
	_puff(rig, "shock_ring", a, 0.4, 1.4, 2.4)
	var shudder := sin(a * 80.0) * 0.006 * kick_k(a, 0.35) if ctx.shots > 0 else 0.0
	rig.pose("pressure_tank", Vector3(shudder, shudder * 0.5, 0))
	var needle := -2.3
	if ctx.loaded:
		var full := lerpf(0.35, 1.2, ctx.charge) if ctx.shots > 0 else 1.2
		needle = lerpf(-2.3, full, smoothstep(0.7, 1.0, ctx.load_k))
	rig.turn("gauge_needle", Vector3.RIGHT, needle)
	var cap := open_k(ctx.load_k)
	rig.turn("tank_cap", Vector3.UP, cap * 5.0, Vector3(0, 0.035 * cap, 0))


# ------------------------------------------------------------------ 9. Snare Launcher

## A Y-frame bola launcher: a wooden stock with two iron-tipped arms spreading
## forward, two heavy cables from the arm tips to a leather cradle that holds
## the crop-woven bola, and a small weaving drum below that spins up the next.
## Parts: base_platform, frame_mount, launcher_frame (rocks forward; + bola_cradle
## with bola, tension_cables pivot with cable_l1/l2 and cable_r1/r2),
## crop_weaver (+ weaver_glow, weaver_spindle with weaver_bola).
static func _snare_launcher(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "frame_mount", "head", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		_turntable(st, 0.28)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.23, 0)), 0.075, 0.065, 0.34, 12, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.41, 0)), Vector3(0.2, 0.03, 0.1), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.08, 0.45, 0)), Vector3(0.03, 0.1, 0.08), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.1, 0.47, 0)), 0.025, 0.025, 0.02, 8, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.08, 0.08, 0.04, 12, UniKit.BRASS_DK)
		_pennant(st, Vector3(0.12, 0.07, 0.1), 0.86, team)
	)
	# The Y frame: stock, junction block, two arms with leather grips and pulley tips.
	_add(parts, "launcher_frame", "gun", Vector3.ZERO, {"trim": {"c": Vector3(0, -0.02, 0.08), "size": Vector3(0.1, 0.09, 0.5)}}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.02, 0.08)), Vector3(0.09, 0.08, 0.52), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.025, 0.06)), Vector3(0.05, 0.012, 0.48), UniKit.IRON_LT)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.02, 0.3)), Vector3(0.095, 0.02, 0.06), team)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.01, 0.345)), Vector3(0.1, 0.09, 0.02), UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.025, 0.025, 0.22, 8, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.01, -0.2)), Vector3(0.17, 0.1, 0.09), UniKit.IRON)
		UniKit.rivet_row(st, Vector3(-0.07, 0.04, -0.2), Vector3(0.07, 0.04, -0.2), 3)
		for sx: float in [-1.0, 1.0]:
			var root := Vector3(sx * 0.07, 0.0, -0.21)
			var tip := Vector3(sx * 0.42, 0.1, -0.55)
			MeshKit.add_limb(st, root, tip, 0.036, UniKit.WOOD_DK)
			MeshKit.add_limb(st, root.lerp(tip, 0.3), root.lerp(tip, 0.55), 0.042, UniKit.LEATHER)
			MeshKit.add_limb(st, root + Vector3(0, -0.04, 0.0), root.lerp(tip, 0.6) + Vector3(0, -0.03, 0), 0.014, UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(Basis(), tip), 0.05, 0.05, 0.06, 10, UniKit.BRASS)
			MeshKit.add_cylinder(st, Transform3D(Basis(), tip + Vector3(0, 0.04, 0)), 0.024, 0.024, 0.03, 6, UniKit.IRON_DK)
	)
	# Cradle: a leather pouch with iron rings at the sides, riding the stock's rail.
	_add(parts, "bola_cradle", "launcher_frame", Vector3(0, 0.06, -0.06), {}, func(st: SurfaceTool) -> void:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, sx * 0.3), Vector3(sx * 0.035, 0.005, 0)), Vector3(0.075, 0.012, 0.08), UniKit.LEATHER)
			MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(sx * 0.078, 0.015, 0)), 0.014, 0.008, 0.008, 8, UniKit.IRON_LT)
	)
	_add(parts, "bola", "bola_cradle", Vector3(0, 0.04, 0), {"crop": true}, func(st: SurfaceTool) -> void:
		var pts: Array[Vector3] = [Vector3(0, 0, -0.045), Vector3(-0.045, 0, 0.028), Vector3(0.045, 0, 0.028)]
		for p in pts:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * 0.034, 3, 8, Color(1, 1, 1))
			MeshKit.add_limb(st, Vector3(0, 0.005, 0), p, 0.005, Color(0.8, 0.78, 0.74), 5)
	)
	parts.append(UniKit.pivot("tension_cables", "launcher_frame"))
	var drawn := _snare_cable_pts(Vector3(0, 0.06, -0.06), 0.0)
	for k in 4:
		var seg: Array = drawn[k]
		var xf := _cable_xf(seg[0], seg[1])
		_add(parts, ["cable_l1", "cable_l2", "cable_r1", "cable_r2"][k], "tension_cables", xf.origin, {"basis": xf.basis}, func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, 0.0, -1.0, 0.012, UniKit.ROPE, 6)
		)
	# The weaver: a little brass drum below the frame with a spindle that spins the bola up.
	_add(parts, "crop_weaver", "head", Vector3(0, 0.13, -0.2), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.2, 0.12, 0.14), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.07, 0.1)), Vector3(0.06, 0.03, 0.1), UniKit.IRON)
		_gear(st, Transform3D(UniKit.ALONG_X, Vector3(-0.11, 0, 0)), 0.04, 0.02, 8, UniKit.IRON_LT)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.065, 0)), 0.05, 0.05, 0.012, 10, UniKit.IRON_DK)
	)
	_add(parts, "weaver_glow", "crop_weaver", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, -0.071)), Vector3(0.16, 0.02, 0.006), UniKit.GLOW_WHITE)
	)
	_add(parts, "weaver_spindle", "crop_weaver", Vector3(0, 0.07, 0), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.008, 0)), 0.045, 0.045, 0.012, 10, UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.04, 0.035, 0)), Vector3(0.01, 0.05, 0.012), UniKit.IRON_LT)
	)
	_add(parts, "weaver_bola", "weaver_spindle", Vector3(0, 0.04, 0), {"crop": true}, func(st: SurfaceTool) -> void:
		for k in 3:
			var a := TAU * k / 3.0
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * 0.018), Vector3.ONE * 0.016, 3, 6, Color(1, 1, 1))
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.47, "parts": parts,
		"muzzles": [Vector3(0, 0.08, -0.6)],
		"pour": Vector3(0, 0.55, -0.2), "ring_r": 0.85}


## The four cable segments [from, to] (frame space) for the cradle at `cradle`
## with the cables sagging `sag` m at their middles: left tip -> mid -> cradle,
## then the right side.
static func _snare_cable_pts(cradle: Vector3, sag: float) -> Array:
	var out: Array = []
	for sx: float in [-1.0, 1.0]:
		var tip := Vector3(sx * 0.42, 0.1, -0.55)
		var att := cradle + Vector3(sx * 0.078, 0.015, 0)
		var mid := (tip + att) * 0.5 + Vector3(0, -sag, 0)
		out.append([tip, mid])
		out.append([mid, att])
	return out


## A unit cable (built along -Z from 0 to -1) stretched from a to b.
static func _cable_xf(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var l := maxf(d.length(), 0.001)
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.BACK
	return Transform3D(Basis.looking_at(d / l, up) * Basis.from_scale(Vector3(1, 1, l)), a)


## Loaded, the cradle is drawn back and the cables taut with the bola in it. A
## shot snaps the cradle forward past the tips (0.05 s), the bola flies, the
## cables wobble back to rest (0.2 s) and the frame rocks 2 cm forward; the
## weaver then spins the next bola up over the fire interval, it lifts into the
## cradle and the cables draw taut again. Unloaded: cables slack, cradle empty.
## Loading: the weaver spins a bola, it lifts to the cradle, the cables draw.
static func _anim_snare_launcher(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var drawn_z := -0.06
	var slack_z := -0.5
	var over_z := -0.62
	var z := slack_z
	var draw := 0.0
	var bola := 0.001
	var weave := 0.001
	var spin_speed := 0.0
	var a := ctx.shot_age
	if ctx.loaded and ctx.load_k < 1.0:
		var l := ctx.load_k
		weave = maxf(smoothstep(0.1, 0.6, l) * (1.0 - smoothstep(0.66, 0.72, l)), 0.001)
		spin_speed = 14.0 if l < 0.7 else 0.0
		bola = maxf(smoothstep(0.7, 0.78, l), 0.001)
		draw = smoothstep(0.78, 1.0, l)
	elif ctx.loaded:
		draw = 1.0
		bola = 1.0
		spin_speed = 1.5
		if ctx.shots > 0 and ctx.charge < 1.0:
			var c := ctx.charge
			bola = 0.001 if c < 0.86 else 1.0
			weave = maxf(smoothstep(0.05, 0.8, c) * (1.0 - smoothstep(0.82, 0.86, c)), 0.001)
			spin_speed = 14.0 if c < 0.84 else 1.5
			draw = smoothstep(0.88, 0.98, c)
			if a < 0.05:
				# The snap: straight from drawn to past the tips.
				z = lerpf(drawn_z, over_z, a / 0.05)
				draw = -1.0
			elif a < 0.25:
				var k := (a - 0.05) / 0.2
				z = slack_z + (over_z - slack_z) * cos(k * PI * 2.5) * (1.0 - k)
				draw = -1.0
	if draw >= 0.0:
		z = lerpf(slack_z, drawn_z, draw)
	var sag := 0.07 * (1.0 - clampf(draw, 0.0, 1.0)) if draw >= 0.0 else 0.0
	var cradle := Vector3(0, 0.06 - 0.03 * (1.0 - clampf(draw, 0.0, 1.0)), z)
	rig.pose("bola_cradle", cradle - Vector3(0, 0.06, -0.06))
	_lscale(rig, "bola", Vector3.ONE * bola)
	var segs := _snare_cable_pts(cradle, sag)
	var names: Array[String] = ["cable_l1", "cable_l2", "cable_r1", "cable_r2"]
	for k in 4:
		var p: Node3D = rig.part(names[k])
		if p != null:
			var seg: Array = segs[k]
			p.transform = _cable_xf(seg[0], seg[1])
	rig.kick("launcher_frame", -0.02 * kick_k(a, 0.25) if ctx.shots > 0 else 0.0)
	var spin := float(rig.state.get("spin", 0.0)) + spin_speed * delta
	rig.state["spin"] = spin
	rig.turn("weaver_spindle", Vector3.UP, spin)
	_lscale(rig, "weaver_bola", Vector3.ONE * weave)


# ------------------------------------------------------------------ 10. Frontier Sentinel

## The hybrid: a wide riveted housing carrying two barrels on one cradle, a
## light jacketed horde barrel on the left and a heavy braked barrel on the
## right; a caged crop canister on the back splits the feed down two brass
## pipes, with a valve that turns to the barrel in use; a semaphore arm on the
## mode plate (H left, S right) shows the mode.
## Parts: base_platform, turret_housing, barrel_cradle, horde_barrel (+ horde_glow),
## st_barrel (+ st_glow), crop_feed_splitter (+ splitter_fill, splitter_valve,
## feed_glow_l, feed_glow_r), mode_indicator (+ mode_flag).
static func _frontier_sentinel(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	_add(parts, "turret_housing", "head", Vector3.ZERO, {"trim": {"c": Vector3(0, 0.15, 0.04), "size": Vector3(0.74, 0.26, 0.56)}}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, 0.04)), Vector3(0.74, 0.26, 0.56), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.305, 0.04)), Vector3(0.66, 0.05, 0.48), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0.04)), Vector3(0.76, 0.04, 0.58), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.2, -0.243)), Vector3(0.6, 0.04, 0.01), team)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.33, 0.43, 0)), Vector3(0.06, 0.26, 0.24), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.365, 0.5, 0)), 0.045, 0.045, 0.02, 10, UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.373, 0.22, -0.2), Vector3(sx * 0.373, 0.22, 0.28), 6)
		UniKit.rivet_row(st, Vector3(-0.33, 0.09, -0.243), Vector3(0.33, 0.09, -0.243), 7)
		_pennant(st, Vector3(0.28, 0.33, 0.26), 0.65, team)
	)
	_add(parts, "barrel_cradle", "gun", Vector3.ZERO, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.56, 0.17, 0.18), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.04, 0.04, 0.72, 10, UniKit.BRASS_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(sx * 0.15, 0, -0.095)), 0.085, 0.085, 0.02, 14, UniKit.BRASS)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(sx * 0.15, 0, 0.1)), 0.035, 0.035, 0.03, 8, UniKit.BRASS)
		UniKit.rivet_row(st, Vector3(-0.25, 0.088, -0.07), Vector3(0.25, 0.088, -0.07), 6)
	)
	# The horde barrel (left): slim, with a slotted cooling jacket.
	_add(parts, "horde_barrel", "gun", Vector3(-0.15, 0, -0.09), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.0, -0.7, 0.03, UniKit.IRON, 10)
		UniKit.barrel(st, 0, 0, -0.04, -0.46, 0.05, UniKit.IRON_LT, 12)
		for k in 6:
			var a := TAU * k / 6.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.049 + Vector3(0, 0, -0.25)), Vector3(0.006, 0.016, 0.3), UniKit.IRON_DK)
		for z: float in [-0.04, -0.46]:
			UniKit.band(st, 0, 0, z, 0.056, 0.025, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.701)), 0.016, 0.016, 0.004, 8, Color(0.06, 0.06, 0.06))
	)
	_add(parts, "horde_glow", "horde_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.67, 0.034, 0.04, UniKit.GLOW_WHITE)
	)
	# The heavy barrel (right): thick, banded, with a slotted muzzle brake.
	_add(parts, "st_barrel", "gun", Vector3(0.15, 0, -0.09), {}, func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.0, -0.88, 0.065, UniKit.IRON_DK, 14, 0.055)
		UniKit.barrel(st, 0, 0, 0.0, -0.22, 0.08, UniKit.BRASS_DK, 14, 0.075)
		UniKit.band(st, 0, 0, -0.5, 0.066, 0.03, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.93)), Vector3(0.15, 0.1, 0.11), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			for k in 2:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.074, 0, -0.9 - 0.05 * k)), Vector3(0.006, 0.06, 0.02), Color(0.08, 0.08, 0.08))
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.986)), 0.03, 0.03, 0.004, 10, Color(0.06, 0.06, 0.06))
	)
	_add(parts, "st_glow", "st_barrel", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.85, 0.064, 0.035, UniKit.GLOW_WHITE)
	)
	# The splitter: a caged canister on the back, two brass pipes forward to the breeches.
	var sp := Vector3(0, 0.5, 0.27)
	_add(parts, "crop_feed_splitter", "head", sp, {}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.08, 0)), 0.09, 0.08, 0.03, 12, UniKit.BRASS_DK)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.09, 0.07, 0.02, 12, UniKit.BRASS_DK)
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08)), Vector3(0.016, 0.16, 0.016), UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.13, 0)), 0.03, 0.03, 0.08, 8, UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.tube(st, [Vector3(0, -0.12, -0.02), Vector3(sx * 0.07, -0.1, -0.06), Vector3(sx * 0.13, -0.02, -0.1), Vector3(sx * 0.15, 0.0, -0.15)], [0.02], 8, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.025, 0.025, 0.03, 8, UniKit.BRASS)
	)
	_add(parts, "splitter_fill", "crop_feed_splitter", Vector3.ZERO, {"crop": true}, func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.01, 0)), 0.07, 0.07, 0.12, 12, Color(0.9, 0.9, 0.88))
	)
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		_add(parts, "feed_glow_l" if i == 0 else "feed_glow_r", "crop_feed_splitter", Vector3.ZERO, {"glow": true}, func(st: SurfaceTool) -> void:
			for f: float in [0.35, 0.75]:
				var c := Vector3(0, -0.12, -0.02).lerp(Vector3(sx * 0.15, 0.0, -0.15), f) + Vector3(0, -0.01 if f < 0.5 else 0.0, 0)
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), c), Vector3.ONE * 0.025, 3, 8, UniKit.GLOW_WHITE)
		)
	_add(parts, "splitter_valve", "crop_feed_splitter", Vector3(0, 0.115, 0), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.01, 0.045)), Vector3(0.02, 0.016, 0.1), Color("#9A2E24"))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.01, 0.095)), Vector3.ONE * 0.016, 2, 6, UniKit.BRASS)
	)
	# Mode plate (left rear of the top): H on the left, S on the right, both faces.
	_add(parts, "mode_indicator", "head", Vector3(-0.25, 0.33, 0.24), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.035, 0)), Vector3(0.17, 0.07, 0.015), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.004, 0)), Vector3(0.19, 0.012, 0.05), UniKit.IRON)
		for fz: float in [-1.0, 1.0]:
			var z := fz * 0.009
			# H
			for hx: float in [-0.068, -0.042]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(hx, 0.04, z)), Vector3(0.007, 0.04, 0.004), UniKit.BRASS)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.055, 0.04, z)), Vector3(0.026, 0.007, 0.004), UniKit.BRASS)
			# S
			for sy: float in [0.021, 0.04, 0.059]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.055, sy, z)), Vector3(0.026, 0.007, 0.004), UniKit.BRASS)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0445 if fz < 0.0 else 0.0655, 0.0495, z)), Vector3(0.007, 0.02, 0.004), UniKit.BRASS)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0655 if fz < 0.0 else 0.0445, 0.0305, z)), Vector3(0.007, 0.02, 0.004), UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0.075, 0)), 0.012, 0.012, 0.03, 8, UniKit.BRASS)
	)
	_add(parts, "mode_flag", "mode_indicator", Vector3(0, 0.075, 0), {}, func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.012, 0.1, 0.008), UniKit.IRON_LT)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.035, 0.03, 0.01), Color("#B8352A"))
	)
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.5, "parts": parts,
		"muzzles": [["horde_barrel", Vector3(0, 0, -0.72)]],
		"heavy_muzzles": [["st_barrel", Vector3(0, 0, -1.0)]],
		"pour": sp + Vector3(0, 0.3, 0), "ring_r": 0.9}


## Horde mode: the left barrel fires fast, kicking 1 cm with a quick return.
## Heavy mode: the right barrel kicks 3 cm and eases back slowly. The idle
## barrel settles back 1 cm. The splitter valve turns to the barrel in use and
## only that pipe glows while firing (both when idle); the semaphore arm leans
## to H or S (upright when unloaded) as mode_k eases across.
static func _anim_frontier_sentinel(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var m := ctx.mode_k
	var heavy := ctx.mode == 1
	var a := ctx.shot_age
	var shot := ctx.shots > 0
	rig.kick("horde_barrel", (0.01 * kick_k(a, 0.07) if shot and not heavy else 0.0) + 0.01 * m)
	rig.kick("st_barrel", (0.03 * kick_k(a, 0.45) if shot and heavy else 0.0) + 0.01 * (1.0 - m))
	var valve := 0.0
	var flag := 0.0
	if ctx.loaded:
		valve = lerpf(-0.8, 0.8, m)
		flag = lerpf(0.7, -0.7, smoothstep(0.15, 0.85, m)) * smoothstep(0.6, 1.0, ctx.load_k)
	rig.turn("splitter_valve", Vector3.UP, valve)
	rig.turn("mode_flag", Vector3.BACK, flag)
	var busy := shot and a < 1.0
	rig.show_part("feed_glow_l", not busy or m < 0.5)
	rig.show_part("feed_glow_r", not busy or m >= 0.5)
