class_name ContraptionBuilder
extends RefCounted
## Meshes for the control / area / pin turrets with special shots (TurretDef.special):
## the Steam Cannon, Flood Gate, Twin Mortar and Bola Launcher. Same parts as
## TurretBuilder (base / head / gun / optional spin, barrels along -Z toward the
## canyon) and the same frontier dressing: team pennants, rivets, brass bands.

const ALONG := Basis(Vector3.RIGHT, PI * 0.5)
const ACROSS := Basis(Vector3.BACK, PI * 0.5)
## Lathe profiles run along +Y; this turns them to run out along -Z (down the barrel).
const OUT := Basis(Vector3.RIGHT, -PI * 0.5)
const BRASS := Color("#D6A74A")
const IRON := Color("#4A4E58")
const COPPER := Color("#C0703F")
const SOOT := Color("#3A3634")
const EMBER := Color("#FF8A2A")
const WATER := Color("#5FB4D6")
const ROPE := Color("#C8A060")
const ROPE_DARK := Color("#9A7A44")
const LEATHER := Color("#6B4229")
const CHILI := Color("#B8352A")


static func has(id: StringName) -> bool:
	return id in [&"steam_cannon", &"flood_gate", &"twin_mortar", &"bola_launcher"]


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"flood_gate":
			return _flood_gate(team)
		&"twin_mortar":
			return _twin_mortar(team)
		&"bola_launcher":
			return _bola_launcher(team)
	return _steam_cannon(team)


# ------------------------------------------------------------------ pieces

## A ring of rivets round a vertical drum of radius `r` at height `y` about `c`.
static func _rivet_ring(st: SurfaceTool, c: Vector3, y: float, r: float, n: int, size: float = 0.018) -> void:
	for i in n:
		var a := TAU * float(i) / n
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + Vector3(cos(a) * r, y, sin(a) * r)), Vector3.ONE * size, 3, 5, BRASS.darkened(0.15))


## A spoked hand wheel (valve or crank) at `at`, axle along `axis_basis` Y.
static func _hand_wheel(st: SurfaceTool, xf: Transform3D, r: float, spokes: int, color: Color) -> void:
	var segs := 12
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		MeshKit.add_limb(st, xf * Vector3(cos(a0) * r, 0, sin(a0) * r), xf * Vector3(cos(a1) * r, 0, sin(a1) * r), r * 0.12, color, 4)
	for i in spokes:
		var a := TAU * float(i) / spokes + 0.3
		MeshKit.add_limb(st, xf.origin, xf * Vector3(cos(a) * r, 0, sin(a) * r), r * 0.08, color, 4)
	MeshKit.add_cylinder(st, Transform3D(xf.basis, xf.origin), r * 0.22, r * 0.22, r * 0.3, 8, BRASS)


## A coil of rope lying flat at `at`.
static func _rope_coil(st: SurfaceTool, at: Vector3, r: float, turns: int) -> void:
	for k in turns:
		MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 0.025 + k * 0.045, 0)), r - k * 0.015, r - k * 0.015, 0.04, 12, ROPE if k % 2 == 0 else ROPE_DARK)


## One bola lying at `at`: three leather weights on ropes knotted together.
static func _bola(st: SurfaceTool, at: Vector3, turn: float, size: float = 1.0) -> void:
	var b := Basis(Vector3.UP, turn)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at), Vector3.ONE * 0.03 * size, 3, 6, ROPE_DARK)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var end := at + b * Vector3(cos(a), 0, sin(a)) * 0.2 * size
		MeshKit.tube(st, [at, (at + end) * 0.5 + b * Vector3(0, 0.015, 0.03), end], [0.01 * size, 0.01 * size, 0.01 * size], 4, ROPE)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), end), Vector3(0.055, 0.05, 0.055) * size, 4, 8, LEATHER.lightened(0.06 * i))
		MeshKit.add_cylinder(st, Transform3D(Basis(), end), 0.057 * size, 0.057 * size, 0.012 * size, 8, ROPE_DARK)


# ------------------------------------------------------------------ Steam Cannon

## Steam Cannon: an upright riveted copper boiler over a glowing firebox, with a
## smokestack, gauge and safety valve, piping steam up a standpipe to a long
## brass nozzle with a bell mouth and a valve wheel. Coal scuttle by the stove.
static func _steam_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 811
	var base := MeshKit.begin()
	TurretBuilder._platform(base, rng, 0.5)
	var deck := 0.58
	# Firebox: an iron stove at the back, its grate door glowing toward the plateau.
	var fb := Vector3(0, deck, 0.5)
	MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(0, 0.2, 0)), Vector3(0.6, 0.4, 0.5), SOOT.lightened(0.12), 0.01, rng)
	MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(0, 0.41, 0)), Vector3(0.66, 0.04, 0.54), IRON)
	MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(0, 0.18, 0.255)), Vector3(0.3, 0.2, 0.02), EMBER, 0.0, null, 0.85)
	for i in 4:
		MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(-0.105 + i * 0.07, 0.18, 0.27)), Vector3(0.025, 0.22, 0.02), SOOT)
	MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(0, 0.3, 0.27)), Vector3(0.36, 0.03, 0.03), IRON)
	MeshKit.add_cylinder(base, Transform3D(ACROSS, fb + Vector3(0.2, 0.3, 0.28)), 0.015, 0.015, 0.12, 5, BRASS)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), fb + Vector3(s * 0.28, -0.03, s * 0.22)), Vector3(0.1, 0.06, 0.1), IRON)
	# Boiler: an upright copper drum with a domed crown, iron hoops and rivet rows.
	var bc := Vector3(0, deck + 0.42, 0.5)
	MeshKit.lathe(base, Transform3D(Basis(), bc), [Vector2(0.26, 0.0), Vector2(0.27, 0.04), Vector2(0.27, 0.62),
			Vector2(0.255, 0.72), Vector2(0.21, 0.8), Vector2(0.12, 0.86), Vector2(0.0, 0.88)], 16, COPPER)
	for y: float in [0.04, 0.32, 0.6]:
		MeshKit.add_cylinder(base, Transform3D(Basis(), bc + Vector3(0, y, 0)), 0.28, 0.28, 0.04, 16, IRON)
		_rivet_ring(base, bc, y + 0.05, 0.276, 14, 0.014)
	# Team band painted round the drum.
	MeshKit.add_cylinder(base, Transform3D(Basis(), bc + Vector3(0, 0.46, 0)), 0.274, 0.274, 0.08, 16, team)
	# Smokestack with a flared spark-catcher crown, and a whisp of soot on top.
	var stack := bc + Vector3(0.0, 0.86, 0.06)
	MeshKit.add_cylinder(base, Transform3D(Basis(), stack + Vector3(0, 0.32, 0)), 0.065, 0.06, 0.64, 10, SOOT)
	MeshKit.lathe(base, Transform3D(Basis(), stack + Vector3(0, 0.6, 0)), [Vector2(0.06, 0.0), Vector2(0.13, 0.12), Vector2(0.14, 0.17), Vector2(0.11, 0.2)], 10, SOOT.lightened(0.08))
	MeshKit.add_cylinder(base, Transform3D(Basis(), stack + Vector3(0, 0.3, 0)), 0.075, 0.075, 0.03, 10, BRASS.darkened(0.2))
	# Safety valve with a little brass whistle, and a pressure gauge facing the plateau.
	MeshKit.add_cylinder(base, Transform3D(Basis(), bc + Vector3(0.16, 0.86, -0.08)), 0.03, 0.03, 0.14, 8, BRASS)
	MeshKit.lathe(base, Transform3D(Basis(), bc + Vector3(0.16, 0.92, -0.08)), [Vector2(0.03, 0.0), Vector2(0.045, 0.02), Vector2(0.045, 0.1), Vector2(0.025, 0.13)], 8, BRASS.lightened(0.1))
	MeshKit.add_limb(base, bc + Vector3(0.16, 0.95, -0.08), bc + Vector3(0.28, 0.98, -0.08), 0.01, IRON, 4)
	var gauge := bc + Vector3(0.0, 0.3, 0.285)
	MeshKit.add_cylinder(base, Transform3D(ALONG, gauge), 0.085, 0.085, 0.04, 14, BRASS)
	MeshKit.add_cylinder(base, Transform3D(ALONG, gauge + Vector3(0, 0, 0.022)), 0.07, 0.07, 0.01, 14, Palette.BONE)
	MeshKit.add_box(base, Transform3D(Basis(Vector3.BACK, -0.7), gauge + Vector3(0.018, 0.02, 0.03)), Vector3(0.012, 0.06, 0.006), CHILI)
	# Steam line: from the boiler's front, an elbow into the standpipe under the head.
	MeshKit.tube(base, [bc + Vector3(0, 0.1, -0.25), bc + Vector3(0, 0.1, -0.36), Vector3(0, deck + 0.5, 0.08), Vector3(0, deck + 0.46, 0.0)],
			[0.05, 0.05, 0.05, 0.05], 8, COPPER.darkened(0.1))
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, deck + 0.36, 0)), 0.09, 0.1, 0.72, 10, IRON)
	for y: float in [deck + 0.06, deck + 0.68]:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, y, 0)), 0.13, 0.13, 0.05, 10, BRASS.darkened(0.15))
	_hand_wheel(base, Transform3D(ALONG, Vector3(0, deck + 0.3, 0.13)), 0.09, 4, CHILI)
	# Coal scuttle full of lumps, and a shovel leaning on it.
	var coal := Vector3(-0.48, deck, -0.38)
	MeshKit.lathe(base, Transform3D(Basis(Vector3.BACK, 0.12), coal), [Vector2(0.12, 0.0), Vector2(0.15, 0.04), Vector2(0.17, 0.22), Vector2(0.15, 0.24)], 10, IRON.darkened(0.2))
	for i in 7:
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, i), coal + Vector3(rng.randf_range(-0.09, 0.09), 0.24, rng.randf_range(-0.09, 0.09))), Vector3(0.05, 0.04, 0.05), 3, 6, SOOT.darkened(0.3), 0.3, rng)
	MeshKit.add_limb(base, coal + Vector3(0.16, 0.02, 0.1), coal + Vector3(0.1, 0.62, 0.02), 0.014, Palette.WOOD, 4)
	MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, 0.2), coal + Vector3(0.17, 0.08, 0.12)), Vector3(0.12, 0.14, 0.02), IRON)
	TurretBuilder._pennant(base, Vector3(0.62, deck, -0.55), 1.4, team)
	# Head: a swivel collar with yoke cheeks, a team plate under the nozzle.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.2, 0.22, 0.12, 14, IRON)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.23, 0.23, 0.03, 14, BRASS)
	_rivet_ring(head, Vector3.ZERO, 0.03, 0.215, 10)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.17, 0.2, 0.02)), Vector3(0.05, 0.26, 0.18), IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.2, 0.24, 0.02)), 0.05, 0.05, 0.04, 10, BRASS)
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.14, -0.2)), Vector3(0.3, 0.14, 0.03), team)
	# Gun: the nozzle, a long brass pipe flaring to a bell mouth, wood-slat grips,
	# a red valve wheel on top and a drip cock under the elbow.
	var gun := MeshKit.begin()
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.13, 0.13, 0.13), 5, 12, BRASS.darkened(0.25))
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.045, 0.045, 0.42, 8, IRON)
	MeshKit.lathe(gun, Transform3D(OUT, Vector3(0, 0, 0.0)), [Vector2(0.085, 0.0), Vector2(0.085, 0.55), Vector2(0.07, 0.78),
			Vector2(0.07, 0.92), Vector2(0.1, 1.02), Vector2(0.16, 1.12), Vector2(0.185, 1.17), Vector2(0.16, 1.18)], 14, BRASS)
	for z: float in [-0.12, -0.42, -0.84]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.1 if z > -0.7 else 0.085, 0.1 if z > -0.7 else 0.085, 0.04, 14, COPPER.darkened(0.2))
	for i in 8:
		var a := TAU * float(i) / 8.0
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.095, sin(a) * 0.095, -0.27)), Vector3(0.03, 0.012, 0.24), Palette.WOOD)
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.14, -0.05)), 0.018, 0.018, 0.12, 6, IRON)
	_hand_wheel(gun, Transform3D(Basis(), Vector3(0, 0.2, -0.05)), 0.075, 4, CHILI)
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, -0.13, 0.03)), 0.02, 0.02, 0.1, 6, BRASS)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0.03, -0.17, 0.03)), Vector3(0.07, 0.015, 0.015), CHILI)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.04, "head_y": deck + 0.74, "gun_y": 0.24, "muzzle": Vector3(0, 0, -1.15)}


# ------------------------------------------------------------------ Flood Gate

## Flood Gate: a staved timber water tank with a shingle cone roof, high on braced
## stilts. A downpipe feeds a swivel collar under it, and the gun is a plank flume
## with a sluice gate, rack and crank wheel; water runs in its bed. A ladder, a
## level board and sandbags round the feet.
static func _flood_gate(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 821
	var base := MeshKit.begin()
	var tank_y := 1.85
	var tank_r := 0.62
	var tank_h := 1.0
	var tc := Vector3(0, tank_y, 0.45)
	# Stilts: four heavy timber legs, splayed, cross-braced, on stone footings.
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var foot := Vector3(x * 0.62, 0.0, tc.z + z * 0.6)
			var top := Vector3(x * 0.44, tank_y, tc.z + z * 0.44)
			MeshKit.add_limb(base, foot, top, 0.075, Palette.WOOD_DARK, 6)
			MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, rng.randf()), foot + Vector3(0, 0.06, 0)), Vector3(0.26, 0.12, 0.26), Palette.ROCK_C.darkened(0.35), 0.03, rng)
	for side in 4:
		var b := Basis(Vector3.UP, side * PI * 0.5)
		var a0 := tc + b * Vector3(-0.56, 0, 0.56) - Vector3(0, tank_y - 0.3, 0)
		var a1 := tc + b * Vector3(0.46, 0, 0.46) - Vector3(0, 0.2, 0)
		var c0 := tc + b * Vector3(0.56, 0, 0.56) - Vector3(0, tank_y - 0.3, 0)
		var c1 := tc + b * Vector3(-0.46, 0, 0.46) - Vector3(0, 0.2, 0)
		MeshKit.add_limb(base, a0, a1, 0.03, Palette.WOOD, 4)
		MeshKit.add_limb(base, c0, c1, 0.03, Palette.WOOD, 4)
	# Joists under the tank.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), tc + Vector3(s * 0.3, -0.06, 0)), Vector3(0.12, 0.12, 1.1), Palette.WOOD_DARK, 0.01, rng)
	# The tank: staves, iron hoops (one painted team colour), a rim, water inside.
	MeshKit.lathe(base, Transform3D(Basis(), tc), [Vector2(tank_r - 0.04, 0.0), Vector2(tank_r, 0.06), Vector2(tank_r + 0.02, tank_h * 0.5),
			Vector2(tank_r, tank_h - 0.04), Vector2(tank_r - 0.03, tank_h)], 20, Palette.WOOD)
	for i in 20:
		var a := TAU * (float(i) + 0.5) / 20.0
		MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, -a), tc + Vector3(cos(a) * (tank_r + 0.012), tank_h * 0.5, sin(a) * (tank_r + 0.012))),
				Vector3(0.012, tank_h * 0.94, 0.012), Palette.WOOD_DARK)
	for y: float in [0.12, 0.45, 0.8]:
		MeshKit.add_cylinder(base, Transform3D(Basis(), tc + Vector3(0, y, 0)), tank_r + 0.035, tank_r + 0.035, 0.05, 20, team if y == 0.45 else IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), tc + Vector3(0, tank_h - 0.06, 0)), tank_r - 0.06, tank_r - 0.06, 0.02, 20, WATER, true)
	# Cone roof of shingles with an overhang, a vent cap and the team pennant.
	var roof := tc + Vector3(0, tank_h + 0.06, 0)
	MeshKit.add_cylinder(base, Transform3D(Basis(), roof + Vector3(0, 0.25, 0)), tank_r + 0.14, 0.08, 0.5, 20, Palette.ROOF)
	for k in 3:
		MeshKit.add_cylinder(base, Transform3D(Basis(), roof + Vector3(0, 0.04 + k * 0.15, 0)), tank_r + 0.15 - k * 0.2, tank_r + 0.15 - k * 0.2, 0.025, 20, Palette.ROOF.darkened(0.2))
	MeshKit.add_cylinder(base, Transform3D(Basis(), roof + Vector3(0, 0.55, 0)), 0.09, 0.09, 0.12, 10, IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), roof + Vector3(0, 0.63, 0)), 0.14, 0.0, 0.08, 10, IRON.darkened(0.2))
	TurretBuilder._pennant(base, roof + Vector3(0, 0.66, 0), 0.9, team)
	# Downpipe from the tank bottom into the head's collar, with a flange.
	MeshKit.tube(base, [tc + Vector3(0, 0.05, -0.3), tc + Vector3(0, -0.12, -0.36), Vector3(0, 1.62, 0.02), Vector3(0, 1.45, 0.0)], [0.1, 0.1, 0.1, 0.1], 10, IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), tc + Vector3(0, -0.06, -0.33)), 0.15, 0.15, 0.04, 12, BRASS.darkened(0.2))
	_rivet_ring(base, tc + Vector3(0, 0, -0.33), -0.04, 0.13, 6)
	# Ladder up the back, and a level board: a float rod showing how full it is.
	for s: float in [-0.17, 0.17]:
		MeshKit.add_limb(base, Vector3(s, 0.0, tc.z + tank_r + 0.1), Vector3(s, tank_y + tank_h + 0.1, tc.z + tank_r + 0.06), 0.025, Palette.WOOD, 4)
	for i in 9:
		var f := (float(i) + 0.6) / 9.6
		var z := lerpf(tc.z + tank_r + 0.1, tc.z + tank_r + 0.06, f)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, f * (tank_y + tank_h + 0.1), z)), Vector3(0.36, 0.03, 0.03), Palette.WOOD_DARK)
	var board := tc + Vector3(tank_r * 0.72, 0.5, tank_r * 0.72)
	var face := Basis(Vector3.UP, -PI * 0.25)
	MeshKit.add_box(base, Transform3D(face, board + face * Vector3(0, 0, 0.04)), Vector3(0.16, 0.7, 0.02), Palette.BONE)
	for k in 5:
		MeshKit.add_box(base, Transform3D(face, board + face * Vector3(-0.03, -0.28 + k * 0.14, 0.052)), Vector3(0.08, 0.012, 0.004), SOOT)
	MeshKit.add_box(base, Transform3D(face, board + face * Vector3(0.04, 0.24, 0.056)), Vector3(0.07, 0.05, 0.006), CHILI)
	# Sandbags round the feet and a spare bucket.
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.3
		var p := Vector3(cos(a) * 0.82, 0.12, tc.z + sin(a) * 0.72)
		if p.z > 0.9 or p.z < -0.2:
			continue
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.17, 0.12, 0.28), 4, 8, Palette.SAND.darkened(0.12 + rng.randf() * 0.1), 0.06, rng)
	MeshKit.lathe(base, Transform3D(Basis(), Vector3(0.62, 0.0, -0.45)), [Vector2(0.11, 0.0), Vector2(0.14, 0.24), Vector2(0.145, 0.26)], 10, Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.62, 0.2, -0.45)), 0.14, 0.14, 0.02, 10, IRON)
	# Head: the swivel collar the flume turns on, with a stub up to the downpipe.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.17, 0.19, 0.16, 14, IRON)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.2, 0.2, 0.04, 14, BRASS)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.25, 0)), 0.12, 0.12, 0.3, 12, IRON.lightened(0.08))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.27, 0.0, 0.0)), Vector3(0.05, 0.22, 0.16), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, -0.02, 0.17)), Vector3(0.36, 0.1, 0.03), team)
	# Gun: the flume, a plank trough with iron straps and water running in it,
	# a lifted sluice gate in a frame with a rack and crank wheel at its back.
	var gun := MeshKit.begin()
	var length := 1.45
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.08, -length * 0.5)), Vector3(0.5, 0.05, length), Palette.WOOD, 0.01, rng)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(s * 0.25, 0.05, -length * 0.5)), Vector3(0.05, 0.28, length), Palette.WOOD.darkened(0.08), 0.01, rng)
	for z: float in [-0.25, -0.75, -1.25]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.112, z)), Vector3(0.56, 0.02, 0.06), IRON)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_box(gun, Transform3D(Basis(), Vector3(s * 0.28, 0.04, z)), Vector3(0.02, 0.3, 0.06), IRON)
			MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(s * 0.292, 0.12, z)), Vector3.ONE * 0.015, 3, 5, BRASS)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.045, -length * 0.5 - 0.02)), Vector3(0.43, 0.02, length - 0.06), WATER, 0.0, null, 0.15)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, -0.11, -length - 0.07)), Vector3(0.5, 0.04, 0.18), Palette.WOOD_DARK)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(s * 0.27, 0.3, 0.02)), Vector3(0.06, 0.8, 0.07), Palette.WOOD_DARK)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.7, 0.02)), Vector3(0.6, 0.07, 0.08), Palette.WOOD_DARK)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.36, 0.03)), Vector3(0.46, 0.4, 0.05), Palette.WOOD.darkened(0.15), 0.01, rng)
	for y: float in [0.22, 0.48]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, y, 0.06)), Vector3(0.47, 0.04, 0.015), IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0.12, 0.62, 0.06)), Vector3(0.04, 0.5, 0.03), IRON.lightened(0.1))
	for k in 6:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0.12, 0.42 + k * 0.07, 0.08)), Vector3(0.05, 0.02, 0.015), IRON.darkened(0.2))
	_hand_wheel(gun, Transform3D(ACROSS, Vector3(0.36, 0.58, 0.04)), 0.14, 5, IRON)
	MeshKit.add_limb(gun, Vector3(0.38, 0.58, 0.04), Vector3(0.38, 0.7, 0.14), 0.015, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.43, 0.7, 0.14)), 0.025, 0.025, 0.1, 6, Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.02, "head_y": 1.1, "gun_y": 0.0, "muzzle": Vector3(0, 0.0, -length - 0.1)}


# ------------------------------------------------------------------ Twin Mortar

## Twin Mortar: two stubby tubes on one trunnion carriage, an iron blast tube and a
## chili-red fire tube, on a turntable over a plank deck ringed with sandbags. A
## shell rack holds both kinds: black round bombs with fuses and red-nosed chili shells.
static func _twin_mortar(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 831
	var base := MeshKit.begin()
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.78, 0.82, 0.2, 18, Palette.WOOD_DARK)
	for i in 7:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(-0.6 + i * 0.2, 0.21, 0)), Vector3(0.18, 0.03, 1.3 - absf(i - 3) * 0.12), Palette.WOOD.darkened(rng.randf() * 0.12), 0.01, rng)
	for i in 11:
		var a := TAU * float(i) / 12.0 + 0.4
		if absf(a - PI * 1.5) < 0.5:
			continue # a gap toward the canyon for the barrels
		var p := Vector3(cos(a) * 0.92, 0.2, sin(a) * 0.92)
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.18, 0.17, 0.3), 4, 8, Palette.SAND.darkened(0.12 + rng.randf() * 0.12), 0.08, rng)
		MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, -a), p + Vector3(0, 0.16, 0)), Vector3(0.04, 0.02, 0.28), Palette.WOOD_DARK)
	# Shell rack at the back: a little A-frame of planks.
	var rack := Vector3(0.0, 0.22, 0.55)
	MeshKit.add_box(base, Transform3D(Basis(), rack + Vector3(0, 0.06, 0)), Vector3(0.7, 0.04, 0.22), Palette.WOOD)
	MeshKit.add_box(base, Transform3D(Basis(), rack + Vector3(0, 0.28, 0)), Vector3(0.7, 0.04, 0.22), Palette.WOOD)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), rack + Vector3(s * 0.36, 0.2, 0)), Vector3(0.04, 0.4, 0.22), Palette.WOOD_DARK)
	for i in 3:
		var p := rack + Vector3(-0.22 + i * 0.22, 0.15, 0)
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), p), Vector3.ONE * 0.075, 5, 10, SOOT)
		MeshKit.add_cylinder(base, Transform3D(Basis(), p + Vector3(0, 0.08, 0)), 0.02, 0.02, 0.03, 6, BRASS)
		MeshKit.add_limb(base, p + Vector3(0, 0.09, 0), p + Vector3(0.03, 0.13, 0.02), 0.006, Palette.BONE, 3)
	for i in 3:
		var p := rack + Vector3(-0.22 + i * 0.22, 0.38, 0)
		MeshKit.add_cylinder(base, Transform3D(Basis(), p), 0.06, 0.06, 0.14, 10, CHILI)
		MeshKit.add_cylinder(base, Transform3D(Basis(), p + Vector3(0, 0.1, 0)), 0.06, 0.0, 0.07, 10, Palette.GLOW_YELLOW.darkened(0.15))
		MeshKit.add_cylinder(base, Transform3D(Basis(), p + Vector3(0, -0.03, 0)), 0.062, 0.062, 0.02, 10, BRASS)
	TurretBuilder._pennant(base, Vector3(-0.66, 0.22, 0.45), 1.3, team)
	# Head: a turntable, two tall trunnion cheeks and the elevation screw.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.5, 0.5, 0.1, 18, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.52, 0.52, 0.03, 18, IRON)
	_rivet_ring(head, Vector3.ZERO, 0.08, 0.5, 14)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.5, 0.22, 0)), Vector3(0.07, 0.36, 0.34), IRON)
		MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(s * 0.5, 0.15, 0.15)), Vector3(0.07, 0.2, 0.2), IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.54, 0.3, 0)), 0.07, 0.07, 0.04, 12, BRASS)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.08, 0.36)), Vector3(0.44, 0.14, 0.04), team)
	MeshKit.add_cylinder(head, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.18, 0.18)), 0.03, 0.03, 0.3, 8, IRON.lightened(0.15))
	_hand_wheel(head, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.3, 0.24)), 0.09, 4, IRON)
	# Gun: the axle and the two tubes, braced together.
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.06, 0.06, 1.0, 10, IRON)
	for tube in 2:
		var x := -0.26 if tube == 0 else 0.26
		var col := IRON.darkened(0.25) if tube == 0 else CHILI
		var band := BRASS if tube == 0 else Palette.GLOW_YELLOW.darkened(0.2)
		MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(x, 0, 0.1)), Vector3(0.2, 0.2, 0.2), 5, 12, col.darkened(0.2))
		MeshKit.lathe(gun, Transform3D(OUT, Vector3(x, 0, 0.1)), [Vector2(0.2, 0.0), Vector2(0.21, 0.12), Vector2(0.18, 0.45),
				Vector2(0.17, 0.62), Vector2(0.2, 0.66), Vector2(0.2, 0.72), Vector2(0.15, 0.73)], 14, col)
		for z: float in [-0.05, -0.32]:
			MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, z)), 0.215 - z * 0.06, 0.215 - z * 0.06, 0.045, 14, band)
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, -0.62)), 0.15, 0.15, 0.01, 14, SOOT.darkened(0.4))
	# A flame stencil on the fire tube, a skull-ish blast mark on the iron one.
	for k in 3:
		MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0.26 - 0.06 + k * 0.06, 0.19, -0.18 - (k % 2) * 0.03)), 0.02, 0.0, 0.08 + (k % 2) * 0.04, 6, Palette.GLOW_YELLOW)
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(-0.26, 0.185, -0.18)), Vector3(0.045, 0.012, 0.045), 3, 8, Palette.BONE)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.0, -0.2)), Vector3(0.18, 0.08, 0.1), IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.0, -0.45)), Vector3(0.18, 0.06, 0.08), IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.12, "head_y": 0.3, "gun_y": 0.3, "muzzle": Vector3(0, 0, -0.66)}


# ------------------------------------------------------------------ Bola Launcher

## Bola Launcher: a spring gun on a post. A flared wooden barrel with brass bands,
## a big coil spring and winding crank along its top, a revolving drum of bolas
## over the breech (it spins round as it fires) and a bola peeking out of the mouth.
## A basket of spare bolas and a coil of rope stand on the platform.
static func _bola_launcher(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 841
	var base := MeshKit.begin()
	TurretBuilder._platform(base, rng, 0.6)
	var deck := 0.68
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, deck + 0.28, 0)), 0.1, 0.14, 0.56, 10, Palette.WOOD_DARK)
	for a: float in [0.4, 2.5, 4.6]:
		MeshKit.add_limb(base, Vector3(cos(a) * 0.4, deck, sin(a) * 0.4), Vector3(cos(a) * 0.08, deck + 0.4, sin(a) * 0.08), 0.035, Palette.WOOD_DARK, 5)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, deck + 0.56, 0)), 0.16, 0.16, 0.04, 12, BRASS.darkened(0.15))
	# A woven basket of spare bolas.
	var basket := Vector3(0.42, deck, 0.4)
	MeshKit.lathe(base, Transform3D(Basis(), basket), [Vector2(0.15, 0.0), Vector2(0.2, 0.18), Vector2(0.22, 0.26), Vector2(0.2, 0.28)], 12, Color("#C8A878"))
	for k in 3:
		MeshKit.add_cylinder(base, Transform3D(Basis(), basket + Vector3(0, 0.05 + k * 0.08, 0)), 0.17 + k * 0.022, 0.18 + k * 0.022, 0.02, 12, Color("#9A7A50"))
	for i in 3:
		var a := TAU * float(i) / 3.0
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), basket + Vector3(cos(a) * 0.09, 0.27, sin(a) * 0.09)), Vector3(0.06, 0.055, 0.06), 4, 8, LEATHER.lightened(0.05 * i))
	MeshKit.tube(base, [basket + Vector3(0.05, 0.3, 0.05), basket + Vector3(0.18, 0.34, 0.1), basket + Vector3(0.26, 0.2, 0.08), basket + Vector3(0.3, 0.02, 0.05)],
			[0.012, 0.012, 0.012, 0.012], 4, ROPE)
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), basket + Vector3(0.3, 0.05, 0.05)), Vector3.ONE * 0.055, 4, 8, LEATHER)
	_bola(base, Vector3(-0.4, deck + 0.05, -0.42), 0.6)
	_rope_coil(base, Vector3(-0.45, deck, 0.38), 0.2, 4)
	TurretBuilder._pennant(base, Vector3(0.62, deck, -0.55), 1.35, team)
	# Head: a wooden yoke on a brass ring, team plate on the back.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.24, 0.26, 0.1, 14, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.25, 0.25, 0.025, 14, BRASS)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.21, 0.17, 0)), Vector3(0.06, 0.28, 0.2), Palette.WOOD)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.245, 0.22, 0)), 0.045, 0.045, 0.03, 10, IRON)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.12, 0.2)), Vector3(0.36, 0.14, 0.03), team)
	# Gun: the barrel (flared, brass-banded), stock, spring, crank and the bola in its mouth.
	var gun := MeshKit.begin()
	MeshKit.lathe(gun, Transform3D(OUT, Vector3(0, 0, 0.17)), [Vector2(0.12, 0.0), Vector2(0.13, 0.08), Vector2(0.12, 0.67),
			Vector2(0.15, 0.83), Vector2(0.2, 0.93), Vector2(0.21, 0.97), Vector2(0.17, 0.98)], 14, Palette.WOOD)
	for z: float in [0.1, -0.25, -0.55]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.135, 0.135, 0.04, 14, BRASS)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.79)), 0.205, 0.205, 0.04, 14, IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.8)), 0.15, 0.15, 0.02, 14, SOOT.darkened(0.3))
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.05, 0.05, 0.46, 8, IRON)
	# A bola waiting in the mouth: two weights showing and the rope between.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(s * 0.075, -0.02, -0.76)), Vector3.ONE * 0.065, 4, 8, LEATHER)
		MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(s * 0.075, -0.02, -0.76)), 0.067, 0.067, 0.014, 8, ROPE_DARK)
	MeshKit.tube(gun, [Vector3(-0.075, -0.02, -0.76), Vector3(0, 0.03, -0.79), Vector3(0.075, -0.02, -0.76)], [0.012, 0.012, 0.012], 4, ROPE)
	# The coil spring along the top, and its winding crank on the right.
	var spring: Array = []
	var radii: Array = []
	for i in 61:
		var u := float(i) / 60.0
		var a := u * TAU * 9.0
		spring.append(Vector3(cos(a) * 0.055, 0.2 + sin(a) * 0.055, lerpf(0.12, -0.5, u)))
		radii.append(0.011)
	MeshKit.tube(gun, spring, radii, 4, IRON.lightened(0.2))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.2, -0.19)), 0.012, 0.012, 0.74, 5, IRON)
	for z: float in [0.15, -0.53]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.15, z)), Vector3(0.05, 0.12, 0.04), IRON)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.15, 0.0, -0.1)), 0.045, 0.045, 0.08, 10, BRASS)
	MeshKit.add_limb(gun, Vector3(0.19, 0.0, -0.1), Vector3(0.19, -0.14, -0.02), 0.017, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.23, -0.14, -0.02)), 0.025, 0.025, 0.08, 6, Palette.WOOD)
	# Stock and a trigger lever.
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.08, 0.62)), Vector3(0.1, 0.16, 0.34), Palette.WOOD_DARK, 0.01, rng)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.47)), Vector3(0.12, 0.12, 0.04), IRON)
	MeshKit.add_limb(gun, Vector3(0, -0.15, 0.45), Vector3(0, -0.25, 0.5), 0.012, IRON, 4)
	# Spin: the drum of bolas over the breech, five chambers each with a weight showing.
	var spin := MeshKit.begin()
	MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3.ZERO), 0.15, 0.15, 0.3, 14, Palette.WOOD_DARK)
	for z: float in [-0.14, 0.14]:
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, z)), 0.16, 0.16, 0.03, 14, BRASS)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var c := Vector3(cos(a) * 0.095, sin(a) * 0.095, -0.155)
		MeshKit.add_cylinder(spin, Transform3D(ALONG, c), 0.042, 0.042, 0.02, 8, SOOT)
		MeshKit.add_ellipsoid(spin, Transform3D(Basis(), c + Vector3(0, 0, -0.01)), Vector3.ONE * 0.035, 3, 7, LEATHER.lightened(0.1))
	MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3.ZERO), 0.03, 0.03, 0.36, 6, IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0.0, 0.32), "recoil": 0.1,
			"head_y": deck + 0.6, "gun_y": 0.22, "muzzle": Vector3(0, 0, -0.85)}
