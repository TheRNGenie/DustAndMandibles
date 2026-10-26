class_name TurretBuilder
extends RefCounted
## Turret meshes in parts so they can aim and animate: base (static), head
## (yaws), gun (pitches), and optionally spin (barrels that whirl, in gun
## space at spin_at). Gun barrels point along -Z; the muzzle offset is returned.
## Every turret wears its team colour (a pennant, a shield stripe) and gets
## frontier detail: rivets, brass bands, ammo crates, sandbags, rope lashings.

## Returns {"base", "head", "gun": ArrayMesh, "head_y", "gun_y": float, "muzzle": Vector3,
##          optional "spin": ArrayMesh, "spin_at": Vector3, "recoil": float}
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"buffalo_rifle":
			return _buffalo(team)
		&"water_cannon":
			return _water_cannon(team)
		&"chili_mortar":
			return _mortar(team, Color("#B8352A"), 0.22, true)
		&"dynamite_lobber":
			return _mortar(team, Palette.WOOD_DARK, 0.3, false)
		&"lasso_harpoon":
			return _harpoon(team)
		&"scattergun_post":
			return _scattergun(team)
		&"sharpshooter_tower":
			return _sharpshooter(team)
		&"porch_repeater":
			return _porch_repeater(team)
		&"rooftop_cannon":
			return _rooftop_cannon(team)
		_:
			return _gatling(team)


const ALONG := Basis(Vector3.RIGHT, PI * 0.5)
const BRASS := Color("#D6A74A")
const IRON := Color("#4A4E58")


# ------------------------------------------------------------------ shared dressing

## A team pennant on a thin pole, planted at `at`.
static func _pennant(st: SurfaceTool, at: Vector3, h: float, team: Color) -> void:
	MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, h * 0.5, 0)), 0.025, 0.02, h, 5, Palette.WOOD_DARK)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, h + 0.03, 0)), Vector3.ONE * 0.04, 3, 6, BRASS)
	var top := at + Vector3(0, h - 0.05, 0)
	var n := Vector3(0, 0, 1)
	MeshKit.tri(st, top, top + Vector3(0.42, -0.1, 0), top + Vector3(0, -0.24, 0), n, n, n, MeshKit.vcol(team), n)
	MeshKit.tri(st, top, top + Vector3(0, -0.24, 0), top + Vector3(0.42, -0.1, 0), -n, -n, -n, MeshKit.vcol(team), -n)


static func _rivets(st: SurfaceTool, c: Vector3, along: Vector3, n: int, step: float, r: float = 0.022) -> void:
	for i in n:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + along * (float(i) - (n - 1) * 0.5) * step), Vector3.ONE * r, 3, 6, BRASS)


static func _crate(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, size: Vector3, turn: float, label: Color) -> void:
	var b := Basis(Vector3.UP, turn)
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, size.y * 0.5, 0)), size, Palette.WOOD, 0.02, rng)
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, size.y * 0.5, 0)), Vector3(size.x * 1.02, size.y * 0.14, size.z * 1.02), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, size.y * 0.55, -size.z * 0.51)), Vector3(size.x * 0.5, size.y * 0.3, 0.01), label)


static func _sandbags(st: SurfaceTool, rng: RandomNumberGenerator, r: float, rows: int, y0: float = 0.0) -> void:
	for row in rows:
		var n := 10 - row * 2
		for i in n:
			var a := TAU * float(i) / n + row * 0.3
			var p := Vector3(cos(a), y0 + 0.2 + row * 0.32, sin(a)) * Vector3(r - row * 0.08, 1, r - row * 0.08)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.18, 0.17, 0.3), 4, 8,
					Palette.SAND.darkened(0.12 + rng.randf() * 0.12), 0.08, rng)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), p + Vector3(0, 0.16, 0)), Vector3(0.04, 0.02, 0.28), Palette.WOOD_DARK)


## A wooden platform on four braced legs.
static func _platform(st: SurfaceTool, rng: RandomNumberGenerator, top: float) -> void:
	for i in 5:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.56 + i * 0.28, top, 0)), Vector3(0.26, 0.16, 1.45), Palette.WOOD.darkened(rng.randf() * 0.12), 0.02, rng)
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.55, 0.55]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, top * 0.5, z)), Vector3(0.16, top, 0.16), Palette.WOOD_DARK, 0.02, rng)
	for z: float in [-0.55, 0.55]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0, top * 0.45, z)), Vector3(1.1, 0.07, 0.06), Palette.WOOD_DARK)


# ------------------------------------------------------------------ cliff turrets

## Gatling post: a hand-cranked six-barrel gun on a tripod, ammo drum on top.
static func _gatling(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := MeshKit.begin()
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(1.5, 0.2, 1.5), Palette.WOOD_DARK, 0.03, rng)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.75, 0)), 0.2, 0.16, 1.1, 8, Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 1.22, 0)), 0.24, 0.24, 0.08, 10, IRON)
	for a: float in [0.3, PI * 0.5 + 0.3, PI + 0.3, PI * 1.5 + 0.3]:
		var foot := Vector3(cos(a), 0.2, sin(a)) * 0.65
		MeshKit.add_limb(base, foot, Vector3(0, 0.95, 0), 0.06, Palette.WOOD_DARK, 5)
		MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, -a), foot + Vector3(0, -0.04, 0)), Vector3(0.18, 0.06, 0.18), IRON)
	_crate(base, rng, Vector3(0.45, 0.2, 0.45), Vector3(0.38, 0.28, 0.28), 0.4, BRASS)
	_pennant(base, Vector3(-0.62, 0.2, 0.6), 1.6, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.3, 0.3, 0.14, 12, IRON)
	# Riveted gun shield with a team stripe.
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.3, -0.18)), Vector3(0.8, 0.45, 0.05), Palette.METAL.darkened(0.15))
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.45, -0.21)), Vector3(0.8, 0.09, 0.02), team)
	_rivets(head, Vector3(0, 0.12, -0.22), Vector3.RIGHT, 6, 0.13)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.32, 0.12, 0.05)), Vector3(0.05, 0.22, 0.12), IRON)
	var gun := MeshKit.begin()
	# Breech housing, crank handle, and a big drum magazine on top.
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.12)), 0.18, 0.18, 0.4, 12, Palette.METAL.darkened(0.1))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.08)), 0.2, 0.2, 0.05, 12, BRASS)
	MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.24, 0, 0.18)), 0.03, 0.03, 0.12, 6, IRON)
	MeshKit.add_limb(gun, Vector3(0.3, 0, 0.18), Vector3(0.3, -0.12, 0.18), 0.02, IRON, 4)
	MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.36, -0.12, 0.18)), 0.035, 0.035, 0.1, 6, Palette.WOOD)
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.26, 0.1)), 0.16, 0.16, 0.1, 14, BRASS.darkened(0.15))
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.32, 0.1)), 0.05, 0.05, 0.04, 8, IRON)
	# The barrel cluster spins on its own.
	var spin := MeshKit.begin()
	for i in 6:
		var a := TAU * float(i) / 6.0
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(cos(a) * 0.09, sin(a) * 0.09, -0.4)), 0.03, 0.03, 0.85, 6, Palette.METAL.lightened(0.1))
	for z: float in [-0.15, -0.55, -0.8]:
		MeshKit.add_cylinder(spin, Transform3D(ALONG, Vector3(0, 0, z)), 0.14, 0.14, 0.04, 10, BRASS if z > -0.7 else IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"spin": MeshKit.finish(spin), "spin_at": Vector3(0, 0, -0.1), "recoil": 0.03,
			"head_y": 1.3, "gun_y": 0.12, "muzzle": Vector3(0, 0, -0.95)}


## Buffalo rifle: a long-barrelled big-game gun in a sandbag nest, ammo crate beside.
static func _buffalo(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var base := MeshKit.begin()
	_sandbags(base, rng, 0.85, 2)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.7, 0)), 0.08, 0.08, 1.0, 6, Palette.WOOD_DARK)
	_crate(base, rng, Vector3(0.35, 0.0, 0.45), Vector3(0.4, 0.3, 0.3), -0.3, BRASS)
	for i in 4:
		MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.28 + i * 0.05, 0.32, 0.4)), 0.015, 0.015, 0.1, 6, BRASS)
	_pennant(base, Vector3(-0.7, 0.3, 0.55), 1.5, team)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.32, 0.12, 0.32), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0.2, 0.15, 0.0)), Vector3(0.04, 0.3, 0.14), team)
	MeshKit.add_cylinder(head, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.1, 0)), 0.035, 0.035, 0.36, 6, IRON)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.75)), 0.045, 0.038, 1.5, 8, Palette.METAL)
	for z: float in [-0.4, -1.1]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.055, 0.055, 0.05, 8, BRASS)
	# Scope with brass caps.
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.1, -0.15)), 0.035, 0.035, 0.6, 8, IRON)
	for z: float in [0.14, -0.44]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.1, z)), 0.045, 0.045, 0.04, 8, BRASS)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.15)), Vector3(0.1, 0.14, 0.5), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.08, 0.5)), Vector3(0.09, 0.2, 0.35), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.03, -1.52)), Vector3(0.1, 0.1, 0.06), IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.12, "head_y": 1.2, "gun_y": 0.12, "muzzle": Vector3(0, 0, -1.55)}


## Water cannon: a brass fire-hose nozzle fed by a hooped barrel and a hand pump.
static func _water_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var base := MeshKit.begin()
	_platform(base, rng, 0.6)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.0, 1.05, 0.45)), 0.36, 0.33, 0.8, 12, Palette.WOOD)
	for y: float in [0.75, 1.05, 1.35]:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.0, y, 0.45)), 0.37, 0.37, 0.04, 12, IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.0, 1.45, 0.45)), 0.3, 0.3, 0.03, 12, Palette.SKY_TOP, false, 0.4)
	# Pump handle and hose snaking into the head.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.45, 0.95, 0.45)), 0.05, 0.05, 0.5, 6, IRON)
	MeshKit.add_limb(base, Vector3(0.45, 1.2, 0.45), Vector3(0.65, 1.35, 0.3), 0.025, Palette.WOOD_DARK, 4)
	MeshKit.add_limb(base, Vector3(0, 0.95, 0.12), Vector3(0, 1.15, -0.05), 0.05, Color("#7A2E22"), 6)
	_pennant(base, Vector3(-0.65, 0.68, 0.62), 1.3, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.25, 0.25, 0.14, 12, IRON)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.25, 0.2)), Vector3(0.4, 0.3, 0.05), team)
	_rivets(head, Vector3(0, 0.13, 0.17), Vector3.RIGHT, 4, 0.1)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.3)), 0.16, 0.09, 0.8, 12, BRASS)
	for z: float in [-0.05, -0.35, -0.6]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.17 - z * -0.08, 0.17 - z * -0.08, 0.04, 12, BRASS.darkened(0.3))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.75)), 0.07, 0.1, 0.12, 12, IRON)
	MeshKit.add_cylinder(gun, Transform3D(Basis(), Vector3(0, 0.15, -0.1)), 0.02, 0.02, 0.12, 6, IRON)
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0.22, -0.1)), Vector3(0.06, 0.02, 0.06), 3, 8, Color("#B8352A"))
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.05, "head_y": 1.3, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.85)}


## Mortars: a stubby tube on a turntable. The chili mortar has a basket of
## chilies; the dynamite lobber has a crate of red sticks with fuses.
static func _mortar(team: Color, tube: Color, radius: float, chili: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 if chili else 42
	var base := MeshKit.begin()
	_platform(base, rng, 0.4)
	if chili:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(-0.35, 0.65, 0.4)), 0.25, 0.2, 0.3, 10, Color("#C8A878"))
		for i in 9:
			var a := rng.randf() * TAU
			MeshKit.add_cylinder(base, Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 1.2), Vector3(-0.35 + cos(a) * 0.12, 0.84, 0.4 + sin(a) * 0.12)), 0.035, 0.0, 0.16, 6, Color("#E3361F"))
	else:
		_crate(base, rng, Vector3(-0.35, 0.48, 0.4), Vector3(0.45, 0.22, 0.3), 0.0, Color("#B8352A"))
		for i in 5:
			MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(-0.5 + i * 0.075, 0.76, 0.4)), 0.03, 0.03, 0.22, 6, Color("#C8352A"))
			MeshKit.add_limb(base, Vector3(-0.5 + i * 0.075, 0.87, 0.43), Vector3(-0.49 + i * 0.075, 0.95, 0.47), 0.006, Palette.BONE, 3)
	_pennant(base, Vector3(0.6, 0.48, 0.6), 1.2, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.38, 0.38, 0.12, 14, Palette.WOOD_DARK)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.4, 0.4, 0.03, 14, IRON)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.28, 0.22, 0)), Vector3(0.06, 0.32, 0.22), IRON)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.2, 0.3)), Vector3(0.3, 0.12, 0.04), team)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.2)), radius + 0.05, radius, 0.6, 14, tube)
	for z: float in [0.05, -0.2, -0.45]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), radius + 0.07, radius + 0.07, 0.05, 14, IRON if z != -0.2 else BRASS)
	MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, -0.05)), 0.05, 0.05, radius * 2.0 + 0.24, 8, IRON)
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.12)), Vector3.ONE * (radius + 0.03), 4, 10, tube.darkened(0.2))
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.1, "head_y": 0.6, "gun_y": 0.3, "muzzle": Vector3(0, 0, -0.55)}


## Lasso harpoon: a big crossbow with a coiled rope drum and a barbed bolt.
static func _harpoon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var base := MeshKit.begin()
	_platform(base, rng, 0.7)
	# Rope coil on a drum.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.4, 0.98, 0.4)), 0.24, 0.24, 0.3, 12, Color("#C8A060"))
	for k in 5:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.4, 0.86 + k * 0.06, 0.4)), 0.25, 0.25, 0.015, 12, Color("#9A7A44"))
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.4, 1.15, 0.4)), 0.28, 0.28, 0.03, 12, Palette.WOOD_DARK)
	_pennant(base, Vector3(-0.62, 0.78, 0.62), 1.2, team)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.32, 0.12, 0.32), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(-0.2, 0.15, 0.0)), Vector3(0.04, 0.3, 0.14), team)
	var gun := MeshKit.begin()
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, -0.2)), Vector3(0.14, 0.1, 1.0), Palette.WOOD)
	# Bow arms curving forward, with the string.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(gun, Vector3(0, 0.02, -0.55), Vector3(s * 0.32, 0.02, -0.5), 0.035, Palette.WOOD_DARK, 5)
		MeshKit.add_limb(gun, Vector3(s * 0.32, 0.02, -0.5), Vector3(s * 0.52, 0.02, -0.38), 0.025, Palette.WOOD_DARK, 5)
		MeshKit.add_limb(gun, Vector3(s * 0.52, 0.02, -0.38), Vector3(0, 0.06, 0.05), 0.006, Palette.BONE, 3)
	# Barbed harpoon bolt.
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.08, -0.35)), 0.018, 0.018, 0.75, 6, IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.08, -0.78)), 0.05, 0.0, 0.14, 6, Palette.METAL.lightened(0.2))
	for s: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.UP, s * 0.6) * ALONG, Vector3(s * 0.03, 0.08, -0.7)), 0.01, 0.0, 0.08, 4, IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.08, 0.2)), Vector3(0.08, 0.12, 0.1), IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.08, "head_y": 1.3, "gun_y": 0.12, "muzzle": Vector3(0, 0.08, -0.85)}


# ------------------------------------------------------------------ last-line turrets

## Scattergun post: squat sandbagged post with a fat double barrel.
static func _scattergun(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var base := MeshKit.begin()
	_sandbags(base, rng, 0.75, 2)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.6, 0)), 0.12, 0.15, 0.9, 8, IRON)
	for i in 5:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.45 + (i % 2) * 0.05, 0.08, 0.3 + i * 0.05)), 0.022, 0.022, 0.07, 6, Color("#B8352A"))
	_pennant(base, Vector3(-0.6, 0.2, 0.55), 1.3, team)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.28, 0.28, 0.12, 12, IRON)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.2, 0.2)), Vector3(0.45, 0.25, 0.05), team)
	var gun := MeshKit.begin()
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(side * 0.065, 0, -0.35)), 0.065, 0.06, 0.8, 10, Palette.METAL)
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(side * 0.065, 0, -0.75)), 0.072, 0.072, 0.04, 10, IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.07, -0.35)), Vector3(0.03, 0.03, 0.75), IRON)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.08)), Vector3(0.24, 0.16, 0.18), Color("#6F6A66"))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.28)), Vector3(0.2, 0.14, 0.3), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.15, "head_y": 1.0, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.78)}


## Sharpshooter tower: a tall lookout with a little roof, a ladder, and a long rifle.
static func _sharpshooter(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var base := MeshKit.begin()
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.5, 0.5]:
			MeshKit.add_limb(base, Vector3(x * 1.3, 0, z * 1.3), Vector3(x, 2.6, z), 0.07, Palette.WOOD, 5)
	for y: float in [0.9, 1.8]:
		for z: float in [-0.5, 0.5]:
			MeshKit.add_box(base, Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0, y, z * (1.0 + (2.6 - y) / 2.6 * 0.3))), Vector3(1.2, 0.06, 0.05), Palette.WOOD_DARK)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 2.65, 0)), Vector3(1.3, 0.12, 1.3), Palette.WOOD_DARK, 0.03, rng)
	# Railing and a slanted roof on posts.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.62, 3.0, 0)), Vector3(0.05, 0.6, 1.3), Palette.WOOD)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 3.0, s * 0.62)), Vector3(1.3, 0.6, 0.05), Palette.WOOD)
		for t: float in [-1.0, 1.0]:
			MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.6, 3.5, t * 0.6)), Vector3(0.07, 1.6, 0.07), Palette.WOOD_DARK)
	MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(0, 4.35, 0)), Vector3(1.6, 0.08, 1.6), Palette.ROOF)
	# Ladder up one side.
	for s: float in [-0.18, 0.18]:
		MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(s, 1.3, 0.78)), Vector3(0.05, 2.7, 0.05), Palette.WOOD)
	for i in 8:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.25 + i * 0.32, 0.6 + 0.2 * (1.0 - i / 8.0))), Vector3(0.38, 0.04, 0.04), Palette.WOOD)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 3.0, -0.65)), Vector3(0.7, 0.25, 0.02), team)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.3, 0.12, 0.3), Palette.WOOD_DARK)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.8)), 0.035, 0.03, 1.6, 8, Palette.METAL)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.09, -0.2)), 0.04, 0.04, 0.5, 8, IRON)
	for z: float in [0.05, -0.45]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0.09, z)), 0.05, 0.05, 0.03, 8, BRASS)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.2)), Vector3(0.1, 0.14, 0.5), Palette.WOOD)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(gun, Vector3(0, -0.02, -0.6), Vector3(s * 0.15, -0.3, -0.7), 0.012, IRON, 4)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.1, "head_y": 2.85, "gun_y": 0.12, "muzzle": Vector3(0, 0, -1.6)}


# ------------------------------------------------------------------ house turrets

## Porch repeater: a twin repeater on a squat swivel post (fits under the porch roof).
static func _porch_repeater(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var base := MeshKit.begin()
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.45, 0.5, 0.16, 12, Palette.WOOD_DARK)
	_rivets(base, Vector3(0, 0.17, 0.4), Vector3.RIGHT, 5, 0.12)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.12, 0.16, 0.7, 10, IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.8, 0)), 0.18, 0.18, 0.06, 10, BRASS)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.22, 0.22, 0.1, 12, Palette.METAL)
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 0.2, -0.22)), Vector3(0.52, 0.3, 0.05), Palette.METAL.darkened(0.25))
	MeshKit.add_box(head, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 0.33, -0.245)), Vector3(0.52, 0.06, 0.02), team)
	_rivets(head, Vector3(0, 0.1, -0.25), Vector3.RIGHT, 4, 0.12, 0.016)
	var gun := MeshKit.begin()
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(side * 0.07, 0, -0.3)), 0.045, 0.045, 0.7, 8, Palette.METAL.lightened(0.1))
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(side * 0.07, 0, -0.64)), 0.052, 0.052, 0.04, 8, BRASS)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.08)), Vector3(0.26, 0.18, 0.32), Palette.METAL.darkened(0.1))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.04, 0.32)), Vector3(0.1, 0.12, 0.25), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.14, 0.05)), Vector3(0.12, 0.1, 0.2), BRASS.darkened(0.2))
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.05, "head_y": 0.85, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.66)}


## Rooftop cannon: a stubby black cannon on a spoked-wheel carriage, shot stacked by it.
static func _rooftop_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var base := MeshKit.begin()
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.0, 0.3, 1.0), Palette.WOOD_DARK, 0.03, rng)
	for side: float in [-1.0, 1.0]:
		var hub := Vector3(side * 0.55, 0.3, 0)
		MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.BACK, PI * 0.5), hub), 0.3, 0.3, 0.06, 14, Palette.WOOD)
		MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.BACK, PI * 0.5), hub + Vector3(side * 0.01, 0, 0)), 0.31, 0.31, 0.03, 14, IRON)
		for k in 6:
			var a := TAU * k / 6.0
			MeshKit.add_box(base, Transform3D(Basis(Vector3.RIGHT, a), hub + Vector3(side * 0.035, 0, 0)), Vector3(0.02, 0.5, 0.03), Palette.WOOD_DARK)
	for i in 3:
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(-0.3 + i * 0.15, 0.38, 0.38)), Vector3.ONE * 0.07, 4, 8, IRON.darkened(0.3))
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(-0.22, 0.5, 0.38)), Vector3.ONE * 0.07, 4, 8, IRON.darkened(0.3))
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.7, 0.2, 0.6), Palette.WOOD, 0.02, rng)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.25, 0.3)), Vector3(0.5, 0.12, 0.04), team)
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.25)), 0.2, 0.15, 0.9, 14, IRON.darkened(0.4))
	for z: float in [0.0, -0.4]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.21 - z * 0.08, 0.21 - z * 0.08, 0.05, 14, BRASS.darkened(0.25))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.72)), 0.2, 0.2, 0.1, 14, IRON.darkened(0.2))
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.22)), Vector3(0.2, 0.2, 0.2), 4, 10, IRON.darkened(0.4), 0.0, rng)
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.44)), Vector3.ONE * 0.05, 3, 8, IRON)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.14, "head_y": 0.4, "gun_y": 0.35, "muzzle": Vector3(0, 0, -0.8)}
