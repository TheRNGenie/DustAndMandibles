class_name CrewedBuilder
extends RefCounted
## Crewed: meshes for the four 2 x 2 crewed guns, in the same parts as
## TurretBuilder (base / head / gun / optional spin, gun barrels along -Z), plus
## "seat": the gunner's eye in head space (the camera sits there when manned).
## Each fills about 3.6 m x 3.6 m: a wagon, a sledge, a mule cart, a turntable.

const ALONG := Basis(Vector3.RIGHT, PI * 0.5)
const ACROSS := Basis(Vector3.BACK, PI * 0.5)
const BRASS := Color("#D6A74A")
const IRON := Color("#4A4E58")
const HOT_IRON := Color("#5A5250")
const MULE := Color("#8E7A68")
const MULE_DARK := Color("#5E4E42")


## The gunner's eye in head space, per gun (also returned as parts["seat"]).
const SEATS := {&"big_bertha": Vector3(0, 1.72, 1.36), &"whaler": Vector3(-0.55, 1.62, 1.45),
		&"thunder_mule": Vector3(0, 1.95, 1.2), &"sky_hound": Vector3(0, 1.6, 1.3)}


## How far each gun's pivot sits toward the lip (-Z) from the middle of its 2 x 2,
## so the gunner's view clears the plateau edge and sees well down the far wall.
const HEAD_Z := {&"big_bertha": -0.8, &"whaler": -0.75, &"thunder_mule": -0.55, &"sky_hound": 0.0}


static func seat(id: StringName) -> Vector3:
	return SEATS.get(id, Vector3(0, 1.4, 1.1))


static func has(id: StringName) -> bool:
	return id in [&"big_bertha", &"whaler", &"thunder_mule", &"sky_hound"]


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"whaler":
			return _whaler(team)
		&"thunder_mule":
			return _thunder_mule(team)
		&"sky_hound":
			return _sky_hound(team)
	return _big_bertha(team)


# ------------------------------------------------------------------ pieces

## A spoked cart wheel standing at `at`, axle along X.
static func _wheel(st: SurfaceTool, at: Vector3, r: float, spokes: int = 10) -> void:
	var segs := 18
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var p0 := at + Vector3(0, sin(a0), cos(a0)) * r
		var p1 := at + Vector3(0, sin(a1), cos(a1)) * r
		MeshKit.add_limb(st, p0, p1, 0.055, Palette.WOOD_DARK, 5)
		var q0 := at + Vector3(0, sin(a0), cos(a0)) * (r + 0.03)
		var q1 := at + Vector3(0, sin(a1), cos(a1)) * (r + 0.03)
		MeshKit.add_limb(st, q0, q1, 0.03, IRON, 4)
	for i in spokes:
		var a := TAU * float(i) / spokes
		MeshKit.add_limb(st, at, at + Vector3(0, sin(a), cos(a)) * (r - 0.04), 0.025, Palette.WOOD, 4)
	MeshKit.add_cylinder(st, Transform3D(ACROSS, at), 0.11, 0.11, 0.2, 10, Palette.WOOD_DARK)
	MeshKit.add_cylinder(st, Transform3D(ACROSS, at), 0.05, 0.05, 0.28, 8, IRON)


## A tractor-style iron seat on a short post, the gunner's place (head space).
static func _seat(st: SurfaceTool, at: Vector3, team: Color) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, -0.22, 0)), 0.05, 0.05, 0.44, 6, IRON)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, 0.02, 0)), Vector3(0.24, 0.05, 0.22), 3, 10, IRON.lightened(0.15))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), at + Vector3(0, 0.2, 0.2)), Vector3(0.36, 0.3, 0.04), IRON.lightened(0.1))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), at + Vector3(0, 0.27, 0.22)), Vector3(0.37, 0.07, 0.02), team)


## A team pennant on a pole planted at `at`.
static func _flag(st: SurfaceTool, at: Vector3, h: float, team: Color) -> void:
	TurretBuilder._pennant(st, at, h, team)


## Wooden planks laid side by side (a bed or deck), `n` planks across X.
static func _planks(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, size: Vector3, n: int) -> void:
	var w := size.x / n
	for i in n:
		MeshKit.add_box(st, Transform3D(Basis(), centre + Vector3(-size.x * 0.5 + w * (i + 0.5), 0, 0)),
				Vector3(w * 0.94, size.y, size.z), Palette.WOOD.darkened(rng.randf() * 0.15), 0.015, rng)


# ------------------------------------------------------------------ Big Bertha

## A buckboard wagon with a ten-barrel crank Gatling on a pintle over the tailgate.
static func _big_bertha(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 701
	var base := MeshKit.begin()
	# Wagon bed on two axles, the tailgate toward the canyon (-Z).
	_planks(base, rng, Vector3(0, 0.95, 0.1), Vector3(1.7, 0.1, 3.1), 6)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.88, 1.18, 0.1)), Vector3(0.08, 0.38, 3.1), Palette.WOOD_DARK, 0.015, rng)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.93, 1.2, 0.1)), Vector3(0.02, 0.12, 2.6), team)
		_wheel(base, Vector3(s * 1.02, 0.6, -0.95), 0.6)
		_wheel(base, Vector3(s * 1.02, 0.6, 1.2), 0.6)
		for z: float in [-0.95, 1.2]:
			MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.55, 0.78, z)), Vector3(0.5, 0.12, 0.14), IRON)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 1.18, 1.62)), Vector3(1.7, 0.38, 0.08), Palette.WOOD_DARK)
	# Draw pole and a doubletree out back.
	MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.62, 2.2)), Vector3(0.12, 0.1, 1.3), Palette.WOOD_DARK)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.55, 2.75)), Vector3(0.9, 0.08, 0.08), Palette.WOOD_DARK)
	# Ammo crates and a water barrel for the barrels.
	TurretBuilder._crate(base, rng, Vector3(-0.5, 1.0, 1.15), Vector3(0.5, 0.32, 0.36), 0.1, BRASS)
	TurretBuilder._crate(base, rng, Vector3(-0.5, 1.32, 1.15), Vector3(0.42, 0.26, 0.3), -0.15, BRASS)
	MeshKit.lathe(base, Transform3D(Basis(), Vector3(0.55, 1.0, 1.2)), [Vector2(0.2, 0.0), Vector2(0.25, 0.25), Vector2(0.2, 0.5)], 12, Palette.WOOD)
	for y: float in [0.08, 0.42]:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.55, 1.0 + y, 1.2)), 0.225, 0.225, 0.04, 12, IRON)
	_flag(base, Vector3(0.82, 1.35, 1.55), 1.5, team)
	var head := MeshKit.begin()
	# Pintle post with a traversing ring, a riveted shield, and the gunner's seat.
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.12, 0.16, 0.3, 10, IRON)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.34, 0.34, 0.08, 14, BRASS.darkened(0.2))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.32, 0.5, 0.0)), Vector3(0.06, 0.36, 0.2), IRON)
	# Split shield: two wings either side of the barrels, so the gunner sees them glow.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(s * 0.42, 0.62, -0.48)), Vector3(0.36, 0.55, 0.05), Palette.METAL.darkened(0.15))
		MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(s * 0.42, 0.84, -0.52)), Vector3(0.36, 0.08, 0.02), team)
		TurretBuilder._rivets(head, Vector3(s * 0.42, 0.42, -0.5), Vector3.RIGHT, 3, 0.12)
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.4, -0.46)), Vector3(0.5, 0.18, 0.05), Palette.METAL.darkened(0.15))
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.12, 0.7)), Vector3(0.12, 0.08, 1.2), IRON)
	_seat(head, Vector3(0, 0.45, 1.3), team)
	var gun := MeshKit.begin()
	# Breech housing, a big Broadwell drum on top, side crank, and the barrel jacket.
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.3)), Vector3(0.42, 0.38, 0.6), Palette.METAL.darkened(0.1))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(s * 0.215, 0.12, 0.3)), Vector3(0.02, 0.06, 0.62), BRASS.darkened(0.2))
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.26, 0.18)), 0.22, 0.22, 0.09, 18, BRASS.darkened(0.25))
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.32, 0.18)), 0.06, 0.06, 0.05, 10, IRON)
	for k in 8:
		var a := TAU * float(k) / 8.0
		MeshKit.add_box(gun, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.19, 0.31, 0.18 + sin(a) * 0.19)), Vector3(0.05, 0.02, 0.03), IRON)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.3, 0.0, 0.42)), 0.04, 0.04, 0.16, 6, IRON)
	MeshKit.add_limb(gun, Vector3(0.38, 0.0, 0.42), Vector3(0.38, -0.2, 0.5), 0.025, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0.45, -0.2, 0.5)), 0.04, 0.04, 0.14, 6, Palette.WOOD)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.02)), 0.21, 0.21, 0.08, 14, BRASS)
	# Spade grips for the gunner.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(gun, Vector3(s * 0.12, 0.0, 0.6), Vector3(s * 0.16, -0.05, 0.78), 0.025, IRON, 4)
		MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(s * 0.17, -0.05, 0.8)), 0.035, 0.035, 0.16, 6, Palette.WOOD_DARK)
	var spin := MeshKit.begin()
	for i in 10:
		var a := TAU * float(i) / 10.0
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(cos(a) * 0.12, sin(a) * 0.12, -0.6)), 0.032, 0.032, 1.25, 6, HOT_IRON)
	for z: float in [-0.12, -0.7, -1.18]:
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, z)), 0.17, 0.17, 0.05, 12, BRASS if z > -1.0 else IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0, -0.08), "recoil": 0.03,
			"head_y": 1.0, "head_z": HEAD_Z[&"big_bertha"], "gun_y": 0.62, "muzzle": Vector3(0, 0, -1.35), "seat": seat(&"big_bertha")}


# ------------------------------------------------------------------ The Whaler

## A whaling ballista on a timber sledge: winch drum, chain, a barbed harpoon.
static func _whaler(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 702
	var base := MeshKit.begin()
	# Two upturned skids and a plank deck.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 1.25, 0.12, 0.0)), Vector3(0.22, 0.24, 3.3), Palette.WOOD_DARK, 0.02, rng)
		MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(s * 1.25, 0.25, -1.75)), Vector3(0.22, 0.2, 0.5), Palette.WOOD_DARK, 0.02, rng)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 1.25, 0.02, 0.0)), Vector3(0.24, 0.04, 3.2), IRON)
	_planks(base, rng, Vector3(0, 0.3, 0), Vector3(2.9, 0.12, 3.0), 8)
	# A crib of squared timbers lifts the ballista so it can look down the far wall.
	for k in 4:
		var y := 0.42 + k * 0.13
		var turn := k % 2 == 1
		for s2: float in [-1.0, 1.0]:
			var at := Vector3(s2 * 0.62, y, -0.75) if not turn else Vector3(0, y, -0.75 + s2 * 0.62)
			MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, PI * 0.5 if turn else 0.0), at), Vector3(0.2, 0.14, 1.5), Palette.WOOD.darkened(0.05 * k), 0.02, rng)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.86, -0.75)), Vector3(1.5, 0.08, 1.5), Palette.WOOD_DARK, 0.01, rng)
	# Steps up to the seat.
	for k in 3:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(-0.5, 0.42 + k * 0.15, 0.55 + (2 - k) * 0.2)), Vector3(0.6, 0.06, 0.22), Palette.WOOD)
	# Winch drum with a chain wound on, cranks either side.
	var drum := Vector3(0, 0.75, 1.15)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), drum + Vector3(s * 0.75, -0.2, 0)), Vector3(0.12, 0.6, 0.3), Palette.WOOD_DARK)
		MeshKit.add_limb(base, drum + Vector3(s * 0.85, 0, 0), drum + Vector3(s * 0.85, -0.25, 0.12), 0.03, IRON, 4)
		MeshKit.add_cylinder(base, Transform3D(ACROSS, drum + Vector3(s * 0.95, -0.25, 0.12)), 0.04, 0.04, 0.16, 6, Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(ACROSS, drum), 0.24, 0.24, 1.3, 14, Palette.WOOD)
	for k in 9:
		MeshKit.add_cylinder(base, Transform3D(ACROSS, drum + Vector3(-0.55 + k * 0.14, 0, 0)), 0.27, 0.27, 0.07, 12, IRON.lightened(0.1))
	# Spare harpoons racked on the side and a team stripe on the skid.
	for i in 2:
		var y := 0.5 + i * 0.12
		MeshKit.add_cylinder(base, Transform3D(ALONG, Vector3(-1.3, y, 0.2)), 0.025, 0.025, 1.8, 6, IRON)
		MeshKit.add_cylinder(base, Transform3D(ALONG, Vector3(-1.3, y, -0.78)), 0.07, 0.0, 0.25, 6, Palette.METAL.lightened(0.2))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 1.37, 0.14, 0.4)), Vector3(0.02, 0.1, 1.6), team)
	_flag(base, Vector3(1.25, 0.35, 1.4), 1.8, team)
	var head := MeshKit.begin()
	# Turntable with a tall timber fork carrying the trunnions, and the seat behind.
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.7, 0.75, 0.12, 16, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.13, 0)), 0.72, 0.72, 0.03, 16, IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.32, 0.5, 0)), Vector3(0.14, 0.8, 0.3), Palette.WOOD, 0.02, rng)
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.32, 0.88, 0)), Vector3(0.18, 0.08, 0.34), IRON)
	# The gunner sits to the left of the stock and sights along it.
	MeshKit.add_box(head, Transform3D(Basis(Vector3.UP, 0.35), Vector3(-0.25, 0.2, 0.62)), Vector3(0.14, 0.1, 1.0), Palette.WOOD_DARK)
	_seat(head, Vector3(-0.55, 0.62, 1.38), team)
	var gun := MeshKit.begin()
	# The stock, the great bow arms curving forward, the string, and the harpoon.
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, -0.3)), Vector3(0.22, 0.16, 2.0), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.09, -0.3)), Vector3(0.1, 0.03, 1.9), IRON)
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3(0, 0, 0)), 0.06, 0.06, 0.8, 8, IRON)
	for s: float in [-1.0, 1.0]:
		var root := Vector3(s * 0.12, 0.02, -1.05)
		var mid := Vector3(s * 0.7, 0.02, -0.95)
		var tip := Vector3(s * 1.1, 0.02, -0.7)
		MeshKit.tube(gun, [root, mid, tip], [0.07, 0.055, 0.035], 6, Palette.WOOD_DARK)
		MeshKit.add_ellipsoid(gun, Transform3D(Basis(), tip), Vector3.ONE * 0.05, 3, 6, BRASS)
		MeshKit.add_limb(gun, tip, Vector3(0, 0.08, 0.35), 0.012, Palette.BONE, 3)
		MeshKit.add_box(gun, Transform3D(Basis(), Vector3(s * 0.18, 0.0, -1.05)), Vector3(0.06, 0.22, 0.2), IRON)
	# Trigger lever and spade grips at the back.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(gun, Vector3(s * 0.08, -0.02, 0.62), Vector3(s * 0.2, -0.08, 0.78), 0.025, IRON, 4)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.12, 0.45)), Vector3(0.05, 0.16, 0.05), IRON)
	# Loaded harpoon: shaft, barbed head, and a chain lead to the drum side.
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.16, -0.65)), 0.03, 0.03, 1.8, 6, IRON.lightened(0.15))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.16, -1.68)), 0.09, 0.0, 0.32, 8, Palette.METAL.lightened(0.3))
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var d := Vector3(cos(a), sin(a), 0)
		MeshKit.add_limb(gun, Vector3(0, 0.16, -1.5) + d * 0.04, Vector3(0, 0.16, -1.38) + d * 0.14, 0.015, IRON, 3)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun), "recoil": 0.12,
			"head_y": 0.92, "head_z": HEAD_Z[&"whaler"], "gun_y": 0.92, "muzzle": Vector3(0, 0.16, -1.85), "seat": seat(&"whaler")}


# ------------------------------------------------------------------ Thunder Mule

## A two-wheel mule cart carrying a frame of three stubby mortars; the mule waits beside.
static func _thunder_mule(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 703
	var base := MeshKit.begin()
	# Cart bed and big wheels (the cart sits a little left, the mule on the right).
	var cx := -0.35
	_planks(base, rng, Vector3(cx, 0.85, 0.15), Vector3(1.9, 0.1, 2.8), 6)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(cx + s * 0.98, 1.05, 0.15)), Vector3(0.08, 0.32, 2.8), Palette.WOOD_DARK, 0.015, rng)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(cx + s * 1.03, 1.08, 0.15)), Vector3(0.02, 0.1, 2.3), team)
		_wheel(base, Vector3(cx + s * 1.12, 0.7, 0.3), 0.7, 12)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(cx, 0.6, 0.3)), Vector3(2.3, 0.1, 0.12), IRON)
	# Prop legs so the cart sits level, and the shafts toward the mule.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(cx + s * 0.6, 0.4, -1.1)), Vector3(0.1, 0.8, 0.1), Palette.WOOD_DARK)
	# Shell crates in the bed.
	for i in 2:
		TurretBuilder._crate(base, rng, Vector3(cx - 0.55 + i * 1.1, 0.9, 1.15), Vector3(0.6, 0.3, 0.4), 0.05 - i * 0.1, Color("#B8352A"))
	for i in 4:
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(cx - 0.75 + i * 0.13, 1.28, 1.15)), Vector3(0.06, 0.1, 0.06), 3, 8, IRON.darkened(0.2))
	_mule(base, Vector3(1.38, 0.0, 0.25))
	_flag(base, Vector3(cx - 0.9, 0.9, 1.5), 1.5, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.62, 0.62, 0.1, 16, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.11, 0)), 0.64, 0.64, 0.03, 16, IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.62, 0.32, -0.05)), Vector3(0.08, 0.45, 0.36), IRON)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.16, 0.5)), Vector3(0.14, 0.08, 0.6), Palette.WOOD_DARK)
	_seat(head, Vector3(0, 0.52, 1.12), team)
	var gun := MeshKit.begin()
	# Three short fat tubes on one trunnion bar, pointing along -Z.
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.06, 0.06, 1.3, 8, IRON)
	for x: float in TUBES_X:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, -0.18)), 0.17, 0.15, 0.75, 14, Palette.METAL.darkened(0.35))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, -0.52)), 0.19, 0.19, 0.07, 14, BRASS)
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0, 0.0)), 0.18, 0.18, 0.05, 14, IRON)
		MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(x, 0, 0.2)), Vector3.ONE * 0.17, 4, 10, Palette.METAL.darkened(0.45))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.1, 0.32)), Vector3(0.9, 0.06, 0.08), Palette.WOOD_DARK)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun), "recoil": 0.14,
			"head_y": 0.92, "head_z": HEAD_Z[&"thunder_mule"], "gun_y": 0.45, "muzzle": Vector3(0, 0, -0.58), "seat": seat(&"thunder_mule")}


## The three mortar tubes' x offsets in gun space (the salvo leaves one from each).
const TUBES_X: Array[float] = [-0.38, 0.0, 0.38]


## A patient mule standing at `at`, nose toward the back (+Z), ears up.
static func _mule(st: SurfaceTool, at: Vector3) -> void:
	var body := at + Vector3(0, 1.05, 0)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), body), Vector3(0.3, 0.32, 0.72), 6, 12, MULE)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), body + Vector3(0, -0.12, 0)), Vector3(0.26, 0.22, 0.6), 4, 10, MULE.lightened(0.15))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hip := body + Vector3(sx * 0.16, -0.12, sz * 0.48)
			var knee := hip + Vector3(0, -0.45, sz * 0.03)
			var hoof := knee + Vector3(0, -0.45, -sz * 0.02)
			MeshKit.add_limb(st, hip, knee, 0.075, MULE, 6)
			MeshKit.add_limb(st, knee, hoof, 0.055, MULE, 6)
			MeshKit.add_cylinder(st, Transform3D(Basis(), hoof + Vector3(0, 0.02, 0)), 0.07, 0.065, 0.08, 8, MULE_DARK.darkened(0.3))
	var neck_a := body + Vector3(0, 0.15, 0.55)
	var neck_b := body + Vector3(0, 0.55, 0.85)
	MeshKit.add_limb(st, neck_a, neck_b, 0.15, MULE, 8)
	var head := neck_b + Vector3(0, 0.02, 0.22)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.5), head), Vector3(0.13, 0.15, 0.3), 5, 10, MULE)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, 0.5), head + Vector3(0, -0.1, 0.2)), Vector3(0.11, 0.1, 0.13), 4, 8, MULE_DARK.lightened(0.3))
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, -sx * 0.25) * Basis(Vector3.RIGHT, -0.2), neck_b + Vector3(sx * 0.08, 0.3, -0.02)), 0.055, 0.015, 0.36, 6, MULE_DARK)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), head + Vector3(sx * 0.1, 0.06, 0.05)), Vector3.ONE * 0.025, 3, 6, Palette.OUTLINE)
	# Mane, tail, a blanket and a collar.
	MeshKit.add_limb(st, neck_a + Vector3(0, 0.15, -0.05), neck_b + Vector3(0, 0.15, -0.05), 0.04, MULE_DARK, 5)
	MeshKit.tube(st, [body + Vector3(0, 0.15, -0.7), body + Vector3(0, -0.05, -0.82), body + Vector3(0, -0.45, -0.8)], [0.04, 0.035, 0.06], 6, MULE_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), body + Vector3(0, 0.27, -0.05)), Vector3(0.66, 0.06, 0.6), Color("#B8352A"))
	MeshKit.add_box(st, Transform3D(Basis(), body + Vector3(0, 0.29, -0.05)), Vector3(0.68, 0.02, 0.1), Palette.GLOW_YELLOW.darkened(0.2))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 0.9), neck_a + Vector3(0, 0.1, 0.05)), 0.2, 0.2, 0.08, 10, Palette.WOOD_DARK)


# ------------------------------------------------------------------ Sky Hound

## Twin flak barrels on a sandbagged turntable, aimed by a seated gunner.
static func _sky_hound(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 704
	var base := MeshKit.begin()
	# A round plank turntable on a low stone footing, ringed with sandbags.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.15, 0)), 1.7, 1.75, 0.3, 24, Palette.ROCK_B.darkened(0.2))
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.33, 0)), 1.6, 1.6, 0.08, 24, Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.38, 0)), 1.62, 1.62, 0.03, 24, IRON)
	for i in 20:
		var a := TAU * float(i) / 20.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45:
			continue # a gap at the back to climb in
		var p := Vector3(cos(a) * 1.55, 0.55, sin(a) * 1.55)
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.18, 0.16, 0.3), 4, 8, Palette.SAND.darkened(0.12 + rng.randf() * 0.12), 0.08, rng)
	# Ready racks of brass shells.
	for i in 6:
		var p := Vector3(-1.05 + (i % 3) * 0.16, 0.6 + (i / 3) * 0.14, 0.95)
		MeshKit.add_cylinder(base, Transform3D(ACROSS, p), 0.06, 0.06, 0.34, 8, BRASS.darkened(0.05))
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(-0.9, 0.48, 0.95)), Vector3(0.6, 0.12, 0.42), Palette.WOOD_DARK)
	_flag(base, Vector3(1.25, 0.38, 1.0), 1.7, team)
	var head := MeshKit.begin()
	# Traversing carriage: an iron ring, two side cheeks with the team stripe, the seat.
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.75, 0.8, 0.1, 18, IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.48, 0.42, 0.0)), Vector3(0.08, 0.7, 0.55), Palette.METAL.darkened(0.2))
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.53, 0.45, 0.0)), Vector3(0.02, 0.12, 0.5), team)
		TurretBuilder._rivets(head, Vector3(s * 0.53, 0.2, 0), Vector3.BACK, 4, 0.13)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.16, 0.7)), Vector3(0.14, 0.08, 1.1), IRON)
	_seat(head, Vector3(0, 0.45, 1.2), team)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.07, 0.07, 0.95, 8, IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.18)), Vector3(0.72, 0.3, 0.5), Palette.METAL.darkened(0.25))
	for x: float in HOUND_BARRELS_X:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0.02, -0.75)), 0.08, 0.065, 1.7, 12, Palette.METAL.darkened(0.3))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0.02, -1.62)), 0.1, 0.1, 0.16, 12, IRON)
		for z: float in [-1.58, -1.66]:
			MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0.02, z)), 0.11, 0.11, 0.02, 12, IRON.darkened(0.2))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(x, 0.02, -0.2)), 0.12, 0.12, 0.12, 12, BRASS)
	# Ring sight on a post, and spade grips.
	MeshKit.add_limb(gun, Vector3(0, 0.15, -0.3), Vector3(0, 0.38, -0.3), 0.015, IRON, 4)
	var segs := 16
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		MeshKit.add_limb(gun, Vector3(cos(a0) * 0.13, 0.42 + sin(a0) * 0.13, -0.3), Vector3(cos(a1) * 0.13, 0.42 + sin(a1) * 0.13, -0.3), 0.01, IRON, 3)
	MeshKit.add_limb(gun, Vector3(-0.13, 0.42, -0.3), Vector3(0.13, 0.42, -0.3), 0.006, IRON, 3)
	MeshKit.add_limb(gun, Vector3(0, 0.29, -0.3), Vector3(0, 0.55, -0.3), 0.006, IRON, 3)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(gun, Vector3(s * 0.15, -0.05, 0.42), Vector3(s * 0.2, -0.1, 0.62), 0.025, IRON, 4)
		MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(s * 0.21, -0.1, 0.64)), 0.035, 0.035, 0.16, 6, Palette.WOOD_DARK)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun), "recoil": 0.16,
			"head_y": 0.42, "head_z": 0.0, "gun_y": 0.62, "muzzle": Vector3(HOUND_BARRELS_X[1], 0.02, -1.72), "seat": seat(&"sky_hound")}


## The Sky Hound's two barrels' x offsets in gun space (they fire in turn).
const HOUND_BARRELS_X: Array[float] = [-0.24, 0.24]
