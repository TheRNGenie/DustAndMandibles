class_name SiteBuilder
extends RefCounted
## Props for the canyon-floor raid sites (Canyon Expeditions): the bleached
## carcass of a giant bug with its ribcage, the old survey camp (canvas tents,
## a brass theodolite on its tripod, crates, a map table), bear traps and a
## dynamite tripwire, the derailed locomotive with its tender and spilled rail
## cars, bug egg clusters in a resin nest, a shored-up tunnel mouth, and every
## loot pile. One vertex-coloured mesh per prop (vertex alpha < 1 glows, see
## toon.gdshader). Local space: origin on the ground, +Z out from the canyon
## wall (toward the open floor), +X across.

const CANVAS := Color("#E6D7B4")
const CANVAS_DARK := Color("#BFA97F")
const BRASS := Color("#D9A93E")
const BRASS_DARK := Color("#9C7426")
const IRON := Color("#3E3A38")
const IRON_RUST := Color("#7A4630")
const RUST := Color("#A0522D")
const ROPE := Color("#C8A971")
const BONE := Color("#F2E4BE")
const BONE_DARK := Color("#C4B08A")
const DYNAMITE := Color("#C8362B")
const EGG := Color("#D8E8A0")
const EGG_GLOW := Color("#B6F06A")
const RESIN := Color("#8A5A2A")
const CHITIN_GLOW := Color("#5FE0C8")
const LOCO_GREEN := Color("#2F5A48")
const LOCO_RED := Color("#9E2B25")
const SAND_MOUND := Color("#C99A5E")


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _xf(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)


## A board between two points (its width along `side`).
static func _plank(st: SurfaceTool, a: Vector3, b: Vector3, width: float, thick: float, col: Color, side: Vector3 = Vector3.UP) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var z := d / len
	var x := side.cross(z).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT.cross(z).normalized()
	var y := z.cross(x).normalized()
	MeshKit.add_box(st, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(width, thick, len), col)


## A spoked wheel in the plane normal to `axle` (rim, hub, spokes, flange).
static func _wheel(st: SurfaceTool, center: Vector3, axle: Vector3, r: float, col: Color, spokes: int = 10, flange: bool = true) -> void:
	var b := MeshKit.basis_from_y(axle)
	MeshKit.add_cylinder(st, Transform3D(b, center), r, r, 0.14, 20, col, false)
	MeshKit.add_cylinder(st, Transform3D(b, center), r * 0.86, r * 0.86, 0.15, 20, col.darkened(0.25), false)
	if flange:
		MeshKit.add_cylinder(st, Transform3D(b, center - axle.normalized() * 0.07), r * 1.07, r * 1.07, 0.04, 20, col.darkened(0.15), true)
	MeshKit.add_cylinder(st, Transform3D(b, center), r * 0.2, r * 0.2, 0.24, 10, col.lightened(0.1))
	MeshKit.add_cylinder(st, Transform3D(b, center), r * 0.08, r * 0.08, 0.34, 8, BRASS_DARK)
	var u := b.x
	var v := b.z
	for i in spokes:
		var a := TAU * float(i) / float(spokes)
		var dir := u * cos(a) + v * sin(a)
		MeshKit.add_limb(st, center + dir * r * 0.18, center + dir * r * 0.86, r * 0.045, col, 5)


## A loose heap of sand banked round something half-buried.
static func _drift(st: SurfaceTool, rng: RandomNumberGenerator, pos: Vector3, size: Vector3) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos), size, 4, 12, SAND_MOUND.darkened(rng.randf() * 0.1), 0.12, rng)


# ------------------------------------------------------------------ bone yard

## The bleached carcass of a giant bug, half sunk in the floor: a spine of
## vertebrae, a ribcage arching over it (ribs curving in, some snapped), a horned
## skull with dark eye sockets and open mandibles, a broken jointed leg or two
## and curled shell plates. About `length` metres from tail to skull.
static func carcass(seed_value: int, length: float = 11.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var bone := BONE
	var spine: Array[Vector3] = []
	var n := 15
	var bend := rng.randf_range(-1.2, 1.2)
	for i in n:
		var t := float(i) / float(n - 1)
		var p := Vector3(sin(t * PI) * bend, 0.9 + sin(t * PI) * 1.4 - t * 0.3, -length * 0.5 + t * length)
		spine.append(p)
	# Vertebrae: a disc and a short spinous process on each.
	for i in n:
		var p := spine[i]
		var fwd := (spine[mini(i + 1, n - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var s := 0.55 + 0.35 * sin(float(i) / float(n - 1) * PI)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(fwd), p), s * 0.55, s * 0.55, 0.45, 9, bone.darkened(rng.randf() * 0.08))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.35), p + Vector3(0, s * 0.45, -0.1)), s * 0.2, s * 0.06, s * 0.8, 6, bone.darkened(0.05))
	# Ribs: from either side of the spine out, up and curling back in, like
	# fingers of a cupped hand, tips well apart; a few snapped short.
	for i in range(3, n - 4):
		var p := spine[i]
		var t := float(i) / float(n - 1)
		var w := 2.4 + 1.4 * sin(t * PI)
		var h := 3.0 + 2.0 * sin(t * PI)
		for side: float in [-1.0, 1.0]:
			var pts: Array = []
			var radii: Array = []
			var broken := rng.randf() < 0.18
			var reach := 0.82 if not broken else rng.randf_range(0.35, 0.55)
			var steps := 10
			for j in steps:
				var k := float(j) / float(steps - 1)
				var th := k * PI * reach
				pts.append(p + Vector3(side * (0.35 + w * sin(th)), (1.0 - cos(th)) * h * 0.5 - 0.5 * sin(th), -k * 0.5))
				radii.append(0.22 * (1.0 - k * 0.6))
			MeshKit.tube(st, pts, radii, 7, bone.darkened(rng.randf() * 0.07))
	# Pelvis plate at the tail.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.4), spine[0] + Vector3(0, 0.3, -0.4)), Vector3(1.6, 0.35, 1.1), 4, 12, bone.darkened(0.06), 0.1, rng)
	# The skull: a big helmet of bone, brow ridge, sockets, horns, mandibles.
	var head := spine[n - 1] + Vector3(0, 0.3, 2.0)
	var hb := Basis(Vector3.RIGHT, -0.15)
	MeshKit.add_ellipsoid(st, Transform3D(hb, head), Vector3(2.0, 1.45, 2.3), 6, 14, bone, 0.06, rng)
	MeshKit.add_ellipsoid(st, Transform3D(hb, head + Vector3(0, 0.75, 0.6)), Vector3(2.1, 0.45, 1.3), 4, 12, bone.darkened(0.04))
	for side: float in [-1.0, 1.0]:
		# Eye sockets: dark hollows ringed with bone.
		var eye := head + Vector3(side * 1.05, 0.35, 1.75)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), eye), Vector3(0.55, 0.5, 0.35), 4, 10, Color("#2A1A14"))
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(Vector3(side * 0.4, 0.1, 1.0)), eye + Vector3(0, 0, -0.05)), 0.62, 0.62, 0.12, 12, bone.darkened(0.1), false)
		# Horns sweeping up and back.
		var h0 := head + Vector3(side * 1.2, 1.1, 0.5)
		MeshKit.tube(st, [h0, h0 + Vector3(side * 1.0, 1.4, -0.4), h0 + Vector3(side * 1.4, 2.8, -1.4), h0 + Vector3(side * 1.1, 3.6, -2.6)],
				[0.42, 0.32, 0.2, 0.05], 8, bone.darkened(0.12))
		# Mandibles: jointed sickles, one gaping wider.
		var m0 := head + Vector3(side * 0.9, -0.85, 2.0)
		var gape := 0.7 if side > 0.0 else 0.35
		var m1 := m0 + Vector3(side * (1.0 + gape), -0.35, 1.3)
		var m2 := m1 + Vector3(-side * 0.9, -0.1, 1.2)
		MeshKit.tube(st, [m0, m1, m2], [0.32, 0.24, 0.05], 8, bone.darkened(0.18))
		for k in 3:
			var tp: Vector3 = m1.lerp(m2, 0.25 + 0.25 * k)
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(Vector3(-side, 0.2, 0)), tp + Vector3(-side * 0.12, 0, 0)), 0.08, 0.0, 0.3, 5, bone.darkened(0.25))
	# Broken legs: jointed bone segments lying where they fell.
	for k in rng.randi_range(3, 4):
		var at: Vector3 = spine[rng.randi_range(4, n - 5)]
		var side := -1.0 if k % 2 == 0 else 1.0
		var a := at + Vector3(side * 2.2, -0.6, rng.randf_range(-0.5, 0.5))
		var b := a + Vector3(side * rng.randf_range(1.6, 2.2), rng.randf_range(0.6, 1.5), rng.randf_range(-1.0, 1.0))
		var c := b + Vector3(side * rng.randf_range(0.8, 1.6), -b.y + 0.15, rng.randf_range(-1.2, 1.2))
		MeshKit.add_limb(st, a, b, 0.24, bone.darkened(0.1), 7)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), b), Vector3.ONE * 0.36, 4, 8, bone.darkened(0.14))
		MeshKit.add_limb(st, b, c, 0.17, bone.darkened(0.12), 7)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(c - b), c + (c - b).normalized() * 0.3), 0.15, 0.0, 0.7, 6, bone.darkened(0.2))
	# Curled shell plates, sun-faded teal and rust, scattered round it.
	for k in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 5.5)
		var p := Vector3(cos(a) * r, 0.18, sin(a) * r * 1.3)
		var col: Color = [Color("#5E8A7E"), Color("#8E5A3C"), Color("#6F7F6A")][rng.randi() % 3]
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a).rotated(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), p), Vector3(rng.randf_range(0.6, 1.1), 0.12, rng.randf_range(0.5, 0.9)), 4, 10, col, 0.1, rng)
	# Sand drifted up its flanks.
	for k in 5:
		var t := float(k) / 4.0
		_drift(st, rng, Vector3(spine[int(t * (n - 1))].x, 0.0, -length * 0.5 + t * length), Vector3(rng.randf_range(2.0, 2.8), 0.55, rng.randf_range(1.8, 2.6)))
	return MeshKit.finish(st)


## A smaller trophy skull (a boss's) propped on a cairn of stones with a
## horn and a bleached jaw: the Boss Trophy pickup.
static func trophy() -> ArrayMesh:
	var rng := _rng(4242)
	var st := MeshKit.begin()
	for k in 7:
		var a := TAU * float(k) / 7.0
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.38, 0.14, sin(a) * 0.38)), Vector3(0.24, 0.16, 0.2), 3, 7, Palette.ROCK_B.darkened(rng.randf() * 0.2), 0.15, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.32, 0)), Vector3(0.35, 0.18, 0.3), 3, 8, Palette.ROCK_A, 0.15, rng)
	var head := Vector3(0, 0.75, 0.05)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, -0.2), head), Vector3(0.42, 0.32, 0.5), 5, 12, BONE, 0.05, rng)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), head + Vector3(side * 0.2, 0.08, 0.38)), Vector3(0.12, 0.11, 0.08), 3, 8, Color("#2A1A14"))
		var h0 := head + Vector3(side * 0.25, 0.22, 0.0)
		MeshKit.tube(st, [h0, h0 + Vector3(side * 0.25, 0.35, -0.1), h0 + Vector3(side * 0.2, 0.75, -0.35)], [0.1, 0.06, 0.01], 7, BONE_DARK)
		var m0 := head + Vector3(side * 0.18, -0.2, 0.35)
		MeshKit.tube(st, [m0, m0 + Vector3(side * 0.22, -0.05, 0.25), m0 + Vector3(-side * 0.05, -0.08, 0.5)], [0.07, 0.05, 0.01], 6, BONE_DARK)
	# A gold-painted ring on one horn (somebody's trophy) so it reads as a prize.
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, 0.5), head + Vector3(0.38, 0.5, -0.08)), 0.07, 0.07, 0.05, 10, BRASS, false, 0.35)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ survey camp

## A canvas A-frame tent: sagging panels on a ridge pole, poles front and back,
## guy ropes to pegs, one door flap tied back and a patch on the side.
static func tent(seed_value: int, length: float = 3.2, width: float = 2.6, height: float = 2.1) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var cloth := CANVAS.darkened(rng.randf() * 0.08)
	var hw := width * 0.5
	var hl := length * 0.5
	var cols := 8
	var rows := 5
	# Each panel: a grid from the ridge down to the ground, sagging between poles.
	for side: float in [-1.0, 1.0]:
		var grid: Array = []
		for r in rows + 1:
			var v := float(r) / float(rows)
			var row: Array[Vector3] = []
			for c in cols + 1:
				var u := float(c) / float(cols)
				var z := -hl + u * length
				var sag := sin(u * PI) * sin(v * PI) * 0.16 + sin(u * PI) * 0.08 * (1.0 - v)
				var p := Vector3(side * (hw * v + 0.12 * v * (1.0 - v)) - side * sag * 0.6, height * (1.0 - v) - sag * (1.0 - v * 0.5), z)
				row.append(p)
			grid.append(row)
		for r in rows:
			for c in cols:
				var a: Vector3 = grid[r][c]
				var b: Vector3 = grid[r][c + 1]
				var cc: Vector3 = grid[r + 1][c + 1]
				var d: Vector3 = grid[r + 1][c]
				var nrm := (b - a).cross(d - a).normalized()
				if nrm.x * side < 0.0:
					nrm = -nrm
				var shade := cloth.darkened(0.05 * float(r % 2))
				MeshKit.quad(st, a, b, cc, d, nrm, shade)
				MeshKit.quad(st, a, b, cc, d, -nrm, CANVAS_DARK.darkened(0.25))
		# Guy ropes from the eaves out to pegs.
		for zz: float in [-hl + 0.1, hl - 0.1]:
			var eave := Vector3(side * hw * 0.55, height * 0.45, zz)
			var peg := Vector3(side * (hw + 1.1), 0.05, zz + signf(zz) * 0.5)
			MeshKit.add_limb(st, eave, peg, 0.012, ROPE, 4)
			MeshKit.add_cylinder(st, _xf(peg + Vector3(0, 0.1, 0), 0.0, 0.0, side * 0.3), 0.025, 0.012, 0.3, 5, Palette.WOOD_DARK)
	# The back wall (a closed triangle) and the front door flaps.
	var back := [Vector3(-hw, 0.0, -hl), Vector3(hw, 0.0, -hl), Vector3(0, height, -hl)]
	MeshKit.tri(st, back[0], back[1], back[2], Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, MeshKit.vcol(cloth.darkened(0.08)), Vector3.FORWARD)
	MeshKit.tri(st, back[0], back[1], back[2], Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(CANVAS_DARK.darkened(0.3)), Vector3.BACK)
	# Left flap closed, right flap tied back to show the dark inside.
	var f0 := Vector3(0, height, hl)
	MeshKit.tri(st, f0, Vector3(-hw, 0.0, hl), Vector3(-0.15, 0.0, hl + 0.05), Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(cloth.darkened(0.12)), Vector3.BACK)
	MeshKit.tri(st, f0, Vector3(hw * 0.95, 0.15, hl + 0.35), Vector3(hw * 0.7, 0.9, hl + 0.3), Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(cloth.darkened(0.15)), Vector3.BACK)
	MeshKit.tri(st, f0, Vector3(-0.15, 0.0, hl - 0.05), Vector3(hw * 0.95, 0.0, hl - 0.05), Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(Color("#2A1D16")), Vector3.BACK)
	MeshKit.add_limb(st, Vector3(hw * 0.72, 0.75, hl + 0.3), Vector3(hw * 0.95, 0.75, hl + 0.05), 0.02, ROPE, 4)
	# Ridge pole and the two uprights (poking out past the canvas).
	MeshKit.add_limb(st, Vector3(0, height + 0.03, -hl - 0.15), Vector3(0, height + 0.03, hl + 0.15), 0.045, Palette.WOOD_DARK, 6)
	for zz: float in [-hl - 0.05, hl + 0.05]:
		MeshKit.add_limb(st, Vector3(0, 0, zz), Vector3(0, height + 0.18, zz), 0.045, Palette.WOOD, 6)
	# A stitched patch and a stencilled survey number on the canvas.
	var patch_at := Vector3(hw * 0.5 + 0.06, height * 0.5, rng.randf_range(-0.6, 0.6))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -atan2(height, hw)), patch_at), Vector3(0.45, 0.02, 0.4), Color("#9C8A62"))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, atan2(height, hw)), Vector3(-hw * 0.5 - 0.06, height * 0.5, 0.2)), Vector3(0.5, 0.02, 0.18), Color("#7A3A2A"))
	return MeshKit.finish(st)


## A brass surveyor's theodolite on a wooden tripod: three splayed legs with
## iron shoes, the head plate, levelling screws, the horizontal circle, the
## standards holding the vertical circle and the telescope (eyepiece, objective,
## sun shade), a plumb bob hanging under it.
static func theodolite() -> ArrayMesh:
	var st := MeshKit.begin()
	var head := Vector3(0, 1.32, 0)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.3
		var foot := Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62)
		var top := head + Vector3(cos(a) * 0.1, -0.05, sin(a) * 0.1)
		# Each leg: two slats side by side, a clamp halfway, an iron shoe.
		var side := Vector3(-sin(a), 0, cos(a)) * 0.035
		for s: float in [-1.0, 1.0]:
			_plank(st, top + side * s, foot + side * s * 0.4 + Vector3(0, 0.12, 0), 0.03, 0.035, Palette.WOOD.lightened(0.05), Vector3(cos(a), 0, sin(a)))
		var mid := top.lerp(foot, 0.55)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), mid), Vector3(0.06, 0.05, 0.12), BRASS_DARK)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(top - foot), foot + Vector3(0, 0.07, 0)), 0.012, 0.035, 0.16, 6, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), head), 0.14, 0.14, 0.05, 14, Palette.WOOD_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), head + Vector3(0, 0.04, 0)), 0.11, 0.11, 0.03, 14, BRASS_DARK)
	# Levelling screws.
	for k in 3:
		var a := TAU * float(k) / 3.0
		MeshKit.add_cylinder(st, Transform3D(Basis(), head + Vector3(cos(a) * 0.075, 0.08, sin(a) * 0.075)), 0.016, 0.016, 0.06, 6, BRASS)
	# Horizontal circle and the upper plate.
	MeshKit.add_cylinder(st, Transform3D(Basis(), head + Vector3(0, 0.12, 0)), 0.095, 0.095, 0.025, 18, BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(), head + Vector3(0, 0.145, 0)), 0.07, 0.07, 0.03, 16, BRASS_DARK)
	# A spirit level vial (glows faintly green).
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), head + Vector3(0, 0.17, 0.05)), 0.012, 0.012, 0.07, 6, Color("#8FE07A"), true, 0.4)
	# The standards (two uprights) and the trunnion axle.
	var axle_y := head.y + 0.3
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(s * 0.065, axle_y - 0.07, 0)), Vector3(0.022, 0.16, 0.05), BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, axle_y, 0)), 0.012, 0.012, 0.16, 8, BRASS_DARK)
	# Vertical circle on one side.
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.09, axle_y, 0)), 0.065, 0.065, 0.015, 16, BRASS)
	# The telescope, tipped up a touch: tube, objective with a shade, eyepiece.
	var tb := Basis(Vector3.RIGHT, PI * 0.5 - 0.12)
	MeshKit.lathe(st, Transform3D(tb, Vector3(0, axle_y, 0)), [Vector2(0.012, -0.2), Vector2(0.024, -0.19), Vector2(0.026, -0.12),
			Vector2(0.03, -0.1), Vector2(0.03, 0.12), Vector2(0.036, 0.14), Vector2(0.038, 0.24), Vector2(0.034, 0.25)], 12, BRASS)
	MeshKit.add_cylinder(st, Transform3D(tb, Vector3(0, axle_y, 0) + tb.y * 0.25), 0.03, 0.03, 0.01, 12, Color("#9FD6F0"), true, 0.5)
	MeshKit.add_cylinder(st, Transform3D(tb, Vector3(0, axle_y, 0) - tb.y * 0.21), 0.016, 0.016, 0.02, 8, Color("#1A1A1A"))
	# Plumb bob on a string under the head.
	MeshKit.add_limb(st, head - Vector3(0, 0.03, 0), head - Vector3(0, 0.75, 0), 0.003, Color("#E0D6C0"), 3)
	MeshKit.lathe(st, Transform3D(Basis(), head - Vector3(0, 0.86, 0)), [Vector2(0.0, -0.06), Vector2(0.025, 0.0), Vector2(0.02, 0.04), Vector2(0.006, 0.07)], 10, BRASS)
	return MeshKit.finish(st)


## A wooden supply crate with planked sides, corner battens, rope handles and
## a stencilled band; `lid_off` leaves it open with straw showing.
static func crate(seed_value: int, size: Vector3 = Vector3(1.0, 0.75, 0.75), lid_off: bool = false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var h := size * 0.5
	var wood := Palette.WOOD.lightened(rng.randf_range(-0.05, 0.1))
	# Planks: horizontal boards on each face (small gaps between them).
	var boards := 3
	for i in boards:
		var y := (float(i) + 0.5) / float(boards) * size.y
		var bh := size.y / float(boards) - 0.02
		var shade := wood.darkened(rng.randf() * 0.12)
		MeshKit.add_box(st, _xf(Vector3(0, y, h.z - 0.015)), Vector3(size.x - 0.02, bh, 0.03), shade, 0.01, rng)
		MeshKit.add_box(st, _xf(Vector3(0, y, -h.z + 0.015)), Vector3(size.x - 0.02, bh, 0.03), shade.darkened(0.05), 0.01, rng)
		MeshKit.add_box(st, _xf(Vector3(h.x - 0.015, y, 0)), Vector3(0.03, bh, size.z - 0.06), shade.darkened(0.03), 0.01, rng)
		MeshKit.add_box(st, _xf(Vector3(-h.x + 0.015, y, 0)), Vector3(0.03, bh, size.z - 0.06), shade.darkened(0.08), 0.01, rng)
	MeshKit.add_box(st, _xf(Vector3(0, 0.02, 0)), Vector3(size.x - 0.04, 0.04, size.z - 0.04), wood.darkened(0.3))
	# Corner battens.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, _xf(Vector3(sx * (h.x - 0.01), h.y, sz * (h.z - 0.01))), Vector3(0.07, size.y + 0.01, 0.07), Palette.WOOD_DARK)
	# A painted band and a "brand" across the front.
	MeshKit.add_box(st, _xf(Vector3(0, size.y * 0.55, h.z + 0.005)), Vector3(size.x * 0.55, 0.12, 0.012), Color("#2B1B17"))
	MeshKit.add_box(st, _xf(Vector3(0, size.y * 0.55, h.z + 0.008)), Vector3(size.x * 0.12, 0.08, 0.012), Color("#C8362B"))
	# Rope handles on the ends.
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * (h.x + 0.03), size.y * 0.62, 0)
		MeshKit.tube(st, [c + Vector3(0, 0.02, -0.12), c + Vector3(sx * 0.05, -0.06, -0.05), c + Vector3(sx * 0.05, -0.06, 0.05), c + Vector3(0, 0.02, 0.12)], [0.018], 5, ROPE)
	if lid_off:
		# Straw spilling over the rim, the lid leaning on the side.
		for k in 9:
			MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-h.x, h.x) * 0.8, size.y - 0.02, rng.randf_range(-h.z, h.z) * 0.8), rng.randf() * TAU), Vector3(0.18, 0.05, 0.08), 3, 6, Color("#D8B860").darkened(rng.randf() * 0.15))
		var lid := Transform3D(Basis(Vector3.RIGHT, -1.2), Vector3(0, size.y * 0.45, h.z + 0.3))
		MeshKit.add_box(st, lid, Vector3(size.x, size.z, 0.04), wood.darkened(0.1))
	else:
		for i in 3:
			MeshKit.add_box(st, _xf(Vector3(0, size.y + 0.015, -h.z + (float(i) + 0.5) * size.z / 3.0)), Vector3(size.x, 0.03, size.z / 3.0 - 0.015), wood.darkened(rng.randf() * 0.1), 0.01, rng)
	return MeshKit.finish(st)


## A folding surveyor's table with a pinned map, an inkwell, a ledger and a
## brass lantern (glowing, so the camp reads in the canyon's shadow).
static func map_table() -> ArrayMesh:
	var st := MeshKit.begin()
	var top_y := 0.82
	MeshKit.add_box(st, _xf(Vector3(0, top_y, 0)), Vector3(1.4, 0.04, 0.8), Palette.WOOD.lightened(0.05))
	for sx: float in [-1.0, 1.0]:
		# X-folding legs.
		_plank(st, Vector3(sx * 0.6, top_y - 0.02, -0.35), Vector3(sx * 0.6, 0.0, 0.35), 0.04, 0.04, Palette.WOOD_DARK, Vector3.RIGHT)
		_plank(st, Vector3(sx * 0.6, top_y - 0.02, 0.35), Vector3(sx * 0.6, 0.0, -0.35), 0.04, 0.04, Palette.WOOD_DARK, Vector3.RIGHT)
	# The map: pale paper with a blue river, red survey line and contour rings.
	MeshKit.add_box(st, _xf(Vector3(-0.1, top_y + 0.025, 0.02), 0.08), Vector3(0.9, 0.006, 0.62), Color("#EDE2C4"))
	for k in 4:
		MeshKit.add_cylinder(st, _xf(Vector3(-0.3 + k * 0.05, top_y + 0.03, -0.05)), 0.1 + k * 0.05, 0.1 + k * 0.05, 0.003, 14, Color("#B89A6A"), false)
	MeshKit.tube(st, [Vector3(-0.5, top_y + 0.031, 0.25), Vector3(-0.2, top_y + 0.031, 0.1), Vector3(0.0, top_y + 0.031, 0.18), Vector3(0.3, top_y + 0.031, -0.2)], [0.012], 4, Color("#4F86C6"))
	MeshKit.tube(st, [Vector3(-0.45, top_y + 0.033, -0.2), Vector3(0.3, top_y + 0.033, 0.22)], [0.006], 4, Color("#C8362B"))
	for c: Vector3 in [Vector3(-0.53, 0, -0.28), Vector3(0.33, 0, -0.28), Vector3(-0.53, 0, 0.3), Vector3(0.33, 0, 0.3)]:
		MeshKit.add_cylinder(st, _xf(c + Vector3(0, top_y + 0.04, 0)), 0.015, 0.015, 0.02, 6, BRASS)
	# Inkwell and quill, a closed ledger.
	MeshKit.add_cylinder(st, _xf(Vector3(0.5, top_y + 0.05, -0.22)), 0.04, 0.035, 0.07, 8, Color("#1E2A3A"))
	MeshKit.add_limb(st, Vector3(0.5, top_y + 0.08, -0.22), Vector3(0.58, top_y + 0.26, -0.3), 0.008, Color("#F2F0E6"), 4)
	MeshKit.add_box(st, _xf(Vector3(0.48, top_y + 0.04, 0.15), 0.3), Vector3(0.22, 0.05, 0.3), Color("#6A2A22"))
	# Lantern: brass frame, glass, a warm glowing flame.
	var l := Vector3(0.52, top_y + 0.02, 0.0)
	MeshKit.add_cylinder(st, _xf(l + Vector3(0, 0.03, 0)), 0.08, 0.08, 0.05, 10, BRASS_DARK)
	MeshKit.add_cylinder(st, _xf(l + Vector3(0, 0.15, 0)), 0.06, 0.06, 0.18, 10, Color("#FFD27A"), false, 0.9)
	MeshKit.add_ellipsoid(st, _xf(l + Vector3(0, 0.14, 0)), Vector3(0.025, 0.05, 0.025), 3, 6, Color("#FFF2B0"), 0.0, null, 1.0)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		MeshKit.add_limb(st, l + Vector3(cos(a) * 0.065, 0.05, sin(a) * 0.065), l + Vector3(cos(a) * 0.065, 0.25, sin(a) * 0.065), 0.006, BRASS_DARK, 4)
	MeshKit.add_cylinder(st, _xf(l + Vector3(0, 0.28, 0)), 0.075, 0.02, 0.07, 10, BRASS_DARK)
	MeshKit.tube(st, [l + Vector3(-0.04, 0.31, 0), l + Vector3(0, 0.36, 0), l + Vector3(0.04, 0.31, 0)], [0.006], 4, BRASS_DARK)
	# A camp stool.
	MeshKit.add_cylinder(st, _xf(Vector3(-0.2, 0.45, 0.75)), 0.18, 0.18, 0.04, 12, Color("#7A3A2A"))
	for k in 3:
		var a := TAU * float(k) / 3.0
		MeshKit.add_limb(st, Vector3(-0.2 + cos(a) * 0.14, 0.43, 0.75 + sin(a) * 0.14), Vector3(-0.2 + cos(a) * 0.22, 0.0, 0.75 + sin(a) * 0.22), 0.016, Palette.WOOD_DARK, 4)
	return MeshKit.finish(st)


## A ring of blackened stones round a dead campfire (charred logs, a coffee pot).
static func cold_fire(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	for k in 9:
		var a := TAU * float(k) / 9.0
		MeshKit.add_ellipsoid(st, _xf(Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), a), Vector3(0.17, 0.12, 0.14), 3, 7, Color("#6A5A50").darkened(rng.randf() * 0.3), 0.15, rng)
	MeshKit.add_cylinder(st, _xf(Vector3(0, 0.02, 0)), 0.45, 0.45, 0.03, 12, Color("#2A2220"))
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		MeshKit.add_limb(st, Vector3(cos(a) * 0.35, 0.06, sin(a) * 0.35), Vector3(-cos(a) * 0.05, 0.16, -sin(a) * 0.05), 0.06, Color("#33241C"), 6)
	# Embers still faintly alive.
	for k in 4:
		MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-0.15, 0.15), 0.05, rng.randf_range(-0.15, 0.15))), Vector3.ONE * 0.04, 2, 5, Color("#FF7A2A"), 0.0, null, 0.8)
	var pot := Vector3(0.75, 0.0, 0.2)
	MeshKit.lathe(st, _xf(pot), [Vector2(0.08, 0.0), Vector2(0.1, 0.05), Vector2(0.1, 0.16), Vector2(0.06, 0.24), Vector2(0.04, 0.26)], 10, Color("#5A6E7A"))
	MeshKit.add_limb(st, pot + Vector3(0.08, 0.18, 0), pot + Vector3(0.17, 0.24, 0), 0.015, Color("#5A6E7A"), 4)
	return MeshKit.finish(st)


## Survey stakes with red rag flags, in a line.
static func survey_stake() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 0.45, 0)), Vector3(0.05, 0.9, 0.05), Palette.WOOD.lightened(0.15))
	MeshKit.add_cylinder(st, _xf(Vector3(0, 0.02, 0)), 0.0, 0.035, 0.08, 4, Palette.WOOD)
	MeshKit.add_box(st, _xf(Vector3(0, 0.8, 0)), Vector3(0.06, 0.08, 0.06), Color("#C8362B"))
	var t0 := Vector3(0.02, 0.86, 0)
	MeshKit.tri(st, t0, t0 + Vector3(0.28, -0.04, 0.05), t0 + Vector3(0.02, -0.14, 0), Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(Color("#E0483C")), Vector3.BACK)
	MeshKit.tri(st, t0, t0 + Vector3(0.28, -0.04, 0.05), t0 + Vector3(0.02, -0.14, 0), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, MeshKit.vcol(Color("#B8362B")), Vector3.FORWARD)
	return MeshKit.finish(st)


## A sprung bear trap: steel jaws open in a ring with teeth, the pan in the
## middle, the two flat springs and a chain to an iron stake.
static func bear_trap(closed: bool = false) -> ArrayMesh:
	var st := MeshKit.begin()
	var steel := Color("#5A5C60")
	# Base bar and pan.
	MeshKit.add_box(st, _xf(Vector3(0, 0.03, 0)), Vector3(0.95, 0.04, 0.08), steel.darkened(0.2))
	MeshKit.add_cylinder(st, _xf(Vector3(0, 0.05, 0)), 0.11, 0.11, 0.02, 12, steel.lightened(0.1))
	# Jaws: two half rings, hinged on the base, with teeth along the inside.
	for side: float in [-1.0, 1.0]:
		var lift := 1.35 if closed else 0.08
		var pts: Array = []
		for k in 11:
			var a := PI * float(k) / 10.0
			var p := Vector3(cos(a) * 0.32, 0.0, side * sin(a) * 0.32)
			# Rotate about the hinge line (X axis) by `lift`.
			p = Vector3(p.x, absf(p.z) * sin(lift), side * absf(p.z) * cos(lift)) + Vector3(0, 0.05, 0)
			pts.append(p)
		MeshKit.tube(st, pts, [0.018], 5, steel)
		for k in range(1, 10):
			var p: Vector3 = pts[k]
			var inward := (Vector3(0, 0.05, 0) - p)
			inward.x = 0.0
			inward = inward.normalized() if inward.length() > 0.01 else Vector3.UP
			var up := Vector3.UP if not closed else inward.rotated(Vector3.RIGHT, side * 0.5)
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y((up + inward * 0.6).normalized()), p + (up + inward * 0.6).normalized() * 0.03), 0.014, 0.0, 0.06, 4, steel.lightened(0.15))
	# Springs: flat leaves out past each end.
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(sx * 0.55, 0.06, 0), 0.0, 0.0, sx * -0.12), Vector3(0.4, 0.02, 0.06), steel.darkened(0.1))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.33, 0.06, 0)), 0.04, 0.04, 0.1, 8, steel.darkened(0.15))
	# Chain links to a stake.
	var prev := Vector3(0.75, 0.04, 0.0)
	for k in 6:
		var p := Vector3(0.75 + float(k) * 0.08, 0.03, sin(float(k)) * 0.05)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, float(k) * 0.9).rotated(Vector3.RIGHT, PI * 0.5 * float(k % 2)), p), 0.03, 0.03, 0.012, 8, Color("#4A4440"), false)
		prev = p
	MeshKit.add_cylinder(st, _xf(prev + Vector3(0.08, 0.06, 0)), 0.02, 0.02, 0.22, 6, Color("#3A3634"))
	MeshKit.add_cylinder(st, _xf(prev + Vector3(0.08, 0.17, 0)), 0.04, 0.04, 0.03, 8, Color("#3A3634"))
	return MeshKit.finish(st)


## A dynamite tripwire: a bundle of red sticks lashed to a stake with a fuse
## and blasting cap, and a taut wire running `span` metres along +X to a peg.
static func tripwire(span: float = 3.2) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 0.3, 0)), Vector3(0.06, 0.6, 0.06), Palette.WOOD)
	for k in 5:
		var a := TAU * float(k) / 5.0
		MeshKit.add_cylinder(st, _xf(Vector3(cos(a) * 0.05 - 0.09, 0.32, sin(a) * 0.05)), 0.028, 0.028, 0.32, 8, DYNAMITE.darkened(float(k % 2) * 0.1))
	for y: float in [0.22, 0.42]:
		MeshKit.add_cylinder(st, _xf(Vector3(-0.09, y, 0)), 0.085, 0.085, 0.025, 10, Color("#3A2A20"), false)
	# The cap, the fuse, and a "DANGER" tag.
	MeshKit.add_cylinder(st, _xf(Vector3(-0.09, 0.5, 0)), 0.015, 0.015, 0.06, 6, BRASS)
	MeshKit.tube(st, [Vector3(-0.09, 0.53, 0), Vector3(-0.02, 0.6, 0.03), Vector3(0.0, 0.45, 0.02), Vector3(0.02, 0.3, 0)], [0.008], 4, Color("#2A2A2A"))
	MeshKit.add_box(st, _xf(Vector3(-0.09, 0.32, 0.09)), Vector3(0.12, 0.08, 0.005), Color("#F2E3C2"))
	# The wire at ankle height, and the far peg.
	MeshKit.add_limb(st, Vector3(0.0, 0.18, 0), Vector3(span, 0.18, 0), 0.006, Color("#B8B8B0"), 4)
	MeshKit.add_box(st, _xf(Vector3(span, 0.14, 0)), Vector3(0.05, 0.28, 0.05), Palette.WOOD_DARK)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ railroad wreck

## A derailed 4-4-0 locomotive lying on its side (roll it in the scene): long
## green boiler with brass bands, smokebox and door, a flared diamond stack,
## steam and sand domes, the bell, a big headlamp (lit), the cowcatcher's
## slats, drivers with spokes and side rods, the pilot truck and the cab with
## its roof. About 9 m long, built along +Z, wheels at y 0.
static func locomotive() -> ArrayMesh:
	var st := MeshKit.begin()
	var axis := Basis(Vector3.RIGHT, PI * 0.5) # lathe Y -> +Z
	var by := 2.0 # boiler centre height
	# Boiler: one long turned shape with bands.
	MeshKit.lathe(st, Transform3D(axis, Vector3(0, by, -1.6)), [Vector2(0.78, -1.6), Vector2(0.8, -1.5), Vector2(0.8, 3.2), Vector2(0.82, 3.3)], 18, LOCO_GREEN)
	for z: float in [-1.1, 0.2, 1.4, 2.6]:
		MeshKit.add_cylinder(st, Transform3D(axis, Vector3(0, by, z)), 0.83, 0.83, 0.08, 18, BRASS, false)
	# Smokebox (black) and its round door with a hinge bar and a number plate.
	MeshKit.add_cylinder(st, Transform3D(axis, Vector3(0, by, 2.5)), 0.86, 0.86, 1.3, 18, IRON)
	MeshKit.add_cylinder(st, Transform3D(axis, Vector3(0, by, 3.18)), 0.7, 0.62, 0.12, 18, IRON.lightened(0.08))
	MeshKit.add_box(st, _xf(Vector3(0, by, 3.25)), Vector3(0.9, 0.06, 0.04), BRASS_DARK)
	MeshKit.add_cylinder(st, Transform3D(axis, Vector3(0, by + 0.25, 3.26)), 0.14, 0.14, 0.03, 12, BRASS)
	# The diamond stack: narrow, swelling to a wide spark-arrester cone, capped.
	MeshKit.lathe(st, _xf(Vector3(0, by + 0.7, 2.6)), [Vector2(0.22, 0.0), Vector2(0.2, 0.5), Vector2(0.24, 0.7), Vector2(0.55, 1.15),
			Vector2(0.6, 1.25), Vector2(0.35, 1.55), Vector2(0.38, 1.6)], 14, IRON)
	MeshKit.add_cylinder(st, _xf(Vector3(0, by + 2.0, 2.6)), 0.6, 0.6, 0.05, 14, BRASS_DARK, false)
	# Headlamp: a big box lamp on the smokebox, glowing.
	var lamp := Vector3(0, by + 1.15, 3.0)
	MeshKit.add_box(st, _xf(lamp), Vector3(0.55, 0.55, 0.6), IRON.lightened(0.05))
	MeshKit.add_cylinder(st, Transform3D(axis, lamp + Vector3(0, 0, 0.31)), 0.22, 0.22, 0.04, 14, Color("#FFE7A0"), true, 0.95)
	MeshKit.add_cylinder(st, Transform3D(axis, lamp + Vector3(0, 0, 0.31)), 0.26, 0.26, 0.05, 14, BRASS, false)
	MeshKit.add_box(st, _xf(lamp + Vector3(0, 0.33, -0.05)), Vector3(0.6, 0.08, 0.65), IRON)
	# Domes and the bell.
	MeshKit.lathe(st, _xf(Vector3(0, by + 0.7, 0.9)), [Vector2(0.38, 0.0), Vector2(0.35, 0.3), Vector2(0.3, 0.45), Vector2(0.18, 0.55), Vector2(0.0, 0.58)], 14, BRASS)
	MeshKit.lathe(st, _xf(Vector3(0, by + 0.7, -0.4)), [Vector2(0.34, 0.0), Vector2(0.3, 0.25), Vector2(0.24, 0.38), Vector2(0.0, 0.45)], 14, LOCO_GREEN)
	MeshKit.lathe(st, _xf(Vector3(0, by + 0.95, 1.7)), [Vector2(0.0, 0.0), Vector2(0.2, 0.02), Vector2(0.17, 0.15), Vector2(0.12, 0.3), Vector2(0.03, 0.36)], 12, BRASS)
	MeshKit.add_box(st, _xf(Vector3(0, by + 0.85, 1.7)), Vector3(0.08, 0.2, 0.3), IRON)
	# Running boards and handrails along the boiler.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(s * 0.95, by - 0.55, 0.6)), Vector3(0.35, 0.05, 5.0), IRON)
		MeshKit.add_limb(st, Vector3(s * 0.84, by + 0.5, -1.4), Vector3(s * 0.84, by + 0.5, 3.0), 0.02, BRASS, 5)
	# Frame and cylinders (steam chests) by the smokebox.
	MeshKit.add_box(st, _xf(Vector3(0, 0.95, 0.2)), Vector3(1.1, 0.35, 7.6), IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(axis, Vector3(s * 0.85, 1.05, 2.35)), 0.3, 0.3, 0.9, 12, LOCO_GREEN.darkened(0.2))
		MeshKit.add_box(st, _xf(Vector3(s * 0.85, 1.42, 2.35)), Vector3(0.4, 0.3, 0.8), LOCO_GREEN.darkened(0.25))
	# Two big drivers each side (red spoked wheels) with side and main rods.
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.4, 1.0]:
			_wheel(st, Vector3(s * 0.82, 0.85, z), Vector3(s, 0, 0), 0.85, LOCO_RED, 14)
		MeshKit.add_box(st, _xf(Vector3(s * 0.98, 0.65, 0.3)), Vector3(0.06, 0.1, 1.6), Color("#8A8E92"))
		MeshKit.add_box(st, _xf(Vector3(s * 1.02, 0.95, 1.6), 0.0, -0.2), Vector3(0.06, 0.1, 1.5), Color("#8A8E92"))
		# Pilot truck wheels up front.
		for z: float in [2.4, 3.1]:
			_wheel(st, Vector3(s * 0.65, 0.42, z), Vector3(s, 0, 0), 0.42, LOCO_RED, 8)
	# Cowcatcher: a wedge of slats out front.
	var tip := Vector3(0, 0.15, 4.45)
	for k in 9:
		var x := -0.85 + float(k) * 0.2125
		_plank(st, Vector3(x, 0.85, 3.5), tip + Vector3(x * 0.15, 0.0, 0.0), 0.06, 0.05, LOCO_RED.darkened(0.15), Vector3.RIGHT)
	MeshKit.add_box(st, _xf(Vector3(0, 0.88, 3.5)), Vector3(1.9, 0.15, 0.15), IRON)
	# The cab: walls, windows, an arched roof overhanging.
	var cab := Vector3(0, 0.0, -2.6)
	MeshKit.add_box(st, _xf(cab + Vector3(0, 1.1, 0)), Vector3(2.2, 0.25, 1.9), IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.05, 2.15, 0)), Vector3(0.08, 1.9, 1.8), LOCO_RED)
		# A window in each side (dark), with a brass sash.
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.1, 2.55, 0.15)), Vector3(0.02, 0.55, 0.7), Color("#1C1814"))
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.115, 2.55, 0.15)), Vector3(0.02, 0.6, 0.06), BRASS_DARK)
	MeshKit.add_box(st, _xf(cab + Vector3(0, 2.15, 0.88)), Vector3(2.1, 1.9, 0.08), LOCO_RED.darkened(0.08))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(axis, cab + Vector3(s * 0.55, 2.6, 0.93)), 0.22, 0.22, 0.04, 12, Color("#1C1814"))
	var roof := cab + Vector3(0, 3.15, 0)
	for k in 6:
		var a0 := -0.55 + 1.1 * float(k) / 6.0
		var a1 := -0.55 + 1.1 * float(k + 1) / 6.0
		var p0 := roof + Vector3(sin(a0) * 1.5, cos(a0) * 0.45 - 0.45, 0)
		var p1 := roof + Vector3(sin(a1) * 1.5, cos(a1) * 0.45 - 0.45, 0)
		_plank(st, p0, p1, 2.3, 0.06, IRON.lightened(0.1), Vector3.BACK)
	# A painted number board under the cab window: "No. 7".
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.1, 1.75, 0.0)), Vector3(0.02, 0.3, 0.9), Color("#2B1B17"))
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.115, 1.75, 0.0)), Vector3(0.02, 0.18, 0.12), BRASS)
	# Trailing wheels under the cab.
	for s: float in [-1.0, 1.0]:
		_wheel(st, Vector3(s * 0.7, 0.5, -2.6), Vector3(s, 0, 0), 0.5, LOCO_RED, 10)
	return MeshKit.finish(st)


## The tender: a box on two trucks heaped with coal, the railroad's name band.
static func tender(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 1.6, 0)), Vector3(2.2, 1.4, 3.8), LOCO_GREEN)
	MeshKit.add_box(st, _xf(Vector3(0, 2.33, 0)), Vector3(2.3, 0.08, 3.9), BRASS_DARK)
	MeshKit.add_box(st, _xf(Vector3(0, 0.85, 0)), Vector3(1.9, 0.2, 3.9), IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(s * 1.11, 1.7, 0)), Vector3(0.02, 0.35, 3.2), Color("#E8C870"))
		MeshKit.add_box(st, _xf(Vector3(s * 1.12, 1.7, 0)), Vector3(0.02, 0.22, 2.9), LOCO_RED.darkened(0.2))
	for k in 18:
		MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-0.85, 0.85), 2.35 + rng.randf() * 0.25, rng.randf_range(-1.6, 1.6)), rng.randf() * TAU), Vector3(0.28, 0.18, 0.24), 3, 6, Color("#1E1C1E").lightened(rng.randf() * 0.08), 0.2, rng)
	for z: float in [-1.25, 1.25]:
		MeshKit.add_box(st, _xf(Vector3(0, 0.55, z)), Vector3(1.8, 0.3, 1.1), IRON.darkened(0.1))
		for zz: float in [-0.35, 0.35]:
			for s: float in [-1.0, 1.0]:
				_wheel(st, Vector3(s * 0.75, 0.42, z + zz), Vector3(s, 0, 0), 0.42, IRON_RUST, 8)
	return MeshKit.finish(st)


## An open rail car (gondola) heaped with salvage: planked sides with iron
## stakes, two trucks; `seed_value` changes the heap.
static func rail_car(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var wood := Color("#8E4A2E").darkened(rng.randf() * 0.15)
	MeshKit.add_box(st, _xf(Vector3(0, 0.95, 0)), Vector3(2.3, 0.18, 5.4), IRON)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			MeshKit.add_box(st, _xf(Vector3(s * 1.1, 1.2 + k * 0.28, 0)), Vector3(0.06, 0.24, 5.3), wood.darkened(rng.randf() * 0.1), 0.02, rng)
		for z: float in [-2.6, -1.3, 0.0, 1.3, 2.6]:
			MeshKit.add_box(st, _xf(Vector3(s * 1.16, 1.45, z)), Vector3(0.06, 0.95, 0.08), IRON_RUST)
	for z: float in [-2.66, 2.66]:
		for k in 3:
			MeshKit.add_box(st, _xf(Vector3(0, 1.2 + k * 0.28, z)), Vector3(2.2, 0.24, 0.06), wood.darkened(0.08), 0.02, rng)
	# Painted car number band.
	MeshKit.add_box(st, _xf(Vector3(1.14, 1.5, 0)), Vector3(0.01, 0.2, 1.4), Color("#F2E3C2"))
	_scrap_heap(st, rng, Vector3(0, 1.75, 0), Vector3(1.0, 0.7, 2.4), 22)
	for z: float in [-1.8, 1.8]:
		MeshKit.add_box(st, _xf(Vector3(0, 0.55, z)), Vector3(1.8, 0.3, 1.1), IRON.darkened(0.1))
		for zz: float in [-0.35, 0.35]:
			for s: float in [-1.0, 1.0]:
				_wheel(st, Vector3(s * 0.75, 0.42, z + zz), Vector3(s, 0, 0), 0.42, IRON_RUST, 8)
	return MeshKit.finish(st)


## Bent rails on broken ties, running along +Z for `length` metres.
static func track(seed_value: int, length: float = 10.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var n := int(length / 0.9)
	for i in n:
		var z := -length * 0.5 + (float(i) + 0.5) * length / float(n)
		if rng.randf() < 0.15:
			continue
		MeshKit.add_box(st, _xf(Vector3(rng.randf_range(-0.1, 0.1), 0.06, z), rng.randf_range(-0.15, 0.15)), Vector3(2.4, 0.12, 0.24), Palette.WOOD_DARK.darkened(rng.randf() * 0.2), 0.03, rng)
	for s: float in [-1.0, 1.0]:
		var pts: Array = []
		var kink := rng.randf_range(0.3, 0.7)
		for k in 9:
			var t := float(k) / 8.0
			var lift := maxf(t - kink, 0.0) * rng.randf_range(0.6, 1.4) * 1.2
			pts.append(Vector3(s * 0.72 + lift * s * 0.6 * signf(t - kink), 0.17 + lift * lift * 0.8, -length * 0.5 + t * length))
		MeshKit.tube(st, pts, [0.06], 5, Color("#6A6058"))
	return MeshKit.finish(st)


## A broken trestle timber (the beams that fall when the wreck gives way).
static func timber(seed_value: int, length: float = 3.2) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3.ZERO), Vector3(0.32, 0.32, length), Palette.WOOD_DARK.lightened(rng.randf() * 0.1), 0.03, rng)
	for k in 4:
		MeshKit.add_cylinder(st, _xf(Vector3(rng.randf_range(-0.16, 0.16), 0.17, rng.randf_range(-length, length) * 0.45)), 0.025, 0.025, 0.05, 6, IRON)
	# A splintered end.
	for k in 5:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), length * 0.5 + 0.12)), 0.05, 0.0, 0.3, 4, Palette.WOOD)
	return MeshKit.finish(st)


## A standing trestle bent (two leaning posts, a cap and cross braces) that
## props the wreck up; it's what comes down.
static func trestle_bent(seed_value: int, height: float = 4.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	for s: float in [-1.0, 1.0]:
		_plank(st, Vector3(s * 1.4, 0, 0), Vector3(s * 0.9, height, 0), 0.28, 0.28, Palette.WOOD_DARK.lightened(rng.randf() * 0.08), Vector3.BACK)
	MeshKit.add_box(st, _xf(Vector3(0, height + 0.15, 0)), Vector3(2.6, 0.3, 0.35), Palette.WOOD_DARK)
	_plank(st, Vector3(-1.25, 0.6, 0.05), Vector3(0.95, height - 0.4, 0.05), 0.2, 0.08, Palette.WOOD, Vector3.BACK)
	_plank(st, Vector3(1.25, 0.6, -0.05), Vector3(-0.95, height - 0.4, -0.05), 0.2, 0.08, Palette.WOOD, Vector3.BACK)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ nest

## The nest itself: a crater of dried resin and mud with ridged walls, sticky
## strands across it and glowing veins in the floor.
static func nest(seed_value: int, radius: float = 4.5) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	# The rim: lumps of resin and mud in a ring.
	for k in 22:
		var a := TAU * float(k) / 22.0 + rng.randf_range(-0.1, 0.1)
		var r := radius * rng.randf_range(0.92, 1.08)
		MeshKit.add_ellipsoid(st, _xf(Vector3(cos(a) * r, 0.25, sin(a) * r), -a), Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.45, 0.8), 0.6), 4, 8, RESIN.darkened(rng.randf() * 0.25), 0.18, rng)
	# Spires of hardened resin leaning out of the rim.
	for k in 6:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * radius * 1.02
		var tip := base + Vector3(cos(a) * 0.6, rng.randf_range(1.6, 2.6), sin(a) * 0.6)
		MeshKit.tube(st, [base, base.lerp(tip, 0.5) + Vector3(0, 0, 0.1), tip], [0.35, 0.2, 0.03], 7, RESIN.darkened(0.15))
	# The floor of the crater, dark and wet, with glowing veins.
	MeshKit.add_cylinder(st, _xf(Vector3(0, 0.03, 0)), radius * 0.95, radius * 0.95, 0.04, 22, Color("#3A2A1C"))
	for k in 7:
		var a := rng.randf() * TAU
		var pts: Array = [Vector3(0, 0.07, 0)]
		var p := Vector3.ZERO
		for j in 4:
			a += rng.randf_range(-0.6, 0.6)
			p += Vector3(cos(a), 0, sin(a)) * radius * 0.22
			pts.append(p + Vector3(0, 0.07, 0))
		MeshKit.tube(st, pts, [0.06, 0.05, 0.04, 0.03, 0.02], 4, EGG_GLOW, 0.75)
	# Sticky strands over the crater.
	for k in 7:
		var a := rng.randf() * TAU
		var b := a + PI + rng.randf_range(-0.8, 0.8)
		var p0 := Vector3(cos(a) * radius, 0.6, sin(a) * radius)
		var p1 := Vector3(cos(b) * radius, 0.6, sin(b) * radius)
		var mid := (p0 + p1) * 0.5 + Vector3(0, 0.3, 0)
		MeshKit.tube(st, [p0, p0.lerp(mid, 0.5) + Vector3(0, 0.05, 0), mid, mid.lerp(p1, 0.5) + Vector3(0, 0.05, 0), p1], [0.025], 4, Color("#E8E0C8"))
	return MeshKit.finish(st)


## A clutch of bug eggs on a resin pad: glossy pale ovals with dark spots and
## a glowing yolk inside each (they light the nest). `count` eggs.
static func egg_cluster(seed_value: int, count: int = 7) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, _xf(Vector3(0, 0.05, 0)), Vector3(0.75, 0.12, 0.7), 3, 12, RESIN.darkened(0.1), 0.15, rng)
	for k in count:
		var a := TAU * float(k) / float(count) + rng.randf_range(-0.2, 0.2)
		var r := 0.0 if k == 0 else rng.randf_range(0.25, 0.5)
		var h := rng.randf_range(0.34, 0.46)
		var p := Vector3(cos(a) * r, h * 0.85, sin(a) * r)
		var tilt := Basis(Vector3(sin(a), 0, -cos(a)), r * 0.7)
		var shell := EGG.lerp(Color("#E8D8A8"), rng.randf())
		MeshKit.add_ellipsoid(st, Transform3D(tilt, p), Vector3(0.2, h, 0.2), 6, 12, shell)
		MeshKit.add_ellipsoid(st, Transform3D(tilt, p + tilt.y * 0.04), Vector3(0.12, h * 0.6, 0.12), 4, 8, EGG_GLOW, 0.0, null, 0.85)
		for j in 3:
			var sa := rng.randf() * TAU
			var sp := p + tilt * Vector3(cos(sa) * 0.19, rng.randf_range(-0.2, 0.25), sin(sa) * 0.19)
			MeshKit.add_ellipsoid(st, _xf(sp), Vector3.ONE * 0.035, 2, 5, Color("#6A7A3A"))
	# Slime strands between the eggs.
	for k in 4:
		var a := rng.randf() * TAU
		MeshKit.add_limb(st, Vector3(cos(a) * 0.3, 0.6, sin(a) * 0.3), Vector3(-cos(a) * 0.2, 0.15, -sin(a) * 0.2), 0.012, Color("#D8E8C0"), 4)
	return MeshKit.finish(st)


## A smashed clutch: broken shells and spilt yolk.
static func smashed_eggs(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, _xf(Vector3(0, 0.04, 0)), Vector3(0.9, 0.05, 0.8), 3, 12, Color("#9AB848"), 0.1, rng, 0.3)
	for k in 9:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.7) + Vector3(0, 0.08, 0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3(cos(a), 0.3, sin(a)).normalized(), rng.randf() * TAU), p), Vector3(0.14, 0.04, 0.1), 3, 7, EGG.darkened(rng.randf() * 0.15))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ tunnel mouth

## Old mine shoring in a tunnel mouth: two posts and a cap beam, a broken
## brace, a "KEEP OUT" board, a moulted bug husk and Doc's dropped satchel.
## Built facing +Z, about `width` wide.
static func shoring(seed_value: int, width: float = 4.4, height: float = 3.4) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var hw := width * 0.5
	for s: float in [-1.0, 1.0]:
		_plank(st, Vector3(s * hw, 0, 0), Vector3(s * (hw - 0.25), height, 0), 0.3, 0.3, Palette.WOOD_DARK.lightened(rng.randf() * 0.1), Vector3.BACK)
	MeshKit.add_box(st, _xf(Vector3(0, height + 0.15, 0), 0.0, 0.0, 0.06), Vector3(width + 0.4, 0.32, 0.36), Palette.WOOD_DARK)
	# A brace snapped and hanging.
	_plank(st, Vector3(-hw + 0.2, height - 0.2, 0.2), Vector3(-0.3, height - 1.4, 0.3), 0.18, 0.1, Palette.WOOD, Vector3.BACK)
	# KEEP OUT board nailed across one post.
	MeshKit.add_box(st, _xf(Vector3(hw - 0.2, 1.6, 0.22), 0.0, 0.0, -0.12), Vector3(1.3, 0.38, 0.05), Color("#C8A06A"))
	MeshKit.add_box(st, _xf(Vector3(hw - 0.2, 1.6, 0.25), 0.0, 0.0, -0.12), Vector3(1.0, 0.1, 0.02), Color("#8A2A20"))
	# A lantern on a nail, still lit (so the mouth reads in the shade).
	var l := Vector3(-hw + 0.05, 2.4, 0.3)
	MeshKit.add_limb(st, l + Vector3(0, 0.3, -0.1), l + Vector3(0, 0.15, 0), 0.01, IRON, 4)
	MeshKit.add_cylinder(st, _xf(l), 0.09, 0.09, 0.22, 10, Color("#FFC860"), false, 0.9)
	MeshKit.add_cylinder(st, _xf(l + Vector3(0, 0.14, 0)), 0.1, 0.03, 0.08, 10, IRON)
	MeshKit.add_cylinder(st, _xf(l - Vector3(0, 0.13, 0)), 0.1, 0.1, 0.04, 10, IRON)
	return MeshKit.finish(st)


## A bug's shed skin, split along the back: a hollow, translucent-looking husk.
static func husk(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	var col := Color("#D8C090")
	for k in 5:
		var z := -0.9 + float(k) * 0.45
		var s := 0.55 - absf(float(k) - 1.5) * 0.08
		for side: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, side * 0.5), Vector3(side * s * 0.45, s * 0.45, z)), Vector3(s * 0.55, s * 0.25, 0.28), 4, 8, col.darkened(rng.randf() * 0.15))
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := -0.6 + float(k / 2) * 0.55
		MeshKit.tube(st, [Vector3(side * 0.4, 0.3, z), Vector3(side * 0.9, 0.5, z + 0.1), Vector3(side * 1.25, 0.05, z + 0.3)], [0.06, 0.05, 0.02], 5, col.darkened(0.2))
	MeshKit.add_ellipsoid(st, _xf(Vector3(0, 0.3, 1.3)), Vector3(0.38, 0.3, 0.35), 4, 10, col.darkened(0.1))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ loot looks

static func _scrap_heap(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, size: Vector3, n: int) -> void:
	for k in n:
		var p := at + Vector3(rng.randf_range(-1, 1) * size.x, rng.randf() * size.y, rng.randf_range(-1, 1) * size.z)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		match rng.randi() % 5:
			0: # a gear
				var r := rng.randf_range(0.15, 0.3)
				MeshKit.add_cylinder(st, Transform3D(b, p), r, r, 0.06, 12, Color("#8A8478"))
				for t in 8:
					var a := TAU * float(t) / 8.0
					MeshKit.add_box(st, Transform3D(b, p + b * Vector3(cos(a) * r, 0, sin(a) * r)), Vector3(0.07, 0.06, 0.07), Color("#8A8478"))
			1: # a pipe
				MeshKit.add_cylinder(st, Transform3D(b, p), 0.06, 0.06, rng.randf_range(0.5, 1.0), 8, IRON_RUST)
			2: # a bent plate
				MeshKit.add_box(st, Transform3D(b, p), Vector3(rng.randf_range(0.3, 0.6), 0.03, rng.randf_range(0.3, 0.5)), Color("#7E8A90").darkened(rng.randf() * 0.3), 0.04, rng)
			3: # a wheel rim
				MeshKit.add_cylinder(st, Transform3D(b, p), 0.28, 0.28, 0.05, 12, IRON, false)
			_: # a spring
				var pts: Array = []
				for j in 12:
					var a := float(j) * 0.9
					pts.append(p + b * Vector3(cos(a) * 0.08, float(j) * 0.03, sin(a) * 0.08))
				MeshKit.tube(st, pts, [0.015], 4, Color("#A0A098"))


## A loot pile by its look (SitePlan.Loot.look). Sized to read from a few
## metres; chitin and eggs glow.
static func loot(look: StringName, seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var st := MeshKit.begin()
	match look:
		&"chitin":
			for i in 3:
				var a := rng.randf() * TAU
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a).rotated(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), Vector3(cos(a), 0.06, sin(a)) * rng.randf_range(0.1, 0.35)),
						Vector3(0.24, 0.06, 0.17), 4, 8, Color("#4A6A60").darkened(rng.randf() * 0.2), 0.15, rng)
			for i in 9:
				var a := rng.randf() * TAU
				var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.4) + Vector3(0, 0.12, 0)
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU), p), 0.0, 0.07, 0.24, 4, CHITIN_GLOW, false, 0.6)
		&"scrap":
			_scrap_heap(st, rng, Vector3(0, 0.2, 0), Vector3(0.45, 0.25, 0.45), 9)
			MeshKit.add_ellipsoid(st, _xf(Vector3(0, 0.03, 0)), Vector3(0.7, 0.06, 0.7), 3, 10, Color("#5A4636"))
		&"part":
			# A small crate, lid off, with a turret part on top and a brass tag.
			var c := crate(seed_value, Vector3(0.7, 0.45, 0.5), true)
			st.append_from(c, 0, Transform3D())
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.62, 0)), 0.09, 0.09, 0.6, 10, IRON)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.28, 0.62, 0)), 0.11, 0.11, 0.06, 10, BRASS)
			MeshKit.add_box(st, _xf(Vector3(-0.15, 0.6, 0.0)), Vector3(0.2, 0.16, 0.18), Palette.METAL)
			MeshKit.add_box(st, _xf(Vector3(0.36, 0.3, 0.27)), Vector3(0.1, 0.06, 0.01), BRASS, 0.0, null, 0.3)
		&"page":
			# Doc's journal: a leather book on a rock with loose pages fluttering.
			MeshKit.add_ellipsoid(st, _xf(Vector3(0, 0.12, 0)), Vector3(0.35, 0.14, 0.3), 3, 8, Palette.ROCK_B, 0.15, rng)
			MeshKit.add_box(st, _xf(Vector3(0, 0.29, 0), 0.3), Vector3(0.3, 0.06, 0.22), Color("#6A3A22"))
			MeshKit.add_box(st, _xf(Vector3(0, 0.29, 0), 0.3), Vector3(0.28, 0.05, 0.215), Color("#F2E8CC"))
			for k in 3:
				MeshKit.add_box(st, _xf(Vector3(rng.randf_range(-0.4, 0.4), 0.02 + k * 0.01, rng.randf_range(-0.4, 0.4)), rng.randf() * TAU), Vector3(0.2, 0.005, 0.26), Color("#F2E8CC"), 0.0, null, 0.25)
			MeshKit.add_box(st, _xf(Vector3(0.0, 0.33, 0.0), 0.3), Vector3(0.02, 0.01, 0.2), Color("#C8362B"))
		&"specimen":
			# A glass jar with a brass lid and a curled glowing grub inside.
			MeshKit.lathe(st, _xf(Vector3.ZERO), [Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.17, 0.05), Vector2(0.17, 0.38), Vector2(0.12, 0.44), Vector2(0.11, 0.46)], 14, Color("#BFE8E0"), Vector2.ONE, 0.35)
			MeshKit.add_cylinder(st, _xf(Vector3(0, 0.49, 0)), 0.125, 0.125, 0.06, 14, BRASS)
			var pts: Array = []
			for k in 8:
				var a := float(k) * 0.75
				pts.append(Vector3(cos(a) * 0.08, 0.12 + float(k) * 0.025, sin(a) * 0.08))
			MeshKit.tube(st, pts, [0.04, 0.05, 0.05, 0.045, 0.04, 0.035, 0.03, 0.02], 6, Color("#F0F070"), 0.7)
			MeshKit.add_box(st, _xf(Vector3(0, 0.25, 0.168)), Vector3(0.14, 0.1, 0.005), Color("#F2E8CC"))
		&"blueprint":
			# Rolled blueprints spilling out of a leather map tube.
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.1, 0.1, 0)), 0.1, 0.1, 0.7, 12, Color("#6A3A22"))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.47, 0.1, 0)), 0.11, 0.11, 0.06, 12, BRASS)
			for k in 3:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(0.35, 0.06 + k * 0.01, -0.15 + k * 0.15)), 0.055, 0.055, 0.6, 10, Color("#3A6EB0"), true, 0.15)
			MeshKit.add_box(st, _xf(Vector3(0.35, 0.02, 0.35), 0.4), Vector3(0.5, 0.005, 0.35), Color("#3A6EB0"))
			for k in 4:
				MeshKit.add_box(st, _xf(Vector3(0.3 + k * 0.05, 0.026, 0.3 + k * 0.03), 0.4), Vector3(0.3, 0.004, 0.012), Color("#E0ECFF"), 0.0, null, 0.4)
		&"trophy":
			st.append_from(trophy(), 0, Transform3D())
		&"egg":
			st.append_from(egg_cluster(seed_value, 5), 0, Transform3D())
		_:
			MeshKit.add_box(st, _xf(Vector3(0, 0.2, 0)), Vector3(0.4, 0.4, 0.4), Palette.WOOD)
	return MeshKit.finish(st)
