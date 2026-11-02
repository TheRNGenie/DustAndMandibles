class_name DummyBuilder
extends RefCounted
## The crash-test-dummy cowboy, part by part, in high detail. Smooth turned
## shells (lathe), swept tubes and curved cloth panels instead of boxes:
##   body:   an egg-shaped head with a moulded brow, painted calibration eyes,
##           a centre seam and quartered target decals; a sculpted chest shell
##           with pec plates, a sternum strip and rivets over a black rubber
##           accordion waist; ball joints capped with hex bolts at shoulders,
##           elbows, hips and knees; tapered limbs with calf and forearm swell;
##           articulated hands curled into a grip.
##   gear:   a tooled gun belt with a cartridge row, an engraved buckle and a
##           holstered revolver; boots with heels, stitching, pull tabs and
##           rowel spurs; hats with dented crowns, curled brims, bands and
##           conchos; vests with lapels, pockets and buttons; a duster with a
##           shoulder cape and split tails; a fringed striped poncho; a star.
## Coordinates match DummyRig's pivots (front is -Z). Lengths come from DummyRig.

const JOINT := Color("#232328")
const JOINT_HI := Color("#3A3A42")
const BOLT := Color("#B9BEC6")
const MARK_DARK := Color("#1E1E22")
const MARK_LIGHT := Color("#F2C230")
const HAT := Color("#6B4A2E")
const HAT_DARK := Color("#4E3420")
const VEST := Color("#4A2E20")
const VEST_HI := Color("#5E3C2A")
const STITCH := Color("#C8A878")
const COAT := Color("#8A6C4A")
const COAT_DARK := Color("#6E5438")
const BOOT := Color("#4A2C1C")
const BOOT_HI := Color("#64402A")
const SOLE := Color("#2A1A12")
const BELT := Color("#3A2416")
const BELT_HI := Color("#5A3A24")
const BRASS := Color("#D6A74A")
const SILVER := Color("#C8CED6")
const LEAD := Color("#8A8A90")
const WALNUT := Color("#7A4A2A")

const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.28

const SEG := 18 # round segments for turned parts


static func part(name: String, team: Color, look: Dictionary) -> ArrayMesh:
	var paint := DummyLook.paint(look)
	var st := MeshKit.begin()
	match name:
		"pelvis":
			_pelvis(st, paint)
		"tails":
			_tails(st, str(look.get("outfit")), team)
		"torso":
			_torso(st, paint, team, look)
		"head":
			_head(st, paint, team, look)
		"thigh_l", "thigh_r":
			_thigh(st, paint, -1.0 if name == "thigh_l" else 1.0)
		"shin":
			_shin(st, paint, look)
		"foot":
			_foot(st, paint, look)
		"upper_arm":
			_upper_arm(st, paint, str(look.get("outfit")))
		"forearm":
			_forearm(st, paint, str(look.get("outfit")))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ shared bits

## A hex bolt head facing along `n` at `at`.
static func bolt(st: SurfaceTool, at: Vector3, n: Vector3, r: float = 0.012) -> void:
	var b := MeshKit.basis_from_y(n.normalized())
	MeshKit.add_cylinder(st, Transform3D(b, at), r * 1.25, r * 1.25, r * 0.35, 12, JOINT_HI)
	MeshKit.add_cylinder(st, Transform3D(b, at + n.normalized() * r * 0.35), r, r, r * 0.5, 6, BOLT)


## A black rubber ball joint with two bolt caps on its sides (along `axis`).
static func ball_joint(st: SurfaceTool, at: Vector3, r: float, axis: Vector3) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at), Vector3.ONE * r, 8, SEG, JOINT)
	for s: float in [-1.0, 1.0]:
		bolt(st, at + axis.normalized() * s * r * 0.92, axis.normalized() * s, r * 0.32)


## Quartered crash-test target decal facing +Y of xf, with a dark rim.
static func marker(st: SurfaceTool, xf: Transform3D, r: float) -> void:
	var n := (xf.basis * Vector3.UP).normalized()
	var c := xf.origin
	var segs := 24
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var col := MeshKit.vcol(MARK_DARK if (i * 4 / segs) % 2 == 0 else MARK_LIGHT)
		MeshKit.tri(st, c, xf * (Vector3(cos(a0), 0.0, sin(a0)) * r), xf * (Vector3(cos(a1), 0.0, sin(a1)) * r), n, n, n, col, n)
	MeshKit.add_cylinder(st, Transform3D(xf.basis, c - n * 0.0025), r + 0.007, r + 0.007, 0.004, 24, MARK_DARK)


## Tapered limb shell between two heights on the Y axis with a swell in the middle.
static func limb(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, swell: float, col: Color, squash := Vector2.ONE) -> void:
	var prof: Array = []
	var n := 9
	for i in n:
		var t := float(i) / (n - 1)
		var r := lerpf(r0, r1, t) + sin(t * PI) * swell
		# Round the ends a little so joints seat into them.
		if i == 0:
			r *= 0.86
		elif i == n - 1:
			r *= 0.86
		prof.append(Vector2(r, lerpf(y0, y1, t)))
	MeshKit.lathe(st, Transform3D(), prof, SEG, col, squash)


## A curved cloth panel hanging from an arc: angles a0..a1 (radians around Y,
## 0 = +X, front is -Z = -PI/2), from y_top down `length`, radius flaring
## from r_top to r_bottom. Stitched hem in `hem`.
static func panel(st: SurfaceTool, a0: float, a1: float, y_top: float, length: float, r_top: float, r_bottom: float,
		col: Color, hem: Color, cols: int = 8, rows: int = 6, sway: float = 0.0, squash: float = 1.0) -> void:
	var grid: Array = []
	for r in rows + 1:
		var t := float(r) / rows
		var row: Array[Vector3] = []
		for c in cols + 1:
			var a := lerpf(a0, a1, float(c) / cols)
			var rad := lerpf(r_top, r_bottom, t * t) + sin(float(c) * 1.7 + t * 3.0) * 0.008 * t
			row.append(Vector3(cos(a) * rad, y_top - length * t, sin(a) * rad * lerpf(squash, 1.0, t * 0.6)) + Vector3(0, 0, sway * t * t))
		grid.append(row)
	var cc := MeshKit.vcol(col)
	for r in rows:
		for c in cols:
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c + 1]
			var d: Vector3 = grid[r + 1][c]
			var e: Vector3 = grid[r + 1][c + 1]
			var mid := (a + e) * 0.5
			var out := Vector3(mid.x, 0, mid.z).normalized()
			var n := (b - a).cross(d - a).normalized()
			if n.dot(out) < 0.0:
				n = -n
			MeshKit.tri(st, a, b, e, n, n, n, cc, out)
			MeshKit.tri(st, a, e, d, n, n, n, cc, out)
			MeshKit.tri(st, a, e, b, -n, -n, -n, cc, -out)
			MeshKit.tri(st, a, d, e, -n, -n, -n, cc, -out)
	# Hem band along the bottom edge.
	var hem_pts: Array = []
	var hem_r: Array = []
	for c in cols + 1:
		hem_pts.append(grid[rows][c])
		hem_r.append(0.008)
	MeshKit.tube(st, hem_pts, hem_r, 6, hem)


# ------------------------------------------------------------------ head

static func _head(st: SurfaceTool, paint: Color, team: Color, look: Dictionary) -> void:
	# Egg-shaped skull, slightly deeper than wide.
	var skull: Array = [Vector2(0.0, -0.05), Vector2(0.05, -0.048), Vector2(0.078, -0.03), Vector2(0.096, 0.0),
		Vector2(0.106, 0.04), Vector2(0.109, 0.08), Vector2(0.104, 0.12), Vector2(0.09, 0.155), Vector2(0.066, 0.18),
		Vector2(0.034, 0.195), Vector2(0.0, 0.2)]
	MeshKit.lathe(st, Transform3D(), skull, 24, paint, Vector2(1.0, 1.08))
	# Jaw and chin, a moulded brow ridge, a stub of a nose.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.005, -0.05)), Vector3(0.078, 0.052, 0.07), 8, 18, paint)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.03, -0.088)), Vector3(0.04, 0.03, 0.03), 6, 12, paint.lightened(0.04))
	MeshKit.tube(st, [Vector3(-0.07, 0.11, -0.083), Vector3(-0.035, 0.12, -0.108), Vector3(0, 0.116, -0.114), Vector3(0.035, 0.12, -0.108), Vector3(0.07, 0.11, -0.083)],
			[0.011, 0.014, 0.012, 0.014, 0.011], 8, paint.lightened(0.06))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.07, -0.118)), Vector3(0.016, 0.026, 0.016), 5, 10, paint.darkened(0.04))
	# Painted calibration eyes: black ovals with a yellow ring and a glint.
	for s: float in [-1.0, 1.0]:
		var e := Vector3(s * 0.038, 0.088, -0.111)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.2), e), Vector3(0.019, 0.023, 0.006), 5, 12, Color("#F4F0E6"))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.2), e + Vector3(0, 0, -0.002)), Vector3(0.012, 0.016, 0.006), 5, 12, MARK_DARK)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), e + Vector3(s * -0.004, 0.006, -0.006)), Vector3.ONE * 0.003, 3, 6, Color(1, 1, 1), 0.0, null, 0.3)
	# Mouth: a moulded seam with little corners.
	MeshKit.tube(st, [Vector3(-0.03, 0.018, -0.103), Vector3(0, 0.014, -0.11), Vector3(0.03, 0.018, -0.103)], [0.003, 0.003, 0.003], 5, JOINT)
	# Centre seam over the skull, and the temple targets with jaw bolts below.
	var seam: Array = []
	var seam_r: Array = []
	for i in 13:
		var a := lerpf(-0.2, PI + 0.4, float(i) / 12.0)
		seam.append(Vector3(0, 0.07 + sin(a) * 0.133, -cos(a) * 0.123))
		seam_r.append(0.0035)
	MeshKit.tube(st, seam, seam_r, 5, JOINT)
	for s: float in [-1.0, 1.0]:
		marker(st, Transform3D(Basis(Vector3.BACK, s * PI * 0.5), Vector3(s * 0.108, 0.08, 0.0)), 0.04)
		bolt(st, Vector3(s * 0.085, -0.012, -0.012), Vector3(s, 0, 0), 0.009)
	# Rubber neck socket under the skull.
	MeshKit.lathe(st, Transform3D(), [Vector2(0.044, -0.085), Vector2(0.05, -0.07), Vector2(0.056, -0.055), Vector2(0.05, -0.045)], 16, JOINT)
	_hair_and_face(st, look, team)
	if str(look.get("neck")) == "mask":
		_mask(st, team)
	_hat_for(st, look, team)


static func _hair_and_face(st: SurfaceTool, look: Dictionary, team: Color) -> void:
	var hair := DummyLook.hair_color(look)
	var hair_hi := hair.lightened(0.15)
	match str(look.get("hair")):
		"mullet":
			for i in 9:
				var x := -0.08 + i * 0.02
				var lock := [Vector3(x, 0.13, 0.07), Vector3(x * 1.05, 0.05, 0.11), Vector3(x * 1.1, -0.04, 0.12), Vector3(x * 1.15, -0.09, 0.105)]
				MeshKit.tube(st, lock, [0.02, 0.022, 0.016, 0.006], 7, hair if i % 2 == 0 else hair_hi)
		"ponytail":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, 0.07)), Vector3(0.1, 0.07, 0.07), 6, 12, hair)
			MeshKit.lathe(st, Transform3D(Basis(), Vector3(0, 0.11, 0.115)), [Vector2(0.022, -0.012), Vector2(0.025, 0.012)], 10, Color("#B8352A"))
			MeshKit.tube(st, [Vector3(0, 0.11, 0.12), Vector3(0, 0.05, 0.16), Vector3(0, -0.03, 0.17), Vector3(0.01, -0.12, 0.15), Vector3(0.02, -0.17, 0.13)],
					[0.026, 0.03, 0.026, 0.016, 0.004], 9, hair)
		"long":
			for i in 13:
				var a := -1.35 + i * 0.225
				var top := Vector3(sin(a) * 0.1, 0.13, cos(a) * 0.085 + 0.02)
				var lock := [top, top + Vector3(sin(a) * 0.03, -0.09, cos(a) * 0.02), top + Vector3(sin(a) * 0.045, -0.2, cos(a) * 0.03), top + Vector3(sin(a) * 0.05 + 0.01 * sin(i), -0.29, cos(a) * 0.035)]
				MeshKit.tube(st, lock, [0.024, 0.024, 0.018, 0.004], 7, hair if i % 2 == 0 else hair_hi)
		"mohawk":
			for i in 9:
				var z := -0.09 + i * 0.026
				var y := 0.19 - absf(z) * 0.4
				MeshKit.tube(st, [Vector3(0, y - 0.02, z), Vector3(0, y + 0.05, z + 0.01), Vector3(0, y + 0.1, z + 0.035)], [0.018, 0.012, 0.002], 6, hair if i % 2 == 0 else hair_hi)
	var lip := Vector3(0, 0.032, -0.112)
	var stache := func(pts: Array, r: Array) -> void: MeshKit.tube(st, pts, r, 8, hair)
	match str(look.get("facial")):
		"handlebar":
			for s: float in [-1.0, 1.0]:
				stache.call([lip, lip + Vector3(s * 0.03, -0.004, 0.004), lip + Vector3(s * 0.058, 0.0, 0.014), lip + Vector3(s * 0.074, 0.022, 0.022), lip + Vector3(s * 0.068, 0.034, 0.024)],
						[0.012, 0.012, 0.009, 0.005, 0.002])
		"horseshoe":
			for s: float in [-1.0, 1.0]:
				stache.call([lip + Vector3(s * 0.006, 0, 0), lip + Vector3(s * 0.035, -0.006, 0.006), lip + Vector3(s * 0.045, -0.04, 0.016), lip + Vector3(s * 0.046, -0.08, 0.026)],
						[0.011, 0.011, 0.01, 0.007])
		"walrus":
			for i in 7:
				var x := -0.045 + i * 0.015
				stache.call([lip + Vector3(x, 0.004, 0.0), lip + Vector3(x * 1.1, -0.02, -0.004), lip + Vector3(x * 1.15, -0.034, -0.004)], [0.012, 0.01, 0.003])
		"pencil":
			stache.call([lip + Vector3(-0.034, 0.0, 0.006), lip + Vector3(0, 0.002, 0.0), lip + Vector3(0.034, 0.0, 0.006)], [0.003, 0.004, 0.003])
		"goatee":
			stache.call([lip + Vector3(-0.026, 0.0, 0.004), lip + Vector3(0, 0.002, 0.0), lip + Vector3(0.026, 0.0, 0.004)], [0.007, 0.008, 0.007])
			stache.call([Vector3(0, -0.03, -0.112), Vector3(0, -0.06, -0.1), Vector3(0, -0.085, -0.085)], [0.018, 0.016, 0.004])
		"beard":
			for i in 11:
				var a := -1.2 + i * 0.24
				var root := Vector3(sin(a) * 0.08, 0.0, -cos(a) * 0.07 - 0.02)
				stache.call([root, root + Vector3(sin(a) * 0.01, -0.05, -0.01), root + Vector3(sin(a) * 0.005, -0.09, 0.0)], [0.02, 0.018, 0.005])
			stache.call([lip + Vector3(-0.04, 0.0, 0.006), lip + Vector3(0, 0.003, 0.0), lip + Vector3(0.04, 0.0, 0.006)], [0.01, 0.011, 0.01])
		"chops":
			for s: float in [-1.0, 1.0]:
				stache.call([Vector3(s * 0.09, 0.07, -0.03), Vector3(s * 0.092, 0.02, -0.05), Vector3(s * 0.075, -0.02, -0.07), Vector3(s * 0.05, -0.03, -0.085)], [0.016, 0.022, 0.02, 0.008])


static func _mask(st: SurfaceTool, team: Color) -> void:
	# A bandana pulled up over the nose, knotted behind, with a printed border.
	MeshKit.lathe(st, Transform3D(), [Vector2(0.088, -0.05), Vector2(0.1, -0.02), Vector2(0.113, 0.02), Vector2(0.112, 0.06), Vector2(0.104, 0.075)], 22, team, Vector2(1.0, 1.1))
	MeshKit.lathe(st, Transform3D(), [Vector2(0.104, 0.07), Vector2(0.106, 0.078)], 22, team.lightened(0.35), Vector2(1.0, 1.1))
	for i in 5:
		var x := -0.04 + i * 0.02
		MeshKit.tube(st, [Vector3(x, -0.04, -0.105), Vector3(x * 1.2, -0.08, -0.1), Vector3(x * 1.4, -0.11, -0.085)], [0.012, 0.01, 0.002], 6, team.darkened(0.08))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.04, 0.125)), Vector3(0.025, 0.02, 0.02), 5, 10, team.darkened(0.15))
	for s: float in [-1.0, 1.0]:
		MeshKit.tube(st, [Vector3(0, 0.04, 0.13), Vector3(s * 0.02, 0.01, 0.15), Vector3(s * 0.025, -0.04, 0.16)], [0.012, 0.01, 0.004], 6, team.darkened(0.15))


# ------------------------------------------------------------------ hats

static func _hat_for(st: SurfaceTool, look: Dictionary, team: Color) -> void:
	match str(look.get("hat")):
		"cattleman":
			_hat(st, team, 0.135, 0.112, 0.27, 0.055, true, false)
		"ten_gallon":
			_hat(st, team, 0.21, 0.12, 0.32, 0.045, true, true)
		"gambler":
			_hat(st, team, 0.1, 0.12, 0.25, 0.0, false, false)
		"bowler":
			MeshKit.lathe(st, Transform3D(), [Vector2(0.12, 0.165), Vector2(0.123, 0.2), Vector2(0.118, 0.24), Vector2(0.1, 0.28), Vector2(0.06, 0.3), Vector2(0.0, 0.305)], 24, Color("#2A2422"))
			MeshKit.lathe(st, Transform3D(), [Vector2(0.124, 0.17), Vector2(0.125, 0.192)], 24, team)
			_brim(st, 0.12, 0.17, 0.165, 0.025, Color("#2A2422"))
		"sombrero":
			MeshKit.lathe(st, Transform3D(), [Vector2(0.118, 0.18), Vector2(0.115, 0.24), Vector2(0.1, 0.3), Vector2(0.075, 0.35), Vector2(0.04, 0.375), Vector2(0.0, 0.38)], 24, Color("#D8B46A"))
			MeshKit.lathe(st, Transform3D(), [Vector2(0.12, 0.19), Vector2(0.118, 0.22)], 24, team)
			for i in 12:
				var a := TAU * i / 12.0
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.12, 0.205, sin(a) * 0.12)), Vector3.ONE * 0.008, 3, 6, SILVER)
			_brim(st, 0.12, 0.46, 0.18, -0.06, Color("#D8B46A"), true)


static func _ring_points(r: float, y: float, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var a := TAU * i / n
		out.append(Vector3(cos(a) * r, y, sin(a) * r))
	return out


static func _const(v: float, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		out.append(v)
	return out


## A cowboy hat: crown height and radius, brim radius and curl (side lift),
## pinched front dents, and a tall rounded top for the ten-gallon.
static func _hat(st: SurfaceTool, team: Color, crown_h: float, crown_r: float, brim_r: float, curl: float, pinch: bool, tall: bool) -> void:
	var y0 := 0.185
	var prof: Array = [Vector2(crown_r, y0), Vector2(crown_r * 1.0, y0 + crown_h * 0.35), Vector2(crown_r * 0.96, y0 + crown_h * 0.7),
		Vector2(crown_r * (0.9 if tall else 0.88), y0 + crown_h * 0.92), Vector2(crown_r * 0.6, y0 + crown_h * (1.02 if tall else 0.98)), Vector2(0.0, y0 + crown_h * (1.0 if tall else 0.94))]
	MeshKit.lathe(st, Transform3D(), prof, 24, HAT, Vector2(0.9, 1.08))
	if pinch:
		# The centre crease and two pinched dents at the front.
		MeshKit.tube(st, [Vector3(0, y0 + crown_h * 0.9, -crown_r * 0.6), Vector3(0, y0 + crown_h * 0.86, 0.0), Vector3(0, y0 + crown_h * 0.9, crown_r * 0.75)], [0.01, 0.016, 0.01], 8, HAT_DARK)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * crown_r * 0.42, y0 + crown_h * 0.72, -crown_r * 0.78)), Vector3(0.03, 0.04, 0.014), 5, 10, HAT_DARK)
	# Band with a silver concho and a little feather.
	MeshKit.lathe(st, Transform3D(), [Vector2(crown_r * 1.012, y0 + 0.008), Vector2(crown_r * 1.012, y0 + 0.034)], 24, team, Vector2(0.9, 1.08))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.5), Vector3(crown_r * 0.42, y0 + 0.021, -crown_r * 0.98)), 0.014, 0.014, 0.006, 12, SILVER)
	MeshKit.tube(st, [Vector3(crown_r * 0.55, y0 + 0.02, -crown_r * 0.85), Vector3(crown_r * 0.8, y0 + 0.07, -crown_r * 0.6), Vector3(crown_r * 0.9, y0 + 0.12, -crown_r * 0.4)],
			[0.008, 0.012, 0.002], 6, Color("#E8DCC0"))
	_brim(st, crown_r * 0.98, brim_r, y0, curl, HAT)


## A hat brim from radius r0 to r1 at height y, its sides curling up by `curl`
## (negative droops the edge, sombrero-style), with a stitched edge.
static func _brim(st: SurfaceTool, r0: float, r1: float, y: float, curl: float, col: Color, wavy: bool = false) -> void:
	var segs := 36
	var rows := 5
	var top: Array = []
	for r in rows + 1:
		var t := float(r) / rows
		var row: Array[Vector3] = []
		for s in segs:
			var a := TAU * s / segs
			var side := sin(a) * sin(a) # 0 front/back, 1 at the sides (x axis: cos)
			side = cos(a) * cos(a)
			var lift := curl * side * t * t * 2.2 - absf(sin(a)) * 0.012 * t
			if wavy:
				lift += curl * t * t + sin(a * 8.0) * 0.006 * t
			var rad := lerpf(r0, r1, t) * (1.0 if not wavy else 1.0)
			row.append(Vector3(cos(a) * rad * 0.93, y + lift, sin(a) * rad * 1.05))
		top.append(row)
	var cc := MeshKit.vcol(col)
	var under := MeshKit.vcol(col.darkened(0.18))
	var thick := Vector3(0, 0.008, 0)
	for r in rows:
		for s in segs:
			var s1 := (s + 1) % segs
			var a: Vector3 = top[r][s]
			var b: Vector3 = top[r][s1]
			var c: Vector3 = top[r + 1][s1]
			var d: Vector3 = top[r + 1][s]
			var n := (b - a).cross(d - a).normalized()
			if n.y < 0.0:
				n = -n
			MeshKit.tri(st, a + thick, b + thick, c + thick, n, n, n, cc, n)
			MeshKit.tri(st, a + thick, c + thick, d + thick, n, n, n, cc, n)
			MeshKit.tri(st, a, b, c, -n, -n, -n, under, -n)
			MeshKit.tri(st, a, c, d, -n, -n, -n, under, -n)
	# Rolled, stitched edge.
	var edge: Array = []
	for s in segs + 1:
		edge.append((top[rows][s % segs] as Vector3) + thick * 0.5)
	MeshKit.tube(st, edge, _const(0.007, segs), 6, col.darkened(0.1))


# ------------------------------------------------------------------ torso

static func _torso(st: SurfaceTool, paint: Color, team: Color, look: Dictionary) -> void:
	# Black rubber accordion waist.
	var waist: Array = []
	for i in 9:
		var y := 0.0 + i * 0.016
		waist.append(Vector2(0.14 + (0.012 if i % 2 == 0 else 0.0), y))
	MeshKit.lathe(st, Transform3D(), waist, SEG, JOINT, Vector2(1.0, 0.7))
	# Chest shell.
	var chest: Array = [Vector2(0.15, 0.12), Vector2(0.17, 0.16), Vector2(0.192, 0.22), Vector2(0.208, 0.29), Vector2(0.214, 0.35),
		Vector2(0.205, 0.41), Vector2(0.18, 0.46), Vector2(0.13, 0.495), Vector2(0.06, 0.51), Vector2(0.0, 0.512)]
	MeshKit.lathe(st, Transform3D(), chest, 24, paint, Vector2(1.0, 0.66))
	# Pec plates, sternum strip with the target, rivets round the plates.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, s * 0.25), Vector3(s * 0.085, 0.34, -0.118)), Vector3(0.085, 0.07, 0.03), 6, 14, paint.lightened(0.06))
		for k in 5:
			var a := PI * (0.15 + k * 0.17)
			bolt(st, Vector3(s * (0.085 + cos(a) * 0.075 * s), 0.34 + sin(a) * 0.06, -0.142), Vector3(s * 0.2, 0, -1), 0.0055)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.26, -0.13)), Vector3(0.05, 0.22, 0.02), JOINT)
	marker(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.22, -0.142)), 0.04)
	# Ab plates.
	for i in 2:
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(s * 0.05, 0.16 + i * 0.045, -0.118)), Vector3(0.04, 0.02, 0.016), 5, 10, paint.darkened(0.04))
	# Back: shoulder blades and a spine ridge with bolts, and a stencilled ID plate.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(s * 0.085, 0.36, 0.115)), Vector3(0.075, 0.08, 0.025), 5, 12, paint.darkened(0.05))
	for i in 5:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.18 + i * 0.065, 0.135)), Vector3(0.018, 0.022, 0.012), 4, 8, JOINT)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.24, 0.138)), Vector3(0.09, 0.05, 0.006), MARK_DARK)
	for i in 4:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.03 + i * 0.02, 0.24, 0.142)), Vector3(0.012, 0.022, 0.004), MARK_LIGHT)
	# Shoulder sockets, ribbed rubber neck with a painted collar ring.
	for s: float in [-1.0, 1.0]:
		ball_joint(st, Vector3(s * 0.205, 0.455, 0), 0.068, Vector3(1, 0, 0))
	var neck: Array = []
	for i in 9:
		neck.append(Vector2(0.05 + (0.008 if i % 2 == 0 else 0.0), 0.5 + i * 0.012))
	MeshKit.lathe(st, Transform3D(), neck, 16, JOINT)
	MeshKit.lathe(st, Transform3D(), [Vector2(0.075, 0.5), Vector2(0.07, 0.515)], 18, paint.darkened(0.1))
	_torso_outfit(st, str(look.get("outfit")), team, look, paint)


static func _torso_outfit(st: SurfaceTool, outfit: String, team: Color, look: Dictionary, paint: Color) -> void:
	match outfit:
		"vest", "lawman":
			var vest := VEST if outfit == "vest" else Color("#2E2A28")
			# Body of the vest: a shell over the chest, open down the front.
			panel(st, -PI * 0.5 + 0.32, PI * 1.5 - 0.32, 0.47, 0.37, 0.222, 0.19, vest, vest.darkened(0.2), 14, 5, 0.0, 0.7)
			# Lapels, pocket flaps with stitching, buttons.
			for s: float in [-1.0, 1.0]:
				MeshKit.tube(st, [Vector3(s * 0.06, 0.47, -0.135), Vector3(s * 0.09, 0.4, -0.155), Vector3(s * 0.075, 0.3, -0.152)], [0.016, 0.02, 0.008], 6, vest.lightened(0.12))
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.35), Vector3(s * 0.13, 0.19, -0.15)), Vector3(0.07, 0.022, 0.012), vest.lightened(0.08))
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, s * 0.35), Vector3(s * 0.13, 0.181, -0.157)), Vector3(0.06, 0.003, 0.003), STITCH)
			for i in 4:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.062, 0.15 + i * 0.06, -0.148)), 0.009, 0.009, 0.006, 10, BRASS)
			if outfit == "lawman":
				# A pressed shirt under the dark vest, and the star.
				panel(st, -PI * 0.5 - 0.34, -PI * 0.5 + 0.34, 0.47, 0.34, 0.218, 0.186, Color("#E8E0CC"), Color("#C8BCA0"), 6, 4, 0.0, 0.69)
				_star(st, Vector3(0.1, 0.36, -0.162), 0.045)
		"duster":
			# Long coat: chest shell, a shoulder cape and a turned-up collar.
			panel(st, -PI * 0.5 + 0.18, PI * 1.5 - 0.18, 0.47, 0.42, 0.228, 0.2, COAT, COAT_DARK, 16, 5, 0.0, 0.72)
			panel(st, -PI * 0.5 + 0.45, PI * 1.5 - 0.45, 0.515, 0.13, 0.15, 0.245, COAT.lightened(0.04), COAT_DARK, 20, 3, 0.0, 0.72)
			MeshKit.lathe(st, Transform3D(), [Vector2(0.085, 0.5), Vector2(0.095, 0.56), Vector2(0.1, 0.6)], 18, COAT_DARK)
			for i in 3:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.055, 0.2 + i * 0.08, -0.158)), 0.011, 0.011, 0.008, 10, Color("#2A1A12"))
		"poncho":
			# Wool poncho: a cone over the shoulders, striped in team colour, fringed hem.
			MeshKit.lathe(st, Transform3D(), [Vector2(0.27, 0.12), Vector2(0.272, 0.2), Vector2(0.262, 0.3), Vector2(0.235, 0.4), Vector2(0.17, 0.47), Vector2(0.1, 0.505), Vector2(0.075, 0.52)], 28, Color("#C8A878"), Vector2(1.0, 0.8))
			for i in 4:
				var y := 0.15 + i * 0.05
				var r := 0.276 - i * 0.002
				MeshKit.lathe(st, Transform3D(), [Vector2(r, y), Vector2(r, y + 0.022)], 28, team if i % 2 == 0 else Color("#3A2416"), Vector2(1.0, 0.8))
			for i in 34:
				var a := TAU * i / 34.0
				var base := Vector3(cos(a) * 0.27, 0.12, sin(a) * 0.216)
				MeshKit.tube(st, [base, base + Vector3(cos(a) * 0.01, -0.06, sin(a) * 0.01)], [0.006, 0.003], 4, Color("#B89868"))
	match str(look.get("neck")):
		"bandana":
			MeshKit.lathe(st, Transform3D(), [Vector2(0.066, 0.505), Vector2(0.074, 0.52), Vector2(0.07, 0.545)], 18, team)
			# Triangle drape in front and a knot at the back.
			for i in 5:
				var x := -0.05 + i * 0.025
				MeshKit.tube(st, [Vector3(x, 0.515, -0.07), Vector3(x * 0.7, 0.47, -0.105), Vector3(x * 0.3, 0.42, -0.13)], [0.016, 0.014, 0.004], 6, team.darkened(0.08 * (i % 2)))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.525, 0.075)), Vector3(0.022, 0.018, 0.016), 5, 10, team.darkened(0.15))
		"bolo":
			for s: float in [-1.0, 1.0]:
				MeshKit.tube(st, [Vector3(s * 0.035, 0.53, -0.055), Vector3(s * 0.01, 0.46, -0.12), Vector3(s * 0.006, 0.36, -0.14)], [0.004, 0.004, 0.003], 4, BELT)
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(s * 0.006, 0.345, -0.14)), 0.006, 0.003, 0.03, 8, SILVER)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.44, -0.14)), Vector3(0.024, 0.03, 0.009), 5, 12, SILVER)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.44, -0.147)), Vector3(0.017, 0.022, 0.006), 5, 12, Color("#3FA8A0"))
	if DummyLook.has_bandolier(look):
		_bandolier(st)


static func _star(st: SurfaceTool, at: Vector3, r: float) -> void:
	var n := Vector3(0, 0, -1)
	var pts: Array[Vector3] = []
	for i in 12:
		var a := TAU * i / 12.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.48
		pts.append(at + Vector3(cos(a) * rr, sin(a) * rr, 0))
	var c := MeshKit.vcol(SILVER.lightened(0.15))
	for i in 12:
		MeshKit.tri(st, at + Vector3(0, 0, -0.006), pts[i], pts[(i + 1) % 12], n, n, n, c, n)
	for i in 6:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), pts[i * 2] + Vector3(0, 0, -0.002)), Vector3.ONE * 0.006, 3, 6, SILVER)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -0.008)), r * 0.28, r * 0.28, 0.004, 14, BRASS)


static func _bandolier(st: SurfaceTool) -> void:
	# A leather strap over the left shoulder, round the back, with a row of rounds.
	var front: Array = []
	var back: Array = []
	for i in 9:
		var t := float(i) / 8.0
		front.append(Vector3(lerpf(-0.17, 0.17, t), lerpf(0.47, 0.08, t), -0.152 - sin(t * PI) * 0.03))
		back.append(Vector3(lerpf(-0.17, 0.17, t), lerpf(0.47, 0.08, t), 0.15 + sin(t * PI) * 0.02))
	MeshKit.tube(st, front, _const(0.022, 8), 6, BELT)
	MeshKit.tube(st, back, _const(0.022, 8), 6, BELT)
	for i in 8:
		var t := 0.08 + i * 0.11
		var p := Vector3(lerpf(-0.17, 0.17, t), lerpf(0.47, 0.08, t), -0.172 - sin(t * PI) * 0.03)
		var b := Basis(Vector3.BACK, 0.85)
		MeshKit.add_cylinder(st, Transform3D(b, p), 0.009, 0.009, 0.04, 8, BRASS)
		MeshKit.add_cylinder(st, Transform3D(b, p + b * Vector3(0, 0.026, 0)), 0.008, 0.002, 0.014, 8, LEAD)


# ------------------------------------------------------------------ pelvis and coat tails

static func _pelvis(st: SurfaceTool, paint: Color) -> void:
	MeshKit.lathe(st, Transform3D(), [Vector2(0.12, -0.12), Vector2(0.16, -0.09), Vector2(0.178, -0.04), Vector2(0.175, 0.03), Vector2(0.15, 0.08)], SEG, paint, Vector2(1.0, 0.72))
	for s: float in [-1.0, 1.0]:
		ball_joint(st, Vector3(s * 0.11, -0.065, 0), 0.07, Vector3(1, 0, 0))
	# Tooled gun belt, cartridge row, engraved buckle, holstered revolver.
	MeshKit.lathe(st, Transform3D(Basis(Vector3.BACK, 0.05)), [Vector2(0.186, 0.0), Vector2(0.19, 0.03), Vector2(0.186, 0.058)], 28, BELT, Vector2(1.0, 0.76))
	for i in 28:
		var a := TAU * i / 28.0
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(cos(a) * 0.19, 0.03, sin(a) * 0.145)), Vector3.ONE * 0.004, 2, 4, BELT_HI)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.03, -0.152)), Vector3(0.042, 0.032, 0.01), 6, 14, SILVER)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.03, -0.158)), Vector3(0.03, 0.022, 0.006), 6, 14, BRASS)
	for i in 9:
		var a := PI * 0.1 + i * 0.1
		var p := Vector3(-cos(a) * 0.196, 0.03, sin(a) * 0.15)
		MeshKit.add_cylinder(st, Transform3D(Basis(), p), 0.008, 0.008, 0.04, 8, BRASS)
		MeshKit.add_cylinder(st, Transform3D(Basis(), p + Vector3(0, 0.026, 0)), 0.007, 0.002, 0.014, 8, LEAD)
	# Holster on the right hip with a revolver grip poking out.
	var hb := Basis(Vector3.BACK, -0.12)
	MeshKit.lathe(st, Transform3D(hb, Vector3(0.205, -0.09, -0.02)), [Vector2(0.02, -0.08), Vector2(0.034, -0.04), Vector2(0.04, 0.03), Vector2(0.044, 0.06)], 12, BELT_HI, Vector2(0.7, 1.0))
	MeshKit.add_box(st, Transform3D(hb, Vector3(0.208, 0.0, -0.025)), Vector3(0.028, 0.06, 0.045), WALNUT)
	MeshKit.add_ellipsoid(st, Transform3D(hb, Vector3(0.211, 0.035, -0.02)), Vector3(0.016, 0.02, 0.025), 4, 8, WALNUT.darkened(0.1))


static func _tails(st: SurfaceTool, outfit: String, team: Color) -> void:
	if outfit == "duster":
		# Long split tails, flared, with a vent at the back.
		panel(st, PI * 0.5 + 0.08, PI * 1.25, 0.04, 0.66, 0.2, 0.27, COAT, COAT_DARK, 8, 7, 0.0, 0.78)
		panel(st, -PI * 0.25, PI * 0.5 - 0.08, 0.04, 0.66, 0.2, 0.27, COAT, COAT_DARK, 8, 7, 0.0, 0.78)
		panel(st, PI * 1.25, PI * 1.45, 0.04, 0.6, 0.19, 0.25, COAT_DARK, COAT_DARK, 3, 6, 0.0, 0.78)
		panel(st, -PI * 0.45, -PI * 0.25, 0.04, 0.6, 0.19, 0.25, COAT_DARK, COAT_DARK, 3, 6, 0.0, 0.78)
	elif outfit == "poncho":
		# Front and back flaps of the poncho hanging past the belt.
		panel(st, -PI * 0.5 - 0.55, -PI * 0.5 + 0.55, 0.14, 0.2, 0.268, 0.25, Color("#C8A878"), team, 10, 4, 0.0, 0.8)
		panel(st, PI * 0.5 - 0.55, PI * 0.5 + 0.55, 0.14, 0.2, 0.268, 0.25, Color("#C8A878"), team, 10, 4, 0.0, 0.8)


# ------------------------------------------------------------------ legs

static func _thigh(st: SurfaceTool, paint: Color, side: float) -> void:
	limb(st, -0.03, -THIGH + 0.045, 0.082, 0.066, 0.014, paint)
	# Calibration bands at the top and a target on the outside.
	MeshKit.lathe(st, Transform3D(), [Vector2(0.088, -0.08), Vector2(0.088, -0.094)], SEG, MARK_DARK)
	marker(st, Transform3D(Basis(Vector3.BACK, side * PI * 0.5), Vector3(side * 0.084, -0.22, 0.0)), 0.034)
	# Knee: a ball joint with bolts and a kneecap plate.
	ball_joint(st, Vector3(0, -THIGH, 0), 0.062, Vector3(1, 0, 0))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, -THIGH + 0.02, -0.058)), Vector3(0.05, 0.05, 0.022), 6, 12, paint.lightened(0.05))


static func _shin(st: SurfaceTool, paint: Color, look: Dictionary) -> void:
	if DummyLook.has_boots(look):
		limb(st, -0.03, -SHIN * 0.45, 0.062, 0.06, 0.008, paint)
		_boot_shaft(st)
	else:
		limb(st, -0.03, -SHIN + 0.05, 0.064, 0.05, 0.014, paint)
		MeshKit.lathe(st, Transform3D(), [Vector2(0.052, -SHIN + 0.05), Vector2(0.058, -SHIN + 0.035), Vector2(0.05, -SHIN + 0.02)], SEG, JOINT)


## The foot hangs off the ankle pivot (at -SHIN), so it can roll heel to toe.
static func _foot(st: SurfaceTool, paint: Color, look: Dictionary) -> void:
	if DummyLook.has_boots(look):
		_boot_foot(st)
	else:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.005, -0.045)), Vector3(0.052, 0.04, 0.115), 7, 16, paint)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.04, -0.045)), Vector3(0.1, 0.02, 0.23), JOINT)
		for i in 4:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.05, -0.13 + i * 0.06)), Vector3(0.1, 0.008, 0.02), JOINT_HI)


static func _boot_shaft(st: SurfaceTool) -> void:
	var top := -SHIN * 0.42
	# Shaft with a scalloped top, pull tabs and decorative stitching.
	MeshKit.lathe(st, Transform3D(), [Vector2(0.06, -SHIN + 0.0), Vector2(0.062, -SHIN + 0.04), Vector2(0.064, -SHIN * 0.75), Vector2(0.07, top - 0.01), Vector2(0.075, top)], SEG, BOOT, Vector2(1.0, 1.1))
	for s: float in [-1.0, 1.0]:
		MeshKit.tube(st, [Vector3(s * 0.073, top - 0.005, 0), Vector3(s * 0.078, top + 0.04, 0.002), Vector3(s * 0.074, top + 0.05, 0.004)], [0.01, 0.009, 0.006], 5, BOOT_HI)
	for i in 3:
		var y := top - 0.05 - i * 0.05
		var pts: Array = []
		for k in 9:
			var a := lerpf(PI * 1.15, PI * 1.85, float(k) / 8.0)
			pts.append(Vector3(cos(a) * 0.069, y + sin(float(k) * 1.4) * 0.012, sin(a) * 0.076))
		MeshKit.tube(st, pts, _const(0.0028, 8), 4, STITCH)


static func _boot_foot(st: SurfaceTool) -> void:
	# Foot: ankle cuff, toe box, instep, raised heel, dark sole and welt.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -SHIN + 0.01, 0.0)), Vector3(0.064, 0.05, 0.07), 6, 14, BOOT)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, -SHIN - 0.005, -0.06)), Vector3(0.055, 0.045, 0.13), 8, 18, BOOT)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.0, -0.165)), Vector3(0.04, 0.03, 0.04), 6, 12, BOOT_HI)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.05, -0.06)), Vector3(0.105, 0.016, 0.26), SOLE)
	MeshKit.lathe(st, Transform3D(Basis(), Vector3(0, -SHIN - 0.03, 0.035)), [Vector2(0.032, -0.03), Vector2(0.036, 0.0), Vector2(0.04, 0.02)], 12, SOLE, Vector2(1.2, 1.0))
	# Spur: strap over the instep, shank, and a spiked rowel.
	MeshKit.tube(st, _arc_pts(Vector3(0, -SHIN - 0.01, -0.02), 0.07, 14, PI * 1.0, PI * 2.0), _const(0.009, 14), 5, BELT)
	MeshKit.tube(st, [Vector3(0, -SHIN - 0.01, 0.06), Vector3(0, -SHIN - 0.005, 0.09)], [0.006, 0.005], 5, SILVER)
	var hub := Vector3(0, -SHIN - 0.005, 0.1)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), hub), 0.01, 0.01, 0.008, 8, SILVER)
	for i in 8:
		var a := TAU * i / 8.0
		MeshKit.tube(st, [hub, hub + Vector3(0, sin(a) * 0.03, cos(a) * 0.03)], [0.004, 0.0008], 4, SILVER)


static func _arc_pts(c: Vector3, r: float, n: int, a0: float, a1: float) -> Array:
	var out: Array = []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector3(cos(a) * r * 0.85, sin(a) * r * 0.55 + r * 0.55, 0) * Vector3(1, 1, 1))
	return out


# ------------------------------------------------------------------ arms

static func _upper_arm(st: SurfaceTool, paint: Color, outfit: String) -> void:
	if outfit == "duster":
		limb(st, -0.01, -UPPER_ARM + 0.02, 0.078, 0.066, 0.01, COAT)
		MeshKit.lathe(st, Transform3D(), [Vector2(0.08, -0.06), Vector2(0.08, -0.066)], SEG, COAT_DARK)
	elif outfit == "lawman":
		limb(st, -0.01, -UPPER_ARM + 0.03, 0.066, 0.056, 0.01, Color("#E8E0CC"))
	else:
		limb(st, -0.03, -UPPER_ARM + 0.04, 0.06, 0.05, 0.012, paint)
		MeshKit.lathe(st, Transform3D(), [Vector2(0.064, -0.1), Vector2(0.064, -0.112)], SEG, MARK_DARK)
	ball_joint(st, Vector3(0, -UPPER_ARM, 0), 0.05, Vector3(1, 0, 0))


static func _forearm(st: SurfaceTool, paint: Color, outfit: String) -> void:
	if outfit == "duster":
		limb(st, -0.01, -FOREARM + 0.05, 0.066, 0.06, 0.006, COAT)
		MeshKit.lathe(st, Transform3D(), [Vector2(0.066, -FOREARM + 0.07), Vector2(0.068, -FOREARM + 0.035)], SEG, COAT_DARK)
	elif outfit == "lawman":
		limb(st, -0.01, -FOREARM + 0.06, 0.058, 0.052, 0.006, Color("#E8E0CC"))
		MeshKit.lathe(st, Transform3D(), [Vector2(0.054, -FOREARM + 0.07), Vector2(0.056, -FOREARM + 0.05)], SEG, Color("#C8BCA0"))
	else:
		limb(st, -0.03, -FOREARM + 0.03, 0.052, 0.044, 0.01, paint)
	# Wrist joint and a hand curled into a grip: palm, four fingers, a thumb.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -FOREARM - 0.002, 0)), Vector3.ONE * 0.034, 6, 12, JOINT)
	hand(st, Vector3(0, -FOREARM - 0.055, -0.004), paint)


## A dummy hand curled into a grip (the fingers wrap toward -Z), palm centre at `c`.
static func hand(st: SurfaceTool, c: Vector3, paint: Color) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), c), Vector3(0.04, 0.045, 0.03), 7, 14, paint)
	for i in 4:
		var x := -0.027 + i * 0.018
		var k0 := c + Vector3(x, -0.04, -0.005)
		var pts := [k0, k0 + Vector3(0, -0.022, -0.012), k0 + Vector3(0, -0.026, -0.036), k0 + Vector3(0, -0.01, -0.05)]
		MeshKit.tube(st, pts, [0.0105, 0.0105, 0.0095, 0.008], 7, paint.darkened(0.03 * (i % 2)))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), k0), Vector3.ONE * 0.011, 4, 8, JOINT)
	var t0 := c + Vector3(0.04, -0.01, -0.02)
	MeshKit.tube(st, [t0, t0 + Vector3(0.012, -0.02, -0.025), t0 + Vector3(0.0, -0.035, -0.04)], [0.012, 0.011, 0.009], 7, paint)
