class_name TurretBuilder
extends RefCounted
## Turret meshes in three parts so they can aim: base (static), head (yaws),
## gun (pitches). Gun barrels point along -Z; the muzzle offset is returned too.

## Returns {"base": ArrayMesh, "head": ArrayMesh, "gun": ArrayMesh, "head_y": float, "muzzle": Vector3}
static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		&"buffalo_rifle":
			return _buffalo(team)
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
