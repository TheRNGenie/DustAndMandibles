class_name WeaponBuilder
extends RefCounted
## Gun meshes built from primitives, at real-world size. Barrel points along -Z,
## +Y is up, the origin sits in the frame just above the trigger. The same meshes
## are used for the first-person viewmodel, the gun in a player's hand, and guns
## lying on the ground. arms() builds the gloved hands and coat sleeves that hold
## each gun in first person.

const BLUED := Color("#4E5862")
const BLUED_DARK := Color("#343B44")
const STEEL := Color("#8A96A0")
const BRASS := Color("#D6A74A")
const WALNUT := Color("#7A4A2A")
const WALNUT_DARK := Color("#5C351D")
const GLOVE := Color("#8A5A34")
const GLOVE_DARK := Color("#6A4024")
const SLEEVE := Color("#7E6246")
const SLEEVE_DARK := Color("#604A34")

const ALONG_Z := Basis(Vector3.RIGHT, PI * 0.5)


# ------------------------------------------------------------------ helpers

## A cylinder running from a to b (any direction).
static func rod(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, segs: int, col: Color) -> void:
	var dir := b - a
	if dir.length() < 0.0001:
		return
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(dir.normalized()), (a + b) * 0.5), r0, r1, dir.length(), segs, col)


## A smooth chain of rods through the given points (trigger guards, levers).
static func bent(st: SurfaceTool, pts: Array, r: float, col: Color) -> void:
	for i in pts.size() - 1:
		MeshKit.add_limb(st, pts[i], pts[i + 1], r, col, 6)


## Points on an arc in the YZ plane (x fixed): centre, radius, start/end angle (radians, 0 = -Z).
static func arc(c: Vector3, radius: float, a0: float, a1: float, steps: int) -> Array:
	var out: Array = []
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / float(steps))
		out.append(c + Vector3(0, sin(a) * radius, -cos(a) * radius))
	return out


static func screw(st: SurfaceTool, p: Vector3, side: float) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(side * 0.001, 0, 0)), 0.0035, 0.0035, 0.004, 6, BRASS)


# ------------------------------------------------------------------ revolver

## Single-action revolver (without the cylinder, which spins on its own).
static func revolver_body() -> ArrayMesh:
	var st := MeshKit.begin()
	# Barrel: eight-sided, with a muzzle crown and the ejector housing below it.
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.022, -0.135)), 0.0155, 0.0155, 0.2, 8, BLUED)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.022, -0.236)), 0.0165, 0.0165, 0.006, 8, BLUED_DARK)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0.009, 0.004, -0.115)), 0.0075, 0.0075, 0.15, 8, BLUED_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.009, 0.004, -0.19)), Vector3(0.008, 0.008, 0.008), 3, 6, STEEL)
	# Front sight blade.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.043, -0.225)), Vector3(0.004, 0.012, 0.014), BLUED_DARK)
	# Frame: recoil shield, top strap with the rear sight notch, case-hardened sides.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.012, 0.02)), Vector3(0.034, 0.05, 0.07), Color("#6F6A66"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.044, -0.012)), Vector3(0.026, 0.009, 0.075), BLUED)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.022, -0.04)), Vector3(0.032, 0.03, 0.012), BLUED)
	for side: float in [-1.0, 1.0]:
		screw(st, Vector3(side * 0.017, 0.022, 0.02), side)
		screw(st, Vector3(side * 0.017, 0.0, 0.04), side)
	# Hammer with a knurled spur.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.045, 0.05)), Vector3(0.011, 0.03, 0.014), BLUED_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, 0.062, 0.063)), Vector3(0.016, 0.006, 0.02), STEEL)
	# Trigger and a brass trigger guard loop.
	bent(st, [Vector3(0, -0.012, 0.012), Vector3(0, -0.028, 0.016), Vector3(0, -0.036, 0.024)], 0.0028, STEEL)
	bent(st, arc(Vector3(0, -0.017, 0.022), 0.024, -0.35 * PI, -1.1 * PI, 8), 0.0035, BRASS)
	# Plow-handle grip: walnut panels between a brass backstrap and front strap.
	var grip_top := Vector3(0, -0.008, 0.05)
	var grip_bottom := Vector3(0, -0.098, 0.088)
	rod(st, grip_top, grip_bottom, 0.0175, 0.0205, 10, WALNUT)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, -0.4), grip_bottom + Vector3(0, -0.004, 0.004)), Vector3(0.021, 0.012, 0.026), 4, 10, BRASS)
	bent(st, [grip_top + Vector3(0, 0.008, 0.016), grip_bottom + Vector3(0, -0.002, 0.02)], 0.004, BRASS)
	for side: float in [-1.0, 1.0]:
		screw(st, (grip_top + grip_bottom) * 0.5 + Vector3(side * 0.018, 0, 0), side)
	return MeshKit.finish(st)


## The fluted six-shot cylinder, centred, rotating around Z.
static func revolver_drum() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3.ZERO), 0.029, 0.029, 0.054, 12, STEEL)
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		var p := Vector3(cos(a), sin(a), 0) * 0.028
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), p), Vector3(0.006, 0.006, 0.04), BLUED_DARK)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p := Vector3(cos(a), sin(a), 0) * 0.018
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, p + Vector3(0, 0, -0.026)), 0.0065, 0.0065, 0.004, 8, BRASS, true)
	return MeshKit.finish(st)


## The whole revolver in one mesh (for a player's hand and guns on the ground).
static func revolver() -> ArrayMesh:
	var st := MeshKit.begin()
	st.append_from(revolver_body(), 0, Transform3D())
	st.append_from(revolver_drum(), 0, Transform3D(Basis(), Vector3(0, 0.018, -0.005)))
	return st.commit()


# ------------------------------------------------------------------ lever-action rifle

static func lever_rifle() -> ArrayMesh:
	var st := MeshKit.begin()
	# Octagonal barrel and the tube magazine under it, held by a barrel band.
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.026, -0.36)), 0.0135, 0.0135, 0.58, 8, BLUED)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.026, -0.652)), 0.0145, 0.0145, 0.006, 8, BLUED_DARK)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.0, -0.31)), 0.0105, 0.0105, 0.48, 10, BLUED_DARK)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.0, -0.553)), 0.012, 0.012, 0.01, 10, STEEL)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.013, -0.6)), Vector3(0.03, 0.045, 0.012), BLUED_DARK)
	# Sights: front blade, rear ladder.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.046, -0.64)), Vector3(0.004, 0.012, 0.012), BRASS)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.043, -0.24)), Vector3(0.018, 0.01, 0.016), BLUED_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.049, -0.245)), Vector3(0.014, 0.006, 0.004), STEEL)
	# Brass receiver with a side plate, loading gate and screws.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.012, -0.01)), Vector3(0.034, 0.058, 0.13), BRASS)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * 0.0175, 0.014, -0.01)), Vector3(0.002, 0.04, 0.1), BRASS.darkened(0.15))
		screw(st, Vector3(side * 0.018, 0.025, -0.045), side)
		screw(st, Vector3(side * 0.018, 0.025, 0.03), side)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.018, -0.004, -0.04)), Vector3(0.002, 0.016, 0.036), BLUED_DARK)
	# Hammer, trigger, and the loop lever.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, 0.036, 0.068)), Vector3(0.008, 0.022, 0.01), BLUED_DARK)
	bent(st, [Vector3(0, -0.016, 0.01), Vector3(0, -0.03, 0.016), Vector3(0, -0.036, 0.024)], 0.0028, STEEL)
	bent(st, [Vector3(0, -0.02, -0.03), Vector3(0, -0.04, -0.01), Vector3(0, -0.05, 0.03), Vector3(0, -0.045, 0.07),
			Vector3(0, -0.03, 0.085), Vector3(0, -0.016, 0.07)], 0.0045, BLUED)
	bent(st, arc(Vector3(0, -0.05, 0.05), 0.022, 0.15 * PI, 1.15 * PI, 7), 0.0045, BLUED)
	# Walnut forend around the magazine.
	rod(st, Vector3(0, 0.008, -0.08), Vector3(0, 0.008, -0.3), 0.021, 0.019, 10, WALNUT)
	# Wrist and buttstock with a crescent buttplate.
	rod(st, Vector3(0, 0.0, 0.065), Vector3(0, -0.03, 0.16), 0.0165, 0.018, 10, WALNUT)
	var stock_a := Vector3(0, -0.03, 0.16)
	var stock_b := Vector3(0, -0.055, 0.43)
	MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((stock_b - stock_a).normalized()).rotated(Vector3.RIGHT, 0.0), (stock_a + stock_b) * 0.5 + Vector3(0, -0.01, 0)),
			Vector3(0.034, (stock_b - stock_a).length(), 0.065), WALNUT)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.1), stock_b + Vector3(0, -0.012, 0.03)), Vector3(0.036, 0.1, 0.03), WALNUT)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.1), stock_b + Vector3(0, -0.012, 0.047)), Vector3(0.038, 0.104, 0.006), BLUED_DARK)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ coach shotgun

static func coach_shotgun() -> ArrayMesh:
	var st := MeshKit.begin()
	# Side-by-side barrels with a flat rib between them.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(side * 0.0172, 0.022, -0.29)), 0.0172, 0.0168, 0.46, 12, BLUED)
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(side * 0.0172, 0.022, -0.522)), 0.0178, 0.0178, 0.006, 12, BLUED_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.039, -0.29)), Vector3(0.012, 0.006, 0.46), BLUED_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.044, -0.51)), Vector3.ONE * 0.003, 3, 6, BRASS)
	# Receiver with engraved side plates.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.012, 0.0)), Vector3(0.05, 0.052, 0.1), Color("#6F6A66"))
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * 0.0255, 0.012, 0.005)), Vector3(0.002, 0.036, 0.07), STEEL.lightened(0.1))
		for k in 3:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.6 * (k - 1)), Vector3(side * 0.0268, 0.012, -0.015 + k * 0.02)), Vector3(0.001, 0.02, 0.003), BRASS)
	# Twin hammers, double triggers, trigger guard.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.8), Vector3(side * 0.016, 0.04, 0.05)), Vector3(0.007, 0.022, 0.01), BLUED_DARK)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -1.3), Vector3(side * 0.018, 0.049, 0.06)), Vector3(0.01, 0.004, 0.013), STEEL)
	bent(st, [Vector3(0, -0.014, 0.0), Vector3(0, -0.03, 0.004)], 0.0028, STEEL)
	bent(st, [Vector3(0, -0.014, 0.02), Vector3(0, -0.03, 0.026)], 0.0028, STEEL)
	bent(st, arc(Vector3(0, -0.018, 0.016), 0.026, -0.3 * PI, -1.1 * PI, 8), 0.0035, BLUED)
	# Splinter forend, pistol grip, stock and butt plate in dark walnut.
	rod(st, Vector3(0, 0.0, -0.06), Vector3(0, 0.0, -0.22), 0.026, 0.022, 10, WALNUT_DARK)
	rod(st, Vector3(0, -0.002, 0.05), Vector3(0, -0.06, 0.12), 0.019, 0.021, 10, WALNUT_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.066, 0.122)), Vector3(0.021, 0.01, 0.022), 4, 8, BLUED_DARK)
	var a := Vector3(0, -0.01, 0.1)
	var b := Vector3(0, -0.075, 0.33)
	MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((b - a).normalized()), (a + b) * 0.5), Vector3(0.04, (b - a).length(), 0.07), WALNUT_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.12), b + Vector3(0, -0.01, 0.03)), Vector3(0.042, 0.11, 0.03), WALNUT_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.12), b + Vector3(0, -0.01, 0.047)), Vector3(0.044, 0.114, 0.006), Color("#2A1A12"))
	return MeshKit.finish(st)


## Any gun by id, as one mesh.
static func gun(id: StringName) -> ArrayMesh:
	match id:
		&"lever_rifle":
			return lever_rifle()
		&"coach_shotgun":
			return coach_shotgun()
	return revolver()


# ------------------------------------------------------------------ first-person arms

## A gloved hand closed around a grip. `at` is the middle of the fist, `along`
## the direction the fingers wrap around (the grip's axis), `back` points to the
## back of the hand.
static func fist(st: SurfaceTool, at: Vector3, along: Vector3, back: Vector3, team: Color) -> void:
	var up := along.normalized()
	var out := back.normalized()
	var side := up.cross(out).normalized()
	var basis := Basis(side, up, out)
	MeshKit.add_ellipsoid(st, Transform3D(basis, at + out * 0.012), Vector3(0.028, 0.045, 0.022), 5, 10, GLOVE)
	# Four curled fingers wrapping the far side, then the thumb over the top.
	for i in 4:
		var f := at - out * 0.02 + up * (0.027 - i * 0.018) - side * 0.006
		MeshKit.add_ellipsoid(st, Transform3D(basis, f), Vector3(0.022, 0.0095, 0.012), 4, 8, GLOVE_DARK if i % 2 == 0 else GLOVE)
	MeshKit.add_limb(st, at + up * 0.03 + side * 0.016 + out * 0.008, at + up * 0.03 - side * 0.006 - out * 0.016, 0.009, GLOVE, 6)
	# Leather gauntlet cuff with a team-colour stitch.
	var cuff := at - up * 0.05 + out * 0.01
	MeshKit.add_cylinder(st, Transform3D(basis, cuff), 0.03, 0.036, 0.04, 10, GLOVE_DARK)
	MeshKit.add_cylinder(st, Transform3D(basis, cuff - up * 0.018), 0.0362, 0.0362, 0.003, 10, team.darkened(0.25))


## A coat sleeve from the wrist back out of view.
static func sleeve(st: SurfaceTool, wrist: Vector3, elbow: Vector3) -> void:
	rod(st, wrist, elbow, 0.038, 0.058, 12, SLEEVE)
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y((elbow - wrist).normalized()), wrist + (elbow - wrist).normalized() * 0.012),
			0.04, 0.04, 0.02, 12, SLEEVE_DARK)


## Both arms holding gun `id` (first person). Same space as the gun mesh.
static func arms(id: StringName, team: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	match id:
		&"lever_rifle":
			# Right hand round the wrist of the stock, finger in the lever; left hand on the forend.
			fist(st, Vector3(0.004, -0.02, 0.1), Vector3(0, 0.6, -0.8), Vector3(1, 0.2, 0.1), team)
			sleeve(st, Vector3(0.03, -0.065, 0.14), Vector3(0.12, -0.32, 0.5))
			fist(st, Vector3(-0.004, -0.016, -0.2), Vector3(0, 0, -1), Vector3(-0.7, -1, 0), team)
			sleeve(st, Vector3(-0.035, -0.065, -0.16), Vector3(-0.2, -0.3, 0.08))
		&"coach_shotgun":
			fist(st, Vector3(0.004, -0.035, 0.085), Vector3(0, 0.8, -0.6), Vector3(1, 0.2, 0.1), team)
			sleeve(st, Vector3(0.03, -0.08, 0.12), Vector3(0.12, -0.33, 0.48))
			fist(st, Vector3(-0.004, -0.024, -0.15), Vector3(0, 0, -1), Vector3(-0.7, -1, 0), team)
			sleeve(st, Vector3(-0.035, -0.07, -0.11), Vector3(-0.2, -0.3, 0.1))
		_:
			# Revolver: right hand on the grip, left hand cupped underneath.
			fist(st, Vector3(0.003, -0.05, 0.07), Vector3(0, 0.95, -0.35), Vector3(1, 0.1, 0.25), team)
			sleeve(st, Vector3(0.025, -0.1, 0.11), Vector3(0.1, -0.33, 0.45))
			fist(st, Vector3(-0.022, -0.075, 0.07), Vector3(0, 0.6, -0.8), Vector3(-1, -0.3, 0.2), team)
			sleeve(st, Vector3(-0.05, -0.11, 0.1), Vector3(-0.22, -0.34, 0.36))
	return MeshKit.finish(st)


## Empty hands (bucket, vegetables, medicine).
static func item_arm(team: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	fist(st, Vector3(0.0, -0.06, 0.03), Vector3(0, 1, 0), Vector3(1, 0, 0.3), team)
	sleeve(st, Vector3(0.02, -0.11, 0.06), Vector3(0.12, -0.34, 0.4))
	return MeshKit.finish(st)


## What you hold when a hotbar item is selected: the water bucket or a vegetable.
static func held_item(id: StringName) -> ArrayMesh:
	var st := MeshKit.begin()
	var at := Vector3(0.0, -0.06, -0.02)
	match id:
		&"water":
			MeshKit.add_cylinder(st, Transform3D(Basis(), at), 0.07, 0.085, 0.13, 12, Palette.WOOD)
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 0.035, 0)), 0.088, 0.088, 0.015, 12, Palette.METAL)
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 0.055, 0)), 0.075, 0.075, 0.01, 12, Palette.SKY_TOP, false, 0.3)
			MeshKit.add_limb(st, at + Vector3(-0.08, 0.06, 0), at + Vector3(0.0, 0.14, 0), 0.006, Palette.METAL, 5)
			MeshKit.add_limb(st, at + Vector3(0.0, 0.14, 0), at + Vector3(0.08, 0.06, 0), 0.006, Palette.METAL, 5)
		&"corn":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 1.2), at), Vector3(0.03, 0.08, 0.03), 5, 8, Color("#F5D140"))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 1.2), at + Vector3(0.025, 0.0, 0.03)), Vector3(0.012, 0.07, 0.03), 4, 6, Palette.CACTUS)
		&"prickly_pear":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), at), Vector3(0.045, 0.055, 0.04), 5, 8, Color("#D94C8C"))
		&"chili":
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 1.3), at), 0.02, 0.0, 0.12, 8, Color("#E3361F"))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 1.3), at + Vector3(0, -0.01, 0.065)), 0.008, 0.008, 0.03, 5, Palette.CACTUS)
		_:
			for i in 4:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, -0.4 + i * 0.27), at + Vector3(-0.02 + i * 0.013, 0.03, 0)), Vector3(0.012, 0.05, 0.02), 3, 6, Color("#8CC66E"))
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, -0.02, 0)), 0.012, 0.012, 0.04, 5, Palette.BONE.darkened(0.3))
	return MeshKit.finish(st)
