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

## Where the rifle's lever hinges (gun space).
const LEVER_PIVOT := Vector3(0, -0.02, -0.03)
## Where the shotgun's barrels hinge when it breaks open (gun space).
const HINGE := Vector3(0, -0.004, -0.055)
## Where each gun's left (support) hand rests, and where rounds go in.
const LEFT_FIST: Dictionary = {&"revolver": Vector3(-0.022, -0.075, 0.07), &"lever_rifle": Vector3(-0.004, -0.016, -0.2),
	&"coach_shotgun": Vector3(-0.004, -0.024, -0.15)}
const LOAD_POINT: Dictionary = {&"revolver": Vector3(0.022, 0.03, 0.03), &"lever_rifle": Vector3(0.026, -0.004, -0.04),
	&"coach_shotgun": Vector3(0.0, 0.03, -0.045)}


static func lever_rifle() -> ArrayMesh:
	var st := MeshKit.begin()
	st.append_from(rifle_body(), 0, Transform3D())
	st.append_from(rifle_lever(), 0, Transform3D(Basis(), LEVER_PIVOT))
	return st.commit()


## The lever loop on its own, in lever-pivot space (it swings down to cycle).
static func rifle_lever() -> ArrayMesh:
	var st := MeshKit.begin()
	var pts: Array = [Vector3(0, -0.02, -0.03), Vector3(0, -0.04, -0.01), Vector3(0, -0.05, 0.03), Vector3(0, -0.045, 0.07),
			Vector3(0, -0.03, 0.085), Vector3(0, -0.016, 0.07)]
	var local: Array = []
	for p: Vector3 in pts:
		local.append(p - LEVER_PIVOT)
	bent(st, local, 0.0045, BLUED)
	var loop: Array = []
	for p: Vector3 in arc(Vector3(0, -0.05, 0.05), 0.022, 0.15 * PI, 1.15 * PI, 7):
		loop.append(p - LEVER_PIVOT)
	bent(st, loop, 0.0045, BLUED)
	return MeshKit.finish(st)


static func rifle_body() -> ArrayMesh:
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
	st.append_from(shotgun_action(), 0, Transform3D())
	st.append_from(shotgun_barrels(), 0, Transform3D(Basis(), HINGE))
	return st.commit()


## Barrels, rib and forend, in hinge space (they tip down when the gun breaks open).
static func shotgun_barrels() -> ArrayMesh:
	var st := MeshKit.begin()
	var o := -HINGE
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, o + Vector3(side * 0.0172, 0.022, -0.29)), 0.0172, 0.0168, 0.46, 12, BLUED)
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, o + Vector3(side * 0.0172, 0.022, -0.522)), 0.0178, 0.0178, 0.006, 12, BLUED_DARK)
		# Chamber mouths at the breech end.
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, o + Vector3(side * 0.0172, 0.022, -0.059)), 0.0125, 0.0125, 0.003, 10, Color("#1A1A1E"))
	MeshKit.add_box(st, Transform3D(Basis(), o + Vector3(0, 0.039, -0.29)), Vector3(0.012, 0.006, 0.46), BLUED_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), o + Vector3(0, 0.044, -0.51)), Vector3.ONE * 0.003, 3, 6, BRASS)
	rod(st, o + Vector3(0, 0.0, -0.065), o + Vector3(0, 0.0, -0.22), 0.026, 0.022, 10, WALNUT_DARK)
	return MeshKit.finish(st)


static func shotgun_action() -> ArrayMesh:
	var st := MeshKit.begin()
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
	# Pistol grip, stock and butt plate in dark walnut.
	rod(st, Vector3(0, -0.002, 0.05), Vector3(0, -0.06, 0.12), 0.019, 0.021, 10, WALNUT_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.066, 0.122)), Vector3(0.021, 0.01, 0.022), 4, 8, BLUED_DARK)
	var a := Vector3(0, -0.01, 0.1)
	var b := Vector3(0, -0.075, 0.33)
	MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((b - a).normalized()), (a + b) * 0.5), Vector3(0.04, (b - a).length(), 0.07), WALNUT_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.12), b + Vector3(0, -0.01, 0.03)), Vector3(0.042, 0.11, 0.03), WALNUT_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.12), b + Vector3(0, -0.01, 0.047)), Vector3(0.044, 0.114, 0.006), Color("#2A1A12"))
	return MeshKit.finish(st)


## A rifle or revolver cartridge (brass case, lead nose), pointing -Z.
static func cartridge() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.0)), 0.0065, 0.0065, 0.03, 8, BRASS)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, -0.02)), 0.006, 0.003, 0.012, 8, Color("#8A8A90"))
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.016)), 0.0075, 0.0075, 0.003, 8, BRASS.darkened(0.15))
	return MeshKit.finish(st)


## A red paper shotgun shell with a brass head, pointing -Z.
static func shell() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, -0.012)), 0.0115, 0.0115, 0.05, 10, Color("#B8352A"))
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.018)), 0.0125, 0.0125, 0.014, 10, BRASS)
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

## A dummy's mitten hand closed around a grip. `at` is the middle of the fist,
## `along` the direction the fingers wrap around (the grip's axis), `back` points
## to the back of the hand.
static func fist(st: SurfaceTool, at: Vector3, along: Vector3, back: Vector3, paint: Color) -> void:
	var up := along.normalized()
	var out := back.normalized()
	var side := up.cross(out).normalized()
	var basis := Basis(side, up, out)
	MeshKit.add_ellipsoid(st, Transform3D(basis, at + out * 0.012), Vector3(0.028, 0.045, 0.022), 5, 10, paint)
	# Mitten fingers wrapping the far side, a thumb over the top.
	MeshKit.add_ellipsoid(st, Transform3D(basis, at - out * 0.016), Vector3(0.024, 0.042, 0.016), 5, 10, paint.darkened(0.08))
	MeshKit.add_limb(st, at + up * 0.03 + side * 0.016 + out * 0.008, at + up * 0.03 - side * 0.006 - out * 0.016, 0.009, paint, 6)
	# Black rubber wrist joint.
	MeshKit.add_ellipsoid(st, Transform3D(basis, at - up * 0.05 + out * 0.008), Vector3(0.026, 0.02, 0.026), 4, 10, Color("#26262C"))


## The forearm from the wrist back out of view: a coat sleeve with the duster,
## otherwise the bare painted dummy arm.
static func sleeve(st: SurfaceTool, wrist: Vector3, elbow: Vector3, look: Dictionary) -> void:
	var dir := (elbow - wrist).normalized()
	if str(look.get("outfit")) == "duster":
		rod(st, wrist + dir * 0.01, elbow, 0.038, 0.058, 12, SLEEVE)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(dir), wrist + dir * 0.02), 0.04, 0.04, 0.02, 12, SLEEVE_DARK)
	else:
		rod(st, wrist + dir * 0.01, elbow, 0.03, 0.044, 12, DummyLook.paint(look))
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(dir), wrist + dir * 0.17), 0.04, 0.04, 0.012, 12, Color("#26262C"))


## Both arms holding gun `id` (first person). Same space as the gun mesh.
static func arms(id: StringName, _team: Color, look: Dictionary = {}) -> ArrayMesh:
	var st := MeshKit.begin()
	st.append_from(arm_right(id, look), 0, Transform3D())
	st.append_from(arm_left(id, look), 0, Transform3D())
	return st.commit()


## The trigger hand and its forearm (gun space).
static func arm_right(id: StringName, look: Dictionary = {}) -> ArrayMesh:
	look = DummyLook.clean(look)
	var paint := DummyLook.paint(look)
	var st := MeshKit.begin()
	match id:
		&"lever_rifle":
			fist(st, Vector3(0.004, -0.02, 0.1), Vector3(0, 0.6, -0.8), Vector3(1, 0.2, 0.1), paint)
			sleeve(st, Vector3(0.03, -0.065, 0.14), Vector3(0.12, -0.32, 0.5), look)
		&"coach_shotgun":
			fist(st, Vector3(0.004, -0.035, 0.085), Vector3(0, 0.8, -0.6), Vector3(1, 0.2, 0.1), paint)
			sleeve(st, Vector3(0.03, -0.08, 0.12), Vector3(0.12, -0.33, 0.48), look)
		_:
			fist(st, Vector3(0.003, -0.05, 0.07), Vector3(0, 0.95, -0.35), Vector3(1, 0.1, 0.25), paint)
			sleeve(st, Vector3(0.025, -0.1, 0.11), Vector3(0.1, -0.33, 0.45), look)
	return MeshKit.finish(st)


## The support hand and forearm. With `local`, it is built around its own fist
## (origin = LEFT_FIST[id]) so a node can move it on its own during reloads.
static func arm_left(id: StringName, look: Dictionary = {}, local: bool = false) -> ArrayMesh:
	look = DummyLook.clean(look)
	var paint := DummyLook.paint(look)
	var o: Vector3 = Vector3.ZERO if not local else -(LEFT_FIST[id] as Vector3)
	var st := MeshKit.begin()
	match id:
		&"lever_rifle":
			fist(st, o + Vector3(-0.004, -0.016, -0.2), Vector3(0, 0, -1), Vector3(-0.7, -1, 0), paint)
			sleeve(st, o + Vector3(-0.035, -0.065, -0.16), o + Vector3(-0.2, -0.3, 0.08), look)
		&"coach_shotgun":
			fist(st, o + Vector3(-0.004, -0.024, -0.15), Vector3(0, 0, -1), Vector3(-0.7, -1, 0), paint)
			sleeve(st, o + Vector3(-0.035, -0.07, -0.11), o + Vector3(-0.2, -0.3, 0.1), look)
		_:
			fist(st, o + Vector3(-0.022, -0.075, 0.07), Vector3(0, 0.6, -0.8), Vector3(-1, -0.3, 0.2), paint)
			sleeve(st, o + Vector3(-0.05, -0.11, 0.1), o + Vector3(-0.22, -0.34, 0.36), look)
	return MeshKit.finish(st)


## Empty hand (bucket, vegetables, medicine).
static func item_arm(_team: Color, look: Dictionary = {}) -> ArrayMesh:
	look = DummyLook.clean(look)
	var st := MeshKit.begin()
	fist(st, Vector3(0.0, -0.06, 0.03), Vector3(0, 1, 0), Vector3(1, 0, 0.3), DummyLook.paint(look))
	sleeve(st, Vector3(0.02, -0.11, 0.06), Vector3(0.12, -0.34, 0.4), look)
	return MeshKit.finish(st)


## What you hold when a hotbar item is selected: the water bucket, a vegetable,
## or a bundle of sage (medicine).
static func held_item(id: StringName) -> ArrayMesh:
	var st := MeshKit.begin()
	var at := Vector3(0.0, -0.06, -0.02)
	match id:
		&"water":
			# Wooden bucket with iron hoops, sloshing water and a rope handle.
			MeshKit.add_cylinder(st, Transform3D(Basis(), at), 0.07, 0.085, 0.13, 14, Palette.WOOD)
			for y: float in [-0.04, 0.04]:
				MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, y, 0)), 0.081 - y * 0.12, 0.081 - y * 0.12, 0.012, 14, BLUED_DARK)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 0.06), at + Vector3(0, 0.05, 0)), 0.078, 0.078, 0.008, 14, Palette.SKY_TOP, false, 0.35)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0.03, 0.056, 0.02)), Vector3(0.015, 0.003, 0.012), 3, 6, Color(1, 1, 1), 0.0, null, 0.5)
			var prev := at + Vector3(-0.085, 0.06, 0)
			for k in 8:
				var a := PI * float(k + 1) / 8.0
				var p := at + Vector3(-cos(a) * 0.085, 0.06 + sin(a) * 0.09, 0)
				MeshKit.add_limb(st, prev, p, 0.005, Color("#B8955A"), 4)
				prev = p
		&"corn":
			var b := Basis(Vector3.RIGHT, 1.2)
			MeshKit.add_ellipsoid(st, Transform3D(b, at), Vector3(0.032, 0.085, 0.032), 6, 10, CropBuilder.CORN)
			for k in 6:
				MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0, -0.06 + k * 0.024, 0.0)), Vector3(0.034, 0.006, 0.034), 3, 10, CropBuilder.CORN.darkened(0.12))
			for s: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.BACK, s * 0.35), at + b * Vector3(s * 0.025, -0.02, 0.0)), Vector3(0.014, 0.08, 0.03), 4, 6, CropBuilder.HUSK)
		&"prickly_pear":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), at), Vector3(0.045, 0.058, 0.042), 6, 10, CropBuilder.PEAR)
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 0.058, 0)), 0.018, 0.012, 0.012, 8, CropBuilder.PEAR.darkened(0.3))
			for k in 8:
				var a := TAU * k / 8.0
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(cos(a) * 0.04, -0.01 + (k % 3) * 0.02, sin(a) * 0.035)), Vector3.ONE * 0.004, 2, 4, CropBuilder.SPINE)
		&"chili":
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 1.3), at), 0.022, 0.0, 0.13, 10, CropBuilder.CHILI, true, 0.1)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0.005, 0.012, -0.02)), Vector3(0.006, 0.003, 0.02), 3, 6, Color(1, 1, 1), 0.0, null, 0.4)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 1.3), at + Vector3(0, -0.012, 0.07)), 0.026, 0.02, 0.012, 8, CropBuilder.CHILI_GREEN)
			MeshKit.add_limb(st, at + Vector3(0, -0.015, 0.075), at + Vector3(0.01, 0.0, 0.1), 0.005, CropBuilder.CHILI_GREEN, 4)
		_:
			# A bundle of sage tied with twine: medicine.
			for k in 7:
				var a := float(k) * 0.9
				var tip := at + Vector3(sin(a) * 0.025, 0.08, cos(a) * 0.02)
				MeshKit.add_limb(st, at + Vector3(0, -0.04, 0), tip, 0.004, CropBuilder.SAGE_DARK.darkened(0.2), 3)
				for j in 3:
					var p := (at + Vector3(0, -0.04, 0)).lerp(tip, 0.45 + j * 0.2)
					MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, sin(a) * 0.5), p), Vector3(0.012, 0.022, 0.006), 3, 6, CropBuilder.SAGE if j % 2 else CropBuilder.SAGE_DARK)
			MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, -0.02, 0)), 0.016, 0.016, 0.02, 8, Color("#C8A878"))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, 0.085, 0)), Vector3.ONE * 0.012, 3, 6, CropBuilder.SAGE_FLOWER)
	return MeshKit.finish(st)
