class_name UniversalBuilder
extends RefCounted
## The universal crop-fed turrets' models (Nov 2026 handoff), built in code as
## placeholders in the parts the handoff lists, so every piece can move:
##   gen/universal_cliff.gd    the 10 cliff turrets
##   gen/universal_air.gd      the 5 air-defense guns
##   gen/universal_house.gd    the 5 last resorts (house mounts)
##   gen/universal_ground.gd   the 5 obstructions
##   gen/universal_crewed.gd   the 5 crewed guns
## Each group has build(id, team) -> spec and animate(id, rig, ctx, delta).
## Until a group builds an id, a plain stand-in (_fallback) is used.
##
## A spec: {
##   "head_y": float      the yaw pivot's height (the turret body turns on it)
##   "gun_y": float       the pitch pivot above the head (the barrels tilt on it)
##   "parts": [UniKit.part(...)]   every piece (see UniKit for the conventions)
##   "muzzles": [Vector3 in gun space, or [part name, Vector3 in that part]]
##   "heavy_muzzles": [...]        hybrids: the heavy barrel's muzzle(s)
##   optional: "rest_pitch" (unloaded barrel tilt, radians, default 45 deg up),
##   "loaded_pitch" (default 0), "ring_r" (base ring radius, default 0.85),
##   "no_aim": true (doesn't track: obstructions, the fog), "pour" (Vector3 in
##   head space where the crop pours in when loading, default above the head),
##   "idle_at" (Vector3 in gun space for the idle crop wisps, default the first muzzle)
## }

static var _specs: Dictionary = {}


static func has(id: StringName) -> bool:
	return Defs.is_universal(id)


## Has its fal model (assets/rigged/turrets, Nov 2026): the turret shows that
## instead of the code parts (UniRig.wrap).
static func rigged(id: StringName) -> bool:
	return has(id) and RiggedTurret.has(id)


## The code spec cut down for a rigged model: its rest angles, aim and seat
## stay; the places tied to the code parts (where the crop pours in, the idle
## wisps) go back to their defaults, and the base ring fits the model's base.
static func rigged_spec(s: Dictionary, ring_r: float) -> Dictionary:
	var out := s.duplicate()
	out.erase("parts")
	out.erase("pour")
	out.erase("idle_at")
	out.erase("muzzles")
	out.erase("heavy_muzzles")
	out["ring_r"] = ring_r
	return out


## The id's group: &"cliff", &"air", &"house", &"ground" or &"crewed".
static func group_of(id: StringName) -> StringName:
	if Defs.UNIVERSAL_AA.has(id):
		return &"air"
	if Defs.UNIVERSAL_LAST.has(id):
		return &"house"
	if Defs.UNIVERSAL_OBSTRUCTIONS.has(id):
		return &"ground"
	if Defs.UNIVERSAL_CREWED.has(id):
		return &"crewed"
	return &"cliff"


static func spec(id: StringName, team: Color) -> Dictionary:
	var key := "%s|%s" % [id, team.to_html()]
	if not _specs.has(key):
		var s: Dictionary = {}
		match group_of(id):
			&"cliff": s = UniversalCliff.build(id, team)
			&"air": s = UniversalAir.build(id, team)
			&"house": s = UniversalHouse.build(id, team)
			&"ground": s = UniversalGround.build(id, team)
			&"crewed": s = UniversalCrewed.build(id, team)
		if s.is_empty():
			s = _fallback(id, team)
		_specs[key] = s
	return _specs[key]


## Every frame, every peer: move the id's parts for this frame.
static func animate(id: StringName, rig: UniRig, ctx: UniCtx, delta: float) -> void:
	match group_of(id):
		&"cliff": UniversalCliff.animate(id, rig, ctx, delta)
		&"air": UniversalAir.animate(id, rig, ctx, delta)
		&"house": UniversalHouse.animate(id, rig, ctx, delta)
		&"ground": UniversalGround.animate(id, rig, ctx, delta)
		&"crewed": UniversalCrewed.animate(id, rig, ctx, delta)


## TurretBuilder's parts for an id: the whole model merged into "base" (the build
## ghost and icons use it; UniversalTurret replaces it with the moving parts).
static func turret_parts(id: StringName, team: Color) -> Dictionary:
	var s := spec(id, team)
	var head_y := float(s.get("head_y", 0.2))
	var gun_y := float(s.get("gun_y", 0.4))
	var muz: Vector3 = Vector3(0, 0, -1.0)
	var ms: Array = s.get("muzzles", [])
	if not ms.is_empty() and ms[0] is Vector3:
		muz = ms[0]
	return {"base": UniRig.whole_mesh(s, head_y, gun_y, float(s.get("loaded_pitch", 0.0))), "head": ArrayMesh.new(),
		"gun": ArrayMesh.new(), "head_y": head_y, "gun_y": gun_y, "muzzle": muz, "recoil": 0.0}


## A plain stand-in for an id its group hasn't built yet: the platform, a box
## body and a barrel sized by its job.
static func _fallback(id: StringName, _team: Color) -> Dictionary:
	var d := Defs.turret(id)
	var heavy := d.job == "ST"
	var parts: Array = []
	parts.append(UniKit.part("base_platform", "base", UniKit.mesh(func(st: SurfaceTool) -> void: UniKit.platform(st))))
	parts.append(UniKit.part("turret_body", "head", UniKit.mesh(func(st: SurfaceTool) -> void:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.25, 0.05)), Vector3(0.5, 0.42, 0.6), UniKit.IRON)
		UniKit.rivet_row(st, Vector3(-0.26, 0.4, -0.2), Vector3(-0.26, 0.4, 0.3), 5)), Vector3.ZERO, Basis(),
		{"trim": {"c": Vector3(0, 0.25, 0.05), "size": Vector3(0.5, 0.42, 0.6)}}))
	var r := 0.07 if heavy else 0.05
	parts.append(UniKit.part("barrel", "gun", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.barrel(st, 0, 0, 0.15, -1.0, r, UniKit.IRON_DK)
		UniKit.band(st, 0, 0, -0.4, r + 0.015, 0.05)), Vector3.ZERO))
	parts.append(UniKit.part("barrel_glow", "barrel", UniKit.mesh(func(st: SurfaceTool) -> void:
		UniKit.band(st, 0, 0, -0.93, r + 0.012, 0.06)), Vector3.ZERO, Basis(), {"glow": true}))
	return {"head_y": UniKit.PLATFORM_TOP + 0.02, "gun_y": 0.45, "parts": parts, "muzzles": [Vector3(0, 0, -1.02)]}
