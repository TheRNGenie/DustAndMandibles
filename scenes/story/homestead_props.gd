class_name HomesteadProps
extends RefCounted
## Story chapter 9, The Dry Gulch Families: the props on the canyon floor.
## A homestead the 1889 blast emptied (a fieldstone footing, log walls half
## down, a fallen roof with its rafters still leaning, the stone chimney left
## standing, a porch, a broken fence, a dead tree, the family's name on the
## gate) with a tin document box on the table inside; the amber crew's camp
## (a timber drill derrick over a glowing resin pit, a donkey engine, tents,
## crates of amber, the board's pennant); a bundle of papers lying where a
## downed carrier dropped it. Local space: origin on the ground, +Z out the
## front door. One vertex-coloured mesh per prop (vertex alpha < 1 glows).

const LOG := Color("#7A5236")
const LOG_DARK := Color("#563826")
const STONE := Color("#9A8A78")
const STONE_DARK := Color("#6E6052")
const CHAR := Color("#2E2420")
const TIN := Color("#3E5A44")
const PAPER := Color("#EFE4C6")
const AMBER := Color("#FFA62B")
const BOARD_RED := Color("#8C1E24")
## The table the tin box sits on, in the ruin's own frame.
const BOX_SPOT := Vector3(-0.9, 0.82, -0.6)


static func _xf(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)


## A log between two points.
static func _log(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	MeshKit.add_limb(st, a, b, r, col, 6)


## The ruined homestead (seed picks which walls stand and how the roof fell).
## `boxes` collects [Transform3D, size] for the solid parts (walls, chimney).
static func ruin_mesh(seed_value: int, boxes: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var w := 6.4
	var d := 5.0
	# Fieldstone footing all round.
	for side in 4:
		var along := side % 2 == 0
		var length := w if along else d
		var n := int(length / 0.55)
		for k in n:
			var t := -length * 0.5 + (k + 0.5) * length / n
			var p := Vector3(t, 0.16, (d * 0.5 if side == 0 else -d * 0.5)) if along else Vector3((w * 0.5 if side == 1 else -w * 0.5), 0.16, t)
			MeshKit.add_ellipsoid(st, _xf(p, rng.randf() * TAU), Vector3(0.32, 0.2, 0.28), 3, 6, STONE.darkened(rng.randf() * 0.2), 0.15, rng)
	# Floorboards, some gone.
	var z := -d * 0.5 + 0.3
	while z < d * 0.5 - 0.2:
		if rng.randf() > 0.18:
			MeshKit.add_box(st, _xf(Vector3(rng.randf_range(-0.2, 0.2), 0.3, z), rng.randf_range(-0.03, 0.03)), Vector3(w - 0.6, 0.05, 0.28), LOG.lightened(0.08).darkened(rng.randf() * 0.2), 0.02, rng)
		z += 0.3
	# Walls of stacked logs: the back wall and one side stand, the other side is
	# half down, the front has its door frame and a broken window.
	var walls := [[Vector3(0, 0, -d * 0.5), w, 0.0, 2.6], [Vector3(-w * 0.5, 0, 0), d, PI * 0.5, 2.4],
			[Vector3(w * 0.5, 0, 0), d, PI * 0.5, 1.1 + rng.randf() * 0.4]]
	for wl: Array in walls:
		var c: Vector3 = wl[0]
		var length: float = wl[1]
		var yaw: float = wl[2]
		var h: float = wl[3]
		var b := Basis(Vector3.UP, yaw)
		var y := 0.42
		while y < h:
			var cut := length * (1.0 - rng.randf() * 0.25 if y > h - 0.8 else 1.0)
			_log(st, c + b * Vector3(-length * 0.5, y, 0), c + b * Vector3(-length * 0.5 + cut, y, 0), 0.15, LOG.darkened(rng.randf() * 0.18))
			y += 0.3
		boxes.append([Transform3D(b, c + Vector3(0, h * 0.5 + 0.2, 0)), Vector3(length, h, 0.32)])
	# Front wall: two short stretches either side of the door, one with a window hole.
	for sx: float in [-1.0, 1.0]:
		var h := 2.2 if sx < 0.0 else 1.5
		var y := 0.42
		while y < h:
			if not (sx < 0.0 and y > 1.1 and y < 1.8):
				_log(st, Vector3(sx * 0.7, y, d * 0.5), Vector3(sx * w * 0.5, y, d * 0.5), 0.15, LOG.darkened(rng.randf() * 0.18))
			else:
				_log(st, Vector3(sx * 0.7, y, d * 0.5), Vector3(sx * 1.3, y, d * 0.5), 0.15, LOG)
				_log(st, Vector3(sx * 2.6, y, d * 0.5), Vector3(sx * w * 0.5, y, d * 0.5), 0.15, LOG)
			y += 0.3
		boxes.append([Transform3D(Basis(), Vector3(sx * (w * 0.25 + 0.35), h * 0.5 + 0.2, d * 0.5)), Vector3(w * 0.5 - 0.7, h, 0.32)])
	# Door frame, the door hanging off one hinge.
	for sx: float in [-0.7, 0.7]:
		MeshKit.add_box(st, _xf(Vector3(sx, 1.3, d * 0.5)), Vector3(0.16, 2.2, 0.2), LOG_DARK)
	MeshKit.add_box(st, _xf(Vector3(0, 2.4, d * 0.5)), Vector3(1.6, 0.18, 0.22), LOG_DARK)
	MeshKit.add_box(st, _xf(Vector3(0.95, 0.95, d * 0.5 + 0.5), 0.9, 0.0, 0.25), Vector3(1.25, 1.9, 0.07), LOG.lightened(0.05), 0.02, rng)
	# An eviction notice nailed to the door frame (white paper, red seal).
	MeshKit.add_box(st, _xf(Vector3(-0.78, 1.55, d * 0.5 + 0.12)), Vector3(0.34, 0.44, 0.01), PAPER)
	MeshKit.add_ellipsoid(st, _xf(Vector3(-0.78, 1.4, d * 0.5 + 0.13)), Vector3(0.05, 0.05, 0.01), 3, 6, BOARD_RED)
	# The stone chimney at the back corner, still standing.
	var ch := Vector3(-w * 0.5 + 0.7, 0, -d * 0.5 + 0.4)
	var cy := 0.0
	while cy < 4.6:
		var s := 1.05 if cy < 2.2 else 0.72
		for k in 4:
			var a := TAU * k / 4.0 + cy
			MeshKit.add_ellipsoid(st, _xf(ch + Vector3(cos(a) * s * 0.28, cy + 0.15, sin(a) * s * 0.28), rng.randf() * TAU), Vector3(0.34, 0.18, 0.3) * s, 3, 6, STONE.darkened(rng.randf() * 0.25), 0.1, rng)
		cy += 0.3
	MeshKit.add_box(st, _xf(ch + Vector3(0, 0.55, 0.5)), Vector3(0.8, 0.7, 0.2), CHAR) # the hearth's black mouth
	boxes.append([Transform3D(Basis(), ch + Vector3(0, 2.3, 0)), Vector3(1.0, 4.6, 1.0)])
	# The roof fell in: the ridge pole down at one end, rafters leaning, a sheet
	# of shakes slumped over the back.
	var ridge_a := Vector3(-w * 0.5 + 0.4, 3.5, 0)
	var ridge_b := Vector3(w * 0.5 - 0.6, 0.6 + rng.randf() * 0.4, rng.randf_range(-0.5, 0.5))
	_log(st, ridge_a, ridge_b, 0.13, LOG_DARK)
	for k in 6:
		var t := (k + 0.5) / 6.0
		var top := ridge_a.lerp(ridge_b, t)
		for sz: float in [-1.0, 1.0]:
			if rng.randf() < 0.3:
				continue
			_log(st, top, top + Vector3(rng.randf_range(-0.3, 0.3), -top.y + 0.35, sz * d * 0.55), 0.08, LOG_DARK.darkened(0.15))
	var slump := Basis(Vector3.RIGHT, -0.75) * Basis(Vector3.FORWARD, 0.25)
	MeshKit.add_box(st, Transform3D(slump, Vector3(-0.8, 1.6, -1.2)), Vector3(3.8, 0.08, 2.4), Color("#5C4A3A"), 0.05, rng)
	for k in 6:
		MeshKit.add_box(st, Transform3D(slump, Vector3(-0.8, 1.6, -1.2) + slump * Vector3(0, 0.06, -1.0 + k * 0.4)), Vector3(3.9, 0.04, 0.08), Color("#4A3A2E"))
	# Inside: a table with the tin box on it, a chair on its back, a cold stove pipe.
	var tb := BOX_SPOT - Vector3(0, 0.82, 0)
	MeshKit.add_box(st, _xf(tb + Vector3(0, 0.78, 0)), Vector3(1.3, 0.07, 0.8), LOG.lightened(0.12))
	for lx: float in [-0.55, 0.55]:
		for lz: float in [-0.32, 0.32]:
			MeshKit.add_box(st, _xf(tb + Vector3(lx, 0.39, lz)), Vector3(0.07, 0.78, 0.07), LOG_DARK)
	MeshKit.add_box(st, _xf(tb + Vector3(1.0, 0.25, 0.4), 0.6, 1.4), Vector3(0.45, 0.06, 0.45), LOG)
	MeshKit.add_box(st, _xf(tb + Vector3(1.2, 0.5, 0.15), 0.6, 1.4), Vector3(0.45, 0.6, 0.06), LOG)
	# A torn calico curtain in the window, a cracked plate and a tin cup on the floor.
	MeshKit.add_box(st, _xf(Vector3(-1.95, 1.45, d * 0.5 - 0.06), 0.0, 0.0, 0.08), Vector3(0.6, 0.55, 0.02), Color("#B85A4A"))
	MeshKit.add_cylinder(st, _xf(Vector3(0.6, 0.35, -0.3)), 0.16, 0.16, 0.02, 12, Color("#E8E2D0"))
	MeshKit.add_cylinder(st, _xf(Vector3(0.9, 0.38, 0.4), 0.0, 1.4), 0.05, 0.05, 0.12, 8, Palette.METAL)
	# A porch out front: boards, two posts, a broken rail.
	MeshKit.add_box(st, _xf(Vector3(0, 0.22, d * 0.5 + 0.9)), Vector3(w * 0.8, 0.08, 1.6), LOG.lightened(0.05), 0.02, rng)
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(sx * w * 0.38, 1.2, d * 0.5 + 1.6)), Vector3(0.14, 2.0, 0.14), LOG_DARK)
	_log(st, Vector3(-w * 0.38, 0.9, d * 0.5 + 1.6), Vector3(-1.0, 0.25, d * 0.5 + 1.75), 0.05, LOG)
	# A broken fence running off from the corner, the gate post with the name board.
	for k in 7:
		var p := Vector3(w * 0.5 + 1.2 + k * 1.4, 0, d * 0.5 + 3.0 - k * 0.4)
		if rng.randf() < 0.25:
			continue
		var lean := rng.randf_range(-0.25, 0.25)
		MeshKit.add_box(st, _xf(p + Vector3(0, 0.6, 0), 0.0, lean, lean * 0.5), Vector3(0.12, 1.2, 0.12), LOG_DARK.darkened(rng.randf() * 0.2))
		if k > 0 and rng.randf() < 0.6:
			_log(st, p + Vector3(-1.4, 0.8, 0.4), p + Vector3(0, 0.75 - rng.randf() * 0.5, 0), 0.04, LOG)
	MeshKit.add_box(st, _xf(Vector3(-1.6, 0.9, d * 0.5 + 3.6)), Vector3(0.16, 1.8, 0.16), LOG_DARK)
	MeshKit.add_box(st, _xf(Vector3(-1.6, 1.55, d * 0.5 + 3.7)), Vector3(1.5, 0.42, 0.05), Color("#D8C49C"))
	# A dead fruit tree by the yard.
	var tr := Vector3(w * 0.5 + 2.2, 0, -1.6)
	_log(st, tr, tr + Vector3(0.2, 2.2, 0.1), 0.17, Color("#4A3A2E"))
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf()
		var from := tr + Vector3(0.2, 1.6 + k * 0.15, 0.1)
		var to := from + Vector3(cos(a) * 1.2, 0.6 + rng.randf() * 0.6, sin(a) * 1.2)
		_log(st, from, to, 0.06, Color("#4A3A2E"))
		_log(st, to, to + Vector3(cos(a + 0.6) * 0.5, 0.3, sin(a + 0.6) * 0.5), 0.03, Color("#4A3A2E"))
	# A well ring with its windlass rotted, a washtub, a wagon wheel against the wall.
	var wl0 := Vector3(-w * 0.5 - 2.0, 0, 1.8)
	for k in 10:
		var a := TAU * k / 10.0
		MeshKit.add_ellipsoid(st, _xf(wl0 + Vector3(cos(a) * 0.6, 0.3, sin(a) * 0.6)), Vector3(0.25, 0.3, 0.2), 3, 6, STONE_DARK.darkened(rng.randf() * 0.2), 0.1, rng)
	MeshKit.add_cylinder(st, _xf(wl0 + Vector3(0, 0.55, 0)), 0.45, 0.45, 0.05, 10, CHAR)
	MeshKit.add_box(st, _xf(wl0 + Vector3(-0.6, 0.85, 0), 0.0, 0.0, 0.2), Vector3(0.1, 1.1, 0.1), LOG_DARK)
	MeshKit.add_cylinder(st, _xf(Vector3(w * 0.5 + 0.7, 0.2, 1.2)), 0.42, 0.36, 0.4, 12, Palette.METAL.darkened(0.2))
	SiteBuilder._wheel(st, Vector3(-w * 0.5 - 0.25, 0.65, -0.8), Vector3(1, 0, 0.15), 0.62, LOG, 10, false)
	# Weeds and drift sand banked against the walls.
	for k in 8:
		var p := Vector3(rng.randf_range(-w * 0.6, w * 0.6), 0.05, rng.randf_range(-d * 0.65, d * 0.65))
		MeshKit.add_ellipsoid(st, _xf(p, rng.randf() * TAU), Vector3(rng.randf_range(0.6, 1.4), 0.18, rng.randf_range(0.4, 0.9)), 3, 8, Color("#C99A5E").darkened(rng.randf() * 0.1), 0.12, rng)
	return MeshKit.finish(st)


## The family's tin document box (deed and letters inside), lid a little open.
static func tin_box_mesh(open_lid: bool = true) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 0.12, 0)), Vector3(0.5, 0.24, 0.32), TIN)
	MeshKit.add_box(st, _xf(Vector3(0, 0.12, 0.165)), Vector3(0.12, 0.08, 0.01), SiteBuilder.BRASS)
	if open_lid:
		MeshKit.add_box(st, _xf(Vector3(0, 0.3, -0.16), 0.0, -1.1), Vector3(0.52, 0.03, 0.34), TIN.lightened(0.08))
		# Papers inside, a ribbon round the deed.
		MeshKit.add_box(st, _xf(Vector3(0, 0.22, 0.0), 0.08), Vector3(0.42, 0.06, 0.26), PAPER, 0.0, null, 0.25)
		MeshKit.add_box(st, _xf(Vector3(0, 0.255, 0.0), 0.08), Vector3(0.05, 0.01, 0.27), BOARD_RED)
	else:
		MeshKit.add_box(st, _xf(Vector3(0, 0.25, 0)), Vector3(0.52, 0.03, 0.34), TIN.lightened(0.08))
	return MeshKit.finish(st)


## A bundle of papers in a ribbon (dropped on the floor, or the empty table's leftovers).
static func bundle_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	for k in 3:
		MeshKit.add_box(st, _xf(Vector3(0, 0.02 + k * 0.025, 0), k * 0.2), Vector3(0.36, 0.02, 0.26), PAPER.darkened(k * 0.05))
	MeshKit.add_box(st, _xf(Vector3(0, 0.08, 0)), Vector3(0.05, 0.01, 0.28), BOARD_RED)
	MeshKit.add_box(st, _xf(Vector3(0, 0.08, 0), PI * 0.5), Vector3(0.05, 0.011, 0.38), BOARD_RED)
	return MeshKit.finish(st)


## The board's harvest ledger: a fat leather book with brass corners.
static func ledger_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 0.07, 0)), Vector3(0.42, 0.14, 0.3), Color("#5A2A20"))
	MeshKit.add_box(st, _xf(Vector3(0.012, 0.07, 0)), Vector3(0.4, 0.11, 0.31), PAPER)
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.13, 0.13]:
			MeshKit.add_box(st, _xf(Vector3(sx, 0.07, sz)), Vector3(0.05, 0.15, 0.05), SiteBuilder.BRASS)
	return MeshKit.finish(st)


## The amber crew's camp: a timber drill derrick over a glowing resin pit dug
## into the floor, a donkey engine with its boiler and belt, two tents (from the
## raid sites' survey camp), crates of amber, the board's red pennant. The
## strongbox with the ledger is its own node. `boxes` collects the solid parts.
static func camp_mesh(seed_value: int, boxes: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	var iron := Palette.METAL.darkened(0.3)
	# The pit: a crater of churned earth with amber glowing in its bottom.
	var pit := Vector3(0, 0, -3.0)
	MeshKit.add_ellipsoid(st, _xf(pit + Vector3(0, -0.05, 0)), Vector3(3.2, 0.5, 3.2), 4, 16, Color("#6A4A32"), 0.2, rng)
	MeshKit.add_ellipsoid(st, _xf(pit + Vector3(0, 0.12, 0)), Vector3(2.2, 0.1, 2.2), 3, 14, Color("#3A2418"))
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf()
		var p := pit + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.6) + Vector3(0, 0.2, 0)
		MeshKit.add_ellipsoid(st, _xf(p, rng.randf() * TAU), Vector3(0.3, 0.16, 0.24) * rng.randf_range(0.7, 1.4), 3, 8, AMBER.darkened(rng.randf() * 0.2), 0.0, null, 0.6)
	for k in 14:
		var a := TAU * k / 14.0
		MeshKit.add_ellipsoid(st, _xf(pit + Vector3(cos(a) * 3.1, 0.3, sin(a) * 3.1), rng.randf() * TAU), Vector3(0.7, 0.4, 0.5), 3, 6, Color("#8A6A4A").darkened(rng.randf() * 0.2), 0.2, rng)
	# The derrick: four legs leaning in to a crown block, cross braces, a ladder.
	var top := pit + Vector3(0, 8.5, 0)
	var feet := [Vector3(-2.0, 0, -2.0), Vector3(2.0, 0, -2.0), Vector3(2.0, 0, 2.0), Vector3(-2.0, 0, 2.0)]
	for f: Vector3 in feet:
		_log(st, pit + f, top + f * 0.15, 0.13, wood)
		boxes.append([Transform3D(Basis(), pit + f * 0.9 + Vector3(0, 1.0, 0)), Vector3(0.4, 2.0, 0.4)])
	for k in 4:
		var y := 1.8 + k * 1.7
		var t := y / 8.5
		for i in 4:
			var a: Vector3 = (feet[i] as Vector3).lerp((feet[i] as Vector3) * 0.15, t)
			var b: Vector3 = (feet[(i + 1) % 4] as Vector3).lerp((feet[(i + 1) % 4] as Vector3) * 0.15, t)
			_log(st, pit + a + Vector3(0, y, 0), pit + b + Vector3(0, y, 0), 0.06, dark)
	MeshKit.add_box(st, _xf(top + Vector3(0, 0.15, 0)), Vector3(1.2, 0.3, 1.2), dark)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), top + Vector3(0, 0.45, 0)), 0.35, 0.35, 0.3, 12, iron)
	# The drill string down into the pit, a bit of glowing resin dripping off it.
	MeshKit.add_cylinder(st, _xf(pit + Vector3(0, 4.4, 0)), 0.09, 0.09, 8.2, 8, iron)
	MeshKit.add_ellipsoid(st, _xf(pit + Vector3(0, 0.6, 0)), Vector3(0.22, 0.4, 0.22), 3, 8, AMBER, 0.0, null, 0.7)
	# A red pennant on the crown: the board's flag.
	MeshKit.add_cylinder(st, _xf(top + Vector3(0.4, 1.6, 0)), 0.04, 0.04, 2.4, 6, dark)
	MeshKit.add_box(st, _xf(top + Vector3(0.4 + 0.75, 2.45, 0), 0.0, 0.0, -0.08), Vector3(1.5, 0.6, 0.02), BOARD_RED)
	# The donkey engine: a skid, an upright boiler, a flywheel and the belt to the derrick.
	var eng := Vector3(4.6, 0, -1.6)
	MeshKit.add_box(st, _xf(eng + Vector3(0, 0.15, 0)), Vector3(1.8, 0.3, 2.6), dark)
	MeshKit.add_cylinder(st, _xf(eng + Vector3(0, 1.2, -0.6)), 0.55, 0.55, 1.9, 14, iron)
	MeshKit.add_cylinder(st, _xf(eng + Vector3(0, 2.6, -0.6)), 0.14, 0.16, 1.0, 8, Color("#2A2624"))
	SiteBuilder._wheel(st, eng + Vector3(0.6, 1.0, 0.6), Vector3(1, 0, 0), 0.7, iron, 6, false)
	MeshKit.add_limb(st, eng + Vector3(0.6, 1.7, 0.6), pit + Vector3(1.0, 1.6, 0.4), 0.04, Color("#3A2A1E"), 4)
	boxes.append([Transform3D(Basis(), eng + Vector3(0, 1.0, -0.3)), Vector3(1.8, 2.0, 2.4)])
	# Two tents and a cold fire.
	var tent := SiteBuilder.tent(seed_value + 3)
	for k in 2:
		var tp := Vector3(-5.0 + k * 1.0, 0, 1.5 + k * 4.0)
		_merge(st, tent, _xf(tp, 0.4 - k * 0.7))
		boxes.append([_xf(tp + Vector3(0, 1.0, 0), 0.4 - k * 0.7), Vector3(2.4, 2.0, 3.0)])
	_merge(st, SiteBuilder.cold_fire(seed_value + 5), _xf(Vector3(-1.6, 0, 3.6)))
	# Crates of amber: lids off, glowing chunks heaped inside, "W.P.&P." stencils.
	for k in 4:
		var cp := Vector3(2.4 + (k % 2) * 1.1, 0, 2.2 + (k / 2) * 1.0)
		MeshKit.add_box(st, _xf(cp + Vector3(0, 0.35, 0), k * 0.2), Vector3(0.95, 0.7, 0.75), Color("#C79A62").darkened(rng.randf() * 0.15), 0.02, rng)
		MeshKit.add_box(st, _xf(cp + Vector3(0, 0.38, 0.38), k * 0.2), Vector3(0.6, 0.14, 0.01), BOARD_RED)
		for q in 4:
			MeshKit.add_ellipsoid(st, _xf(cp + Vector3(rng.randf_range(-0.3, 0.3), 0.72, rng.randf_range(-0.2, 0.2))), Vector3(0.14, 0.1, 0.12), 3, 6, AMBER, 0.0, null, 0.5)
	return MeshKit.finish(st)


## Copies `mesh`'s first surface into `st` through `xf` (vertex colours kept).
static func _merge(st: SurfaceTool, mesh: ArrayMesh, xf: Transform3D) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	st.append_from(mesh, 0, xf)
