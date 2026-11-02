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

## A smoothly lofted piece of woodwork (gunstocks, forends) through stations of
## [centre, half height, half width]. Rounded-square cross sections, smooth
## normals, both ends capped. Grain is suggested by a slightly darker belly.
static func loft(st: SurfaceTool, stations: Array, col: Color, segs: int = 16) -> void:
	var rings: Array = []
	var norms: Array = []
	var n := stations.size()
	for i in n:
		var c: Vector3 = stations[i][0]
		var hh: float = stations[i][1]
		var hw: float = stations[i][2]
		var prev: Vector3 = stations[maxi(i - 1, 0)][0]
		var next: Vector3 = stations[mini(i + 1, n - 1)][0]
		var tan := (next - prev).normalized()
		var side := tan.cross(Vector3.UP).normalized()
		if side.length() < 0.5:
			side = Vector3.RIGHT
		var up := side.cross(tan).normalized()
		var ring: Array[Vector3] = []
		var nring: Array[Vector3] = []
		for s in segs:
			var a := TAU * float(s) / segs
			var ca := cos(a)
			var sa := sin(a)
			# Superellipse: squarer than an oval, like carved walnut.
			var x := signf(ca) * pow(absf(ca), 0.7)
			var y := signf(sa) * pow(absf(sa), 0.7)
			ring.append(c + side * x * hw + up * y * hh)
			nring.append((side * ca / maxf(hw, 0.001) + up * sa / maxf(hh, 0.001)).normalized())
		rings.append(ring)
		norms.append(nring)
	var belly := col.darkened(0.08)
	for i in n - 1:
		for s in segs:
			var s1 := (s + 1) % segs
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s1]
			var c2: Vector3 = rings[i + 1][s1]
			var d: Vector3 = rings[i + 1][s]
			var cc := MeshKit.vcol(belly if sin(TAU * float(s) / segs) < -0.3 else col)
			var na: Vector3 = norms[i][s]
			var nb: Vector3 = norms[i][s1]
			var nc: Vector3 = norms[i + 1][s1]
			var nd: Vector3 = norms[i + 1][s]
			MeshKit.tri(st, a, b, c2, na, nb, nc, cc, (na + nb + nc).normalized())
			MeshKit.tri(st, a, c2, d, na, nc, nd, cc, (na + nc + nd).normalized())
	for e in [0, n - 1]:
		var c: Vector3 = stations[e][0]
		var other: Vector3 = stations[1 if e == 0 else n - 2][0]
		var out := (c - other).normalized()
		var cc := MeshKit.vcol(col.darkened(0.12))
		for s in segs:
			MeshKit.tri(st, c, rings[e][s], rings[e][(s + 1) % segs], out, out, out, cc, out)


## A buttplate shaped to the last station of a loft (a thin shell just behind it).
static func buttplate(st: SurfaceTool, stations: Array, col: Color) -> void:
	var last: Array = stations[stations.size() - 1]
	var prev: Array = stations[stations.size() - 2]
	var dir := ((last[0] as Vector3) - (prev[0] as Vector3)).normalized()
	loft(st, [[(last[0] as Vector3) - dir * 0.001, float(last[1]) * 1.02, float(last[2]) * 1.04],
			[(last[0] as Vector3) + dir * 0.006, float(last[1]) * 1.02, float(last[2]) * 1.04]], col, 16)


## Engraved scrollwork on a flat side: a pair of curling vines around `c`,
## on the plane facing `n`, `size` across.
static func scroll(st: SurfaceTool, c: Vector3, n: Vector3, size: float, col: Color) -> void:
	var nn := n.normalized()
	var u := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right := u.cross(nn).normalized()
	var up := nn.cross(right).normalized()
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		var radii: Array = []
		for k in 14:
			var f := float(k) / 13.0
			var ang := f * TAU * 1.15 * side
			var r := size * 0.5 * (1.0 - f * 0.8)
			var centre := c + right * side * size * 0.22
			pts.append(centre + (right * cos(ang) + up * sin(ang)) * r + nn * 0.0006)
			radii.append(size * 0.022)
		MeshKit.tube(st, pts, radii, 4, col)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + nn * 0.0008), Vector3.ONE * size * 0.06, 3, 6, col)


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
		scroll(st, Vector3(side * 0.0172, 0.008, 0.022), Vector3(side, 0, 0), 0.034, Color("#C8CED6"))
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
## Measured on the Meshy guns (tools/rig: gridded side views): the forend each
## support hand holds, and the wrist or grip the trigger hand wraps [centre, grip axis].
const LEFT_FIST: Dictionary = {&"revolver": Vector3(-0.022, -0.075, 0.07), &"lever_rifle": Vector3(-0.004, -0.022, -0.194),
	&"coach_shotgun": Vector3(-0.004, -0.03, -0.25), &"blunderbuss": Vector3(-0.004, -0.068, -0.215),
	&"crank_gatling": Vector3(-0.108, -0.076, -0.203)}
const RIGHT_GRIP: Dictionary = {&"lever_rifle": [Vector3(0.004, -0.046, 0.114), Vector3(0, 0.55, -0.83)],
	&"coach_shotgun": [Vector3(0.004, -0.075, 0.112), Vector3(0, 0.75, -0.66)],
	&"blunderbuss": [Vector3(0.004, -0.064, 0.12), Vector3(0, 0.6, -0.8)],
	&"crank_gatling": [Vector3(0.004, -0.082, -0.078), Vector3(0, 0.86, -0.52)]}
const LOAD_POINT: Dictionary = {&"revolver": Vector3(0.022, 0.03, 0.03), &"lever_rifle": Vector3(0.026, -0.004, -0.04),
	&"coach_shotgun": Vector3(0.0, 0.02, -0.09), &"blunderbuss": Vector3(0.0, 0.05, -0.44),
	&"crank_gatling": Vector3(0.0, 0.1, 0.03)}
## Crank Gatling: barrel spin axis origin and the crank's pivot (gun space).
const GATLING_AXIS := Vector3(0, 0.0, -0.05)
const GATLING_CRANK := Vector3(0.06, 0.0, 0.04)


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
	# Walnut forend around the magazine, with a steel cap.
	loft(st, [[Vector3(0, 0.006, -0.075), 0.019, 0.018], [Vector3(0, 0.004, -0.12), 0.022, 0.02], [Vector3(0, 0.004, -0.26), 0.021, 0.019],
			[Vector3(0, 0.006, -0.3), 0.017, 0.016]], WALNUT, 14)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.008, -0.304)), 0.018, 0.018, 0.008, 12, BLUED_DARK)
	# Wrist, comb and buttstock in one carved piece, a crescent steel buttplate.
	var stock := [[Vector3(0, 0.004, 0.06), 0.022, 0.016], [Vector3(0, -0.006, 0.11), 0.017, 0.0155], [Vector3(0, -0.018, 0.17), 0.021, 0.016],
		[Vector3(0, -0.03, 0.26), 0.036, 0.018], [Vector3(0, -0.04, 0.36), 0.048, 0.019], [Vector3(0, -0.048, 0.43), 0.055, 0.0195]]
	loft(st, stock, WALNUT)
	buttplate(st, stock, BLUED_DARK)
	# Checkering on the wrist.
	for k in 5:
		for side: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.5 if k % 2 == 0 else -0.5), Vector3(side * 0.0158, -0.008, 0.095 + k * 0.012)), Vector3(0.001, 0.022, 0.0016), WALNUT_DARK)
	# Engraved receiver sides.
	for side: float in [-1.0, 1.0]:
		scroll(st, Vector3(side * 0.0187, 0.016, -0.005), Vector3(side, 0, 0), 0.04, BRASS.darkened(0.3))
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
	loft(st, [[o + Vector3(0, 0.002, -0.062), 0.022, 0.026], [o + Vector3(0, -0.002, -0.1), 0.026, 0.03], [o + Vector3(0, 0.0, -0.2), 0.024, 0.028],
			[o + Vector3(0, 0.004, -0.225), 0.018, 0.024]], WALNUT_DARK, 14)
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
	var stock := [[Vector3(0, 0.01, 0.045), 0.026, 0.022], [Vector3(0, -0.002, 0.1), 0.021, 0.019], [Vector3(0, -0.02, 0.17), 0.032, 0.02],
		[Vector3(0, -0.04, 0.25), 0.046, 0.021], [Vector3(0, -0.058, 0.33), 0.056, 0.022], [Vector3(0, -0.064, 0.36), 0.058, 0.0222]]
	loft(st, stock, WALNUT_DARK)
	buttplate(st, stock, Color("#2A1A12"))
	for side: float in [-1.0, 1.0]:
		scroll(st, Vector3(side * 0.0268, 0.012, 0.005), Vector3(side, 0, 0), 0.034, Color("#E8C870"))
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
		&"blunderbuss":
			return blunderbuss()
		&"crank_gatling":
			var st := MeshKit.begin()
			st.append_from(gatling_body(), 0, Transform3D())
			st.append_from(gatling_barrels(), 0, Transform3D(Basis(), GATLING_AXIS))
			st.append_from(gatling_crank(), 0, Transform3D(Basis(), GATLING_CRANK))
			return st.commit()
	return revolver()


# ------------------------------------------------------------------ first-person arms

## A dummy's hand closed around a grip. `at` is the middle of the fist,
## `along` the direction the fingers wrap around (the grip's axis), `back` points
## to the back of the hand. Four jointed fingers curl round the grip, the thumb
## locks over them, with black rubber knuckles and a painted calibration dot.
static func fist(st: SurfaceTool, at: Vector3, along: Vector3, back: Vector3, paint: Color, right: bool = false) -> void:
	var up := along.normalized()
	var out := (back - up * back.dot(up)).normalized()
	# A right hand is the mirror image of a left: its fingers curl round the other way.
	var side := up.cross(out).normalized() * (-1.0 if right else 1.0)
	var basis := Basis(side, up, out)
	var joint := Color("#26262C")
	# Back of the hand: a moulded shell with a target dot.
	MeshKit.add_ellipsoid(st, Transform3D(basis, at + out * 0.016 + side * 0.004), Vector3(0.03, 0.046, 0.017), 6, 14, paint)
	MeshKit.add_ellipsoid(st, Transform3D(basis, at + out * 0.031 + side * 0.004), Vector3(0.009, 0.009, 0.003), 3, 8, Color("#F2C230"))
	MeshKit.add_ellipsoid(st, Transform3D(basis, at + out * 0.0325 + side * 0.004), Vector3(0.0045, 0.0045, 0.002), 3, 8, Color("#1E1E22"))
	# Grip centre the fingers wrap round.
	var g := at - out * 0.008
	for f in 4:
		var h := -0.03 + f * 0.02
		var r := 0.0092 if f < 3 else 0.0078
		var pts: Array = []
		var radii: Array = []
		for k in 6:
			var a := lerpf(0.25, PI - 0.15, float(k) / 5.0)
			var rad := lerpf(0.031, 0.022, float(k) / 5.0)
			pts.append(g + up * h + (out * cos(a) - side * sin(a)) * rad)
			radii.append(r * lerpf(1.0, 0.82, float(k) / 5.0))
		MeshKit.tube(st, pts, radii, 7, paint.darkened(0.04 * (f % 2)))
		# Rubber knuckle and middle joint.
		MeshKit.add_ellipsoid(st, Transform3D(basis, pts[0] + out * 0.002), Vector3.ONE * r * 0.92, 4, 8, joint)
	# Thumb: from the heel of the palm, over the curled fingers.
	var t0 := g + up * 0.036 + side * 0.018 + out * 0.004
	MeshKit.tube(st, [t0, t0 + up * 0.006 - side * 0.012 - out * 0.012, t0 + up * 0.004 - side * 0.03 - out * 0.022],
			[0.011, 0.0105, 0.009], 7, paint)
	MeshKit.add_ellipsoid(st, Transform3D(basis, t0), Vector3.ONE * 0.0115, 4, 8, joint)
	# Ribbed rubber wrist.
	for k in 3:
		MeshKit.add_ellipsoid(st, Transform3D(basis, at - up * (0.05 + k * 0.011) + out * 0.008), Vector3(0.027, 0.007, 0.025), 4, 12, joint)


## The forearm from the wrist back out of view: a coat sleeve with the duster
## (cuff, buttons and a fold), a pressed shirt for the lawman, otherwise the
## painted dummy arm with a calibration band and a bolted elbow.
static func sleeve(st: SurfaceTool, wrist: Vector3, elbow: Vector3, look: Dictionary) -> void:
	var dir := (elbow - wrist).normalized()
	var b := MeshKit.basis_from_y(dir)
	var outfit := str(look.get("outfit"))
	if outfit == "duster":
		rod(st, wrist + dir * 0.01, elbow, 0.04, 0.06, 16, SLEEVE)
		MeshKit.add_cylinder(st, Transform3D(b, wrist + dir * 0.025), 0.044, 0.046, 0.04, 16, SLEEVE_DARK)
		for k in 2:
			var bp := wrist + dir * (0.02 + k * 0.022) + b.z * 0.045
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(b.z), bp), 0.006, 0.006, 0.004, 8, Color("#2A1A12"))
		MeshKit.add_cylinder(st, Transform3D(b, wrist + dir * 0.16), 0.052, 0.054, 0.012, 16, SLEEVE_DARK)
	elif outfit == "lawman":
		rod(st, wrist + dir * 0.01, elbow, 0.034, 0.05, 16, Color("#E8E0CC"))
		MeshKit.add_cylinder(st, Transform3D(b, wrist + dir * 0.022), 0.038, 0.038, 0.03, 16, Color("#C8BCA0"))
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(b.z), wrist + dir * 0.022 + b.z * 0.039), 0.005, 0.005, 0.004, 8, BRASS)
	else:
		var paint := DummyLook.paint(look)
		rod(st, wrist + dir * 0.01, elbow, 0.03, 0.046, 16, paint)
		MeshKit.add_cylinder(st, Transform3D(b, wrist + dir * 0.12), 0.039, 0.04, 0.012, 16, Color("#1E1E22"))
		MeshKit.add_cylinder(st, Transform3D(b, wrist + dir * 0.14), 0.041, 0.042, 0.008, 16, Color("#F2C230"))
		MeshKit.add_ellipsoid(st, Transform3D(b, elbow), Vector3.ONE * 0.05, 5, 12, Color("#26262C"))


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
		&"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling":
			var g: Vector3 = RIGHT_GRIP[id][0]
			fist(st, g, RIGHT_GRIP[id][1], Vector3(1, 0.2, 0.1), paint, true)
			sleeve(st, g + Vector3(0.026, -0.045, 0.04), g + Vector3(0.116, -0.3, 0.4), look)
		_:
			fist(st, Vector3(0.003, -0.05, 0.07), Vector3(0, 0.95, -0.35), Vector3(1, 0.1, 0.25), paint, true)
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
		&"lever_rifle", &"coach_shotgun", &"blunderbuss":
			# Cupping the forend from below.
			var lf: Vector3 = LEFT_FIST[id]
			fist(st, o + lf, Vector3(0, 0, -1), Vector3(-0.7, -1, 0), paint)
			sleeve(st, o + lf + Vector3(-0.031, -0.049, 0.04), o + lf + Vector3(-0.196, -0.284, 0.28), look)
		&"crank_gatling":
			# Left hand on the crank handle, turning it.
			var lf: Vector3 = LEFT_FIST[id]
			fist(st, o + lf, Vector3(1, 0, 0), Vector3(0, -0.2, 1), paint)
			sleeve(st, o + lf + Vector3(-0.03, -0.045, 0.04), o + lf + Vector3(-0.17, -0.3, 0.3), look)
		_:
			fist(st, o + Vector3(-0.022, -0.075, 0.07), Vector3(0, 0.6, -0.8), Vector3(-1, -0.3, 0.2), paint)
			sleeve(st, o + Vector3(-0.05, -0.11, 0.1), o + Vector3(-0.22, -0.34, 0.36), look)
	return MeshKit.finish(st)


## Empty hand (bucket, vegetables, medicine).
static func item_arm(_team: Color, look: Dictionary = {}) -> ArrayMesh:
	look = DummyLook.clean(look)
	var st := MeshKit.begin()
	fist(st, Vector3(0.0, -0.06, 0.03), Vector3(0, 1, 0), Vector3(1, 0, 0.3), DummyLook.paint(look), true)
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
		&"lighter":
			pass # the Zippo is its own animated model (Lighter)
		&"grapple":
			# A stubby brass launcher: barrel pointing forward (-Z), a walnut grip,
			# a rope drum on the side, and the hook's prongs poking out the muzzle.
			var g := at + Vector3(0, 0.04, -0.05)
			var fwd := Basis(Vector3.RIGHT, -PI * 0.5)
			MeshKit.add_cylinder(st, Transform3D(fwd, g + Vector3(0, 0, -0.06)), 0.03, 0.034, 0.2, 12, BRASS)
			for z: float in [-0.15, -0.02, 0.03]:
				MeshKit.add_cylinder(st, Transform3D(fwd, g + Vector3(0, 0, z)), 0.037, 0.037, 0.012, 12, BLUED_DARK)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.3), g + Vector3(0, -0.06, 0.03)), Vector3(0.03, 0.09, 0.04), WALNUT)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), g + Vector3(0.045, 0.0, 0.0)), 0.028, 0.028, 0.025, 12, WALNUT_DARK)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), g + Vector3(0.046, 0.0, 0.0)), 0.024, 0.024, 0.03, 12, Color("#B8955A"))
			for k in 3:
				var a := TAU * k / 3.0
				var tip := g + Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.2)
				MeshKit.add_limb(st, g + Vector3(0, 0, -0.16), tip, 0.006, STEEL, 4)
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


## The grappling hook head where it bites in (along +Y = back toward the player).
static func grapple_hook() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.03, 0.03, 0.24, 8, STEEL)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3.ONE * 0.04, 3, 8, BRASS)
	for k in 3:
		var a := TAU * k / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		MeshKit.add_limb(st, Vector3.ZERO, out * 0.14 + Vector3(0, 0.05, 0), 0.02, STEEL, 5)
		MeshKit.add_limb(st, out * 0.14 + Vector3(0, 0.05, 0), out * 0.12 + Vector3(0, 0.15, 0), 0.016, STEEL.lightened(0.1), 5)
	return MeshKit.finish(st)


## The Zippo, built in parts so the lid can swing (origin at the base, Y up).
const ZIPPO_HINGE := Vector3(0.0, 0.04, 0.0065)
const ZIPPO_WICK := Vector3(0.0, 0.05, -0.001)


static func zippo_body() -> ArrayMesh:
	var st := MeshKit.begin()
	var chrome := STEEL.lightened(0.25)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.036, 0.04, 0.013), chrome)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, -0.0068)), Vector3(0.026, 0.026, 0.001), BRASS)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.02, -0.0075)), Vector3(0.006, 0.006, 0.001), 3, 8, Palette.TEAM_WEST)
	# Chimney (windscreen with holes), flint wheel and cam.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.047, 0)), Vector3(0.024, 0.014, 0.011), STEEL)
	for x: float in [-0.007, 0.0, 0.007]:
		for y: float in [0.044, 0.05]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, y, -0.0058)), Vector3(0.003, 0.003, 0.001), BLUED_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.055, 0.004)), 0.004, 0.004, 0.008, 10, BLUED)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0545, -0.001)), Vector3(0.004, 0.004, 0.004), Palette.BONE)
	return MeshKit.finish(st)


## Lid, relative to its hinge at the back top edge of the body.
static func zippo_lid() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.008, -0.0065)), Vector3(0.0365, 0.016, 0.0135), STEEL.lightened(0.25))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.0005, -0.0065)), Vector3(0.037, 0.001, 0.0137), STEEL)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, 0)), 0.0015, 0.0015, 0.012, 6, STEEL)
	return MeshKit.finish(st)


## Flame: a glowing orange teardrop with a yellow core and a blue base.
static func zippo_flame() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(0.007, 0.016, 0.007), 5, 10, Color("#FF8A2A"), 0.0, null, 0.3)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.009, 0)), Vector3(0.004, 0.009, 0.004), 4, 8, Color("#FFE27A"), 0.0, null, 0.2)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.002, 0)), Vector3(0.004, 0.003, 0.004), 3, 8, Color("#5AA8FF"), 0.0, null, 0.4)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ blunderbuss

## Blunderbuss: a short brass barrel that flares into a wide bell, a flintlock,
## and a stubby walnut stock. Muzzle along -Z.
static func blunderbuss() -> ArrayMesh:
	var st := MeshKit.begin()
	# Barrel, widening toward the bell, with brass bands.
	rod(st, Vector3(0, 0.012, -0.03), Vector3(0, 0.012, -0.36), 0.016, 0.021, 12, BRASS.darkened(0.08))
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.012, -0.4)), 0.042, 0.022, 0.08, 14, BRASS)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.012, -0.441)), 0.045, 0.045, 0.006, 14, BRASS.lightened(0.15))
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.012, -0.443)), 0.034, 0.034, 0.004, 14, Color("#1A1410"))
	for z: float in [-0.08, -0.2, -0.32]:
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0.012, z)), 0.022 + (-z) * 0.012, 0.022 + (-z) * 0.012, 0.008, 12, BLUED_DARK)
	# Walnut forestock under the barrel, ramrod beneath.
	loft(st, [[Vector3(0, -0.006, -0.02), 0.016, 0.017], [Vector3(0, -0.01, -0.06), 0.017, 0.018], [Vector3(0, -0.01, -0.26), 0.014, 0.017],
			[Vector3(0, -0.006, -0.285), 0.01, 0.014]], WALNUT, 14)
	rod(st, Vector3(0, -0.028, -0.02), Vector3(0, -0.028, -0.3), 0.0035, 0.0035, 6, WALNUT_DARK)
	# Flintlock: lock plate, cock with flint, frizzen and pan.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.019, 0.006, 0.02)), Vector3(0.006, 0.026, 0.07), STEEL)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0.022, 0.032, 0.045)), Vector3(0.006, 0.028, 0.01), BLUED_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.022, 0.042, 0.036)), Vector3(0.008, 0.006, 0.01), Color("#6A6A70"))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0.022, 0.03, 0.008)), Vector3(0.006, 0.026, 0.006), STEEL.lightened(0.1))
	bent(st, [Vector3(0, -0.014, 0.03), Vector3(0, -0.03, 0.036)], 0.0028, STEEL)
	bent(st, arc(Vector3(0, -0.018, 0.045), 0.024, -0.3 * PI, -1.1 * PI, 8), 0.0035, BRASS)
	# Stubby stock with a brass butt plate.
	var stock := [[Vector3(0, 0.004, 0.0), 0.02, 0.02], [Vector3(0, -0.004, 0.06), 0.02, 0.018], [Vector3(0, -0.018, 0.12), 0.03, 0.019],
		[Vector3(0, -0.04, 0.2), 0.046, 0.021], [Vector3(0, -0.058, 0.28), 0.058, 0.023], [Vector3(0, -0.062, 0.3), 0.06, 0.0232]]
	loft(st, stock, WALNUT)
	buttplate(st, stock, BRASS)
	scroll(st, Vector3(0.0225, 0.006, 0.02), Vector3(1, 0, 0), 0.03, BRASS)
	return MeshKit.finish(st)


## A cow-horn powder flask with a brass spout (what the hand pours in on a reload).
static func powder_horn() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.01)), 0.016, 0.006, 0.07, 10, Color("#E8D9B8"))
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, -0.03)), 0.005, 0.004, 0.02, 8, BRASS)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.045)), 0.017, 0.017, 0.006, 10, BRASS.darkened(0.2))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ crank gatling

## Crank Gatling: a boxy brass receiver with a carry handle, a side grip on the
## left, and a drum magazine on top. The barrels and crank are separate parts.
static func gatling_body() -> ArrayMesh:
	var st := MeshKit.begin()
	# Turned brass housing (the gear case), with steel bands and rivet rows.
	MeshKit.lathe(st, Transform3D(ALONG_Z, Vector3(0, 0, 0.04)), [Vector2(0.042, -0.072), Vector2(0.047, -0.064), Vector2(0.048, 0.05),
			Vector2(0.044, 0.066), Vector2(0.03, 0.072), Vector2(0.0, 0.074)], 20, BRASS.darkened(0.1))
	for z: float in [-0.015, 0.04, 0.095]:
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, z)), 0.0495, 0.0495, 0.008, 20, BLUED_DARK)
		for k in 10:
			var a := TAU * k / 10.0
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.05, sin(a) * 0.05, z)), Vector3.ONE * 0.0032, 3, 6, BRASS.lightened(0.25))
	# Maker's plate on the side.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.048, 0.0, 0.068)), Vector3(0.002, 0.026, 0.04), Color("#E8C870"))
	scroll(st, Vector3(0.0495, 0.0, 0.068), Vector3(1, 0, 0), 0.024, BRASS.darkened(0.35))
	# Front bearing plate where the barrels turn.
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, -0.035)), 0.05, 0.05, 0.02, 14, BLUED)
	# Carry handle and the left side grip.
	bent(st, [Vector3(0, 0.04, 0.0), Vector3(0, 0.075, 0.02), Vector3(0, 0.075, 0.08), Vector3(0, 0.04, 0.1)], 0.006, BLUED_DARK)
	rod(st, Vector3(-0.046, 0.0, -0.12), Vector3(-0.07, 0.0, -0.12), 0.007, 0.007, 6, BLUED_DARK)
	rod(st, Vector3(-0.07, -0.03, -0.12), Vector3(-0.07, 0.06, -0.12), 0.014, 0.014, 8, WALNUT)
	rod(st, Vector3(-0.046, 0.0, -0.05), Vector3(-0.046, 0.0, -0.12), 0.006, 0.006, 6, BLUED_DARK)
	# Drum magazine on top.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.09, 0.03)), 0.05, 0.05, 0.03, 16, BLUED)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.108, 0.03)), 0.015, 0.015, 0.012, 10, BRASS)
	# A short back plate with a brass butt cap (it's carried at the hip, no stock).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.115)), Vector3(0.07, 0.06, 0.012), BRASS)
	return MeshKit.finish(st)


## The spinning barrel cluster (around the gun's -Z axis, origin at GATLING_AXIS).
static func gatling_barrels() -> ArrayMesh:
	var st := MeshKit.begin()
	for i in 6:
		var a := TAU * float(i) / 6.0
		rod(st, Vector3(cos(a) * 0.024, sin(a) * 0.024, 0.0), Vector3(cos(a) * 0.024, sin(a) * 0.024, -0.36), 0.008, 0.008, 8, STEEL.darkened(0.1))
	for z: float in [-0.12, -0.3]:
		MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, z)), 0.036, 0.036, 0.01, 12, BRASS)
	MeshKit.add_cylinder(st, Transform3D(ALONG_Z, Vector3(0, 0, -0.36)), 0.034, 0.034, 0.012, 12, BLUED_DARK)
	return MeshKit.finish(st)


## The crank: an arm and a wooden knob, turning about the gun's X axis.
static func gatling_crank() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.006, 0, 0)), 0.012, 0.012, 0.012, 10, BRASS)
	rod(st, Vector3(0.012, 0, 0), Vector3(0.012, -0.07, 0.0), 0.005, 0.005, 6, BLUED_DARK)
	rod(st, Vector3(0.012, -0.07, 0.0), Vector3(0.045, -0.07, 0.0), 0.005, 0.005, 6, BLUED_DARK)
	rod(st, Vector3(0.03, -0.07, 0.0), Vector3(0.06, -0.07, 0.0), 0.009, 0.009, 8, WALNUT)
	return MeshKit.finish(st)


## A spare drum magazine (in the hand during a reload).
static func gatling_drum() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.05, 0.05, 0.03, 16, BLUED)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.018)), 0.015, 0.015, 0.012, 10, BRASS)
	return MeshKit.finish(st)
