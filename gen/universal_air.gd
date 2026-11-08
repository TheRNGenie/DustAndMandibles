class_name UniversalAir
extends RefCounted
## Universal crop-fed turrets: the 5 air-defense guns (Sky Hopper, Cloud Popper,
## Hawk Eye, Flyswatter, Skyward Battery). Models built in code in the parts the
## handoff lists (see UniKit for the conventions and UniversalBuilder for the
## spec), and their animation.
##
## All five sit on a roof / clifftop bracket (UniKit.roof_mount, the "roof_mount"
## part), turn all the way round and rest with their barrels straight up while
## empty ("rest_pitch" ~90 deg). The turret class idles them at 45 deg when
## loaded; "loaded_pitch" is the doc's loaded angle (used by the preview tool).


## The id's spec, or {} for one not built yet (UniversalBuilder uses a stand-in).
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"cf_sky_hopper": return _sky_hopper(team)
		&"cf_cloud_popper": return _cloud_popper(team)
		&"cf_hawk_eye": return _hawk_eye(team)
		&"cf_flyswatter": return _flyswatter(team)
		&"cf_skyward_battery": return _skyward_battery(team)
	return {}


## Every frame, every peer: pose the id's moving parts (see UniCtx).
static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match id:
		&"cf_sky_hopper": _anim_sky_hopper(rig, ctx, delta)
		&"cf_cloud_popper": _anim_cloud_popper(rig, ctx, delta)
		&"cf_hawk_eye": _anim_hawk_eye(rig, ctx, delta)
		&"cf_flyswatter": _anim_flyswatter(rig, ctx, delta)
		&"cf_skyward_battery": _anim_skyward_battery(rig, ctx, delta)


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


## A swivel cradle: a round turntable and two upright cheeks at +-cheek_x
## holding the gun's trunnion at height `gun_y`.
static func _cradle(st: SurfaceTool, r: float, cheek_x: float, gun_y: float, color: Color = UniKit.IRON) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.04, 0)), r, r * 0.95, 0.08, 16, UniKit.IRON_DK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.085, 0)), r * 0.9, r * 0.9, 0.012, 16, UniKit.BRASS_DK)
	UniKit.rivet_ring(st, Vector3(0, 0.08, 0), r * 0.82, 10, 0.016)
	for sx: float in [-1.0, 1.0]:
		var h := gun_y + 0.04 - 0.08
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * cheek_x, 0.08 + h * 0.5, 0)), Vector3(0.045, h, 0.16), color)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * cheek_x, 0.1, 0)), Vector3(0.06, 0.04, 0.22), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * (cheek_x + 0.03), gun_y, 0)), 0.045, 0.045, 0.025, 10, UniKit.BRASS)


## A small team pennant on a staff standing at `at` (staff `h` tall).
static func _pennant(st: SurfaceTool, at: Vector3, team: Color, h: float = 0.35) -> void:
	MeshKit.add_limb(st, at, at + Vector3(0, h, 0), 0.01, UniKit.IRON_DK, 6)
	MeshKit.add_box(st, Transform3D(Basis(), at + Vector3(0, h - 0.06, 0.08)), Vector3(0.008, 0.09, 0.15), team)


## A small vane / arrow pointing down -Z round its pivot (a hub, a shaft, a head and a tail fin).
static func _vane(st: SurfaceTool, length: float = 0.24, color: Color = UniKit.BRASS) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3.ZERO), 0.018, 0.018, 0.04, 8, UniKit.IRON_DK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.01, 0.01, length), UniKit.IRON_DK)
	UniKit.barrel(st, 0, 0, -length * 0.5, -length * 0.5 - 0.07, 0.035, color, 4, 0.0)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, length * 0.5)), Vector3(0.005, 0.07, 0.09), color)


# ------------------------------------------------------------------ 11. Sky Hopper

## Twin short barrels on a 360-degree swivel cradle, a box magazine on the right
## with a crop window, and a little brass tracking vane on a mast.
## Parts: roof_mount, swivel_cradle, dual_barrels (receiver; barrel_l / barrel_r
## each with a glow band), crop_magazine (+ magazine_fill, magazine_glow,
## magazine_lid), tracking_vane.
static func _sky_hopper(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.3
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.roof_mount(st, 0.5))))
	parts.append(UniKit.part("swivel_cradle", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_cradle(st, 0.25, 0.25, gun_y)
		# The vane's mast up the left cheek, and the team pennant on the right.
		MeshKit.add_limb(st, Vector3(-0.25, gun_y + 0.04, 0.06), Vector3(-0.25, 0.66, 0.06), 0.012, UniKit.IRON_DK, 6)
		_pennant(st, Vector3(0.25, gun_y + 0.04, 0.07), team, 0.3)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.16, 0), "size": Vector3(0.5, 0.3, 0.24)}}))
	# The receiver block on the trunnion; the barrels hang off it.
	parts.append(UniKit.part("dual_barrels", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0.03)), Vector3(0.2, 0.14, 0.3), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.075, 0.03)), Vector3(0.16, 0.02, 0.24), UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.035, 0.035, 0.46, 10, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, -0.125)), Vector3(0.2, 0.1, 0.03), UniKit.BRASS)
		UniKit.rivet_row(st, Vector3(-0.1, 0.07, -0.08), Vector3(-0.1, 0.07, 0.16), 4, 0.014)
		UniKit.rivet_row(st, Vector3(0.1, 0.07, -0.08), Vector3(0.1, 0.07, 0.16), 4, 0.014)
		# Spade grips at the back.
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.05, 0.0, 0.18), Vector3(sx * 0.06, -0.02, 0.24), 0.014, UniKit.WOOD_DK, 6)),
		Vector3.ZERO))
	for side: Array in [["barrel_l", -0.05], ["barrel_r", 0.05]]:
		var bn: String = side[0]
		parts.append(UniKit.part(bn, "dual_barrels", UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, 0.0, -0.45, 0.03, UniKit.IRON_DK)
			UniKit.band(st, 0, 0, -0.03, 0.038, 0.03)
			UniKit.band(st, 0, 0, -0.18, 0.036, 0.025)
			UniKit.barrel(st, 0, 0, -0.42, -0.46, 0.037, UniKit.BRASS_DK, 12)),
			Vector3(float(side[1]), 0.02, -0.14)))
		parts.append(UniKit.part(bn + "_glow", bn, UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, -0.33, 0.036, 0.04, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The box magazine on the right, between the receiver and the cheek, with a
	# crop window on its outer face and a lid hinged at the back.
	parts.append(UniKit.part("crop_magazine", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.04, 0)), Vector3(0.085, 0.2, 0.16), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, -0.145, 0)), Vector3(0.09, 0.02, 0.17), UniKit.BRASS_DK)
		for z: float in [-0.07, 0.07]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.044, -0.04, z)), Vector3(0.008, 0.19, 0.018), UniKit.BRASS)),
		Vector3(0.148, -0.02, 0.05)))
	parts.append(UniKit.part("magazine_fill", "crop_magazine", UniKit.mesh(func(st: SurfaceTool) -> void:
		for k in 4:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.043, 0.02 - k * 0.042, 0)), Vector3(0.006, 0.034, 0.11), Color(1, 1, 1) if k % 2 == 0 else Color(0.82, 0.82, 0.8))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("magazine_glow", "crop_magazine", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.046, -0.128, 0)), Vector3(0.006, 0.012, 0.12), UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("magazine_lid", "crop_magazine", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.008, -0.08)), Vector3(0.095, 0.016, 0.165), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, -0.15)), Vector3(0.03, 0.012, 0.02), UniKit.BRASS)),
		Vector3(0, 0.06, 0.08)))
	parts.append(UniKit.part("tracking_vane", "head", UniKit.mesh(func(st: SurfaceTool) -> void: _vane(st)), Vector3(-0.25, 0.68, 0.06)))
	return {"head_y": 0.5, "gun_y": gun_y, "parts": parts,
		"muzzles": [["barrel_l", Vector3(0, 0, -0.48)], ["barrel_r", Vector3(0, 0, -0.48)]],
		"rest_pitch": PI * 0.5, "loaded_pitch": PI * 0.25, "pour": Vector3(0.15, gun_y + 0.4, 0.05), "ring_r": 0.75}


## Barrels fire left-right-left, each recoiling 1.5 cm and back in 0.06 s. The
## tracking vane locks along the gun while tracking, wanders loosely forward
## while loaded and idle, and spins lazily in the wind while empty. The
## magazine lid opens while loading.
static func _anim_sky_hopper(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var fired := fired_index(ctx.shots, 2)
	var k := kick_k(ctx.shot_age, 0.06)
	rig.kick("barrel_l", 0.015 * k if fired == 0 else 0.0)
	rig.kick("barrel_r", 0.015 * k if fired == 1 else 0.0)
	rig.turn("magazine_lid", Vector3.RIGHT, 1.7 * open_k(ctx.load_k))
	_anim_vane(rig, ctx, delta, "tracking_vane")


## A tracking vane: locks along the gun (0 relative to the head) while tracking,
## wanders forward while loaded, spins lazily while empty.
static func _anim_vane(rig: UniRig, ctx: UniCtx, delta: float, n: String) -> void:
	var lock := move_toward(float(rig.state.get(n + "_lock", 0.0)), 1.0 if ctx.tracking else 0.0, delta * 5.0)
	rig.state[n + "_lock"] = lock
	var free := ctx.t * 0.7 + sin(ctx.t * 0.9) * 0.6
	if ctx.loaded:
		free = sin(ctx.t * 0.5) * 0.45
	rig.turn(n, Vector3.UP, lerp_angle(free, 0.0, lock))


# ------------------------------------------------------------------ 12. Cloud Popper

## A squat cast-iron mortar: a wide tube on trunnions in a round bearing base,
## a timed fuse dial on the base's right side and a rack of crop shells on its left.
## Parts: roof_mount, mortar_base (+ timed_fuse_dial, crop_shell_rack with
## shell_rack_fill and rack_cover), mortar_tube (+ tube_glow).
static func _cloud_popper(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.34
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.roof_mount(st, 0.5))))
	parts.append(UniKit.part("mortar_base", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.015, 0)), 0.31, 0.22, 0.03, 16, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.28, 0.25, 0.18, 16, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.195, 0)), 0.25, 0.23, 0.02, 16, UniKit.IRON)
		UniKit.rivet_ring(st, Vector3(0, 0.17, 0), 0.262, 12, 0.017)
		UniKit.rivet_ring(st, Vector3(0, 0.04, 0), 0.282, 12, 0.017)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.19, 0.29, 0)), Vector3(0.05, 0.2, 0.2), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.225, gun_y, 0)), 0.05, 0.05, 0.025, 10, UniKit.BRASS)
		# The fuse dial's fixed index mark, and a team pennant at the back.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.275, 0.17, 0)), Vector3(0.02, 0.02, 0.014), UniKit.BRASS)
		_pennant(st, Vector3(0.0, 0.2, 0.22), team, 0.42)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.1, 0), "r": 0.28, "h": 0.18}}))
	# The fuse dial: a cream disc on the base's right face, turning about X, with a red pointer.
	parts.append(UniKit.part("timed_fuse_dial", "mortar_base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.065, 0.065, 0.02, 14, Color("#EDE3C8"))
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3(0.005, 0, 0)), 0.075, 0.062, 0.028, 14, UniKit.BRASS)
		for i in 8:
			var a := TAU * i / 8.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.012, cos(a) * 0.05, sin(a) * 0.05)), Vector3(0.004, 0.014, 0.005), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.013, 0.022, 0)), Vector3(0.005, 0.045, 0.01), Color("#B8352A"))
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.014, 0, 0)), 0.01, 0.01, 0.008, 6, UniKit.BRASS)),
		Vector3(0.272, 0.1, 0)))
	# The shell rack on the left: a wooden tray on an iron arm, three shells standing in it.
	parts.append(UniKit.part("crop_shell_rack", "mortar_base", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.06, 0.0, 0)), Vector3(0.1, 0.03, 0.06), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.12, 0.03, 0.28), UniKit.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.055, 0.07, 0)), Vector3(0.015, 0.13, 0.28), UniKit.WOOD_DK)
		for y: float in [0.05, 0.11]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, y, 0.142)), Vector3(0.12, 0.018, 0.008), UniKit.IRON_DK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, y, -0.142)), Vector3(0.12, 0.018, 0.008), UniKit.IRON_DK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.058, y, 0)), Vector3(0.008, 0.018, 0.29), UniKit.IRON_DK)),
		Vector3(-0.36, 0.05, 0)))
	parts.append(UniKit.part("shell_rack_fill", "crop_shell_rack", UniKit.mesh(func(st: SurfaceTool) -> void:
		for z: float in [-0.085, 0.0, 0.085]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.07, z)), 0.034, 0.034, 0.1, 10, Color(0.85, 0.85, 0.85))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, z)), Vector3(0.034, 0.05, 0.034), 3, 10, Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("rack_cover", "crop_shell_rack", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.065, 0.006, 0)), Vector3(0.13, 0.012, 0.29), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.125, 0.016, 0)), Vector3(0.012, 0.012, 0.06), UniKit.BRASS)),
		Vector3(-0.065, 0.17, 0)))
	# The tube: wide, flared at the mouth, a rounded breech behind the trunnions.
	parts.append(UniKit.part("mortar_tube", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.08, -0.5, 0.12, UniKit.IRON_DK, 14, 0.125)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.09)), Vector3(0.12, 0.12, 0.08), 3, 14, UniKit.IRON_DK)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.5)), 0.155, 0.1, 0.05, 14, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.49)), 0.1, 0.1, 0.03, 12, Color("#1A1B1F"))
		UniKit.band(st, 0, 0, -0.08, 0.135, 0.04, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, -0.3, 0.132, 0.03, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.045, 0.045, 0.42, 10, UniKit.IRON)),
		Vector3.ZERO))
	parts.append(UniKit.part("tube_glow", "mortar_tube", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.42, 0.133, 0.035, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": 0.5, "gun_y": gun_y, "parts": parts, "muzzles": [["mortar_tube", Vector3(0, 0, -0.55)]],
		"rest_pitch": PI * 0.5, "loaded_pitch": deg_to_rad(75.0), "pour": Vector3(-0.36, 0.45, 0), "ring_r": 0.75}


## THUMP: the whole base jolts 2 cm down and back up in 0.2 s, the tube sinks
## 3 cm into its trunnions. The fuse dial sits at zero while empty, ticks once a
## second while loaded and spins to a new setting after every shot. The shell
## rack's cover opens while loading.
static func _anim_cloud_popper(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var k := kick_k(ctx.shot_age, 0.2)
	rig.pose("mortar_base", Vector3(0, -0.02 * k, 0))
	rig.kick("mortar_tube", 0.03 * k)
	var dial := 0.0
	if ctx.loaded:
		dial = -floorf(ctx.t) * TAU / 24.0
		if ctx.shots > 0:
			dial += (ctx.shots - 1 + smoothstep(0.0, 0.5, ctx.shot_age)) * 2.3
	rig.turn("timed_fuse_dial", Vector3.RIGHT, dial)
	rig.turn("rack_cover", Vector3.BACK, 1.9 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 13. Hawk Eye

## A long buffalo-rifle barrel on a counterweighted cradle, brass scope on top,
## a breech-loading crop chamber at the back, all on a roof bracket with dampeners.
## Parts: roof_mount, rifle_cradle, long_barrel (+ barrel_glow, bolt, casing),
## counterweight, scope (+ scope_lens glow), crop_breech (+ breech_fill,
## breech_glow, breech_block).
static func _hawk_eye(team: Color) -> Dictionary:
	var parts: Array = []
	var head_y := 0.38
	var gun_y := 0.34
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.roof_mount(st, head_y)
		# Brass dampener pots on the foot plate.
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var p := Vector3(sx * 0.3, 0.16, sz * 0.18)
				MeshKit.add_cylinder(st, Transform3D(Basis(), p), 0.04, 0.04, 0.12, 10, UniKit.BRASS)
				MeshKit.add_cylinder(st, Transform3D(Basis(), p + Vector3(0, 0.07, 0)), 0.03, 0.03, 0.03, 8, UniKit.IRON_DK)
				MeshKit.add_limb(st, p + Vector3(0, 0.08, 0), Vector3(sx * 0.15, head_y - 0.1, sz * 0.1), 0.014, UniKit.IRON_LT, 6))))
	parts.append(UniKit.part("rifle_cradle", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_cradle(st, 0.2, 0.135, gun_y)
		_pennant(st, Vector3(-0.135, gun_y + 0.04, 0.06), team, 0.25)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.2, 0), "size": Vector3(0.3, 0.36, 0.2)}}))
	# The rifle: receiver on the trunnion, a long tapering barrel with a muzzle brake.
	parts.append(UniKit.part("long_barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.1, 0.1, 0.24), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.06, -0.14)), Vector3(0.07, 0.04, 0.2), UniKit.WOOD)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.03, 0.03, 0.3, 10, UniKit.BRASS_DK)
		UniKit.barrel(st, 0, 0.01, -0.09, -0.68, 0.032, UniKit.IRON_DK, 12, 0.024)
		UniKit.band(st, 0, 0.01, -0.1, 0.04, 0.03)
		UniKit.band(st, 0, 0.01, -0.36, 0.033, 0.025)
		UniKit.barrel(st, 0, 0.01, -0.66, -0.72, 0.034, UniKit.BRASS_DK, 10)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.03, 0.01, -0.69)), Vector3(0.012, 0.03, 0.025), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.051, 0.02, 0.07)), Vector3(0.004, 0.035, 0.06), Color("#1A1B1F"))),
		Vector3.ZERO))
	parts.append(UniKit.part("barrel_glow", "long_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0.01, -0.6, 0.029, 0.03, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The bolt on the right: a short cylinder and a handle with a brass knob.
	parts.append(UniKit.part("bolt", "long_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.014, 0.014, 0.09, 8, UniKit.IRON_LT)
		MeshKit.add_limb(st, Vector3(0, 0, 0.03), Vector3(0.06, -0.015, 0.04), 0.008, UniKit.IRON_LT, 6)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.065, -0.017, 0.04)), Vector3(0.016, 0.016, 0.016), 3, 8, UniKit.BRASS)),
		Vector3(0.058, 0.02, 0.1)))
	parts.append(UniKit.part("casing", "long_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.011, 0.011, 0.05, 8, UniKit.BRASS)),
		Vector3(0.06, 0.03, 0.07)))
	# The counterweight: an arm under the receiver ending in an iron block; it
	# swings forward against the recoil.
	parts.append(UniKit.part("counterweight", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.022, 0.022, 0.1, 8, UniKit.BRASS)
		MeshKit.add_limb(st, Vector3(-0.03, 0, 0), Vector3(-0.03, -0.1, 0.06), 0.012, UniKit.IRON, 6)
		MeshKit.add_limb(st, Vector3(0.03, 0, 0), Vector3(0.03, -0.1, 0.06), 0.012, UniKit.IRON, 6)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, -0.12, 0.07)), Vector3(0.11, 0.06, 0.08), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, -0.12, 0.07)), Vector3(0.115, 0.015, 0.085), UniKit.BRASS)),
		Vector3(0, -0.06, 0.06)))
	# The scope: a brass tube on two rings above the receiver.
	parts.append(UniKit.part("scope", "long_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		for z: float in [0.08, -0.1]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.03, z)), Vector3(0.02, 0.04, 0.022), UniKit.IRON)
			UniKit.band(st, 0, 0, z, 0.03, 0.022, UniKit.IRON)
		UniKit.barrel(st, 0, 0, 0.17, -0.2, 0.022, UniKit.BRASS, 12)
		UniKit.barrel(st, 0, 0, -0.18, -0.26, 0.022, UniKit.BRASS, 12, 0.034)
		UniKit.barrel(st, 0, 0, 0.15, 0.2, 0.026, UniKit.BRASS_DK, 12)),
		Vector3(0, 0.1, 0.0)))
	parts.append(UniKit.part("scope_lens", "scope", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.03, 0.03, 0.006, 12, UniKit.GLOW_WHITE)),
		Vector3(0, 0, -0.262), Basis(), {"glow": true}))
	# The breech at the back: two brass bands with the crop showing between,
	# a glow ring, and a hinged iron block that swings up to load.
	parts.append(UniKit.part("crop_breech", "long_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, 0.01, 0.058, 0.02, UniKit.BRASS)
		UniKit.band(st, 0, 0, 0.075, 0.058, 0.02, UniKit.BRASS)
		for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.052, sin(a) * 0.052, 0.042)), Vector3(0.012, 0.012, 0.06), UniKit.BRASS_DK)),
		Vector3(0, 0, 0.15)))
	parts.append(UniKit.part("breech_fill", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.042)), 0.048, 0.048, 0.06, 12, Color(0.9, 0.9, 0.9))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("breech_glow", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, 0.042, 0.054, 0.012, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("breech_block", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, -0.058, 0.012)), 0.058, 0.058, 0.025, 12, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.058, 0.035)), Vector3(0.03, 0.03, 0.025), UniKit.BRASS)),
		Vector3(0, 0.058, 0.085)))
	return {"head_y": head_y, "gun_y": gun_y, "parts": parts, "muzzles": [["long_barrel", Vector3(0, 0.01, -0.74)]],
		"rest_pitch": deg_to_rad(78.0), "loaded_pitch": deg_to_rad(40.0), "pour": Vector3(0, gun_y + 0.3, 0.2), "ring_r": 0.7}


## Sharp 3 cm recoil with a fast return; the counterweight swings forward against
## it and settles; the bolt lifts, draws back and closes over 0.6 s while a spent
## casing flips out to the right; the scope lens swells for a flash. The breech
## block hangs open while empty and swings open while loading.
static func _anim_hawk_eye(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	rig.kick("long_barrel", 0.03 * kick_k(a, 0.12))
	var swing := 0.0
	if a < 1.4:
		swing = 0.45 * sin(a * 12.0) * exp(-a * 4.0)
	rig.turn("counterweight", Vector3.RIGHT, swing)
	# Bolt: lift 0.05-0.15 s, back 0.15-0.35, forward 0.35-0.5, down 0.5-0.6.
	var lift := smoothstep(0.05, 0.15, a) * (1.0 - smoothstep(0.5, 0.6, a))
	var back := smoothstep(0.15, 0.35, a) * (1.0 - smoothstep(0.35, 0.5, a))
	rig.pose("bolt", Vector3(0, 0, 0.05 * back), Basis(Vector3.BACK, 1.1 * lift))
	var eject := ctx.shots > 0 and a > 0.15 and a < 0.6
	rig.show_part("casing", eject)
	if eject:
		var e := a - 0.15
		rig.pose("casing", Vector3(0.6 * e, 0.5 * e - 1.6 * e * e, 0.1 * e), Basis(Vector3.UP, e * 20.0))
	var flash := 1.0 + 0.6 * kick_k(a, 0.15)
	rig.stretch("scope_lens", Vector3(flash, flash, 1.0))
	var open := open_k(ctx.load_k)
	if not ctx.loaded:
		open = 1.0
	rig.turn("breech_block", Vector3.RIGHT, -1.9 * open)


# ------------------------------------------------------------------ 14. Flyswatter

## A wide, short net-launching tube on a swivel yoke; a compression chamber
## behind it with a pressure gauge, a hand crank on the left that winds it,
## and a drum of rolled crop nets on the right.
## Parts: roof_mount, swivel_yoke, launcher_tube (+ tube_glow, net_bundle),
## compression_chamber (+ pressure_needle, pressure_lamp), winding_crank,
## net_magazine (+ net_rolls), drum_hatch.
static func _flyswatter(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.36
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.roof_mount(st, 0.45))))
	parts.append(UniKit.part("swivel_yoke", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_cradle(st, 0.26, 0.24, gun_y)
		_pennant(st, Vector3(-0.24, gun_y + 0.04, 0.08), team, 0.28)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.2, 0), "size": Vector3(0.5, 0.36, 0.24)}}))
	# The tube: wide and short, banded, with a flared mouth.
	parts.append(UniKit.part("launcher_tube", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.02, -0.46, 0.15, UniKit.IRON, 14, 0.16)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.46)), 0.185, 0.13, 0.05, 14, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.44)), 0.14, 0.14, 0.03, 12, Color("#1A1B1F"))
		UniKit.band(st, 0, 0, -0.02, 0.165, 0.04, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, -0.25, 0.168, 0.03, UniKit.IRON_DK)
		UniKit.rivet_row(st, Vector3(0, 0.162, -0.05), Vector3(0, 0.168, -0.4), 5, 0.014)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.04, 0.04, 0.46, 10, UniKit.IRON_DK)),
		Vector3.ZERO))
	parts.append(UniKit.part("tube_glow", "launcher_tube", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.38, 0.17, 0.03, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The next net bundle sitting in the mouth (crop-woven rope ball).
	parts.append(UniKit.part("net_bundle", "launcher_tube", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, -0.42)), Vector3(0.11, 0.11, 0.05), 3, 12, Color(0.9, 0.9, 0.9))
		for a: float in [0.0, PI * 0.5]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(0, 0, -0.465)), Vector3(0.2, 0.014, 0.01), Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	# The compression chamber behind the tube: a brass cylinder with a gauge on top.
	parts.append(UniKit.part("compression_chamber", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.27, 0.02, 0.11, UniKit.BRASS_DK, 14)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.27)), Vector3(0.11, 0.11, 0.05), 3, 14, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, 0.1, 0.118, 0.025, UniKit.IRON_DK)
		UniKit.band(st, 0, 0, 0.22, 0.118, 0.025, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.125, 0.16)), 0.012, 0.012, 0.04, 6, UniKit.BRASS)
		UniKit.gauge(st, Vector3(0, 0.15, 0.16), Vector3.UP, 0.045)),
		Vector3.ZERO))
	parts.append(UniKit.part("pressure_needle", "compression_chamber", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.needle(st, 0.035)), Vector3(0, 0.168, 0.16), Basis(Vector3.RIGHT, -PI * 0.5)))
	parts.append(UniKit.part("pressure_lamp", "compression_chamber", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.016, 0.016, 0.016), 3, 8, UniKit.GLOW_WHITE)),
		Vector3(0.0, 0.11, 0.26), Basis(), {"glow": true}))
	# The winding crank on the left of the chamber, turning about X.
	parts.append(UniKit.part("winding_crank", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.02, 0, 0)), 0.035, 0.035, 0.03, 10, UniKit.BRASS)
		for i in 10:
			var a := TAU * i / 10.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.02, cos(a) * 0.037, sin(a) * 0.037)), Vector3(0.026, 0.008, 0.01), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.01, 0.05, 0)), Vector3(0.015, 0.11, 0.025), UniKit.IRON)
		MeshKit.add_limb(st, Vector3(-0.01, 0.1, 0), Vector3(-0.07, 0.1, 0), 0.01, UniKit.IRON, 6)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(-0.06, 0.1, 0)), 0.016, 0.016, 0.05, 8, UniKit.WOOD)),
		Vector3(-0.12, -0.02, 0.18)))
	# The net drum on the right: an iron carousel along the tube with five rolled nets.
	parts.append(UniKit.part("net_magazine", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.06, 0.06, 0.24, 12, UniKit.IRON_DK)
		for z: float in [-0.11, 0.11]:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, z)), 0.105, 0.105, 0.02, 14, UniKit.IRON)
		for i in 5:
			var a := TAU * i / 5.0 + TAU / 10.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.08, sin(a) * 0.08, 0)), Vector3(0.05, 0.012, 0.2), UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0)), 0.02, 0.02, 0.27, 8, UniKit.BRASS)),
		Vector3(0.17, -0.07, -0.04)))
	parts.append(UniKit.part("net_rolls", "net_magazine", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 5:
			var a := TAU * i / 5.0
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(cos(a) * 0.075, sin(a) * 0.075, 0)), 0.032, 0.032, 0.2, 8, Color(0.9, 0.9, 0.9) if i % 2 == 0 else Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	# The drum's back hatch (on the gun, so it doesn't spin with the drum).
	parts.append(UniKit.part("drum_hatch", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0.1, 0, 0)), 0.1, 0.1, 0.015, 14, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.1, 0, 0.012)), Vector3(0.06, 0.02, 0.012), UniKit.IRON_DK)),
		Vector3(0.07, -0.07, 0.092)))
	return {"head_y": 0.45, "gun_y": gun_y, "parts": parts, "muzzles": [["launcher_tube", Vector3(0, 0, -0.5)]],
		"rest_pitch": PI * 0.5, "loaded_pitch": deg_to_rad(60.0), "pour": Vector3(0.17, gun_y + 0.25, 0.1), "ring_r": 0.75}


## WHUMP: the tube recoils 2 cm and the net bundle leaves the mouth (it hides
## until the next one is in). The crank winds two turns over the fire interval
## in clicky steps while the gauge needle climbs back to full; the drum turns
## the next net into place. The drum hatch swings open while loading.
static func _anim_flyswatter(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	rig.kick("launcher_tube", 0.02 * kick_k(a, 0.15))
	var wind := 0.0
	var drum := 0.0
	var gauge := 0.0
	if ctx.loaded:
		var c := ctx.charge if ctx.shots > 0 else 1.0
		wind = floorf(c * 20.0) / 20.0 * TAU * 2.0
		gauge = c
		if ctx.shots > 0:
			drum = (ctx.shots - 1 + smoothstep(0.3, 0.8, a)) * TAU / 5.0
	rig.turn("winding_crank", Vector3.RIGHT, -wind)
	rig.turn("net_magazine", Vector3.BACK, drum)
	rig.turn("pressure_needle", Vector3.BACK, lerpf(2.2, -2.2, gauge))
	# The bundle is gone for the first part of each reload.
	if ctx.loaded:
		rig.show_part("net_bundle", not (ctx.shots > 0 and a < 0.8))
	rig.turn("drum_hatch", Vector3.UP, -1.7 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 15. Skyward Battery

## A wide riveted housing on a heavy roof bracket carrying three small flock
## barrels on the left and one heavy barrel on the right, a crop feed splitter
## between them at the back and a weather-vane mode indicator (F / H) on a mast.
## Parts: roof_mount, turret_housing, flock_barrels (flock_1..3 each with a glow
## band), heavy_barrel (+ heavy_glow), crop_feed_splitter (+ splitter_fill,
## splitter_flap, splitter_lid), mode_vane.
static func _skyward_battery(team: Color) -> Dictionary:
	var parts: Array = []
	var gun_y := 0.32
	parts.append(UniKit.part("roof_mount", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.roof_mount(st, 0.5)
		# Heavy-duty: an extra deck plate and gussets.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.125, 0)), Vector3(0.9, 0.05, 0.9), UniKit.IRON)
		UniKit.rivet_row(st, Vector3(-0.42, 0.155, -0.42), Vector3(0.42, 0.155, -0.42), 6)
		UniKit.rivet_row(st, Vector3(-0.42, 0.155, 0.42), Vector3(0.42, 0.155, 0.42), 6)
		for a in 4:
			var b := Basis(Vector3.UP, a * PI * 0.5)
			MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 0.26, 0.2)), Vector3(0.03, 0.22, 0.12), UniKit.IRON_DK))))
	parts.append(UniKit.part("turret_housing", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.36, 0.34, 0.12, 16, UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.125, 0)), 0.33, 0.33, 0.012, 16, UniKit.BRASS_DK)
		UniKit.rivet_ring(st, Vector3(0, 0.12, 0), 0.3, 14, 0.017)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.33, 0.23, 0)), Vector3(0.05, 0.24, 0.26), UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.33, 0.35, 0)), Vector3(0.06, 0.02, 0.27), UniKit.BRASS)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.365, gun_y, 0)), 0.055, 0.055, 0.025, 10, UniKit.BRASS)
			UniKit.rivet_row(st, Vector3(sx * 0.357, 0.15, -0.1), Vector3(sx * 0.357, 0.15, 0.1), 3, 0.015)
		# The vane's mast at the back, and a team stripe round the turntable.
		MeshKit.add_limb(st, Vector3(0, 0.12, 0.3), Vector3(0, 0.72, 0.3), 0.014, UniKit.IRON_DK, 6)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, 0.34)), Vector3(0.3, 0.035, 0.04), team)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03, -0.34)), Vector3(0.3, 0.035, 0.04), team)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.06, 0), "r": 0.36, "h": 0.12}}))
	# A shared axle through both barrel groups.
	parts.append(UniKit.part("gun_axle", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.04, 0.04, 0.66, 10, UniKit.IRON_DK)), Vector3.ZERO))
	# Flock barrels: a brass breech block carrying three small barrels in a triangle.
	parts.append(UniKit.part("flock_barrels", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.05)), Vector3(0.17, 0.15, 0.26), UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.095)), Vector3(0.15, 0.13, 0.03), UniKit.IRON)
		UniKit.band(st, 0, 0, -0.36, 0.09, 0.03, UniKit.IRON)
		UniKit.rivet_row(st, Vector3(-0.086, 0.06, -0.05), Vector3(-0.086, 0.06, 0.16), 3, 0.014)),
		Vector3(-0.17, 0, 0)))
	var flock_off: Array[Vector3] = [Vector3(0, 0.04, 0), Vector3(-0.042, -0.03, 0), Vector3(0.042, -0.03, 0)]
	for i in 3:
		var bn := "flock_%d" % (i + 1)
		parts.append(UniKit.part(bn, "flock_barrels", UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, -0.08, -0.5, 0.024, UniKit.IRON_DK, 10)
			UniKit.barrel(st, 0, 0, -0.48, -0.52, 0.029, UniKit.BRASS_DK, 10)), flock_off[i] + Vector3(0, 0, -0.02)))
		parts.append(UniKit.part(bn + "_glow", bn, UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, -0.44, 0.028, 0.03, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# Heavy barrel: one fat barrel with a muzzle brake.
	parts.append(UniKit.part("heavy_barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.06)), 0.1, 0.1, 0.24, 12, UniKit.IRON)
		UniKit.barrel(st, 0, 0, -0.06, -0.58, 0.065, UniKit.IRON_DK, 14, 0.058)
		UniKit.band(st, 0, 0, -0.08, 0.08, 0.04, UniKit.BRASS)
		UniKit.band(st, 0, 0, -0.3, 0.072, 0.03, UniKit.BRASS_DK)
		UniKit.barrel(st, 0, 0, -0.56, -0.64, 0.075, UniKit.IRON, 12)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.07, 0, -0.6)), Vector3(0.02, 0.05, 0.04), UniKit.IRON_DK)),
		Vector3(0.17, 0, 0)))
	parts.append(UniKit.part("heavy_glow", "heavy_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.5, 0.068, 0.04, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The feed splitter: a glass-windowed hopper at the back centre, a flap that
	# turns towards the active barrels, a hinged lid.
	parts.append(UniKit.part("crop_feed_splitter", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.14, 0.12, 0.12), UniKit.IRON)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.05, -0.02, -0.02), Vector3(sx * 0.1, -0.02, -0.06), 0.02, UniKit.BRASS_DK, 8)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0.061)), Vector3(0.1, 0.08, 0.004), UniKit.BRASS)),
		Vector3(0, 0.07, 0.18)))
	parts.append(UniKit.part("splitter_fill", "crop_feed_splitter", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0.064)), Vector3(0.085, 0.065, 0.004), Color(0.95, 0.95, 0.95))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("splitter_flap", "crop_feed_splitter", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3.ZERO), 0.012, 0.012, 0.04, 6, UniKit.BRASS)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.035)), Vector3(0.006, 0.03, 0.07), UniKit.BRASS)),
		Vector3(0, 0.095, 0.0)))
	parts.append(UniKit.part("splitter_lid", "crop_feed_splitter", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.006, -0.065)), Vector3(0.15, 0.012, 0.13), UniKit.BRASS_DK)),
		Vector3(0, 0.08, 0.06)))
	# The mode vane: an arrow over the active barrels with an F / H sign on its tail.
	parts.append(UniKit.part("mode_vane", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3.ZERO), 0.02, 0.02, 0.04, 8, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.26, 0.012, 0.012), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.165, 0, 0)), 0.04, 0.0, 0.07, 4, UniKit.BRASS)
		# The sign: F on its front face, H on the back (front once flipped).
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.12, 0, 0)), Vector3(0.11, 0.09, 0.008), Color("#EDE3C8"))
		var ink := UniKit.IRON_DK
		var f := -0.006
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.145, 0, f)), Vector3(0.012, 0.064, 0.004), ink)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.123, 0.026, f)), Vector3(0.045, 0.012, 0.004), ink)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.128, 0.0, f)), Vector3(0.034, 0.01, 0.004), ink)
		var b := 0.006
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.098, 0, b)), Vector3(0.012, 0.064, 0.004), ink)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.142, 0, b)), Vector3(0.012, 0.064, 0.004), ink)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.12, 0, b)), Vector3(0.04, 0.012, 0.004), ink)),
		Vector3(0, 0.74, 0.3)))
	return {"head_y": 0.5, "gun_y": gun_y, "parts": parts,
		"muzzles": [["flock_1", Vector3(0, 0, -0.54)], ["flock_2", Vector3(0, 0, -0.54)], ["flock_3", Vector3(0, 0, -0.54)]],
		"heavy_muzzles": [["heavy_barrel", Vector3(0, 0, -0.66)]],
		"rest_pitch": PI * 0.5, "loaded_pitch": PI * 0.25, "pour": Vector3(0, gun_y + 0.35, 0.2), "ring_r": 0.8}


## Flock mode: the three small barrels fire in sequence (1.5 cm kicks). Heavy
## mode: the big barrel fires with a 5 cm kick that eases back over 0.25 s. The
## mode vane flips from F (pointing at the flock barrels) to H (pointing at the
## heavy one) with mode_k; the splitter's flap turns to feed the active side.
## The splitter lid opens while loading.
static func _anim_skyward_battery(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var heavy := ctx.mode == 1
	var fired := -1 if heavy else fired_index(ctx.shots, 3)
	var k := kick_k(ctx.shot_age, 0.06)
	for i in 3:
		rig.kick("flock_%d" % (i + 1), 0.015 * k if i == fired else 0.0)
	rig.kick("heavy_barrel", 0.05 * kick_k(ctx.shot_age, 0.25) if heavy else 0.0)
	var flip := smoothstep(0.0, 1.0, ctx.mode_k)
	rig.turn("mode_vane", Vector3.UP, PI * flip + sin(ctx.t * 1.3) * 0.04)
	rig.turn("splitter_flap", Vector3.UP, lerpf(0.5, -0.5, flip))
	rig.turn("splitter_lid", Vector3.RIGHT, 1.6 * open_k(ctx.load_k))
