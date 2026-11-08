class_name UniversalHouse
extends RefCounted
## Universal crop-fed turrets: the 5 last resorts on the house mounts (Crop
## Blaster, Feed Porch Gun, Roof Perch, Porch Fog, Homestead Bastion). Models
## built in code in the parts the handoff lists (see UniKit for the conventions
## and UniversalBuilder for the spec), and their animation.
##
## They mount on the house (porch rail, roof peak or wall: one bracket each), so
## they're smaller than the cliff guns: ~0.6-1.0 m, within ~0.5 m of centre.


## The id's spec, or {} for one not built yet (UniversalBuilder uses a stand-in).
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"cf_crop_blaster": return _crop_blaster(team)
		&"cf_feed_porch_gun": return _feed_porch_gun(team)
		&"cf_roof_perch": return _roof_perch(team)
		&"cf_porch_fog": return _porch_fog(team)
		&"cf_homestead_bastion": return _homestead_bastion(team)
	return {}


## Every frame, every peer: pose the id's moving parts (see UniCtx).
static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match id:
		&"cf_crop_blaster": _anim_crop_blaster(rig, ctx, delta)
		&"cf_feed_porch_gun": _anim_feed_porch_gun(rig, ctx, delta)
		&"cf_roof_perch": _anim_roof_perch(rig, ctx, delta)
		&"cf_porch_fog": _anim_porch_fog(rig, ctx, delta)
		&"cf_homestead_bastion": _anim_homestead_bastion(rig, ctx, delta)


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


## The index (0..n-1) of the barrel that fired the latest shot, matching the
## turret class's muzzle order (shot 1 comes out of muzzle 0); -1 before any shot.
static func fired_index(shots: int, n: int) -> int:
	if shots <= 0:
		return -1
	return (shots - 1) % n


## A small swivel fork on the porch mount's stub: a turntable disc and two
## cheeks at +-cheek_x holding the gun's trunnion at `gun_y`.
static func _fork(st: SurfaceTool, cheek_x: float, gun_y: float) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.13, 0.13, 0.04, 14, UniKit.IRON_DK)
	UniKit.rivet_ring(st, Vector3(0, 0.04, 0), 0.105, 8, 0.014)
	for sx: float in [-1.0, 1.0]:
		var h := gun_y + 0.03 - 0.04
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * cheek_x, 0.04 + h * 0.5, 0)), Vector3(0.03, h, 0.08), UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * (cheek_x + 0.02), gun_y, 0)), 0.028, 0.028, 0.015, 8, UniKit.BRASS)


## A spent shell's flight after a shot: hidden except between `from` and `to`
## seconds after it, flipping out sideways (+X) and falling.
static func _eject(rig: UniRig, ctx: UniCtx, n: String, from: float, to: float, side: float = 1.0) -> void:
	var a := ctx.shot_age
	var on := ctx.shots > 0 and a > from and a < to
	rig.show_part(n, on)
	if on:
		var e := a - from
		rig.pose(n, Vector3(side * 0.7 * e, 0.45 * e - 2.2 * e * e, 0.15 * e), Basis(Vector3.UP, e * 24.0))


# ------------------------------------------------------------------ 16. Crop Blaster

## A short wide-bore pump shotgun on a porch-rail swivel: flared barrel under a
## perforated heat shield, a caged tube magazine of crop shells underneath with
## a wooden pump slide on it, a wooden stock with the team stripe.
## Parts: porch_mount, swivel_fork, shotgun_body (+ muzzle_glow, spent_shell,
## loading_gate), heat_shield, crop_shell_tube (+ shell_tube_fill,
## shell_tube_glow), pump_mechanism.
static func _crop_blaster(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.12
	parts.append(UniKit.part("porch_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.porch_mount(st, 0.42))))
	parts.append(UniKit.part("swivel_fork", "head", UniKit.mesh(func(st: SurfaceTool) -> void: _fork(st, 0.09, gun_y))))
	parts.append(UniKit.part("shotgun_body", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		# Receiver, trunnion, the wide barrel flaring at the muzzle.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0.04)), Vector3(0.12, 0.1, 0.2), UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.022, 0.022, 0.16, 8, UniKit.BRASS_DK)
		UniKit.barrel(st, 0, 0.012, -0.06, -0.33, 0.045, UniKit.IRON_DK, 12, 0.048)
		UniKit.barrel(st, 0, 0.012, -0.33, -0.4, 0.048, UniKit.IRON_DK, 12, 0.068)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0.012, -0.398)), 0.055, 0.055, 0.01, 12, Color("#1A1B1F"))
		UniKit.band(st, 0, 0.012, -0.065, 0.055, 0.025, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.061, 0.01, 0.05)), Vector3(0.004, 0.035, 0.07), Color("#1A1B1F"))
		# Wooden stock and grip with the team stripe, brass butt plate.
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, -0.035, 0.22)), Vector3(0.06, 0.08, 0.18), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, -0.052, 0.315)), Vector3(0.065, 0.1, 0.015), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, -0.035, 0.23)), Vector3(0.064, 0.02, 0.1), team)
		UniKit.rivet_row(st, Vector3(-0.061, 0.03, -0.03), Vector3(-0.061, 0.03, 0.12), 3, 0.012)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0, 0.04), "size": Vector3(0.12, 0.1, 0.2)}}))
	parts.append(UniKit.part("muzzle_glow", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0.012, -0.355, 0.058, 0.02, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The perforated heat shield: a half shroud of tiles over the barrel's top.
	parts.append(UniKit.part("heat_shield", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		for row in 5:
			var z := -0.09 - row * 0.048
			for col in 5:
				var a := deg_to_rad(20.0 + col * 35.0)
				var p := Vector3(cos(a) * 0.062, 0.012 + sin(a) * 0.062, z)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), p), Vector3(0.028, 0.006, 0.036), UniKit.IRON_LT)
		for z: float in [-0.075, -0.3]:
			for col in 9:
				var a := deg_to_rad(10.0 + col * 20.0)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), Vector3(cos(a) * 0.063, 0.012 + sin(a) * 0.063, z)), Vector3(0.024, 0.008, 0.012), UniKit.BRASS_DK)),
		Vector3.ZERO))
	# The tube magazine under the barrel: end caps and three rails caging the shells.
	parts.append(UniKit.part("crop_shell_tube", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, -0.27, -0.3, 0.028, UniKit.BRASS, 10)
		UniKit.barrel(st, 0, 0, -0.03, 0.0, 0.028, UniKit.BRASS, 10)
		for a: float in [PI * 0.5, PI * 0.5 + TAU / 3.0, PI * 0.5 - TAU / 3.0]:
			MeshKit.add_limb(st, Vector3(cos(a) * 0.024, sin(a) * 0.024, -0.02), Vector3(cos(a) * 0.024, sin(a) * 0.024, -0.28), 0.005, UniKit.IRON_DK, 5)),
		Vector3(0, -0.058, -0.04)))
	parts.append(UniKit.part("shell_tube_fill", "crop_shell_tube", UniKit.mesh(func(st: SurfaceTool) -> void:
		for k in 4:
			UniKit.barrel(st, 0, 0, -0.035 - k * 0.058, -0.087 - k * 0.058, 0.02, Color(1, 1, 1) if k % 2 == 0 else Color(0.85, 0.85, 0.85), 10)),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("shell_tube_glow", "crop_shell_tube", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.305, 0.022, 0.012, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The pump: a grooved wooden fore-end round the magazine, action bars back to the receiver.
	parts.append(UniKit.part("pump_mechanism", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.075, 0.06, 0.08), UniKit.WOOD)
		for z: float in [-0.025, 0.0, 0.025]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.031, z)), Vector3(0.078, 0.006, 0.008), UniKit.WOOD_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.04, 0.012, 0.075)), Vector3(0.006, 0.012, 0.13), UniKit.IRON_LT)),
		Vector3(0, -0.058, -0.17)))
	parts.append(UniKit.part("spent_shell", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.02, -0.03, 0.018, Color("#B8352A"), 8)
		UniKit.barrel(st, 0, 0, 0.03, 0.02, 0.019, UniKit.BRASS, 8)), Vector3(0.065, 0.01, 0.05)))
	# The loading gate under the receiver, hinged at its front edge.
	parts.append(UniKit.part("loading_gate", "shotgun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.004, 0.04)), Vector3(0.06, 0.008, 0.08), UniKit.BRASS)),
		Vector3(0, -0.05, 0.0)))
	return {"head_y": 0.42, "gun_y": gun_y, "parts": parts, "muzzles": [["shotgun_body", Vector3(0, 0.012, -0.42)]],
		"pour": Vector3(0, gun_y - 0.1, 0.05), "idle_at": Vector3(0, 0.012, -0.42), "ring_r": 0.5}


## Heavy 3 cm kick, back in 0.25 s. The pump racks: back 5 cm then forward over
## 0.2 s after the kick, while the spent shell flips out of the right-hand port.
## Empty: the pump sits forward (open). The loading gate drops open while loading.
static func _anim_crop_blaster(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	rig.kick("shotgun_body", 0.03 * kick_k(a, 0.25))
	var pump := 0.0
	if not ctx.loaded:
		pump = -0.05
	elif ctx.shots > 0 and a > 0.08 and a < 0.28:
		pump = 0.05 * sin(PI * (a - 0.08) / 0.2)
	rig.pose("pump_mechanism", Vector3(0, 0, pump))
	_eject(rig, ctx, "spent_shell", 0.12, 0.5)
	rig.turn("loading_gate", Vector3.RIGHT, 1.2 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 17. Feed Porch Gun

## A compact brass twin-barrel gun on a railing swivel, belt-fed from a crop box
## hung off the swivel's left side, with a shell chute down its right side.
## Parts: porch_mount, swivel_yoke, gun_body, twin_barrels (barrel_l / barrel_r
## with glow bands), crop_belt_feed (the box, + crop_box_fill, crop_box_lid),
## belt (+ belt_rounds), shell_chute (+ shell_a, shell_b).
static func _feed_porch_gun(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.13
	parts.append(UniKit.part("porch_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.porch_mount(st, 0.42))))
	parts.append(UniKit.part("swivel_yoke", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_fork(st, 0.1, gun_y)
		# The arm carrying the crop box on the left.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.15, 0.02, 0.1)), Vector3(0.16, 0.025, 0.05), UniKit.IRON_DK))))
	parts.append(UniKit.part("gun_body", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0.04)), Vector3(0.15, 0.12, 0.22), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.065, 0.04)), Vector3(0.12, 0.012, 0.18), team)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.022, 0.022, 0.19, 8, UniKit.IRON_DK)
		UniKit.rivet_row(st, Vector3(-0.076, 0.035, -0.05), Vector3(-0.076, 0.035, 0.13), 4, 0.012)
		UniKit.rivet_row(st, Vector3(0.076, 0.035, -0.05), Vector3(0.076, 0.035, 0.13), 4, 0.012)
		# The feed port on the left, the cocking lever and spade grips at the back.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.08, 0.02, 0.1)), Vector3(0.02, 0.04, 0.06), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.04, -0.02, 0.15), Vector3(sx * 0.045, -0.06, 0.2), 0.012, UniKit.WOOD_DK, 6)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0, 0.04), "size": Vector3(0.15, 0.12, 0.22)}}))
	parts.append(UniKit.part("twin_barrels", "gun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.0)), Vector3(0.14, 0.06, 0.03), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.19)), Vector3(0.12, 0.05, 0.02), UniKit.BRASS)),
		Vector3(0, 0.0, -0.085)))
	for side: Array in [["barrel_l", -0.035], ["barrel_r", 0.035]]:
		var bn: String = side[0]
		parts.append(UniKit.part(bn, "twin_barrels", UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, 0.02, -0.28, 0.02, UniKit.IRON_DK, 10)
			UniKit.barrel(st, 0, 0, -0.27, -0.3, 0.025, UniKit.BRASS_DK, 10)), Vector3(float(side[1]), 0, 0)))
		parts.append(UniKit.part(bn + "_glow", bn, UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, -0.24, 0.024, 0.025, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The crop box: a wooden crate on the yoke's arm, lid hinged at the back.
	var box := Vector3(-0.22, -0.02, 0.1)
	parts.append(UniKit.part("crop_belt_feed", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.11, 0.1, 0.14), UniKit.WOOD)
		for y: float in [-0.03, 0.03]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(0.115, 0.012, 0.145), UniKit.IRON_DK)),
		box))
	parts.append(UniKit.part("crop_box_fill", "crop_belt_feed", UniKit.mesh(func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.045, 0)), Vector3(0.095, 0.02, 0.125), Color(0.85, 0.85, 0.85))
		for k in 10:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(rng.randf_range(-0.04, 0.04), 0.057, rng.randf_range(-0.055, 0.055))), Vector3(0.014, 0.01, 0.014), 2, 5, Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("crop_box_lid", "crop_belt_feed", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.006, -0.072)), Vector3(0.118, 0.012, 0.146), UniKit.WOOD_DK)),
		Vector3(0, 0.05, 0.072)))
	# The belt: links from the box's top up into the gun's feed port (just
	# behind the trunnion, so it barely moves as the gun pitches).
	var b0 := box + Vector3(0.03, 0.05, 0)
	var b1 := Vector3(-0.09, gun_y + 0.02, 0.1)
	var dir := (b1 - b0).normalized()
	var links := 6
	var pitch := b0.distance_to(b1) / float(links)
	var lb := Basis(Vector3.BACK, atan2(dir.y, dir.x))
	parts.append(UniKit.part("belt", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		for k in links:
			MeshKit.add_box(st, Transform3D(lb, dir * pitch * (k + 0.5)), Vector3(pitch * 0.55, 0.008, 0.06), UniKit.BRASS_DK)),
		b0))
	parts.append(UniKit.part("belt_rounds", "belt", UniKit.mesh(func(st: SurfaceTool) -> void:
		for k in links:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, dir * pitch * (k + 0.5) + lb * Vector3(0, 0.012, 0)), 0.011, 0.011, 0.05, 6, Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	# The shell chute down the right side, two casings sliding out of it while firing.
	parts.append(UniKit.part("shell_chute", "gun_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		var cb := Basis(Vector3.BACK, -0.7)
		MeshKit.add_box(st, Transform3D(cb, Vector3(0.05, -0.03, 0)), Vector3(0.12, 0.008, 0.05), UniKit.IRON)
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(cb, cb * Vector3(0, 0.015, 0) + Vector3(0.05, -0.03, sz * 0.025)), Vector3(0.12, 0.03, 0.006), UniKit.IRON)),
		Vector3(0.075, 0.0, 0.06)))
	for sn: String in ["shell_a", "shell_b"]:
		parts.append(UniKit.part(sn, "shell_chute", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.009, 0.009, 0.035, 6, UniKit.BRASS)),
			Vector3(0.0, 0.0, 0.0)))
	return {"head_y": 0.42, "gun_y": gun_y, "parts": parts,
		"muzzles": [["barrel_l", Vector3(0, 0, -0.32)], ["barrel_r", Vector3(0, 0, -0.32)]],
		"pour": box + Vector3(0, 0.25, 0), "idle_at": Vector3(0, 0, -0.42), "ring_r": 0.5,
		"belt": {"dir": dir, "pitch": pitch}}


## Barrels alternate, 1 cm kicks each. The belt steps one link per shot (it
## pulls a link's length then snaps back, so it reads as a continuous feed) and
## sags slack when empty. Casings slide down the chute and drop out while the
## gun is firing. The crop box lid opens while loading.
static func _anim_feed_porch_gun(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var fired := fired_index(ctx.shots, 2)
	var k := kick_k(ctx.shot_age, 0.05)
	rig.kick("barrel_l", 0.01 * k if fired == 0 else 0.0)
	rig.kick("barrel_r", 0.01 * k if fired == 1 else 0.0)
	var belt: Dictionary = rig.spec.get("belt", {})
	var dir: Vector3 = belt.get("dir", Vector3.RIGHT)
	var pitch := float(belt.get("pitch", 0.03))
	if ctx.loaded:
		var step := 0.0
		if ctx.shots > 0 and ctx.shot_age < 0.1:
			step = smoothstep(0.0, 0.08, ctx.shot_age)
		rig.pose("belt", dir * pitch * step)
	else:
		rig.turn("belt", Vector3.BACK, -0.45)
	# Two casings chase each other down the chute while firing.
	var pouring := ctx.loaded and ctx.firing > 0.0 and ctx.shot_age < 0.3
	var chute := Basis(Vector3.BACK, -0.7)
	for i in 2:
		var n := "shell_a" if i == 0 else "shell_b"
		rig.show_part(n, pouring)
		if pouring:
			var f := fposmod(ctx.t * 6.0 + i * 0.5, 1.0)
			var p := chute * Vector3(f * 0.13, 0.02, 0) + Vector3(0.0, -0.03 - f * f * 0.06, 0)
			rig.pose(n, p, Basis(Vector3.RIGHT, f * 9.0))
	rig.turn("crop_box_lid", Vector3.RIGHT, 1.7 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 18. Roof Perch

## A long precision rifle on a bipod over a saddle bracket clamped to the roof
## ridge: brass scope, bolt action on the right, a rear-loading crop chamber.
## Parts: roof_mount, perch_swivel, rifle_body (+ bipod, barrel_glow, casing),
## scope (+ scope_lens), bolt_action, crop_breech (+ breech_fill, breech_glow,
## breech_cap).
static func _roof_perch(team: Color) -> Dictionary:
	var parts: Array = []
	var head_y := 0.34
	var gun_y := 0.2
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		# A saddle over the ridge: two sloped plates meeting at a capped apex.
		for sx: float in [-1.0, 1.0]:
			var b := Basis(Vector3.BACK, sx * -0.55)
			MeshKit.add_box(st, Transform3D(b, Vector3(sx * 0.16, 0.09, 0)), Vector3(0.36, 0.03, 0.5), UniKit.IRON_DK)
			for sz: float in [-1.0, 1.0]:
				UniKit.bolt(st, Vector3(sx * 0.26, 0.04, sz * 0.18) + b * Vector3(0, 0.016, 0), b * Vector3.UP, 0.022, 0.02)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0.18, 0)), 0.035, 0.035, 0.52, 8, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.26, 0)), 0.06, 0.07, 0.16, 10, UniKit.IRON)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, head_y - 0.015, 0)), 0.1, 0.06, 0.03, 12, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.2, 0.25)), Vector3(0.08, 0.02, 0.012), team))))
	parts.append(UniKit.part("perch_swivel", "head", UniKit.mesh(func(st: SurfaceTool) -> void: _fork(st, 0.06, gun_y))))
	parts.append(UniKit.part("rifle_body", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		# Receiver, wood fore-end and stock, a long barrel.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0.03)), Vector3(0.07, 0.07, 0.2), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.018, 0.018, 0.12, 8, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.03, -0.17)), Vector3(0.055, 0.04, 0.2), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.035, 0.25)), Vector3(0.05, 0.08, 0.24), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.05, 0.37)), Vector3(0.055, 0.1, 0.014), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.035, 0.2)), Vector3(0.054, 0.02, 0.05), team)
		UniKit.barrel(st, 0, 0.01, -0.07, -0.62, 0.02, UniKit.IRON_DK, 10, 0.016)
		UniKit.band(st, 0, 0.01, -0.27, 0.026, 0.02, UniKit.BRASS)
		UniKit.barrel(st, 0, 0.01, -0.6, -0.64, 0.02, UniKit.BRASS_DK, 10)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.036, 0.015, 0.06)), Vector3(0.004, 0.025, 0.05), Color("#1A1B1F"))),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0, 0.03), "size": Vector3(0.07, 0.07, 0.2)}}))
	# The bipod: two splayed legs from a clamp under the fore-end.
	parts.append(UniKit.part("bipod", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, 0, 0.03, 0.025, UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.015, -0.01, 0), Vector3(sx * 0.13, -0.28, -0.06), 0.009, UniKit.IRON, 6)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sx * 0.13, -0.285, -0.06)), Vector3(0.018, 0.01, 0.018), 2, 6, UniKit.IRON_DK)),
		Vector3(0, -0.04, -0.3)))
	parts.append(UniKit.part("barrel_glow", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0.01, -0.55, 0.019, 0.025, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("casing", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.02, -0.02, 0.008, UniKit.BRASS, 6)), Vector3(0.04, 0.02, 0.06)))
	# The scope: brass tube on two rings, a lens at the front that glints.
	parts.append(UniKit.part("scope", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		for z: float in [0.07, -0.08]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.025, z)), Vector3(0.016, 0.03, 0.016), UniKit.IRON)
			UniKit.band(st, 0, 0, z, 0.024, 0.016, UniKit.IRON)
		UniKit.barrel(st, 0, 0, 0.13, -0.14, 0.017, UniKit.BRASS, 10)
		UniKit.barrel(st, 0, 0, -0.13, -0.19, 0.017, UniKit.BRASS, 10, 0.026)
		UniKit.barrel(st, 0, 0, 0.11, 0.15, 0.02, UniKit.BRASS_DK, 10)),
		Vector3(0, 0.065, 0.0)))
	parts.append(UniKit.part("scope_lens", "scope", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.022, 0.022, 0.005, 10, UniKit.GLOW_WHITE)),
		Vector3(0, 0, -0.193), Basis(), {"glow": true}))
	# The bolt on the right of the receiver: lifts, draws back, closes.
	parts.append(UniKit.part("bolt_action", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.012, 0.012, 0.08, 8, UniKit.IRON_LT)
		MeshKit.add_limb(st, Vector3(0, 0, 0.03), Vector3(0.05, -0.012, 0.035), 0.007, UniKit.IRON_LT, 6)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.055, -0.014, 0.035)), Vector3(0.014, 0.014, 0.014), 3, 8, UniKit.BRASS)),
		Vector3(0.042, 0.015, 0.09)))
	# The crop chamber on top at the back, its brass cap hinged at the back.
	parts.append(UniKit.part("crop_breech", "rifle_body", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.06, 0.03, 0.07), UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.026, 0.025, 0)), Vector3(0.008, 0.02, 0.07), UniKit.BRASS_DK)),
		Vector3(0, 0.05, 0.1)))
	parts.append(UniKit.part("breech_fill", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.022, 0)), Vector3(0.044, 0.016, 0.06), Color(0.95, 0.95, 0.95))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("breech_glow", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.031, 0.0, 0)), Vector3(0.003, 0.01, 0.05), UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("breech_cap", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.005, -0.037)), Vector3(0.066, 0.01, 0.075), UniKit.BRASS_DK)),
		Vector3(0, 0.035, 0.037)))
	return {"head_y": head_y, "gun_y": gun_y, "parts": parts, "muzzles": [["rifle_body", Vector3(0, 0.01, -0.66)]],
		"loaded_pitch": -0.08, "pour": Vector3(0, gun_y + 0.25, 0.1), "ring_r": 0.5}


## Slow and deliberate: a 3 cm kick that eases back over 0.3 s, then the bolt
## lifts, draws back, pushes home and drops over 1.2 s, throwing out a casing
## on the draw. The scope lens swells for a moment at the shot. The bipod folds
## up along the barrel while empty. The breech cap
## swings open while loading.
static func _anim_roof_perch(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	rig.kick("rifle_body", 0.03 * kick_k(a, 0.3))
	# The bipod folds up along the barrel while empty (the gun rests pointing up).
	rig.turn("bipod", Vector3.RIGHT, 0.0 if ctx.loaded else 1.35)
	var lift := smoothstep(0.3, 0.5, a) * (1.0 - smoothstep(1.2, 1.4, a))
	var back := smoothstep(0.5, 0.8, a) * (1.0 - smoothstep(0.9, 1.2, a))
	if ctx.shots <= 0:
		lift = 0.0
		back = 0.0
	rig.pose("bolt_action", Vector3(0, 0, 0.06 * back), Basis(Vector3.BACK, 1.2 * lift))
	_eject(rig, ctx, "casing", 0.75, 1.15)
	var flash := 1.0 + 0.7 * kick_k(a, 0.2)
	rig.stretch("scope_lens", Vector3(flash, flash, 1.0))
	rig.turn("breech_cap", Vector3.RIGHT, -1.9 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 19. Porch Fog

## A squat riveted iron tank on a low floor plate with six brass nozzles round
## its shoulder, a glass reservoir jar of crop liquid beside it, pipes and a
## valve wheel between them and a pressure gauge on the front. Doesn't aim.
## Parts: porch_mount, fog_generator (+ nozzle_tip_1..6 glow), crop_reservoir
## (+ reservoir_liquid, bubble_1..3, reservoir_cap), valve_assembly (+ valve_wheel),
## pressure_gauge (+ gauge_needle).
static func _porch_fog(team: Color) -> Dictionary:
	var parts: Array = []
	var jar := Vector3(-0.26, 0.0, -0.22)
	var nozzles: Array[Vector3] = []
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0 + PI / 6.0
		nozzles.append(Vector3(cos(a) * 0.245, 0.43, sin(a) * 0.245))
	parts.append(UniKit.part("porch_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.05, 0.025, -0.06)), Vector3(0.78, 0.05, 0.72), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				UniKit.bolt(st, Vector3(-0.05 + sx * 0.34, 0.05, -0.06 + sz * 0.31), Vector3.UP, 0.025, 0.02))))
	parts.append(UniKit.part("fog_generator", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.lathe(st, Transform3D(), [Vector2(0.0, 0.0), Vector2(0.23, 0.0), Vector2(0.245, 0.03), Vector2(0.245, 0.33),
				Vector2(0.21, 0.4), Vector2(0.1, 0.44), Vector2(0.0, 0.445)], 16, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.255, 0.255, 0.04, 16, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.25, 0.25, 0.035, 16, team)
		UniKit.rivet_ring(st, Vector3(0, 0.3, 0), 0.248, 14, 0.015)
		UniKit.rivet_ring(st, Vector3(0, 0.1, 0), 0.248, 14, 0.015)
		# The manifold ring round the shoulder, and the nozzles off it.
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.38, 0)), 0.235, 0.2, 0.03, 16, UniKit.BRASS)
		for p: Vector3 in nozzles:
			var flat := Vector3(p.x, 0, p.z).normalized()
			MeshKit.add_limb(st, flat * 0.21 + Vector3(0, 0.39, 0), p, 0.014, UniKit.BRASS_DK, 6)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.46, 0)), 0.04, 0.05, 0.04, 10, UniKit.BRASS_DK)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.18, 0), "r": 0.245, "h": 0.32}}))
	# The nozzle tips glow; each is its own part (pivot at the tip) so it can pulse.
	for i in nozzles.size():
		var p: Vector3 = nozzles[i]
		var flat := Vector3(p.x, 0, p.z).normalized()
		parts.append(UniKit.part("nozzle_tip_%d" % (i + 1), "fog_generator", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.02, 0.016, 0.02), 2, 6, UniKit.GLOW_WHITE)),
			p + flat * 0.01 + Vector3(0, 0.006, 0), Basis(), {"glow": true}))
	# The reservoir jar: brass base and cap, four posts, glass panes as glints.
	parts.append(UniKit.part("crop_reservoir", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.095, 0.095, 0.04, 14, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.305, 0)), 0.09, 0.09, 0.02, 14, UniKit.BRASS)
		for i in 4:
			var a := TAU * i / 4.0 + PI * 0.25
			MeshKit.add_limb(st, Vector3(cos(a) * 0.088, 0.03, sin(a) * 0.088), Vector3(cos(a) * 0.088, 0.3, sin(a) * 0.088), 0.008, UniKit.BRASS_DK, 5)
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			if i % 2 == 0:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.084, 0.165, sin(a) * 0.084)), Vector3(0.003, 0.23, 0.022), UniKit.GLASS)),
		jar))
	parts.append(UniKit.part("reservoir_liquid", "crop_reservoir", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.13, 0)), 0.076, 0.076, 0.26, 14, Color(0.75, 0.75, 0.75))),
		Vector3(0, 0.04, 0), Basis(), {"crop": true}))
	for i in 3:
		parts.append(UniKit.part("bubble_%d" % (i + 1), "crop_reservoir", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.012, 0.012, 0.012), 3, 6, Color(1, 1, 1))),
			Vector3(0, 0.05, 0), Basis(), {"crop": true}))
	parts.append(UniKit.part("reservoir_cap", "crop_reservoir", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.07, 0.01, 0)), 0.07, 0.07, 0.02, 12, UniKit.BRASS_DK)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.07, 0.03, 0)), Vector3(0.018, 0.018, 0.018), 2, 6, UniKit.BRASS)),
		Vector3(-0.07, 0.315, 0)))
	# Pipes: out of the jar's foot into the tank, a riser up the front to the manifold.
	parts.append(UniKit.part("valve_assembly", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.tube(st, [jar + Vector3(0.09, 0.035, -0.03), Vector3(-0.08, 0.04, -0.262), Vector3(-0.07, 0.12, -0.265), Vector3(-0.07, 0.3, -0.258), Vector3(-0.06, 0.37, -0.22)],
				[0.016, 0.016, 0.016, 0.016, 0.016], 6, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), jar + Vector3(0.09, 0.035, -0.03)), 0.024, 0.024, 0.04, 8, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.07, 0.15, -0.265)), Vector3(0.05, 0.05, 0.05), UniKit.BRASS)
		MeshKit.add_limb(st, Vector3(-0.07, 0.15, -0.265), Vector3(-0.07, 0.15, -0.305), 0.008, UniKit.IRON_DK, 5)),
		Vector3.ZERO))
	parts.append(UniKit.part("valve_wheel", "valve_assembly", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.042, 0.032, 0.012, 12, Color("#B8352A"))
		for i in 3:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, PI * i / 3.0), Vector3.ZERO), Vector3(0.07, 0.008, 0.008), Color("#B8352A"))),
		Vector3(-0.07, 0.15, -0.31)))
	parts.append(UniKit.part("pressure_gauge", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.gauge(st, Vector3.ZERO, Vector3.FORWARD, 0.06)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.02)), Vector3(0.03, 0.03, 0.03), UniKit.BRASS_DK)),
		Vector3(0.1, 0.25, -0.24)))
	parts.append(UniKit.part("gauge_needle", "pressure_gauge", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.needle(st, 0.048)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.008, 0.008, 0.008, 6, UniKit.BRASS)),
		Vector3(0, 0, -0.022)))
	return {"head_y": 0.05, "gun_y": 0.44, "parts": parts, "no_aim": true,
		"muzzles": [["fog_generator", nozzles[0]]], "idle_at": Vector3(0, 0.02, 0),
		"pour": jar + Vector3(0, 0.45, 0), "ring_r": 0.5}


## The reservoir fills during loading, stays full between waves and drains
## slowly through a wave (to a reserve); empty (clear) when unloaded. The gauge
## needle follows the level (zero when empty), trembling while spraying;
## bubbles rise through the liquid; the nozzle tips pulse while it sprays. The
## valve wheel turns open while loading and the jar's cap flips up.
static func _anim_porch_fog(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var lvl := float(rig.state.get("level", 1.0))
	if not ctx.loaded:
		lvl = minf(lvl, 1.0 - ctx.drain_k) if ctx.drain_k < 1.0 else 0.0
	elif ctx.load_k < 1.0:
		lvl = smoothstep(0.3, 0.9, ctx.load_k)
	elif ctx.in_wave:
		lvl = maxf(0.15, lvl - delta / 150.0)
	else:
		lvl = move_toward(lvl, 1.0, delta)
	rig.state["level"] = lvl
	rig.stretch("reservoir_liquid", Vector3(1.0, maxf(lvl, 0.01), 1.0))
	var spraying := ctx.loaded and ctx.in_wave
	for i in 3:
		var n := "bubble_%d" % (i + 1)
		var f := fposmod(ctx.t * 0.5 + i / 3.0, 1.0)
		var a := TAU * (i / 3.0) + ctx.t * 0.7
		rig.pose(n, Vector3(cos(a) * 0.066, 0.26 * lvl * f, sin(a) * 0.066))
		rig.show_part(n, ctx.loaded and lvl > 0.05)
	var shake := sin(ctx.t * 31.0) * 0.05 if spraying else 0.0
	rig.turn("gauge_needle", Vector3.BACK, lerpf(-2.2, 2.2, lvl) + shake)
	for i in 6:
		var pulse := 1.0 + (0.35 * absf(sin(ctx.t * 9.0 + i * 1.7)) if spraying else 0.0)
		rig.stretch("nozzle_tip_%d" % (i + 1), Vector3(pulse, pulse, pulse))
	rig.turn("valve_wheel", Vector3.BACK, (2.5 if ctx.loaded else 0.0) * smoothstep(0.0, 0.6, ctx.load_k))
	rig.turn("reservoir_cap", Vector3.BACK, 1.9 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 20. Homestead Bastion

## A boxy riveted armoured housing on a heavy wall bracket, a barrel through a
## mantlet in its firing port, a drum magazine on its right side and an
## auto-loader rail on the roof with a reciprocating bolt.
## Parts: wall_mount, turret_housing (+ port_glow), mantlet, barrel (+ barrel_glow),
## crop_drum (+ drum_fill), auto_loader (+ loader_bolt).
static func _homestead_bastion(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.16
	parts.append(UniKit.part("wall_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		# The wall plate behind, a shelf out from it, braces and the swivel post.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.24, 0.44)), Vector3(0.52, 0.5, 0.04), UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			for y: float in [0.06, 0.42]:
				UniKit.bolt(st, Vector3(sx * 0.21, y, 0.42), Vector3.FORWARD, 0.025, 0.02)
			MeshKit.add_limb(st, Vector3(sx * 0.13, 0.03, 0.42), Vector3(sx * 0.13, 0.25, 0.02), 0.02, UniKit.IRON, 6)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.25, 0.2)), Vector3(0.3, 0.04, 0.5), UniKit.IRON)
		UniKit.rivet_row(st, Vector3(-0.15, 0.27, 0.0), Vector3(-0.15, 0.27, 0.4), 4, 0.014)
		UniKit.rivet_row(st, Vector3(0.15, 0.27, 0.0), Vector3(0.15, 0.27, 0.4), 4, 0.014)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.285, 0)), 0.1, 0.11, 0.03, 12, UniKit.IRON_DK)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.29, 0)), 0.14, 0.1, 0.02, 14, UniKit.BRASS))))
	parts.append(UniKit.part("turret_housing", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		var c := Vector3(0, 0.17, 0.115)
		MeshKit.add_box(st, Transform3D(Basis(), c), Vector3(0.36, 0.28, 0.33), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), c + Vector3(0, 0.15, 0)), Vector3(0.33, 0.025, 0.3), UniKit.IRON_DK)
		# The firing port: a dark slot in the front plate.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, gun_y, -0.052)), Vector3(0.2, 0.22, 0.006), Color("#1A1B1F"))
		for sx: float in [-1.0, 1.0]:
			UniKit.rivet_row(st, Vector3(sx * 0.165, 0.29, -0.054), Vector3(sx * 0.165, 0.05, -0.054), 4, 0.014)
			UniKit.rivet_row(st, Vector3(sx * 0.181, 0.29, -0.03), Vector3(sx * 0.181, 0.29, 0.26), 4, 0.014)
		UniKit.rivet_row(st, Vector3(-0.15, 0.04, -0.054), Vector3(0.15, 0.04, -0.054), 5, 0.014)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.181, 0.17, 0.12)), Vector3(0.006, 0.05, 0.28), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.17, 0.115), "size": Vector3(0.36, 0.28, 0.33)}}))
	parts.append(UniKit.part("port_glow", "turret_housing", UniKit.mesh(func(st: SurfaceTool) -> void:
		for sy: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, gun_y + sy * 0.115, -0.054)), Vector3(0.21, 0.01, 0.006), UniKit.GLOW_WHITE)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.105, gun_y, -0.054)), Vector3(0.01, 0.23, 0.006), UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	# The mantlet: a rounded iron block on the trunnion filling the port.
	parts.append(UniKit.part("mantlet", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.095, 0.095, 0.18, 14, UniKit.IRON_DK)
		UniKit.barrel(st, 0, 0, -0.06, -0.12, 0.055, UniKit.IRON, 12, 0.05)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3(0.09, 0, 0)), 0.095, 0.06, 0.012, 14, UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3(-0.09, 0, 0)), 0.095, 0.06, 0.012, 14, UniKit.BRASS)),
		Vector3.ZERO))
	parts.append(UniKit.part("barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, -0.02, -0.45, 0.036, UniKit.IRON_DK, 12, 0.032)
		UniKit.band(st, 0, 0, -0.2, 0.042, 0.025, UniKit.BRASS)
		UniKit.barrel(st, 0, 0, -0.43, -0.48, 0.042, UniKit.BRASS_DK, 12)),
		Vector3.ZERO))
	parts.append(UniKit.part("barrel_glow", "barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.38, 0.037, 0.03, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The drum on the right side: an iron drum about X with eight crop slots.
	parts.append(UniKit.part("crop_drum", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.0, 0, 0)), 0.12, 0.12, 0.08, 16, UniKit.IRON_DK)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3(0.042, 0, 0)), 0.125, 0.11, 0.012, 16, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.045, 0, 0)), 0.03, 0.03, 0.02, 8, UniKit.BRASS)
		for i in 8:
			var a := TAU * i / 8.0
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.041, cos(a) * 0.08, sin(a) * 0.08)), 0.024, 0.024, 0.004, 8, Color("#1A1B1F"))),
		Vector3(0.235, 0.15, 0.12)))
	parts.append(UniKit.part("drum_fill", "crop_drum", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 8:
			var a := TAU * i / 8.0
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.042, cos(a) * 0.08, sin(a) * 0.08)), 0.019, 0.019, 0.006, 8, Color(1, 1, 1) if i % 2 == 0 else Color(0.85, 0.85, 0.85))),
		Vector3.ZERO, Basis(), {"crop": true}))
	# The auto-loader: a rail on the roof from the drum's feed arm to the breech,
	# with a bolt that runs back and forth on it.
	parts.append(UniKit.part("auto_loader", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.06, 0.02, 0.26), UniKit.BRASS_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.028, 0.018, 0)), Vector3(0.008, 0.02, 0.26), UniKit.IRON_DK)
		MeshKit.add_limb(st, Vector3(0.03, 0.0, 0.0), Vector3(0.12, -0.08, 0.0), 0.016, UniKit.BRASS, 6)),
		Vector3(0.1, 0.33, 0.12)))
	parts.append(UniKit.part("loader_bolt", "auto_loader", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.022, 0)), Vector3(0.045, 0.03, 0.06), UniKit.IRON_LT)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.045, 0.02)), Vector3(0.013, 0.013, 0.013), 2, 6, UniKit.BRASS)),
		Vector3(0, 0, -0.08)))
	return {"head_y": 0.3, "gun_y": gun_y, "parts": parts, "muzzles": [["barrel", Vector3(0, 0, -0.5)]],
		"rest_pitch": 0.12, "pour": Vector3(0.235, 0.45, 0.12), "ring_r": 0.5}


## The barrel slides back into the housing when empty (and as the crop drains
## at wave end) and runs out when loaded. Each shot: a 2 cm kick, the drum
## clicks round one slot (an eighth) and the loader bolt runs back along its
## rail and returns. The steady rhythm comes from the fire interval itself.
static func _anim_homestead_bastion(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var ext := smoothstep(0.45, 1.0, ctx.load_k) if ctx.loaded else 1.0 - ctx.drain_k
	var a := ctx.shot_age
	rig.pose("barrel", Vector3(0, 0, 0.3 * (1.0 - ext) + 0.02 * kick_k(a, 0.15)))
	var drum := 0.0
	if ctx.shots > 0:
		drum = (ctx.shots - 1 + smoothstep(0.0, 0.1, a)) * TAU / 8.0
	rig.turn("crop_drum", Vector3.RIGHT, drum)
	var run := 0.0
	if ctx.shots > 0 and a < 0.4:
		run = sin(PI * a / 0.4)
	rig.pose("loader_bolt", Vector3(0, 0, 0.15 * run))
