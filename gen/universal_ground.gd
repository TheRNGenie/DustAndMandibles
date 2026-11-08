class_name UniversalGround
extends RefCounted
## Universal crop-fed turrets: the 5 obstructions (Crop Mine, Stake Pit, Tangle
## Line, Crop Palisade, Scatter Patch). Ground pieces that don't aim: each one
## has a placing animation (ctx.placed_age), an armed idle, and what happens when
## it goes off (ctx.triggered, ctx.trigger_age); UniversalObstruction removes it
## a moment later. Built in code in the parts the handoff lists (see UniKit).


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"cf_crop_mine": return _mine(team)
		&"cf_stake_pit": return _stake_pit(team)
		&"cf_tangle_line": return _tangle_line(team)
		&"cf_crop_palisade": return _palisade(team)
		&"cf_scatter_patch": return _scatter_patch(team)
	return {}


static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match id:
		&"cf_crop_mine": _anim_mine(rig, ctx, delta)
		&"cf_stake_pit": _anim_stake_pit(rig, ctx, delta)
		&"cf_tangle_line": _anim_tangle_line(rig, ctx, delta)
		&"cf_crop_palisade": _anim_palisade(rig, ctx, delta)
		&"cf_scatter_patch": _anim_scatter_patch(rig, ctx, delta)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


# ------------------------------------------------------------------ 21. Crop Mine

## A flat iron disc half in the dirt, a pressure plate on top, crop light seeping
## through the seams, and a ring of blast holes round the rim.
static func _mine(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("dirt", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.01, 0)), 0.62, 0.5, 0.03, 14, Color("#9A7650"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			var a := rng.randf() * TAU
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.52, 0.02, sin(a) * 0.52)), Vector3(0.07, 0.03, 0.06), 2, 5, Color("#8A6644")))))
	parts.append(UniKit.part("mine_body", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.4, 0.36, 0.12, 16, UniKit.IRON_DK)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.41, 0.33, 0.03, 16, UniKit.IRON)
		UniKit.rivet_ring(st, Vector3(0, 0.065, 0), 0.37, 10, 0.016)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.3, 0.07, 0)), Vector3(0.06, 0.012, 0.04), team)),
		Vector3(0, 0.02, 0), Basis(), {"trim": {"c": Vector3.ZERO, "r": 0.4, "h": 0.12}}))
	parts.append(UniKit.part("crop_charge", "mine_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.062, 0)), 0.31, 0.27, 0.01, 16, UniKit.GLOW_WHITE)
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.34, 0.03, sin(a) * 0.34)), Vector3(0.012, 0.05, 0.08), UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("detonation_ring", "mine_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 12:
			var a := TAU * i / 12.0
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(Vector3(cos(a), 0, sin(a))), Vector3(cos(a) * 0.395, 0.0, sin(a) * 0.395)),
					0.018, 0.018, 0.02, 6, Color("#1A1A1E"))), Vector3.ZERO))
	parts.append(UniKit.part("pressure_plate", "mine_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.22, 0.22, 0.03, 14, UniKit.BRASS_DK)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.012, 0)), 0.2, 0.12, 0.012, 14, UniKit.BRASS)), Vector3(0, 0.075, 0)))
	# Going off: a scorched crater left in the dirt and a shockwave ring racing out.
	parts.append(UniKit.part("crater", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.012, 0)), 0.5, 0.42, 0.02, 14, Color("#3A2E26"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 8:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.45, 0.7)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, 0.015, sin(a) * r)), Vector3(0.07, 0.02, 0.04), UniKit.IRON_DK)),
		Vector3.ZERO))
	parts.append(UniKit.part("blast_ring", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.5, 0.42, 0.03, 24, UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": 0.0, "gun_y": 0.0, "parts": parts, "muzzles": [Vector3(0, 0.15, 0)], "no_aim": true, "ring_r": 0.7,
		"pour": Vector3(0, 0.5, 0), "idle_at": Vector3(0, 0.1, 0)}


## Placed: drops into the dirt with a puff. Armed: the plate trembles. Triggered:
## the plate clicks down 1 cm, 0.1 s later the mine heaves up and swells as it
## goes, a shockwave ring races out over the ground and a scorched crater is left.
static func _anim_mine(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var sink := 1.0 - _ease(ctx.placed_age / 0.35)
	var shake := 0.0
	if ctx.loaded and ctx.in_wave:
		shake = sin(ctx.t * 40.0) * 0.0015
	if not ctx.triggered:
		rig.show_part("crater", false)
		rig.show_part("blast_ring", false)
		rig.pose("mine_body", Vector3(0, 0.15 * sink, 0))
		rig.pose("pressure_plate", Vector3(0, shake, 0))
		return
	var k := ctx.trigger_age
	rig.pose("pressure_plate", Vector3(0, -0.01, 0))
	rig.show_part("crater", k >= 0.1)
	rig.show_part("blast_ring", k >= 0.1 and k < 0.6)
	if k >= 0.1:
		var w := 0.4 + 3.0 * _ease((k - 0.1) / 0.5)
		rig.stretch("blast_ring", Vector3(w, 1, w))
	if k < 0.1:
		rig.pose("mine_body")
		return
	var up := _ease((k - 0.1) / 0.15)
	var s := 1.0 + up * 0.6
	rig.stretch("mine_body", Vector3(s, s, s) * (1.0 - smoothstep(0.3, 0.45, k)), Vector3(0, up * 0.4, 0))


# ------------------------------------------------------------------ 22. Stake Pit

## Disturbed earth with five to seven iron-cored stakes jutting at angles, their
## points coated in the crop.
static func _stake_pit(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("ground_patch", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.lathe(st, Transform3D(), [Vector2(0.75, 0.0), Vector2(0.62, 0.06), Vector2(0.3, 0.1), Vector2(0.0, 0.11)], 14, Color("#9A7650"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in 8:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.3, 0.7)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * r, 0.06, sin(a) * r)), Vector3(0.06, 0.03, 0.05), 2, 5, Color("#7E5C3C"))
		MeshKit.add_limb(st, Vector3(0.62, 0.0, 0.3), Vector3(0.66, 0.35, 0.32), 0.012, UniKit.WOOD_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.66, 0.31, 0.38)), Vector3(0.01, 0.07, 0.12), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.05, 0), "r": 0.62, "h": 0.1}}))
	var stakes := [[0.0, 0.0, 0.0, 0.62], [0.28, 0.1, 0.35, 0.5], [-0.25, 0.18, -0.3, 0.52], [0.12, -0.3, 0.3, 0.46],
		[-0.2, -0.22, -0.32, 0.48], [0.34, -0.12, 0.45, 0.42], [-0.36, 0.0, -0.5, 0.44]]
	parts.append(UniKit.pivot("spike_cluster", "base", Vector3(0, 0.08, 0)))
	for i in stakes.size():
		var s: Array = stakes[i]
		var tilt := Basis(Vector3(s[1], 0, -s[0]).normalized() if Vector2(s[0], s[1]).length() > 0.01 else Vector3.RIGHT, float(s[2]))
		var h := float(s[3])
		parts.append(UniKit.part("stake_%d" % i, "spike_cluster", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.4, 0)), 0.035, 0.028, h * 0.8, 6, UniKit.WOOD)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.06, 0)), 0.04, 0.04, 0.05, 6, UniKit.IRON_DK)),
			Vector3(s[0], 0, s[1]), tilt))
		parts.append(UniKit.part("crop_coating_%d" % i, "stake_%d" % i, UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.9, 0)), 0.03, 0.0, h * 0.22, 6, UniKit.GLOW_WHITE)),
			Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": 0.0, "gun_y": 0.0, "parts": parts, "muzzles": [Vector3(0, 0.4, 0)], "no_aim": true, "ring_r": 0.85,
		"pour": Vector3(0, 0.8, 0), "idle_at": Vector3(0, 0.3, 0)}


## Placed: the earth bulges up and the stakes punch out of it. Triggered: the
## stakes snap and fall flat, the mound slumps.
static func _anim_stake_pit(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var rise := _ease((ctx.placed_age - 0.1) / 0.3)
	rig.stretch("ground_patch", Vector3(1, maxf(_ease(ctx.placed_age / 0.2), 0.05), 1))
	if not ctx.triggered:
		rig.pose("spike_cluster", Vector3(0, -0.5 * (1.0 - rise), 0))
		for i in 7:
			rig.turn("stake_%d" % i, Vector3.UP, sin(ctx.t * 0.7 + i) * 0.01)
		return
	var k := _ease(ctx.trigger_age / 0.25)
	for i in 7:
		var dir := Vector3(cos(i * 2.1), 0, sin(i * 2.1))
		rig.pose("stake_%d" % i, -Vector3.UP * 0.1 * k, Basis(dir.cross(Vector3.UP).normalized(), 1.2 * k))
	rig.stretch("ground_patch", Vector3(1.05, 1.0 - 0.7 * k, 1.05))


# ------------------------------------------------------------------ 23. Tangle Line

## Two short iron stakes about 2 m apart and a crop-fibre wire between them at ankle height.
static func _tangle_line(team: Color) -> Dictionary:
	var parts: Array = []
	for side: float in [-1.0, 1.0]:
		var nm := "post_left" if side < 0.0 else "post_right"
		parts.append(UniKit.part(nm, "base", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.04, 0.03, 0.42, 6, UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.34, 0)), 0.055, 0.055, 0.05, 6, UniKit.IRON_DK)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.12, 0)), 0.03, 0.0, 0.14, 6, UniKit.IRON_DK)
			MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.055, 0.035, 0.03, 8, UniKit.ROPE)
			if side > 0.0:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.3, 0.07)), Vector3(0.01, 0.06, 0.1), team)),
			Vector3(side * 0.95, 0, 0)))
	parts.append(UniKit.part("wire", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.012, 0.012, 1.9, 6, UniKit.GLOW_WHITE)),
		Vector3(0, 0.2, 0), Basis(), {"glow": true}))
	parts.append(UniKit.part("wire_fibres", "wire", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 9:
			var x := -0.85 + i * 0.21
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(x, 0.0, 0)), Vector3(0.03, 0.022, 0.022), 2, 5, Color(0.9, 0.9, 0.88))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("divots", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		for side: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(side * 0.95, 0.005, 0)), 0.12, 0.09, 0.01, 8, Color("#8A6644"))),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.02, 0), "size": Vector3(2.0, 0.04, 0.2)}}))
	return {"head_y": 0.0, "gun_y": 0.0, "parts": parts, "muzzles": [Vector3(0, 0.25, 0)], "no_aim": true, "ring_r": 1.05,
		"pour": Vector3(0, 0.6, 0), "idle_at": Vector3(0, 0.2, 0)}


## Placed: the stakes hammer down, then the wire stretches out from the middle.
## Idle: a little sway. Triggered: the wire snaps taut and drags the stakes up
## and in towards the bug, then it's all gone.
static func _anim_tangle_line(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var drive := 1.0 - _ease(ctx.placed_age / 0.15)
	var stretch := _ease((ctx.placed_age - 0.15) / 0.2)
	if not ctx.triggered:
		rig.pose("post_left", Vector3(0, 0.3 * drive, 0))
		rig.pose("post_right", Vector3(0, 0.3 * drive, 0))
		var sway := sin(ctx.t * 1.7) * 0.006
		rig.stretch("wire", Vector3(maxf(stretch, 0.01), 1, 1), Vector3(0, 0, sway))
		return
	var k := _ease(ctx.trigger_age / 0.3)
	rig.pose("post_left", Vector3(0.6 * k, 0.25 * k, 0), Basis(Vector3.BACK, -0.9 * k))
	rig.pose("post_right", Vector3(-0.6 * k, 0.25 * k, 0), Basis(Vector3.BACK, 0.9 * k))
	rig.stretch("wire", Vector3(maxf(1.0 - 0.6 * k, 0.05), 1, 1), Vector3(0, 0.1 * k, -0.2 * sin(k * PI)))


# ------------------------------------------------------------------ 24. Crop Palisade

## A waist-high timber frame (posts and rails) packed with crop bundles, rope
## lashings, and crop-hardened spike tips along the top.
static func _palisade(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("wall_frame", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 4:
			var x := -0.9 + i * 0.6
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03)), Vector3(x, 0.6, 0)), Vector3(0.12, 1.25, 0.12), UniKit.WOOD_DK, 0.01, rng)
		for y: float in [0.25, 0.95]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.02, 0.02)), Vector3(0, y, 0.07)), Vector3(1.95, 0.09, 0.06), UniKit.WOOD, 0.01, rng)
		# The cap rail along the top the spike tips are nailed into.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.17, 0)), Vector3(2.0, 0.07, 0.14), UniKit.WOOD)
		UniKit.rivet_row(st, Vector3(-0.95, 1.21, 0.0), Vector3(0.95, 1.21, 0.0), 8, 0.016)
		for i in 4:
			var x := -0.9 + i * 0.6
			for y: float in [0.25, 0.95]:
				MeshKit.add_rim(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, y, 0.07)), 0.075, 0.05, 0.05, 8, UniKit.ROPE)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.9, 1.12, 0.07)), Vector3(0.02, 0.12, 0.16), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.6, 0), "size": Vector3(1.95, 1.2, 0.18)}}))
	for i in 3:
		var x := -0.6 + i * 0.6
		parts.append(UniKit.part("crop_bundles_%d" % i, "wall_frame", UniKit.mesh(func(st: SurfaceTool) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 30 + i
			for row in 4:
				for b in 2:
					var c := Vector3((b - 0.5) * 0.27 + rng.randf_range(-0.02, 0.02), 0.15 + row * 0.24, rng.randf_range(-0.03, 0.03))
					MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, c), 0.11, 0.115, 0.24, 8,
							Color(0.95, 0.95, 0.92) if (row + b) % 2 == 0 else Color(0.8, 0.8, 0.76))
					MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, c), 0.118, 0.1, 0.03, 8, UniKit.ROPE)),
			Vector3(x, 0.0, 0), Basis(), {"crop": true}))
	parts.append(UniKit.part("spike_trim", "wall_frame", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 7:
			var x := -0.9 + i * 0.3
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(x, 1.3, -0.025)), 0.03, 0.0, 0.2, 6, UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": 0.0, "gun_y": 0.0, "parts": parts, "muzzles": [Vector3(0, 1.0, 0)], "no_aim": true, "ring_r": 1.1,
		"pour": Vector3(0, 1.4, 0), "idle_at": Vector3(0, 0.8, 0)}


## Placed: the posts slam down, the rails go on, the bundles fill in (0.5 s).
## Hit: a jiggle. Worn down: the bundles sag and thin and the frame leans.
## Destroyed (triggered): the frame topples back flat and the bundles burst.
static func _anim_palisade(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var slam := 1.0 - _ease(ctx.placed_age / 0.18)
	var fill := _ease((ctx.placed_age - 0.2) / 0.3)
	var last_hp := float(rig.state.get("hp", ctx.hp_frac))
	var jig := float(rig.state.get("jig", 0.0))
	if ctx.hp_frac < last_hp - 0.001:
		jig = 1.0
	jig = move_toward(jig, 0.0, delta * 4.0)
	rig.state["hp"] = ctx.hp_frac
	rig.state["jig"] = jig
	var lean := (1.0 - smoothstep(0.2, 0.5, ctx.hp_frac)) * 0.12
	rig.pose("wall_frame", Vector3(sin(ctx.t * 60.0) * 0.01 * jig, 0.6 * slam, 0), Basis(Vector3.RIGHT, lean))
	for i in 3:
		var wear := clampf(ctx.hp_frac * 1.4 - (0.15 * i), 0.15, 1.0)
		rig.stretch("crop_bundles_%d" % i, Vector3(maxf(fill, 0.02), maxf(fill * wear, 0.02), maxf(fill, 0.02)))
	rig.show_part("spike_trim", fill > 0.9)
	if ctx.triggered:
		# Destroyed: the frame splinters and topples back onto the ground,
		# the bundles burst apart.
		var k := _ease(ctx.trigger_age / 0.45)
		rig.pose("wall_frame", Vector3(0, -0.08 * k, 0.15 * k), Basis(Vector3.RIGHT, 1.35 * k))
		for i in 3:
			var burst := 1.0 + 0.5 * k
			rig.stretch("crop_bundles_%d" % i, Vector3(burst, maxf(1.0 - k, 0.05), burst), Vector3(0, 0, -0.3 * k * (i - 1)))


# ------------------------------------------------------------------ 25. Scatter Patch

## Loose crop scattered over a patch of ground (no structure), a few dry husks.
static func _scatter_patch(team: Color) -> Dictionary:
	var parts: Array = []
	parts.append(UniKit.part("ground_debris_patch", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		# An uneven patch of churned ground with darker scuffs (fits the 2 m cell).
		var rng := RandomNumberGenerator.new()
		rng.seed = 61
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.004, 0)), 0.97, 0.95, 0.008, 18, Color("#A88A60"))
		for i in 7:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.2, 0.75)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(cos(a) * r, 0.007, sin(a) * r)), rng.randf_range(0.12, 0.22), 0.1, 0.008, 8, Color("#957650"))
		# A few dry husks and stalks lying about.
		for i in 9:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.15, 0.85)
			var p := Vector3(cos(a) * r, 0.012, sin(a) * r)
			var d := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * rng.randf_range(0.08, 0.16)
			MeshKit.add_limb(st, p - d, p + d, 0.008, UniKit.ROPE, 5)
		MeshKit.add_limb(st, Vector3(0.9, 0.0, 0.0), Vector3(0.92, 0.3, 0.0), 0.01, UniKit.WOOD_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.92, 0.26, 0.06)), Vector3(0.01, 0.06, 0.1), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.01, 0), "r": 0.95, "h": 0.02}}))
	for ring in 3:
		parts.append(UniKit.part("crop_scatter_%d" % ring, "base", UniKit.mesh(func(st: SurfaceTool) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 90 + ring
			for i in 34:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.03, 0.32) + ring * 0.31
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, 0.02, sin(a) * r)),
						Vector3(rng.randf_range(0.03, 0.06), 0.018, rng.randf_range(0.02, 0.04)), 2, 5,
						Color(1, 1, 1) if i % 3 else Color(0.78, 0.76, 0.72))), Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("crop_particles", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.012, 0)), 0.99, 0.94, 0.01, 32, UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": 0.0, "gun_y": 0.0, "parts": parts, "muzzles": [Vector3(0, 0.2, 0)], "no_aim": true, "ring_r": 1.0,
		"pour": Vector3(0, 0.7, 0), "idle_at": Vector3(0, 0.1, 0)}


## Placed: the crop scatters out from the middle (0.3 s). Worn: trampled
## (ctx.hp_frac = tramples left) the outer rings thin and go first.
static func _anim_scatter_patch(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var out := _ease(ctx.placed_age / 0.3)
	for ring in 3:
		var keep := clampf(ctx.hp_frac * 3.0 - (2 - ring) + 0.3, 0.0, 1.0)
		var s := maxf(out * (0.7 + 0.3 * keep), 0.02)
		rig.stretch("crop_scatter_%d" % ring, Vector3(s, maxf(keep, 0.05), s))
		rig.show_part("crop_scatter_%d" % ring, keep > 0.05 and ctx.loaded)
	var glow := 1.0
	if ctx.triggered:
		# Trampled flat: what's left sinks away and the zone line closes in (0.5 s).
		var k := _ease(ctx.trigger_age / 0.5)
		glow = maxf(1.0 - k, 0.02)
		for ring in 3:
			rig.stretch("crop_scatter_%d" % ring, Vector3(1.0, maxf(1.0 - k, 0.05), 1.0))
	else:
		# The zone edge shimmers a little; it shrinks as the patch thins.
		glow = (0.85 + 0.15 * ctx.hp_frac) * (1.0 + 0.01 * sin(ctx.t * 3.0))
	rig.stretch("crop_particles", Vector3(glow, 1.0, glow))
