class_name TurretBuilder
extends RefCounted
## Turret meshes in three parts so they can aim: base (static), head (yaws),
## gun (pitches). Gun barrels point along -Z; the muzzle offset is returned too.

## Returns {"base": ArrayMesh, "head": ArrayMesh, "gun": ArrayMesh, "head_y": float, "muzzle": Vector3}
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"buffalo_rifle":
			return _buffalo(team)
		&"water_cannon":
			return _water_cannon(team)
		&"chili_mortar":
			return _mortar(team, Palette.TEAM_WEST.darkened(0.2), 0.22)
		&"dynamite_lobber":
			return _mortar(team, Palette.WOOD_DARK, 0.3)
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


static func _gatling(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := MeshKit.begin()
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(1.5, 0.24, 1.5), Palette.WOOD_DARK, 0.03, rng)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.75, 0)), 0.22, 0.18, 1.1, 8, Palette.WOOD)
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var foot := Vector3(cos(a), 0.2, sin(a)) * 0.65
		MeshKit.add_limb(base, foot, Vector3(0, 0.9, 0), 0.06, Palette.WOOD_DARK, 5)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.3, 0.3, 0.16, 10, Palette.METAL)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.28, 0.25)), Vector3(0.7, 0.4, 0.06), Palette.METAL.darkened(0.2))
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.52, 0.25)), Vector3(0.5, 0.12, 0.08), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, 0.05)), 0.2, 0.2, 0.45, 10, Palette.METAL.darkened(0.1))
	for i in 6:
		var a := TAU * float(i) / 6.0
		MeshKit.add_cylinder(gun, Transform3D(along, Vector3(cos(a) * 0.09, sin(a) * 0.09, -0.45)), 0.03, 0.03, 0.9, 6, Palette.METAL.lightened(0.1))
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.85)), 0.15, 0.15, 0.06, 10, Palette.METAL.darkened(0.3))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.05, 0.4)), Vector3(0.12, 0.12, 0.3), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 1.35, "gun_y": 0.25, "muzzle": Vector3(0, 0, -0.95)}


static func _buffalo(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var base := MeshKit.begin()
	# Sandbag ring.
	for i in 10:
		var a := TAU * float(i) / 10.0
		var p := Vector3(cos(a), 0.22, sin(a)) * 0.85
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.18, 0.2, 0.32), 4, 8, Palette.SAND.darkened(0.15), 0.1, rng)
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.3
		var p := Vector3(cos(a), 0.55, sin(a)) * 0.75
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.17, 0.18, 0.3), 4, 8, Palette.SAND.darkened(0.25), 0.1, rng)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.7, 0)), 0.08, 0.08, 1.0, 6, Palette.WOOD_DARK)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.3, 0.12, 0.3), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0.2, 0.15, 0.0)), Vector3(0.04, 0.3, 0.12), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.75)), 0.04, 0.035, 1.5, 8, Palette.METAL)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.15)), Vector3(0.1, 0.14, 0.5), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.08, 0.5)), Vector3(0.09, 0.2, 0.35), Palette.WOOD)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0.09, -0.1)), 0.03, 0.03, 0.35, 6, Palette.METAL.darkened(0.3))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.03, -1.5)), Vector3(0.1, 0.1, 0.1), Palette.METAL.darkened(0.3))
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 1.2, "gun_y": 0.12, "muzzle": Vector3(0, 0, -1.55)}


## Simple shared base: a wooden platform on four legs.
static func _platform(st: SurfaceTool, rng: RandomNumberGenerator, top: float) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, top, 0)), Vector3(1.4, 0.18, 1.4), Palette.WOOD, 0.03, rng)
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.55, 0.55]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, top * 0.5, z)), Vector3(0.16, top, 0.16), Palette.WOOD_DARK, 0.02, rng)


static func _water_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var base := MeshKit.begin()
	_platform(base, rng, 0.6)
	# A water barrel feeding the cannon.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.0, 1.0, 0.45)), 0.35, 0.35, 0.7, 10, Palette.WOOD)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.0, 1.36, 0.45)), 0.3, 0.3, 0.04, 10, Palette.SKY_TOP, false, 0.4)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.25, 0.25, 0.14, 10, Palette.METAL)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.25, 0.2)), Vector3(0.4, 0.3, 0.05), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.3)), 0.16, 0.1, 0.8, 10, Palette.METAL.lightened(0.15))
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.75)), 0.08, 0.12, 0.15, 10, Palette.GLOW_YELLOW.darkened(0.3))
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 1.3, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.85)}


static func _mortar(team: Color, tube: Color, radius: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var base := MeshKit.begin()
	_platform(base, rng, 0.4)
	for i in 3:
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(-0.45 + i * 0.3, 0.62, 0.5)), 0.1, 0.1, 0.25, 8, Palette.TEAM_WEST if radius < 0.25 else Palette.ROOF)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.35, 0.35, 0.12, 10, Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0.3, 0.2, 0)), Vector3(0.05, 0.3, 0.3), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.2)), radius + 0.04, radius, 0.6, 12, tube)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.5)), radius + 0.06, radius + 0.06, 0.08, 12, Palette.METAL)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 0.6, "gun_y": 0.3, "muzzle": Vector3(0, 0, -0.55)}


static func _harpoon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var base := MeshKit.begin()
	_platform(base, rng, 0.7)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.4, 0.95, 0.4)), 0.22, 0.22, 0.3, 10, Palette.BONE.darkened(0.3))
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.3, 0.12, 0.3), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(-0.2, 0.15, 0.0)), Vector3(0.04, 0.3, 0.12), team)
	var gun := MeshKit.begin()
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, -0.2)), Vector3(0.12, 0.1, 1.0), Palette.WOOD)
	MeshKit.add_box(gun, Transform3D(Basis(Vector3.UP, 0.0), Vector3(0, 0.02, -0.55)), Vector3(1.0, 0.06, 0.08), Palette.WOOD_DARK)
	MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.08, -0.6)), 0.025, 0.0, 0.3, 6, Palette.METAL)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 1.3, "gun_y": 0.12, "muzzle": Vector3(0, 0.08, -0.75)}


## Last-line shotgun turret: squat sandbagged post with a fat double barrel.
static func _scattergun(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var base := MeshKit.begin()
	_platform(base, rng, 0.5)
	for i in 6:
		var a := TAU * float(i) / 6.0
		MeshKit.add_ellipsoid(base, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0.2, sin(a)) * 0.7), Vector3(0.16, 0.18, 0.28), 4, 8, Palette.SAND.darkened(0.2), 0.1, rng)
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.28, 0.28, 0.12, 10, Palette.METAL.darkened(0.2))
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.2, 0.2)), Vector3(0.45, 0.25, 0.05), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(along, Vector3(side * 0.06, 0, -0.35)), 0.06, 0.06, 0.8, 8, Palette.METAL)
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.15)), Vector3(0.2, 0.14, 0.35), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 1.0, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.78)}


## Last-line sniper: a tall lookout tower with a long rifle on top.
static func _sharpshooter(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var base := MeshKit.begin()
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.5, 0.5]:
			MeshKit.add_limb(base, Vector3(x * 1.3, 0, z * 1.3), Vector3(x, 2.6, z), 0.07, Palette.WOOD, 5)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 2.65, 0)), Vector3(1.3, 0.12, 1.3), Palette.WOOD_DARK, 0.03, rng)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 1.3, 0.62)), Vector3(0.9, 0.08, 0.06), Palette.WOOD_DARK)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.3, 0.12, 0.3), Palette.WOOD_DARK)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0.2, 0.2, 0)), Vector3(0.04, 0.35, 0.3), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.8)), 0.035, 0.03, 1.6, 8, Palette.METAL)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0.08, -0.2)), 0.04, 0.04, 0.4, 8, Palette.METAL.darkened(0.3))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.02, 0.2)), Vector3(0.1, 0.14, 0.5), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 2.85, "gun_y": 0.12, "muzzle": Vector3(0, 0, -1.6)}


## House turret: a twin repeater on a squat swivel post (fits under the porch roof).
static func _porch_repeater(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var base := MeshKit.begin()
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.45, 0.5, 0.16, 10, Palette.WOOD_DARK)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.12, 0.16, 0.7, 8, Palette.METAL.darkened(0.2))
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.22, 0.22, 0.1, 10, Palette.METAL)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.2, 0.22)), Vector3(0.5, 0.3, 0.05), Palette.METAL.darkened(0.25))
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.38, 0.22)), Vector3(0.36, 0.08, 0.06), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(gun, Transform3D(along, Vector3(side * 0.07, 0, -0.3)), 0.045, 0.045, 0.7, 8, Palette.METAL.lightened(0.1))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0, 0.08)), Vector3(0.26, 0.18, 0.32), Palette.METAL.darkened(0.1))
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, -0.04, 0.32)), Vector3(0.1, 0.12, 0.25), Palette.WOOD)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 0.85, "gun_y": 0.15, "muzzle": Vector3(0, 0, -0.66)}


## House turret: a stubby black cannon on a wooden carriage.
static func _rooftop_cannon(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var base := MeshKit.begin()
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.0, 0.3, 1.0), Palette.WOOD_DARK, 0.03, rng)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(side * 0.55, 0.3, 0)), 0.28, 0.28, 0.08, 12, Palette.WOOD)
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.7, 0.2, 0.6), Palette.WOOD, 0.02, rng)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.25, 0.3)), Vector3(0.5, 0.12, 0.04), team)
	var gun := MeshKit.begin()
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.25)), 0.2, 0.15, 0.9, 12, Palette.METAL.darkened(0.45))
	MeshKit.add_cylinder(gun, Transform3D(along, Vector3(0, 0, -0.72)), 0.2, 0.2, 0.1, 12, Palette.METAL.darkened(0.3))
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.22)), Vector3(0.2, 0.2, 0.2), 4, 8, Palette.METAL.darkened(0.45), 0.0, rng)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"head_y": 0.4, "gun_y": 0.35, "muzzle": Vector3(0, 0, -0.8)}
