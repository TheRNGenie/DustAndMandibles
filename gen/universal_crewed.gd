class_name UniversalCrewed
extends RefCounted
## Universal crop-fed turrets: the 5 crewed guns (Iron Mule, Crop Howitzer, Sky
## Hound, Vortex Engine, Thunder Mule). Each stands on a big timber platform
## over its 2 x 2 spot (4 m; the deck is 3.2 m with the access step inside the
## spot, and its underside is flat so it can stand on a tower). The head (the
## turntable with the seat or station) sits "head_z" towards the lip and turns,
## the gun pitches, and "seat" is the gunner's eye in head space (the camera sits
## there when manned: kept clear of geometry, with a view over the gun). Built in
## code in the parts the handoff lists (see UniKit), with their animation
## (UniversalCrewedTurret fills ctx.crewed, heat, overheated, spin, pitch, yaw, mode).

## Platform half-width (the 2 x 2 spot is 4 m across).
const HALF := 1.6
const DECK := 0.35
## The head's turntable sits this far above the deck (head_y = DECK + this).
const HEAD_Y := 0.42


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"cf_iron_mule": return _iron_mule(team)
		&"cf_crop_howitzer": return _howitzer(team)
		&"cf_sky_hound": return _sky_hound(team)
		&"cf_vortex_engine": return _vortex(team)
		&"cf_thunder_mule": return _thunder_mule(team)
	return {}


static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match id:
		&"cf_iron_mule": _anim_iron_mule(rig, ctx, delta)
		&"cf_crop_howitzer": _anim_howitzer(rig, ctx, delta)
		&"cf_sky_hound": _anim_sky_hound(rig, ctx, delta)
		&"cf_vortex_engine": _anim_vortex(rig, ctx, delta)
		&"cf_thunder_mule": _anim_thunder_mule(rig, ctx, delta)


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


## The shared deck: timber on iron skids (flat underside), the access step at
## the back with handrails (inside the spot), a team pennant in the back corner
## and a brass bearing ring under the head's turntable (at head_z, radius r).
static func _platform(team: Color, railing: bool, head_z: float, r: float) -> Dictionary:
	return UniKit.part("heavy_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.heavy_platform(st, DECK, HALF)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, DECK + 0.02, head_z)), r + 0.07, r - 0.02, 0.04, 28, UniKit.BRASS_DK)
		UniKit.rivet_ring(st, Vector3(0, DECK + 0.04, head_z), r + 0.03, 16, 0.02)
		# Step handrails.
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.5, DECK * 0.7, HALF + 0.3), Vector3(sx * 0.5, DECK + 0.75, HALF + 0.3), 0.022, UniKit.IRON)
			MeshKit.add_limb(st, Vector3(sx * 0.5, DECK + 0.75, HALF + 0.3), Vector3(sx * 0.5, DECK + 0.75, HALF - 0.15), 0.022, UniKit.BRASS_DK)
			MeshKit.add_limb(st, Vector3(sx * 0.5, DECK, HALF - 0.15), Vector3(sx * 0.5, DECK + 0.75, HALF - 0.15), 0.022, UniKit.IRON)
		# Team pennant in the back corner.
		MeshKit.add_limb(st, Vector3(HALF - 0.1, DECK, HALF - 0.1), Vector3(HALF - 0.1, DECK + 1.6, HALF - 0.1), 0.02, UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(HALF - 0.1, DECK + 1.45, HALF - 0.25)), Vector3(0.01, 0.2, 0.3), team)
		if railing:
			for sx: float in [-1.0, 1.0]:
				for z: float in [-HALF + 0.2, 0.0, HALF - 0.2]:
					MeshKit.add_limb(st, Vector3(sx * (HALF - 0.08), DECK, z), Vector3(sx * (HALF - 0.08), DECK + 0.9, z), 0.025, UniKit.IRON)
				MeshKit.add_limb(st, Vector3(sx * (HALF - 0.08), DECK + 0.9, -HALF + 0.2), Vector3(sx * (HALF - 0.08), DECK + 0.9, HALF - 0.2), 0.03, UniKit.BRASS_DK)
				MeshKit.add_limb(st, Vector3(sx * (HALF - 0.08), DECK + 0.45, -HALF + 0.2), Vector3(sx * (HALF - 0.08), DECK + 0.45, HALF - 0.2), 0.02, UniKit.IRON)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, DECK * 0.5, 0), "size": Vector3(HALF * 2.0, DECK, HALF * 2.0)}})


## A turntable deck the head stands on (head space, top at y 0).
static func _turntable(st: SurfaceTool, r: float) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.04, 0)), r, r, 0.08, 24, UniKit.IRON_DK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.003, 0)), r - 0.06, r - 0.06, 0.01, 24, UniKit.IRON)
	UniKit.rivet_ring(st, Vector3(0, 0.0, 0), r - 0.03, 16)


## An iron bucket seat with a back plate on a post standing on the turntable
## (head space, facing -Z); `at` is the seat pan.
static func _seat(st: SurfaceTool, at: Vector3) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(at.x, at.y * 0.5, at.z)), 0.06, 0.09, at.y, 8, UniKit.IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(at.x, 0.02, at.z)), 0.16, 0.18, 0.04, 10, UniKit.IRON_DK)
	MeshKit.add_box(st, Transform3D(Basis(), at), Vector3(0.48, 0.06, 0.42), UniKit.LEATHER)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.15), at + Vector3(0, 0.32, 0.23)), Vector3(0.48, 0.6, 0.05), UniKit.IRON)
	UniKit.rivet_row(st, at + Vector3(-0.2, 0.55, 0.27), at + Vector3(0.2, 0.55, 0.27), 4)


## Two upright cheeks at +-x holding a trunnion at height y (head space).
static func _cheeks(st: SurfaceTool, x: float, y: float, depth: float = 0.45, color: Color = UniKit.IRON) -> void:
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * x, (y + 0.08) * 0.5, 0)), Vector3(0.1, y + 0.08, depth), color)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * (x + 0.06), y, 0)), 0.09, 0.09, 0.03, 12, UniKit.BRASS)
		UniKit.rivet_row(st, Vector3(sx * (x + 0.052), 0.08, -depth * 0.4), Vector3(sx * (x + 0.052), 0.08, depth * 0.4), 4)


# ------------------------------------------------------------------ 26. Iron Mule

## A six-barrel gatling between two iron cheeks, a perforated shroud that heats
## orange then red, a big hopper on top with a glass window facing the gunner, a
## chute down into the breech, a hand crank either side and the seat behind.
## Parts: heavy_platform, seat_station, breech_housing, crank_handles (crank_l /
## crank_r), gatling_barrel_cluster (+ barrel_glow), barrel_shroud (+ shroud_heat,
## shroud_hot), crop_hopper_large (+ hopper_fill, hopper_window, hopper_lid), ammo_chute.
static func _iron_mule(team: Color) -> Dictionary:
	var head_z := -0.5
	var tr := 0.95
	var gun_y := 0.62
	var parts: Array = [_platform(team, false, head_z, tr)]
	parts.append(UniKit.part("seat_station", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_turntable(st, tr)
		_seat(st, Vector3(0, 0.7, 0.8))
		_cheeks(st, 0.42, gun_y, 0.5)
		# A footrest bar in front of the seat.
		MeshKit.add_limb(st, Vector3(-0.25, 0.18, 0.42), Vector3(0.25, 0.18, 0.42), 0.02, UniKit.BRASS_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.25, 0.0, 0.5), Vector3(sx * 0.25, 0.18, 0.42), 0.018, UniKit.IRON)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.35, 0), "size": Vector3(0.95, 0.7, 0.5)}}))
	# The breech: the rear drum, the trunnion axle and the crank gearboxes.
	parts.append(UniKit.part("breech_housing", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.18)), 0.2, 0.2, 0.22, 16, UniKit.IRON)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.29)), Vector3(0.2, 0.2, 0.07), 3, 16, UniKit.IRON_DK)
		UniKit.band(st, 0, 0, 0.08, 0.21, 0.03, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.05, 0.05, 1.04, 10, UniKit.BRASS_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.53, 0, 0)), Vector3(0.08, 0.18, 0.18), UniKit.BRASS_DK)
			UniKit.bolt(st, Vector3(sx * 0.57, 0.06, 0.06), Vector3(sx, 0, 0), 0.015, 0.012)),
		Vector3.ZERO))
	# Six barrels round the axis (they spin), with a brass front plate.
	parts.append(UniKit.part("gatling_barrel_cluster", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 6:
			var a := TAU * i / 6.0
			UniKit.barrel(st, cos(a) * 0.1, sin(a) * 0.1, 0.1, -1.35, 0.034, UniKit.IRON_DK, 8)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.0)), 0.06, 0.06, 0.2, 10, UniKit.BRASS)
		for z: float in [-0.95, -1.28]:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, z)), 0.15, 0.15, 0.035, 14, UniKit.BRASS)),
		Vector3.ZERO))
	parts.append(UniKit.part("barrel_glow", "gatling_barrel_cluster", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -1.2)), 0.152, 0.152, 0.04, 14, UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	# The perforated shroud: rows of slats with gaps between them.
	parts.append(UniKit.part("barrel_shroud", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		for i in 10:
			var a := TAU * i / 10.0
			for seg in 4:
				var z := -0.12 - seg * 0.19
				MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Basis(Vector3.BACK, a) * Vector3(0, 0.2, z)), Vector3(0.1, 0.018, 0.15), UniKit.IRON)
		for z: float in [-0.04, -0.85]:
			MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, z)), 0.225, 0.19, 0.05, 16, UniKit.IRON_DK)),
		Vector3.ZERO))
	# Heat: orange bands on the shroud, then red ones (emissive vertex colours).
	for hot: Array in [["shroud_heat", Color("#E8782A"), 0.6], ["shroud_hot", Color("#E0301E"), 0.85]]:
		var col: Color = hot[1]
		var g := float(hot[2])
		parts.append(UniKit.part(str(hot[0]), "barrel_shroud", UniKit.mesh(func(st: SurfaceTool) -> void:
			for seg in 3:
				var z := -0.215 - seg * 0.19
				MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, z)), 0.205, 0.205, 0.035, 16, col, true, g)),
			Vector3.ZERO))
	# The cranks, one each side on the gearboxes, turning with the barrels.
	parts.append(UniKit.pivot("crank_handles", "gun"))
	for sx: float in [-1.0, 1.0]:
		parts.append(UniKit.part("crank_l" if sx < 0.0 else "crank_r", "crank_handles", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.02, 0, 0)), 0.03, 0.03, 0.05, 8, UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.05, 0.1, 0)), Vector3(0.025, 0.24, 0.035), UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.11, 0.2, 0)), 0.028, 0.028, 0.12, 8, UniKit.WOOD)),
			Vector3(sx * 0.57, 0, 0)))
	# The big hopper on top, lid hinged at the back, a glass window facing the gunner.
	var hop := Vector3(0, 0.45, -0.2)
	parts.append(UniKit.part("crop_hopper_large", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.lathe(st, Transform3D(), [Vector2(0.07, -0.2), Vector2(0.12, -0.1), Vector2(0.28, 0.12), Vector2(0.29, 0.2)], 16, UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.31, 0.26, 0.04, 16, UniKit.IRON_DK)
		UniKit.rivet_ring(st, Vector3(0, 0.15, 0), 0.255, 10, 0.014)
		# The window's brass frame on the back face.
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.63), Vector3(0, 0.04, 0.225)), Vector3(0.2, 0.15, 0.012), UniKit.BRASS_DK)
		# Struts down to the shroud.
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.12, -0.08, 0), Vector3(sx * 0.16, -0.25, 0.0), 0.016, UniKit.IRON)),
		hop))
	parts.append(UniKit.part("hopper_window", "crop_hopper_large", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.63), Vector3(0, 0.04, 0.232)), Vector3(0.16, 0.115, 0.008), Color(0.92, 0.92, 0.9))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("hopper_fill", "crop_hopper_large", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.13, 0)), 0.25, 0.26, 0.06, 16, Color(0.9, 0.9, 0.88))
		for i in 14:
			var a := TAU * i / 14.0
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.16, 0.17, sin(a) * 0.16)), Vector3.ONE * 0.035, 2, 5, Color(1, 1, 1))),
		Vector3.ZERO, Basis(), {"crop": true}))
	parts.append(UniKit.part("hopper_lid", "crop_hopper_large", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0, -0.3)), 0.3, 0.3, 0.025, 16, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.025, -0.55)), Vector3(0.08, 0.03, 0.06), UniKit.BRASS)), Vector3(0, 0.225, 0.3)))
	# The chute from the hopper's spout back down into the breech drum.
	parts.append(UniKit.part("ammo_chute", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.tube(st, [hop + Vector3(0, -0.2, 0), Vector3(0, 0.26, -0.02), Vector3(0, 0.24, 0.12), Vector3(0, 0.19, 0.18)], [0.045, 0.045, 0.045, 0.05], 8, UniKit.BRASS_DK)),
		Vector3.ZERO))
	return {"head_y": HEAD_Y, "head_z": head_z, "gun_y": gun_y, "parts": parts, "muzzles": [Vector3(0, 0.1, -1.4)],
		"seat": Vector3(0, 1.7, 0.8), "rest_pitch": 0.6, "ring_r": 1.75, "pour": Vector3(0, gun_y + 0.95, -0.2)}


## Barrels spin with the crank (ctx.spin: 0 to full over 2 s) and the cranks
## turn with them; unmanned it spins while it fires; they coast down over ~1 s.
## The shroud glows orange past 35% heat and red past 75%; overheated the
## barrels stop and the shroud trembles. Each shot nudges the shroud 1 cm.
## The hopper lid opens while loading.
static func _anim_iron_mule(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var ang := float(rig.state.get("spin", 0.0))
	var speed := ctx.spin * 24.0
	if not ctx.crewed and ctx.shot_age < 0.3:
		speed = 18.0 # unmanned: it turns while it fires
	if ctx.overheated:
		speed = 0.0
	var cur := float(rig.state.get("speed", 0.0))
	cur = move_toward(cur, speed, delta * (12.0 if speed > cur else 24.0))
	ang += cur * delta
	rig.state["spin"] = ang
	rig.state["speed"] = cur
	rig.turn("gatling_barrel_cluster", Vector3.BACK, ang)
	rig.turn("crank_l", Vector3.RIGHT, -ang * 0.5)
	rig.turn("crank_r", Vector3.RIGHT, -ang * 0.5)
	var shake := sin(ctx.t * 70.0) * 0.004 if ctx.overheated else 0.0
	rig.pose("barrel_shroud", Vector3(shake, 0, 0.01 * kick_k(ctx.shot_age, 0.06)))
	var heat := 1.0 if ctx.overheated else ctx.heat
	rig.show_part("shroud_heat", heat > 0.35 and heat <= 0.75)
	rig.show_part("shroud_hot", heat > 0.75)
	rig.turn("hopper_lid", Vector3.RIGHT, PI * 0.5 * open_k(ctx.load_k))


# ------------------------------------------------------------------ 27. Crop Howitzer

## A fat mortar barrel on an elevation cradle, a breech loader with a handle at
## the back, a rack of four crop shells on legs to the right, the big aiming
## wheel geared to the left cheek, and a standing operator's rail with grips,
## all on a railed platform.
## Parts: heavy_platform, operator_station, howitzer_barrel (+ muzzle_glow,
## loading_mechanism), shell_rack (+ shell_0..3), aiming_wheel.
static func _howitzer(team: Color) -> Dictionary:
	var head_z := -0.5
	var tr := 1.0
	var gun_y := 0.62
	var parts: Array = [_platform(team, true, head_z, tr)]
	parts.append(UniKit.part("operator_station", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_turntable(st, tr)
		_cheeks(st, 0.38, gun_y, 0.6)
		# The standing operator's rail with leather grips, behind the gun.
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.35, 0.0, 0.92), Vector3(sx * 0.35, 1.0, 0.82), 0.03, UniKit.IRON)
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(sx * 0.42, 1.0, 0.82)), 0.035, 0.035, 0.14, 8, UniKit.LEATHER)
		MeshKit.add_limb(st, Vector3(-0.35, 1.0, 0.82), Vector3(0.35, 1.0, 0.82), 0.03, UniKit.BRASS_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0.75)), Vector3(0.7, 0.04, 0.4), UniKit.WOOD_DK)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.35, 0), "size": Vector3(0.86, 0.7, 0.6)}}))
	parts.append(UniKit.part("howitzer_barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.42, -1.05, 0.22, UniKit.IRON_DK, 16, 0.19)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -1.07)), 0.24, 0.15, 0.08, 16, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -1.06)), 0.15, 0.15, 0.03, 14, Color("#1A1B1F"))
		UniKit.band(st, 0, 0, -0.3, 0.24, 0.1, UniKit.BRASS_DK)
		UniKit.band(st, 0, 0, 0.3, 0.235, 0.06, UniKit.IRON)
		UniKit.rivet_row(st, Vector3(0, 0.215, -0.2), Vector3(0, 0.2, -0.95), 5)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0, 0, 0)), 0.07, 0.07, 0.72, 10, UniKit.IRON)), Vector3.ZERO))
	parts.append(UniKit.part("muzzle_glow", "howitzer_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.95, 0.205, 0.04, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The breech block hinged at the back of the barrel, with its handle.
	parts.append(UniKit.part("loading_mechanism", "howitzer_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0.0, -0.2, 0.0)), 0.19, 0.19, 0.08, 14, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0.0, -0.2, 0.05)), 0.08, 0.08, 0.04, 10, UniKit.BRASS)
		MeshKit.add_limb(st, Vector3(0.0, -0.2, 0.06), Vector3(0.22, -0.32, 0.1), 0.02, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.25, -0.33, 0.1)), 0.025, 0.025, 0.08, 8, UniKit.WOOD)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0, 0, 0)), 0.03, 0.03, 0.12, 8, UniKit.BRASS_DK)),
		Vector3(0, 0.2, 0.46)))
	# The rack of four crop shells on legs, to the right of the gun.
	parts.append(UniKit.part("shell_rack", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.2, 0.05, 0.95), UniKit.WOOD_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, 0.25, 0)), Vector3(0.2, 0.04, 0.95), UniKit.WOOD)
		for z: float in [-0.45, 0.45]:
			for sx: float in [-1.0, 1.0]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.08, -0.13, z)), Vector3(0.04, 0.27, 0.04), UniKit.WOOD_DK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, z)), Vector3(0.2, 0.28, 0.04), UniKit.WOOD)
		for i in 4:
			MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.25, -0.33 + i * 0.22)), 0.09, 0.075, 0.045, 10, UniKit.IRON_DK)),
		Vector3(0.72, 0.27, 0.1)))
	for i in 4:
		parts.append(UniKit.part("shell_%d" % i, "shell_rack", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.07, 0.07, 0.2, 10, Color(0.92, 0.92, 0.9))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.27, 0)), 0.07, 0.0, 0.1, 10, Color(0.8, 0.8, 0.78))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.035, 0)), 0.074, 0.074, 0.03, 10, Color(0.7, 0.7, 0.68))),
			Vector3(0, 0.0, -0.33 + i * 0.22), Basis(), {"crop": true}))
	# The aiming wheel on an axle out of the left cheek (turns with the elevation).
	parts.append(UniKit.part("aiming_wheel", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.3, 0.26, 0.05, 20, UniKit.IRON_DK)
		for k in 6:
			var b := Basis(Vector3.RIGHT, TAU * k / 6.0)
			MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 0.14, 0)), Vector3(0.03, 0.27, 0.03), UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.06, 0, 0)), 0.035, 0.035, 0.22, 8, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.06, 0.06, 0.08, 10, UniKit.BRASS)
		MeshKit.add_limb(st, Vector3(-0.02, 0.27, 0), Vector3(-0.12, 0.27, 0), 0.02, UniKit.WOOD)),
		Vector3(-0.6, 0.5, 0.28)))
	return {"head_y": HEAD_Y, "head_z": head_z, "gun_y": gun_y, "parts": parts, "muzzles": [Vector3(0, 0, -1.12)],
		"seat": Vector3(0, 1.75, 1.0), "rest_pitch": 1.25, "ring_r": 1.75, "pour": Vector3(0.72, 1.0, 0.1)}


## Each shell: the breech drops open and swings shut, the barrel rocks back 5 cm;
## the rack empties one shell per shot of a volley and fills again as the gun
## recharges. The breech hangs open while empty and while loading. The wheel
## turns as the barrel's elevation changes.
static func _anim_howitzer(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	rig.kick("howitzer_barrel", 0.05 * kick_k(ctx.shot_age, 0.25))
	var breech := kick_k(ctx.shot_age, 0.3)
	if not ctx.loaded:
		breech = 1.0
	rig.turn("loading_mechanism", Vector3.RIGHT, -1.3 * maxf(breech, open_k(ctx.load_k)))
	# Shells on the rack: one gone per shot of a volley, back as it recharges.
	var spent := int(rig.state.get("spent", 0))
	var last := int(rig.state.get("last", ctx.shots))
	if ctx.shots != last:
		spent = mini(spent + (ctx.shots - last), 4)
	if ctx.charge > 0.9 and ctx.shot_age > 1.0:
		spent = 0
	rig.state["spent"] = spent
	rig.state["last"] = ctx.shots
	for i in 4:
		rig.show_part("shell_%d" % i, ctx.loaded and i >= spent)
	var wheel := float(rig.state.get("wheel", 0.0)) + (ctx.pitch - float(rig.state.get("pitch", ctx.pitch))) * 6.0
	rig.state["pitch"] = ctx.pitch
	rig.state["wheel"] = wheel
	rig.turn("aiming_wheel", Vector3.RIGHT, wheel)


# ------------------------------------------------------------------ 28. Sky Hound

## A long heavy cannon between tall cheeks, a big brass scope with an eyepiece,
## an oversized riveted breech with a side door (a crop round showing), a
## counterweight hanging under the back, and an elevated swivel chair.
## Parts: heavy_platform, gunner_seat, cannon_barrel (+ barrel_glow),
## scope_assembly (+ scope_lens), crop_breech (+ breech_round, breech_door,
## casing), counterweight.
static func _sky_hound(team: Color) -> Dictionary:
	var head_z := -0.3
	var tr := 0.95
	var gun_y := 0.9
	var parts: Array = [_platform(team, false, head_z, tr)]
	parts.append(UniKit.part("gunner_seat", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_turntable(st, tr)
		_seat(st, Vector3(0, 0.78, 0.9))
		# A footrest ring round the tall post.
		MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.4, 0.9)), 0.2, 0.16, 0.03, 12, UniKit.BRASS_DK)
		_cheeks(st, 0.3, gun_y, 0.42)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, sx * 0.25), Vector3(sx * 0.42, 0.25, 0)), Vector3(0.06, 0.5, 0.3), UniKit.IRON_DK)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.45, 0), "size": Vector3(0.7, 0.9, 0.42)}}))
	parts.append(UniKit.part("cannon_barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.15, -2.15, 0.11, UniKit.IRON_DK, 14, 0.08)
		UniKit.barrel(st, 0, 0, -2.1, -2.25, 0.1, UniKit.IRON, 12)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.1, 0, -2.18)), Vector3(0.03, 0.06, 0.06), UniKit.IRON_DK)
		for z: float in [-0.6, -1.3]:
			UniKit.band(st, 0, 0, z, 0.115, 0.06, UniKit.BRASS)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0, 0, 0)), 0.06, 0.06, 0.62, 10, UniKit.IRON)), Vector3.ZERO))
	parts.append(UniKit.part("barrel_glow", "cannon_barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -1.95, 0.09, 0.06, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The big scope along the top on two rings, an eyepiece cup at the back.
	parts.append(UniKit.part("scope_assembly", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.4, -0.62, 0.05, UniKit.BRASS, 12)
		UniKit.barrel(st, 0, 0, -0.6, -0.72, 0.05, UniKit.BRASS, 12, 0.07)
		UniKit.barrel(st, 0, 0, 0.5, 0.38, 0.065, UniKit.BRASS_DK, 12, 0.05)
		UniKit.barrel(st, 0, 0, 0.52, 0.5, 0.07, UniKit.LEATHER, 12)
		for z: float in [0.15, -0.4]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.075, z)), Vector3(0.04, 0.1, 0.04), UniKit.IRON)
			UniKit.band(st, 0, 0, z, 0.06, 0.04, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3(0.06, 0, 0.0)), 0.025, 0.025, 0.03, 8, UniKit.BRASS_DK)),
		Vector3(0, 0.21, 0)))
	parts.append(UniKit.part("scope_lens", "scope_assembly", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.064, 0.064, 0.01, 14, UniKit.GLOW_WHITE)),
		Vector3(0, 0, -0.722), Basis(), {"glow": true}))
	# The oversized breech at the back, a side door showing the crop round.
	parts.append(UniKit.part("crop_breech", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.3, 0.28, 0.4), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.21)), Vector3(0.26, 0.24, 0.02), UniKit.IRON_DK)
		UniKit.rivet_row(st, Vector3(-0.152, 0.1, -0.15), Vector3(-0.152, 0.1, 0.15), 3)
		UniKit.rivet_row(st, Vector3(-0.152, -0.1, -0.15), Vector3(-0.152, -0.1, 0.15), 3)
		UniKit.rivet_row(st, Vector3(-0.12, 0.142, -0.17), Vector3(0.12, 0.142, -0.17), 3)), Vector3(0, 0, 0.33)))
	parts.append(UniKit.part("breech_round", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0.152, 0, 0)), 0.07, 0.07, 0.26, 10, Color(0.95, 0.95, 0.92))),
		Vector3.ZERO, Basis(), {"crop": true}))
	# The door on the right side, hinged at its top edge.
	parts.append(UniKit.part("breech_door", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, -0.1, 0)), Vector3(0.025, 0.2, 0.32), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.025, -0.17, 0.0)), Vector3(0.03, 0.03, 0.08), UniKit.BRASS)), Vector3(0.17, 0.1, 0)))
	parts.append(UniKit.part("casing", "crop_breech", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.06, 0.06, 0.22, 10, UniKit.BRASS)), Vector3(0.18, -0.05, 0)))
	# The counterweight hanging under the back: swings forward on the recoil.
	parts.append(UniKit.part("counterweight", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.035, 0.035, 0.24, 8, UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.1, -0.13, 0)), Vector3(0.03, 0.26, 0.04), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.32, 0)), Vector3(0.28, 0.18, 0.2), UniKit.IRON_DK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.32, 0)), Vector3(0.29, 0.03, 0.21), UniKit.BRASS_DK)), Vector3(0, -0.15, 0.4)))
	return {"head_y": HEAD_Y, "head_z": head_z, "gun_y": gun_y, "parts": parts, "muzzles": [Vector3(0, 0, -2.28)],
		"seat": Vector3(0, 1.55, 0.9), "rest_pitch": 1.1, "ring_r": 1.75, "pour": Vector3(0, gun_y + 0.5, 0.33)}


## Heavy recoil: the barrel slides back 8 cm and creeps home over 0.5 s; the
## counterweight swings forward and settles; the breech door kicks open, the
## spent casing drops out, the door shuts. Scoped (mode 1, manned) the lens
## swells; the door also opens while loading.
static func _anim_sky_hound(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	rig.kick("cannon_barrel", 0.08 * kick_k(a, 0.5))
	var swing := 0.0
	if a < 2.0:
		swing = 0.45 * sin(a * 8.0) * exp(-a * 3.0)
	rig.turn("counterweight", Vector3.RIGHT, swing)
	var door := smoothstep(0.05, 0.15, a) * (1.0 - smoothstep(0.5, 0.75, a))
	if ctx.shots <= 0:
		door = 0.0
	rig.turn("breech_door", Vector3.BACK, 1.4 * maxf(door, open_k(ctx.load_k)))
	var drop := ctx.shots > 0 and a > 0.12 and a < 0.7
	rig.show_part("casing", drop)
	if drop:
		var e := a - 0.12
		rig.pose("casing", Vector3(0.25 * e, -2.4 * e * e, 0), Basis(Vector3.RIGHT, e * 6.0))
	var scope := 1.25 if (ctx.mode == 1 and ctx.crewed) else 1.0
	rig.stretch("scope_lens", Vector3(scope, scope, 1.0))


# ------------------------------------------------------------------ 29. Vortex Engine

## A big turbine drum on tall trunnion cheeks: intake vents round it, blades
## inside its open back, a flared output cone at the front, two exhaust stacks;
## a glass tank of crop brew piped into it, and a control panel with two levers
## where the operator stands.
## Parts: heavy_platform, operator_station (+ lever_l / lever_r), turbine_housing
## (+ turbine_blades, output_cone with cone_glow, exhaust_vents), crop_feed_tank
## (+ tank_brew), feed_pipe.
static func _vortex(team: Color) -> Dictionary:
	var head_z := -0.4
	var tr := 1.0
	var gun_y := 1.05
	var parts: Array = [_platform(team, true, head_z, tr)]
	parts.append(UniKit.part("operator_station", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_turntable(st, tr)
		_cheeks(st, 0.53, gun_y, 0.4, UniKit.IRON_DK)
		# The control panel the levers stand in, with a gauge.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.45, 0.8)), Vector3(0.7, 0.9, 0.2), UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.93, 0.79)), Vector3(0.74, 0.06, 0.28), UniKit.BRASS_DK)
		UniKit.gauge(st, Vector3(0, 0.6, 0.91), Vector3.BACK, 0.07)
		UniKit.rivet_row(st, Vector3(-0.3, 0.1, 0.91), Vector3(0.3, 0.1, 0.91), 5)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.45, 0.8), "size": Vector3(0.7, 0.9, 0.2)}}))
	for sx: float in [-1.0, 1.0]:
		parts.append(UniKit.part("lever_l" if sx < 0.0 else "lever_r", "operator_station", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.04, 0.04, 0.08, 8, UniKit.BRASS)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.04, 0.5, 0.04), UniKit.IRON)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.52, 0)), Vector3.ONE * 0.05, 3, 8, Color("#B8352A"))),
			Vector3(sx * 0.22, 0.95, 0.78)))
	# The turbine drum (the gun), its trunnion axle, intake vents and bands.
	parts.append(UniKit.part("turbine_housing", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		# The drum is closed at z 0.2; the blades spin behind it inside a guard ring.
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.175)), 0.42, 0.42, 0.75, 20, UniKit.IRON)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.205)), 0.36, 0.36, 0.01, 20, Color("#24262C"))
		for k in 4:
			var bs := Basis(Vector3.BACK, TAU * (k + 0.5) / 4.0)
			MeshKit.add_box(st, Transform3D(bs, bs * Vector3(0, 0.415, 0.27)), Vector3(0.05, 0.03, 0.16), UniKit.IRON_DK)
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.06, 0.06, 1.08, 10, UniKit.BRASS_DK)
		for z: float in [0.34, 0.15, -0.2, -0.52]:
			MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, z)), 0.45, 0.38, 0.05, 20, UniKit.BRASS_DK)
		for k in 8:
			var b := Basis(Vector3.BACK, TAU * k / 8.0)
			MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 0.425, -0.02)), Vector3(0.1, 0.014, 0.24), UniKit.IRON_DK)
		# Spokes holding the blade hub across the open back.
		for k in 3:
			var b := Basis(Vector3.BACK, TAU * k / 3.0)
			MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 0.2, 0.36)), Vector3(0.03, 0.4, 0.03), UniKit.IRON)),
		Vector3.ZERO))
	parts.append(UniKit.part("turbine_blades", "turbine_housing", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.08, 0.08, 0.14, 10, UniKit.BRASS)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.08)), Vector3(0.08, 0.08, 0.06), 3, 10, UniKit.BRASS_DK)
		for k in 7:
			var b := Basis(Vector3.BACK, TAU * k / 7.0)
			MeshKit.add_box(st, Transform3D(b * Basis(Vector3.UP, 0.45), b * Vector3(0, 0.22, 0)), Vector3(0.12, 0.3, 0.02), UniKit.IRON_LT)),
		Vector3(0, 0, 0.27)))
	parts.append(UniKit.part("output_cone", "turbine_housing", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.lathe(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), [Vector2(0.4, 0.0), Vector2(0.45, 0.2), Vector2(0.6, 0.4), Vector2(0.63, 0.45)], 20, UniKit.BRASS)
		MeshKit.add_rim(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, -0.44)), 0.66, 0.58, 0.04, 20, UniKit.BRASS_DK)),
		Vector3(0, 0, -0.55)))
	parts.append(UniKit.part("cone_glow", "output_cone", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.02)), 0.38, 0.38, 0.02, 20, UniKit.GLOW_WHITE)),
		Vector3.ZERO, Basis(), {"glow": true}))
	parts.append(UniKit.part("exhaust_vents", "turbine_housing", UniKit.mesh(func(st: SurfaceTool) -> void:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(sx * 0.2, 0.46, 0.05)), 0.06, 0.075, 0.3, 10, UniKit.IRON_DK)
			MeshKit.add_rim(st, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(sx * 0.2, 0.59, 0.12)), 0.085, 0.055, 0.04, 10, UniKit.BRASS_DK)),
		Vector3.ZERO))
	# The glass tank of crop brew on the turntable, piped up to the right trunnion.
	var tank := Vector3(0.68, 0.0, 0.42)
	parts.append(UniKit.part("crop_feed_tank", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.28, 0.28, 0.06, 16, UniKit.BRASS_DK)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.8, 0)), 0.28, 0.28, 0.06, 16, UniKit.BRASS_DK)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.84, 0)), Vector3(0.2, 0.08, 0.2), 3, 12, UniKit.BRASS)
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.27, 0.42, sin(a) * 0.27)), Vector3(0.04, 0.74, 0.04), UniKit.BRASS)
		for k in 8:
			var a := TAU * (k + 0.5) / 8.0 + 0.4
			if k % 2 == 0:
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.262, 0.42, sin(a) * 0.262)), Vector3(0.004, 0.68, 0.05), UniKit.GLASS)),
		tank))
	parts.append(UniKit.part("tank_brew", "crop_feed_tank", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.36, 0)), 0.25, 0.25, 0.72, 16, Color(0.9, 0.9, 0.9))),
		Vector3(0, 0.06, 0), Basis(), {"crop": true}))
	parts.append(UniKit.part("feed_pipe", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.tube(st, [tank + Vector3(-0.2, 0.75, -0.1), Vector3(0.6, 1.1, 0.15), Vector3(0.62, gun_y, 0.0)], [0.035, 0.035, 0.035], 8, UniKit.BRASS_DK)),
		Vector3.ZERO))
	return {"head_y": HEAD_Y, "head_z": head_z, "gun_y": gun_y, "parts": parts, "muzzles": [Vector3(0, 0, -1.02)],
		"seat": Vector3(0, 1.7, 1.15), "rest_pitch": 0.55, "ring_r": 1.75, "pour": tank + Vector3(0, 1.2, 0)}


## Loaded it idles slowly with a faint hum; firing pulls both levers and spins
## the blades up fast (0.3 s) and holds them high through the vortex, the drum
## shakes, then winds down over 1 s; the brew's level drops through the vortex
## and refills on the cooldown.
static func _anim_vortex(rig: UniRig, ctx: UniCtx, delta: float) -> void:
	var fast := ctx.loaded and ctx.shots > 0 and ctx.shot_age < 4.0
	var want := (30.0 if fast else (2.5 if ctx.loaded else 0.0))
	var cur := float(rig.state.get("speed", 0.0))
	cur = move_toward(cur, want, delta * (100.0 if want > cur else 28.0))
	var ang := float(rig.state.get("ang", 0.0)) + cur * delta
	rig.state["speed"] = cur
	rig.state["ang"] = ang
	rig.turn("turbine_blades", Vector3.BACK, ang)
	var pull := 0.0
	if ctx.shots > 0 and ctx.shot_age < 4.2:
		pull = 0.7 * smoothstep(0.0, 0.1, ctx.shot_age) * (1.0 - smoothstep(3.5, 4.2, ctx.shot_age))
	rig.turn("lever_l", Vector3.RIGHT, pull)
	rig.turn("lever_r", Vector3.RIGHT, pull)
	var level := 1.0 - 0.6 * clampf(1.0 - ctx.charge, 0.0, 1.0)
	if ctx.load_k < 1.0:
		level = smoothstep(0.3, 0.9, ctx.load_k)
	rig.stretch("tank_brew", Vector3(1, maxf(level, 0.05), 1))
	var hum := 0.0
	if fast:
		hum = sin(ctx.t * 50.0) * 0.004
	elif ctx.loaded:
		hum = sin(ctx.t * 37.0) * 0.001
	rig.pose("turbine_housing", Vector3(hum, 0, 0))


# ------------------------------------------------------------------ 30. Thunder Mule

## A salvo array of three barrels on the left and a heavy cannon on the right on
## a shared trunnion; between and behind them the auto-switch rod and cam and
## the dual crop feed (a feed box with a line to each side, the active one lit);
## two blast shields in front of the central seat with its restraint bar.
## Parts: heavy_platform, gunner_seat (+ restraint_bar), muzzle_shields,
## salvo_array (salvo_barrel_0..2), heavy_cannon, auto_switch_mechanism
## (+ switch_cam), crop_feed_dual (+ feed_box_crop, crop_feed_left / _right glow).
static func _thunder_mule(team: Color) -> Dictionary:
	var head_z := -0.5
	var tr := 1.0
	var gun_y := 0.95
	var parts: Array = [_platform(team, false, head_z, tr)]
	parts.append(UniKit.part("gunner_seat", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		_turntable(st, tr)
		_seat(st, Vector3(0, 0.55, 0.85))
		_cheeks(st, 0.66, gun_y, 0.55)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.66, 0.6, 0.25), Vector3(sx * 0.3, 0.0, 0.55), 0.03, UniKit.IRON_DK)),
		Vector3.ZERO, Basis(), {"trim": {"c": Vector3(0, 0.5, 0), "size": Vector3(1.42, 1.0, 0.55)}}))
	parts.append(UniKit.part("restraint_bar", "gunner_seat", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.025, 0.025, 0.56, 8, UniKit.IRON_DK)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.26, 0, 0), Vector3(sx * 0.26, 0.05, -0.32), 0.02, UniKit.IRON)
		MeshKit.add_limb(st, Vector3(-0.26, 0.05, -0.32), Vector3(0.26, 0.05, -0.32), 0.025, UniKit.BRASS)),
		Vector3(0, 0.95, 1.12)))
	# Two small blast shields on stalks in front of the gunner.
	parts.append(UniKit.part("muzzle_shields", "gunner_seat", UniKit.mesh(func(st: SurfaceTool) -> void:
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(sx * 0.28, 0.0, 0.5), Vector3(sx * 0.28, 0.85, 0.5), 0.025, UniKit.IRON)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, sx * 0.3), Vector3(sx * 0.3, 1.0, 0.48)), Vector3(0.42, 0.34, 0.03), UniKit.IRON_DK)
			UniKit.rivet_row(st, Vector3(sx * 0.12, 1.14, 0.465), Vector3(sx * 0.48, 1.14, 0.41), 3)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, sx * 0.3), Vector3(sx * 0.3, 0.86, 0.47)), Vector3(0.42, 0.03, 0.035), team)),
		Vector3.ZERO))
	# A shared trunnion axle through both weapons.
	parts.append(UniKit.part("gun_axle", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.06, 0.06, 1.3, 10, UniKit.IRON_DK)), Vector3.ZERO))
	# Left: the salvo array's housing; its three barrels kick one by one.
	parts.append(UniKit.part("salvo_array", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.34, 0.32, 0.4), UniKit.BRASS_DK)
		UniKit.rivet_row(st, Vector3(-0.172, 0.12, -0.05), Vector3(-0.172, 0.12, 0.25), 3)
		UniKit.band(st, 0, 0, -0.45, 0.18, 0.06, UniKit.IRON)
		UniKit.band(st, 0, 0, -0.95, 0.18, 0.05, UniKit.IRON)), Vector3(-0.36, 0, 0)))
	for i in 3:
		var a := PI * 0.5 + TAU * i / 3.0
		parts.append(UniKit.part("salvo_barrel_%d" % i, "salvo_array", UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.barrel(st, 0, 0, -0.1, -1.1, 0.058, UniKit.IRON_DK, 12, 0.062)
			UniKit.barrel(st, 0, 0, -1.06, -1.12, 0.07, UniKit.IRON, 12)), Vector3(cos(a) * 0.09, sin(a) * 0.09, 0)))
		parts.append(UniKit.part("salvo_glow_%d" % i, "salvo_barrel_%d" % i, UniKit.mesh(func(st: SurfaceTool) -> void:
			UniKit.band(st, 0, 0, -1.0, 0.065, 0.04, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# Right: the heavy cannon with a muzzle brake.
	parts.append(UniKit.part("heavy_cannon", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3(0, 0, 0.12)), 0.19, 0.19, 0.36, 14, UniKit.IRON)
		UniKit.barrel(st, 0, 0, -0.06, -1.5, 0.13, UniKit.IRON_DK, 14, 0.11)
		UniKit.barrel(st, 0, 0, -1.45, -1.62, 0.13, UniKit.IRON, 12)
		for sy: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, sy * 0.12, -1.53)), Vector3(0.06, 0.05, 0.06), UniKit.IRON_DK)
		UniKit.band(st, 0, 0, -0.4, 0.15, 0.1, UniKit.BRASS_DK)), Vector3(0.36, 0, 0)))
	parts.append(UniKit.part("heavy_glow", "heavy_cannon", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -1.3, 0.122, 0.05, UniKit.GLOW_WHITE)), Vector3.ZERO, Basis(), {"glow": true}))
	# The auto-switch: a rod sliding across the breeches and a cam on a hub.
	parts.append(UniKit.part("auto_switch_mechanism", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_X, Vector3.ZERO), 0.028, 0.028, 0.6, 8, UniKit.BRASS)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.3, 0, 0)), Vector3(0.05, 0.08, 0.05), UniKit.IRON)),
		Vector3(0, 0.2, 0.36)))
	parts.append(UniKit.part("switch_cam", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_cylinder(st, Transform3D(UniKit.ALONG_Z, Vector3.ZERO), 0.07, 0.07, 0.05, 12, UniKit.IRON)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(0.035, 0.14, 0.04), UniKit.BRASS_DK)), Vector3(0, 0.08, 0.36)))
	# The dual feed: a box of crop on top behind the guns, a brass line to each.
	var box := Vector3(0, 0.3, 0.52)
	parts.append(UniKit.part("crop_feed_dual", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), box), Vector3(0.3, 0.2, 0.26), UniKit.WOOD_DK)
		MeshKit.add_box(st, Transform3D(Basis(), box + Vector3(0, -0.07, 0)), Vector3(0.31, 0.02, 0.27), UniKit.IRON_DK)
		MeshKit.add_limb(st, box + Vector3(0, -0.1, 0), Vector3(0, 0.1, 0.4), 0.03, UniKit.IRON)
		for side: float in [-1.0, 1.0]:
			MeshKit.tube(st, [box + Vector3(side * 0.15, -0.02, 0), Vector3(side * 0.3, 0.3, 0.3), Vector3(side * 0.36, 0.16, 0.2)], [0.03, 0.03, 0.03], 8, UniKit.BRASS_DK)),
		Vector3.ZERO))
	parts.append(UniKit.part("feed_box_crop", "crop_feed_dual", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), box + Vector3(0, 0.1, 0)), Vector3(0.26, 0.025, 0.22), Color(0.95, 0.95, 0.92))),
		Vector3.ZERO, Basis(), {"crop": true}))
	for side: float in [-1.0, 1.0]:
		parts.append(UniKit.part("crop_feed_left" if side < 0.0 else "crop_feed_right", "crop_feed_dual", UniKit.mesh(func(st: SurfaceTool) -> void:
			MeshKit.tube(st, [box + Vector3(side * 0.15, -0.02, 0), Vector3(side * 0.3, 0.3, 0.3), Vector3(side * 0.36, 0.16, 0.2)], [0.036, 0.036, 0.036], 8, UniKit.GLOW_WHITE)),
			Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": HEAD_Y, "head_z": head_z, "gun_y": gun_y, "parts": parts,
		"muzzles": [["salvo_barrel_0", Vector3(0, 0, -1.14)], ["salvo_barrel_1", Vector3(0, 0, -1.14)], ["salvo_barrel_2", Vector3(0, 0, -1.14)]],
		"heavy_muzzles": [["heavy_cannon", Vector3(0, 0, -1.65)]],
		"seat": Vector3(0, 1.55, 0.85), "rest_pitch": 0.9, "ring_r": 1.75, "pour": Vector3(0, gun_y + 0.7, 0.52)}


## Each shot flips the mode (mode 1: the heavy round is next). A salvo (mode now
## 1): the three barrels kick 2 cm in turn, 0.15 s apart. The heavy round (mode
## now 0): the cannon slams back 4 cm. The switch rod slides towards the side
## that fires next and the cam turns over (0.2 s); that side's feed line lights.
## The restraint bar is down while manned and up when empty.
static func _anim_thunder_mule(rig: UniRig, ctx: UniCtx, _delta: float) -> void:
	var a := ctx.shot_age
	var fired := ctx.shots > 0
	var was_heavy := fired and ctx.mode == 0
	rig.kick("heavy_cannon", 0.04 * kick_k(a, 0.35) if was_heavy else 0.0)
	for i in 3:
		var k := 0.0
		if fired and not was_heavy:
			k = kick_k(a - 0.15 * i, 0.1) if a >= 0.15 * i else 0.0
		rig.kick("salvo_barrel_%d" % i, 0.02 * k)
	var next := smoothstep(0.0, 1.0, ctx.mode_k)
	rig.pose("auto_switch_mechanism", Vector3(lerpf(-0.14, 0.14, next), 0, 0))
	rig.turn("switch_cam", Vector3.BACK, lerpf(0.7, -0.7, next))
	rig.show_part("crop_feed_left", ctx.loaded and next < 0.5)
	rig.show_part("crop_feed_right", ctx.loaded and next >= 0.5)
	rig.turn("restraint_bar", Vector3.RIGHT, 0.0 if ctx.crewed else 1.2)
