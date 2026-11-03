class_name TrainMeshes
extends RefCounted
## Story chapter 10, The Reckoning: the Iron Mandible, the Western Plains &
## Pacific board's armoured harvest train, and the railroad it rides in on.
## Cars (each a vertex-coloured mesh, origin on the rails at the car's middle,
## +Z the way it travels):
##   locomotive: an armoured 4-6-0 under riveted gunmetal plate, a slab-sided
##     boiler casing, a flared armoured stack, slit-windowed cab, a big
##     headlamp and, for a cowcatcher, two huge curved iron MANDIBLES with
##     teeth either side of a wedge plow (the train's name).
##   tender: plated, heaped with coal.
##   charge car: a red armoured boxcar, door slid open on crates of railroad
##     dynamite, drums of powder and a folded drill boom on the roof.
##   furnace car: a flatcar carrying the amber furnace, a riveted iron kiln
##     with a tall stack, a firebox door each side (glowing when lit; iron
##     shutters over them when not), hoppers of raw amber, pipes.
##   private car: Vane's own car, maroon with gold lining, lit windows, a
##     clerestory roof and a brass-railed observation platform at the back,
##     iron plate bolted over its lower half.
## The furnace wreck replaces the furnace car once it blows.

const GUN := Color("#3A3F44")
const GUN_DARK := Color("#26292C")
const RIVET := Color("#5C6268")
const RUST := Color("#7A4630")
const BRASS := Color("#D9A93E")
const RED := Color("#8C1E24")
const MAROON := Color("#4E1A20")
const GOLD := Color("#E8C55A")
const WHEEL := Color("#9E2B25")
const AMBER := Color("#FFA62B")
const LAMP := Color("#FFE7A0")
const WINDOW := Color("#FFD48A")
const SOOT := Color("#1E1C1E")
## Car lengths (metres) and the gap between cars.
const LENGTHS := {"loco": 13.0, "tender": 7.0, "charges": 9.0, "furnace": 11.0, "private": 11.0}
const GAP := 1.1
## The furnace's firebox doors (furnace car frame): one each side.
const DOORS: Array[Vector3] = [Vector3(1.55, 2.6, 0.0), Vector3(-1.55, 2.6, 0.0)]
## The kiln's middle and the top of its stack (furnace car frame).
const KILN := Vector3(0, 3.2, 0)
const STACK_TOP := Vector3(0, 10.4, -1.2)


static func _xf(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)


static func _rivets(st: SurfaceTool, from: Vector3, to: Vector3, n: int) -> void:
	for i in n:
		var p := from.lerp(to, (i + 0.5) / float(n))
		MeshKit.add_ellipsoid(st, _xf(p), Vector3.ONE * 0.045, 2, 5, RIVET)


## A two-axle truck under a car at z, wheels of radius r.
static func _truck(st: SurfaceTool, z: float, r: float = 0.48) -> void:
	MeshKit.add_box(st, _xf(Vector3(0, r + 0.1, z)), Vector3(2.0, 0.32, 2.0), GUN_DARK)
	for zz: float in [-0.65, 0.65]:
		for s: float in [-1.0, 1.0]:
			SiteBuilder._wheel(st, Vector3(s * 0.78, r, z + zz), Vector3(s, 0, 0), r, GUN_DARK.lightened(0.05), 8)


## The car's mesh by kind ("loco", "tender", "charges", "furnace", "private", "furnace_wreck").
static func car(kind: String) -> ArrayMesh:
	match kind:
		"loco":
			return locomotive()
		"tender":
			return tender()
		"charges":
			return charge_car()
		"furnace":
			return furnace_car(false)
		"furnace_wreck":
			return furnace_car(true)
		"private":
			return private_car()
	return tender()


static func locomotive() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1890
	var half: float = float(LENGTHS["loco"]) * 0.5
	# Frame and the drivers: three big red-spoked wheels a side, rods, a pilot truck.
	MeshKit.add_box(st, _xf(Vector3(0, 1.25, 0)), Vector3(2.2, 0.45, 12.4), GUN_DARK)
	for s: float in [-1.0, 1.0]:
		for z: float in [-2.6, -0.6, 1.4]:
			SiteBuilder._wheel(st, Vector3(s * 1.0, 1.0, z), Vector3(s, 0, 0), 1.0, WHEEL, 14)
		MeshKit.add_box(st, _xf(Vector3(s * 1.2, 0.75, -0.6)), Vector3(0.08, 0.14, 4.4), Color("#8A8E92"))
		for z: float in [3.6, 4.6]:
			SiteBuilder._wheel(st, Vector3(s * 0.8, 0.5, z), Vector3(s, 0, 0), 0.5, WHEEL, 8)
		# Armoured skirts over the wheels, riveted.
		MeshKit.add_box(st, _xf(Vector3(s * 1.32, 1.55, -0.2)), Vector3(0.1, 0.9, 8.6), GUN)
		_rivets(st, Vector3(s * 1.38, 1.9, -4.4), Vector3(s * 1.38, 1.9, 4.0), 18)
	# The boiler under slab armour: a long hull with a ridged top and plate seams.
	var by := 2.9
	MeshKit.add_box(st, _xf(Vector3(0, by, 1.2)), Vector3(2.5, 2.1, 7.4), GUN)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(s * 0.7, by + 1.22, 1.2), 0.0, 0.0, -s * 0.5), Vector3(1.55, 0.14, 7.4), GUN.lightened(0.06))
		for k in 5:
			MeshKit.add_box(st, _xf(Vector3(s * 1.26, by, -2.0 + k * 1.6)), Vector3(0.03, 2.0, 0.06), GUN_DARK)
		_rivets(st, Vector3(s * 1.27, by + 0.85, -2.4), Vector3(s * 1.27, by + 0.85, 4.8), 16)
		_rivets(st, Vector3(s * 1.27, by - 0.85, -2.4), Vector3(s * 1.27, by - 0.85, 4.8), 16)
	# The smokebox front: a heavy plate with a red W.P.&P. disc and the headlamp.
	MeshKit.add_box(st, _xf(Vector3(0, by - 0.1, 4.95)), Vector3(2.7, 2.4, 0.3), GUN_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, by - 0.2, 5.12)), 0.6, 0.6, 0.06, 18, RED)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, by - 0.2, 5.14)), 0.4, 0.4, 0.06, 18, GOLD)
	var lamp := Vector3(0, by + 1.55, 4.6)
	MeshKit.add_box(st, _xf(lamp), Vector3(0.75, 0.7, 0.8), GUN_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), lamp + Vector3(0, 0, 0.42)), 0.3, 0.3, 0.05, 16, LAMP, true, 0.95)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), lamp + Vector3(0, 0, 0.43)), 0.36, 0.36, 0.06, 16, BRASS, false)
	# The armoured stack: tall and flared, a soot-black lip.
	MeshKit.lathe(st, _xf(Vector3(0, by + 1.0, 3.6)), [Vector2(0.38, 0.0), Vector2(0.34, 0.8), Vector2(0.4, 1.4), Vector2(0.72, 2.2),
			Vector2(0.76, 2.35), Vector2(0.5, 2.5)], 12, GUN_DARK)
	MeshKit.add_cylinder(st, _xf(Vector3(0, by + 3.5, 3.6)), 0.5, 0.5, 0.05, 12, SOOT)
	# A domed sand box and a brass bell.
	MeshKit.lathe(st, _xf(Vector3(0, by + 1.15, 1.6)), [Vector2(0.45, 0.0), Vector2(0.4, 0.3), Vector2(0.25, 0.5), Vector2(0.0, 0.56)], 12, GUN.lightened(0.05))
	MeshKit.lathe(st, _xf(Vector3(0, by + 1.2, 0.2)), [Vector2(0.0, 0.0), Vector2(0.24, 0.02), Vector2(0.2, 0.2), Vector2(0.14, 0.36), Vector2(0.03, 0.42)], 12, BRASS)
	# The cab: armoured box, slit windows glowing faintly, a heavy roof.
	var cab := Vector3(0, 0, -4.0)
	MeshKit.add_box(st, _xf(cab + Vector3(0, 3.0, 0)), Vector3(2.9, 3.2, 3.2), GUN)
	MeshKit.add_box(st, _xf(cab + Vector3(0, 4.7, 0)), Vector3(3.3, 0.22, 3.6), GUN_DARK)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(cab + Vector3(s * 1.46, 3.5, 0.4)), Vector3(0.02, 0.16, 1.4), WINDOW, 0.0, null, 0.5)
		_rivets(st, cab + Vector3(s * 1.47, 1.6, -1.5), cab + Vector3(s * 1.47, 1.6, 1.5), 8)
		_rivets(st, cab + Vector3(s * 1.47, 4.45, -1.5), cab + Vector3(s * 1.47, 4.45, 1.5), 8)
	MeshKit.add_box(st, _xf(cab + Vector3(0, 3.5, 1.61)), Vector3(1.8, 0.16, 0.02), WINDOW, 0.0, null, 0.5)
	# The mandibles: two great curved iron jaws out front, toothed, either side of a wedge plow.
	for s: float in [-1.0, 1.0]:
		var pts := [Vector3(s * 1.25, 1.3, 4.9), Vector3(s * 1.9, 1.2, 6.0), Vector3(s * 1.7, 1.0, 7.3), Vector3(s * 0.7, 0.8, 8.3), Vector3(s * 0.15, 0.75, 8.6)]
		var radii := [0.34, 0.3, 0.24, 0.16, 0.07]
		MeshKit.tube(st, pts, radii, 8, GUN_DARK.lightened(0.08))
		for k in 4:
			var p: Vector3 = (pts[1] as Vector3).lerp(pts[3], 0.15 + k * 0.25)
			var inward := Vector3(-s, 0.0, 0.25).normalized()
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(inward), p + inward * 0.2), 0.11, 0.0, 0.4, 6, RIVET.lightened(0.2))
		MeshKit.add_ellipsoid(st, _xf(Vector3(s * 1.3, 1.3, 4.95)), Vector3(0.45, 0.45, 0.3), 4, 8, GUN_DARK)
	MeshKit.add_box(st, _xf(Vector3(0, 0.75, half - 0.2), 0.0, -0.5), Vector3(2.0, 0.12, 1.6), GUN.lightened(0.04))
	return MeshKit.finish(st)


static func tender() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	MeshKit.add_box(st, _xf(Vector3(0, 1.15, 0)), Vector3(2.4, 0.3, 6.6), GUN_DARK)
	MeshKit.add_box(st, _xf(Vector3(0, 2.3, 0)), Vector3(2.8, 2.0, 6.4), GUN)
	for s: float in [-1.0, 1.0]:
		_rivets(st, Vector3(s * 1.42, 3.1, -3.0), Vector3(s * 1.42, 3.1, 3.0), 12)
		_rivets(st, Vector3(s * 1.42, 1.5, -3.0), Vector3(s * 1.42, 1.5, 3.0), 12)
	for k in 22:
		MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-1.1, 1.1), 3.35 + rng.randf() * 0.3, rng.randf_range(-2.8, 2.6)), rng.randf() * TAU), Vector3(0.32, 0.2, 0.28), 3, 6, SOOT.lightened(rng.randf() * 0.08), 0.2, rng)
	_truck(st, -2.1)
	_truck(st, 2.1)
	return MeshKit.finish(st)


static func charge_car() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 1.15, 0)), Vector3(2.4, 0.3, 8.6), GUN_DARK)
	# A red armoured box, its door slid open on the near side.
	var h := 3.0
	MeshKit.add_box(st, _xf(Vector3(0, 1.3 + h * 0.5, 0)), Vector3(2.7, h, 8.4), RED)
	MeshKit.add_box(st, _xf(Vector3(0, 1.3 + h + 0.1, 0)), Vector3(2.9, 0.2, 8.6), GUN_DARK)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, _xf(Vector3(s * 1.36, 1.6, 0)), Vector3(0.06, 0.5, 8.4), GUN)
		_rivets(st, Vector3(s * 1.4, 1.6, -4.0), Vector3(s * 1.4, 1.6, 4.0), 16)
	# The open doorway (dark) and the door slid back beside it.
	MeshKit.add_box(st, _xf(Vector3(1.36, 2.7, 0.6)), Vector3(0.04, 2.3, 2.4), Color("#1A1210"))
	MeshKit.add_box(st, _xf(Vector3(1.42, 2.7, -2.0)), Vector3(0.06, 2.4, 2.5), RED.darkened(0.15))
	# Dynamite crates and powder drums inside the door.
	for k in 3:
		DownTheHole.crate_mesh(st, _xf(Vector3(0.7, 1.3 + (k % 2) * 0.62, -0.2 + k * 0.7), k * 0.2))
	for k in 2:
		MeshKit.add_cylinder(st, _xf(Vector3(0.6, 1.75, 1.6 + k * 0.6)), 0.3, 0.3, 0.9, 10, Color("#3A2A20"))
	# A folded drill boom on the roof.
	MeshKit.add_box(st, _xf(Vector3(0, 4.6, 0.5)), Vector3(0.4, 0.4, 7.0), GUN_DARK)
	MeshKit.add_cylinder(st, _xf(Vector3(0, 4.6, 4.2), 0.0, PI * 0.5), 0.18, 0.0, 0.8, 8, RIVET)
	_truck(st, -2.9)
	_truck(st, 2.9)
	return MeshKit.finish(st)


## The furnace car (whole, or `wrecked`: the kiln burst, the stack down, scorched).
static func furnace_car(wrecked: bool) -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891
	MeshKit.add_box(st, _xf(Vector3(0, 1.2, 0)), Vector3(2.9, 0.4, 10.6), GUN_DARK)
	_truck(st, -3.6)
	_truck(st, 3.6)
	if not wrecked:
		# The kiln: a riveted iron drum on a firebox base, a cone top and the stack.
		MeshKit.add_box(st, _xf(Vector3(0, 2.0, 0)), Vector3(3.0, 1.4, 3.4), GUN_DARK)
		MeshKit.add_cylinder(st, _xf(KILN + Vector3(0, 0.6, 0)), 1.55, 1.45, 3.4, 18, GUN)
		for k in 4:
			MeshKit.add_cylinder(st, _xf(Vector3(0, 2.0 + k * 0.85, 0)), 1.58, 1.58, 0.1, 18, RIVET, false)
		MeshKit.add_cylinder(st, _xf(Vector3(0, 5.75, 0)), 1.5, 0.5, 0.9, 18, GUN_DARK)
		MeshKit.add_cylinder(st, _xf(Vector3(0, 8.1, -1.2)), 0.42, 0.5, 4.6, 12, GUN_DARK)
		MeshKit.add_limb(st, Vector3(0, 6.0, 0), Vector3(0, 6.4, -1.2), 0.5, GUN_DARK, 8)
		MeshKit.add_cylinder(st, _xf(STACK_TOP + Vector3(0, -0.1, 0)), 0.62, 0.62, 0.18, 12, SOOT)
		# Door frames (the glow and the shutters are separate meshes).
		for d in DOORS:
			var s := signf(d.x)
			MeshKit.add_box(st, _xf(d + Vector3(s * 0.02, 0, 0)), Vector3(0.12, 1.2, 1.3), RIVET.darkened(0.3))
		# Amber hoppers at both ends of the deck, heaped with raw amber.
		for z: float in [-4.0, 4.0]:
			MeshKit.add_box(st, _xf(Vector3(0, 2.0, z)), Vector3(2.4, 1.2, 2.0), GUN)
			for q in 9:
				MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-0.9, 0.9), 2.7 + rng.randf() * 0.2, z + rng.randf_range(-0.7, 0.7)), rng.randf() * TAU), Vector3(0.24, 0.16, 0.2), 3, 6, AMBER.darkened(rng.randf() * 0.2), 0.0, null, 0.45)
		# Pipes from the hoppers to the kiln.
		for z: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(0.6, 2.8, z * 3.0), Vector3(0.6, 3.6, z * 1.4), 0.12, RUST, 6)
		MeshKit.add_box(st, _xf(Vector3(0, 1.45, 5.2)), Vector3(2.2, 0.1, 0.3), RED)
	else:
		# Burst open: the drum split and peeled, the stack fallen across the deck,
		# the hoppers spilled, everything soot-black.
		MeshKit.add_box(st, _xf(Vector3(0, 1.8, 0), 0.0, 0.0, 0.15), Vector3(3.0, 1.2, 3.4), SOOT.lightened(0.05))
		for k in 7:
			var a := TAU * k / 7.0 + 0.3
			var p := Vector3(cos(a) * 1.2, 3.0, sin(a) * 1.2)
			var out := Vector3(cos(a), 0.35, sin(a)).normalized()
			MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(out.rotated(Vector3.UP, 0.2) + Vector3.UP * 0.6), p + out * 0.4),
					Vector3(1.2, 2.2 - k * 0.15, 0.08), SOOT.lightened(rng.randf() * 0.1), 0.06, rng)
		MeshKit.add_limb(st, Vector3(0.6, 2.2, -1.0), Vector3(2.8, 0.8, -6.0), 0.46, SOOT, 8)
		for q in 18:
			MeshKit.add_ellipsoid(st, _xf(Vector3(rng.randf_range(-2.5, 2.5), 1.45 + rng.randf() * 0.3, rng.randf_range(-5.0, 5.0)), rng.randf() * TAU), Vector3(0.22, 0.14, 0.18), 3, 6, AMBER.darkened(0.2 + rng.randf() * 0.3), 0.0, null, 0.35)
		# Embers still glowing in the burst firebox.
		MeshKit.add_ellipsoid(st, _xf(Vector3(0, 2.4, 0)), Vector3(1.0, 0.4, 1.2), 4, 10, Color("#FF6A2B"), 0.0, null, 0.85)
	return MeshKit.finish(st)


## The furnace's firebox doors as one glowing mesh (shown while it burns).
static func door_glow() -> ArrayMesh:
	var st := MeshKit.begin()
	for d in DOORS:
		var s := signf(d.x)
		MeshKit.add_box(st, _xf(d + Vector3(s * 0.08, 0, 0)), Vector3(0.04, 1.0, 1.1), AMBER, 0.0, null, 0.95)
		for k in 3:
			MeshKit.add_box(st, _xf(d + Vector3(s * 0.1, -0.3 + k * 0.3, 0)), Vector3(0.03, 0.06, 1.1), GUN_DARK)
	return MeshKit.finish(st)


## Iron shutters bolted over the doors (before the furnace is stoked).
static func shutters() -> ArrayMesh:
	var st := MeshKit.begin()
	for d in DOORS:
		var s := signf(d.x)
		MeshKit.add_box(st, _xf(d + Vector3(s * 0.12, 0, 0)), Vector3(0.08, 1.24, 1.36), GUN.lightened(0.05))
		_rivets(st, d + Vector3(s * 0.17, 0.5, -0.55), d + Vector3(s * 0.17, 0.5, 0.55), 5)
		_rivets(st, d + Vector3(s * 0.17, -0.5, -0.55), d + Vector3(s * 0.17, -0.5, 0.55), 5)
	return MeshKit.finish(st)


static func private_car() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, _xf(Vector3(0, 1.15, 0)), Vector3(2.4, 0.3, 10.2), GUN_DARK)
	# The body: maroon with gold lining, a row of lit windows, iron plate below.
	MeshKit.add_box(st, _xf(Vector3(0, 2.75, -0.4)), Vector3(2.8, 2.9, 9.0), MAROON)
	MeshKit.add_box(st, _xf(Vector3(0, 1.85, -0.4)), Vector3(2.9, 1.1, 9.1), GUN)
	for s: float in [-1.0, 1.0]:
		_rivets(st, Vector3(s * 1.46, 2.3, -4.8), Vector3(s * 1.46, 2.3, 4.0), 16)
		MeshKit.add_box(st, _xf(Vector3(s * 1.41, 4.0, -0.4)), Vector3(0.02, 0.06, 9.0), GOLD)
		MeshKit.add_box(st, _xf(Vector3(s * 1.41, 2.5, -0.4)), Vector3(0.02, 0.06, 9.0), GOLD)
		for k in 7:
			MeshKit.add_box(st, _xf(Vector3(s * 1.41, 3.25, -4.0 + k * 1.2)), Vector3(0.02, 0.8, 0.7), WINDOW, 0.0, null, 0.55)
	# Clerestory roof.
	MeshKit.add_box(st, _xf(Vector3(0, 4.3, -0.4)), Vector3(3.0, 0.2, 9.3), Color("#2A1A1C"))
	MeshKit.add_box(st, _xf(Vector3(0, 4.62, -0.4)), Vector3(1.5, 0.45, 8.6), MAROON.darkened(0.2))
	MeshKit.add_box(st, _xf(Vector3(0, 4.88, -0.4)), Vector3(1.8, 0.1, 8.8), Color("#2A1A1C"))
	# The observation platform at the back, its brass rail and a lamp.
	var back: float = -float(LENGTHS["private"]) * 0.5
	MeshKit.add_box(st, _xf(Vector3(0, 1.4, back + 0.7)), Vector3(2.6, 0.12, 1.4), Palette.WOOD_DARK)
	for x in 7:
		MeshKit.add_cylinder(st, _xf(Vector3(-1.2 + x * 0.4, 1.95, back + 0.1)), 0.03, 0.03, 1.0, 6, BRASS)
	MeshKit.add_limb(st, Vector3(-1.25, 2.45, back + 0.1), Vector3(1.25, 2.45, back + 0.1), 0.05, BRASS, 6)
	MeshKit.add_ellipsoid(st, _xf(Vector3(1.1, 3.4, back + 1.45)), Vector3(0.12, 0.16, 0.12), 3, 6, WINDOW, 0.0, null, 0.9)
	_truck(st, -3.6)
	_truck(st, 3.6)
	return MeshKit.finish(st)


## The rails: ties and two rails along `route` (world points), as one mesh in
## world space, from metre `from` to metre `to` along it.
static func track(route: PackedVector3Array, from: float, to: float) -> ArrayMesh:
	var st := MeshKit.begin()
	var s := from
	var rng := RandomNumberGenerator.new()
	rng.seed = 1868
	while s <= to:
		var p := ReckoningRules.point_at(route, s)
		var d := ReckoningRules.dir_at(route, s)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, atan2(d.x, d.z) + rng.randf_range(-0.04, 0.04)), p + Vector3(0, 0.07, 0)),
				Vector3(2.5, 0.14, 0.26), Palette.WOOD_DARK.darkened(rng.randf() * 0.2))
		s += 0.9
	var step := 3.0
	s = from
	while s < to:
		var a := ReckoningRules.point_at(route, s)
		var b := ReckoningRules.point_at(route, minf(s + step, to))
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var side := d.cross(Vector3.UP).normalized()
		for k: float in [-0.75, 0.75]:
			MeshKit.add_limb(st, a + side * k + Vector3(0, 0.2, 0), b + side * k + Vector3(0, 0.2, 0), 0.06, Color("#6A6058"), 4)
		s += step
	return MeshKit.finish(st)
